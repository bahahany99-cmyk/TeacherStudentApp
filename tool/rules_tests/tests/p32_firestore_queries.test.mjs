/**
 * P32 (إصلاح 1 و4) — **استعلامات تنفيذ Firestore الفعلية على المحاكي**.
 *
 * لماذا هذا الملف؟ لأن اختبارات Dart في `test/` تعمل على منطق نقي وعلى
 * المستودعات التجريبية فقط: لا يستورد أيٌّ منها `firestore_repositories.dart`،
 * و`cloud_firestore` لا يعمل في `flutter test` (يحتاج قناة منصّة أصلية).
 * فنجاح اختبارات Dart لا يثبت أن **الاستعلامات** التي يُنفّذها التطبيق صحيحة
 * (ترتيب، مؤشر، سقف، حصر).
 *
 * هنا نُنفّذ **نفس شكل الاستعلامات** التي يبنيها التنفيذ الحقيقي، على خادم
 * Firestore المحاكي وبقواعد المشروع نفسها:
 *
 *  1) `listPage`      → `where(recipientId==) + orderBy(createdAt desc)
 *                        + orderBy(__name__ asc) + limit(n+1) + startAfter(...)`
 *  2) `markChatMessagesRead` → `where(recipientId==) + where(type==)
 *                        + where(targetId==) + where(readAt isNull)` ثم تحديث `readAt`.
 *  3) `unreadCount`   → تجميعان: `count(sentAt > lastReadAt)` و
 *                        `count(sentAt > lastReadAt && senderId == me)` ثم الفرق.
 *  4) `markRead`      → كتابة `lastReadAt` في `studyGroups/{id}/reads/{uid}`.
 *
 * **حدود هذا الاختبار (بصراحة):** لا يُشغّل كود Dart؛ يُثبت أن **شكل الاستعلام**
 * صحيح على Firestore حقيقي، وأن القواعد تسمح له بالضبط. ولا يُثبت أن المحاكي
 * يفرض الفهرس المركّب (المحاكي لا يفرضه) — مطابقة الفهرس تبقى خطوة تحقّق يدوية
 * قبل النشر.
 *
 * يُشغَّل مع بقية اختبارات القواعد: `npm --prefix tool/rules_tests test`
 */

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { after, before, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  Timestamp,
  collection,
  documentId,
  doc,
  getCountFromServer,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  setDoc,
  startAfter,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const RULES = readFileSync(resolve('../../firestore.rules'), 'utf8');
const PROJECT_ID = 'demo-darsly';
const HOST_PORT = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');

/** صفحة الإشعارات في التطبيق: `NotificationRules.pageSize`. */
const PAGE_SIZE = 20;
const at = (minutes) => new Date(Date.UTC(2026, 10, 4, 9, minutes, 0));

/** لحظة قبل [minutes] من الآن — لاختبارات تعتمد على «قرأت الآن». */
const minutesAgo = (minutes) => new Date(Date.now() - minutes * 60 * 1000);

let testEnv;

const asStudent = () => testEnv.authenticatedContext('student-1').firestore();
const asTeacher = () => testEnv.authenticatedContext('teacher-1').firestore();

async function seed(writes) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const { path, data } of writes) {
      await setDoc(doc(db, path), data);
    }
  });
}

async function readRaw(path) {
  let data = null;
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const snap = await getDoc(doc(context.firestore(), path));
    data = snap.exists() ? snap.data() : null;
  });
  return data;
}

/**
 * إشعار كما يكتبه التطبيق (**بـ`readAt: null` صريح**).
 *
 * هذا مقصود: التطبيق يكتب `readAt` فارغًا عند الإنشاء، لأن Firestore لا
 * يُطابق «غياب الحقل» بشرط `readAt == null` — وهو ما يُثبته الاختبار الأخير
 * في هذا الملف. بدون الحقل الصريح لا يظهر الإشعار في عدّاد الجرس ولا يُعلَّم
 * مقروءًا أبدًا.
 */
const notificationDoc = (recipientId, overrides = {}) => ({
  recipientId,
  type: 'bookingAccepted',
  actorId: 'teacher-1',
  actorName: 'أ. سارة الخطيب',
  targetId: 'b1',
  title: 'إشعار',
  createdAt: at(0),
  readAt: null,
  ...overrides,
});

/** رسالة مجموعة: الحقول التي يقرأها عدّ غير المقروء. */
const groupMessage = (senderId, sentAt, overrides = {}) => ({
  groupId: 'g1',
  senderId,
  senderName: senderId,
  senderRole: 'student',
  text: 'رسالة',
  sentAt,
  ...overrides,
});

const seedGroup = () =>
  seed([
    {
      path: 'studyGroups/g1',
      data: {
        teacherId: 'teacher-1',
        teacherName: 'أ. سارة الخطيب',
        title: 'التفاضل',
        subject: 'الرياضيات',
        stage: 'الثانوية العامة',
        seatsTotal: 12,
        seatsTaken: 1,
        meetingMode: 'center',
        scheduleNote: 'السبت 5 م',
        isActive: true,
      },
    },
    {
      path: 'studyGroups/g1/members/student-1',
      data: {
        studentId: 'student-1',
        name: 'طالب',
        joinedAt: at(0),
        status: 'active',
      },
    },
  ]);

// ── استعلامات مطابقة لما يبنيه التنفيذ الحقيقي ────────────────────────────────

/** نفس استعلام `FirestoreNotificationRepository.listPage`. */
const pageQuery = (db, recipientId, pageSize, before = null) => {
  let q = query(
    collection(db, 'notifications'),
    where('recipientId', '==', recipientId),
    orderBy('createdAt', 'desc'),
    orderBy(documentId()),
    limit(pageSize + 1),
  );
  if (before != null) {
    q = query(
      collection(db, 'notifications'),
      where('recipientId', '==', recipientId),
      orderBy('createdAt', 'desc'),
      orderBy(documentId()),
      startAfter(Timestamp.fromDate(before.createdAt), before.id),
      limit(pageSize + 1),
    );
  }
  return q;
};

/** نفس استعلام `markChatMessagesRead` (بدون الكتابة). */
const unreadChatQuery = (db, recipientId, chatId) =>
  query(
    collection(db, 'notifications'),
    where('recipientId', '==', recipientId),
    where('type', '==', 'directMessage'),
    where('targetId', '==', chatId),
    where('readAt', '==', null),
  );

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: RULES,
      host: HOST_PORT[0],
      port: Number(HOST_PORT[1]),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// ═════════════════════════════════════════════════════════════════════════════
describe('P32 — listPage على Firestore الفعلي', () => {
  it('صفحتان بلا فقد ولا تكرار عبر startAfter(createdAt, id)', async () => {
    await seed(
      Array.from({ length: 45 }, (_, i) => ({
        path: `notifications/n${String(i).padStart(2, '0')}`,
        data: notificationDoc('student-1', { createdAt: at(i) }),
      })),
    );

    const db = asStudent();
    const collected = [];
    let cursor = null;

    for (let page = 0; page < 5; page++) {
      const snap = await assertSucceeds(getDocs(pageQuery(db, 'student-1', PAGE_SIZE, cursor)));
      const docs = snap.docs;
      const hasMore = docs.length > PAGE_SIZE;
      const visible = hasMore ? docs.slice(0, PAGE_SIZE) : docs;
      for (const item of visible) {
        collected.push(item.id);
        cursor = { id: item.id, createdAt: item.data().createdAt.toDate() };
      }
      if (!hasMore) {
        break;
      }
    }

    assert.equal(collected.length, 45, 'كل الإشعارات وصلت');
    assert.equal(new Set(collected).size, 45, 'لا تكرار بين الصفحتين');
    // الأحدث أولًا: n44 الأحدث (at(44)) ثم تنازليًا حتى n00.
    assert.deepEqual(collected, Array.from({ length: 45 }, (_, i) => `n${String(44 - i).padStart(2, '0')}`));
  });

  it('تساوي createdAt: الترتيب بالمعرّف تصاعديًا ولا يُسقط أحدًا', async () => {
    const sameInstant = at(10);
    await seed(
      ['n3', 'n1', 'n5', 'n2', 'n4'].map((id) => ({
        path: `notifications/${id}`,
        data: notificationDoc('student-1', { createdAt: sameInstant }),
      })),
    );

    const db = asStudent();
    const collected = [];
    let cursor = null;

    for (let page = 0; page < 6; page++) {
      const snap = await assertSucceeds(getDocs(pageQuery(db, 'student-1', 2, cursor)));
      const docs = snap.docs;
      const hasMore = docs.length > 2;
      const visible = hasMore ? docs.slice(0, 2) : docs;
      for (const item of visible) {
        collected.push(item.id);
        cursor = { id: item.id, createdAt: item.data().createdAt.toDate() };
      }
      if (!hasMore) {
        break;
      }
    }

    assert.deepEqual(collected, ['n1', 'n2', 'n3', 'n4', 'n5'], 'الترتيب حتمي عند تساوي الوقت');
  });

  it('hasMore ونهاية القائمة: 3 إشعارات وصفحة بحجم 4', async () => {
    await seed(
      ['a', 'b', 'c'].map((id, i) => ({
        path: `notifications/${id}`,
        data: notificationDoc('student-1', { createdAt: at(i) }),
      })),
    );

    const db = asStudent();
    const first = await assertSucceeds(getDocs(pageQuery(db, 'student-1', 4)));
    assert.equal(first.docs.length, 3);
    assert.equal(first.docs.length > 4, false, 'hasMore = false');

    // طلب «ما بعد الأخير» يعيد لا شيء — أي أن الشاشة تقول «وصلت إلى النهاية».
    const lastDoc = first.docs[first.docs.length - 1];
    const second = await assertSucceeds(
      getDocs(
        pageQuery(db, 'student-1', 4, {
          id: lastDoc.id,
          createdAt: lastDoc.data().createdAt.toDate(),
        }),
      ),
    );
    assert.equal(second.docs.length, 0);
  });

  it('لا يقرأ إشعارات مستخدم آخر (القواعد ترفض الاستعلام لغيره)', async () => {
    await seed([
      { path: 'notifications/mine', data: notificationDoc('student-1') },
      { path: 'notifications/other', data: notificationDoc('teacher-1') },
    ]);

    const db = asStudent();
    const snap = await assertSucceeds(getDocs(pageQuery(db, 'student-1', PAGE_SIZE)));
    assert.deepEqual(snap.docs.map((d) => d.id), ['mine']);

    // طلب صريح لإشعارات غيره مرفوض (القواعد ليست مُرشِّحًا).
    await assertFails(getDocs(pageQuery(db, 'teacher-1', PAGE_SIZE)));
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe('P32 — markChatMessagesRead على Firestore الفعلي', () => {
  const seedChats = () =>
    seed([
      {
        path: 'notifications/dm-1',
        data: notificationDoc('student-1', {
          type: 'directMessage',
          targetId: 'chat-1',
          createdAt: at(1),
        }),
      },
      {
        path: 'notifications/dm-2',
        data: notificationDoc('student-1', {
          type: 'directMessage',
          targetId: 'chat-1',
          createdAt: at(2),
        }),
      },
      {
        path: 'notifications/dm-read',
        data: notificationDoc('student-1', {
          type: 'directMessage',
          targetId: 'chat-1',
          createdAt: at(3),
          readAt: at(4),
        }),
      },
      {
        path: 'notifications/dm-other-chat',
        data: notificationDoc('student-1', {
          type: 'directMessage',
          targetId: 'chat-2',
          createdAt: at(5),
        }),
      },
      {
        path: 'notifications/booking-same-target',
        data: notificationDoc('student-1', {
          type: 'bookingAccepted',
          targetId: 'chat-1',
          createdAt: at(6),
        }),
      },
      {
        path: 'notifications/dm-other-user',
        data: notificationDoc('teacher-1', {
          type: 'directMessage',
          targetId: 'chat-1',
          createdAt: at(7),
        }),
      },
    ]);

  it('يُعلّم إشعارات المحادثة المحددة فقط، ولا يمسّ غيرها', async () => {
    await seedChats();
    const db = asStudent();

    const unread = await assertSucceeds(getDocs(unreadChatQuery(db, 'student-1', 'chat-1')));
    assert.deepEqual(unread.docs.map((d) => d.id).sort(), ['dm-1', 'dm-2']);

    const batch = writeBatch(db);
    for (const item of unread.docs) {
      batch.update(item.ref, { readAt: new Date() });
    }
    await assertSucceeds(batch.commit());

    assert.equal((await readRaw('notifications/dm-1')).readAt != null, true);
    assert.equal((await readRaw('notifications/dm-2')).readAt != null, true);

    // ما لا يجب أن يُمسّ:
    assert.ok((await readRaw('notifications/booking-same-target')).readAt == null, 'إشعار حجز بنفس targetId لم يُمسّ');
    assert.ok((await readRaw('notifications/dm-other-chat')).readAt == null, 'محادثة أخرى لم تُمسّ');
    assert.ok((await readRaw('notifications/dm-other-user')).readAt == null, 'إشعار مستخدم آخر لم يُمسّ');
    assert.equal(
      (await readRaw('notifications/dm-read')).readAt.toDate().toISOString(),
      at(4).toISOString(),
      'ما كان مقروءًا يبقى بلحظته',
    );

    // التشغيل الثاني لا يجد شيئًا ⇒ لا كتابة (نفس سلوك التنفيذ الحقيقي).
    const again = await assertSucceeds(getDocs(unreadChatQuery(db, 'student-1', 'chat-1')));
    assert.equal(again.docs.length, 0);
  });

  it('لا يستطيع تعليم إشعار مستخدم آخر (القواعد ترفض)', async () => {
    await seedChats();
    const db = asStudent();

    await assertFails(updateDoc(doc(db, 'notifications/dm-other-user'), { readAt: new Date() }));
    await assertFails(getDocs(unreadChatQuery(db, 'teacher-1', 'chat-1')));
  });

  it('غياب حقل readAt لا يُطابق الشرط — لذلك يكتبه التطبيق null صريحًا', async () => {
    // يوثّق سبب وجود `'readAt': null` في `FirestoreNotificationRepository.push`:
    // لو غاب الحقل لما ظهر الإشعار في عدّاد الجرس ولا في هذا الاستعلام إطلاقًا.
    await seed([
      {
        path: 'notifications/missing-field',
        data: {
          recipientId: 'student-1',
          type: 'directMessage',
          actorId: 'teacher-1',
          actorName: 'أ. سارة الخطيب',
          targetId: 'chat-1',
          title: 'إشعار',
          createdAt: at(0),
        },
      },
      {
        path: 'notifications/explicit-null',
        data: notificationDoc('student-1', { type: 'directMessage', targetId: 'chat-1' }),
      },
    ]);

    const db = asStudent();
    const snap = await assertSucceeds(getDocs(unreadChatQuery(db, 'student-1', 'chat-1')));
    assert.deepEqual(
      snap.docs.map((d) => d.id),
      ['explicit-null'],
      'الحقل الصريح فقط يُطابق readAt == null',
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe('P32 — unreadCount على Firestore الفعلي (إصلاح 1)', () => {
  /** نفس تجميعَي `FirestoreMessageRepository.unreadCount`. */
  const countAfterRead = async (db, readAt) => {
    const filters = readAt == null ? [] : [where('sentAt', '>', Timestamp.fromDate(readAt))];
    const total = (
      await assertSucceeds(
        getCountFromServer(query(collection(db, 'studyGroups/g1/messages'), ...filters)),
      )
    ).data().count;
    const own = (
      await assertSucceeds(
        getCountFromServer(
          query(
            collection(db, 'studyGroups/g1/messages'),
            ...filters,
            where('senderId', '==', 'student-1'),
          ),
        ),
      )
    ).data().count;
    return { total, own, unread: Math.max(total - own, 0) };
  };

  it('10 رسائل لي بعد آخر قراءة ثم رسالة من غيري ⇒ 1 لا صفر', async () => {
    const readAt = minutesAgo(120);
    await seedGroup();
    await seed([
      { path: 'studyGroups/g1/reads/student-1', data: { lastReadAt: readAt } },
      ...Array.from({ length: 10 }, (_, i) => ({
        path: `studyGroups/g1/messages/mine-${i}`,
        data: groupMessage('student-1', minutesAgo(100 - i)),
      })),
      { path: 'studyGroups/g1/messages/other-1', data: groupMessage('teacher-1', minutesAgo(30)) },
    ]);

    const db = asStudent();
    const counts = await countAfterRead(db, readAt);

    assert.equal(counts.total, 11, 'كل الرسائل بعد آخر قراءة');
    assert.equal(counts.own, 10, 'رسائلي أنا');
    assert.equal(counts.unread, 1, 'رسالة الزميل — وهو ما كان السقف القديم يُخفيه');
    assert.notEqual(counts.unread, 0);

    // العدد يبقى دقيقًا عند التجاوز أيضًا (ولا يُقتطع عند سقفٍ ما).
    await seed(
      Array.from({ length: 15 }, (_, i) => ({
        path: `studyGroups/g1/messages/teacher-${i}`,
        data: groupMessage('teacher-1', minutesAgo(20 - i)),
      })),
    );
    const manyOthers = await countAfterRead(db, readAt);
    assert.equal(manyOthers.total, 26);
    assert.equal(manyOthers.own, 10);
    assert.equal(manyOthers.unread, 16, 'كل رسائل الآخرين تُعدّ كاملة لا مقتطعة');
  });

  it('رسائلي لا تُحتسب، والغياب يعني «لم يقرأ شيئًا»', async () => {
    await seedGroup();
    await seed([
      { path: 'studyGroups/g1/messages/mine-1', data: groupMessage('student-1', minutesAgo(50)) },
      { path: 'studyGroups/g1/messages/other-1', data: groupMessage('teacher-1', minutesAgo(40)) },
      { path: 'studyGroups/g1/messages/other-2', data: groupMessage('teacher-1', minutesAgo(30)) },
    ]);

    const db = asStudent();
    const before = await countAfterRead(db, null);
    assert.equal(before.total, 3);
    assert.equal(before.own, 1);
    assert.equal(before.unread, 2, 'رسالتا المدرس فقط');

    // بعد التعليم: صفر (كل الرسائل أقدم من «الآن»).
    await assertSucceeds(
      setDoc(doc(db, 'studyGroups/g1/reads/student-1'), { lastReadAt: new Date() }),
    );
    const marker = await readRaw('studyGroups/g1/reads/student-1');
    assert.ok(marker.lastReadAt, 'علامة القراءة كُتبت');

    const afterRead = await countAfterRead(db, marker.lastReadAt.toDate());
    assert.equal(afterRead.unread, 0);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe('P32 — markRead على Firestore الفعلي', () => {
  it('يكتب علامة العضو نفسه فقط، ولا يلمس علامة غيره', async () => {
    await seedGroup();
    await seed([
      { path: 'studyGroups/g1/reads/teacher-1', data: { lastReadAt: at(0) } },
    ]);

    const db = asStudent();
    await assertSucceeds(
      setDoc(doc(db, 'studyGroups/g1/reads/student-1'), { lastReadAt: new Date() }),
    );

    assert.ok((await readRaw('studyGroups/g1/reads/student-1')).lastReadAt);
    assert.equal(
      (await readRaw('studyGroups/g1/reads/teacher-1')).lastReadAt.toDate().toISOString(),
      at(0).toISOString(),
      'علامة الزميل لم تُمسّ',
    );

    // كتابة علامة الغير مرفوضة.
    await assertFails(
      updateDoc(doc(asTeacher(), 'studyGroups/g1/reads/student-1'), { lastReadAt: new Date() }),
    );
  });
});
