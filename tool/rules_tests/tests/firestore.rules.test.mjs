/**
 * اختبارات قواعد Firestore على المحاكي — P6.
 *
 * تُشغَّل بـ:  npm --prefix tool/rules_tests test
 * (السكربت يشغّل `firebase emulators:exec --only firestore` ثم هذه الاختبارات)
 *
 * كل اختبار هنا يقابل بندًا في السياسة المعتمدة A-42. الهدف ليس تغطية كل سطر
 * في `firestore.rules`، بل إثبات أن **الحدود** التي وعدنا بها صاحب المشروع
 * صحيحة فعلًا: صاحب الحساب فقط، الدور ثابت، الملف غير المعتمد مخفي، وحقول
 * الإدارة لا يكتبها التطبيق.
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
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const RULES = readFileSync(resolve('../../firestore.rules'), 'utf8');
const PROJECT_ID = 'demo-darsly';

let testEnv;

const HOST_PORT = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');

const now = () => new Date('2026-10-27T09:00:00Z');

// ── مساعدات بناء البيانات ────────────────────────────────────────────────────

const userDoc = (uid, role = 'student') => ({
  displayName: role === 'teacher' ? 'أ. سارة' : 'طالب',
  email: `${uid}@example.com`,
  role,
  createdAt: now(),
  roleChosenAt: now(),
});

const teacherDoc = (uid, overrides = {}) => ({
  ownerId: uid,
  displayName: 'أ. سارة الخطيب',
  status: 'pendingReview',
  createdAt: now(),
  subject: 'الرياضيات',
  stage: 'الثانوية العامة',
  area: 'المعادي',
  bio: 'شرح مبسّط',
  priceHint: '150 ج.م',
  ...overrides,
});

const groupDoc = (teacherId, overrides = {}) => ({
  teacherId,
  teacherName: 'أ. سارة الخطيب',
  title: 'التفاضل',
  subject: 'الرياضيات',
  stage: 'الثانوية العامة',
  seatsTotal: 12,
  // صفر هو القيمة الصحيحة للإنشاء؛ اختبارات التعديل تمرّر 9 صريحًا.
  seatsTaken: 0,
  meetingMode: 'center',
  scheduleNote: 'السبت 5 م',
  isActive: true,
  ...overrides,
});

/** طلب انضمام (P8): المالك منسوخ في المستند، والمعرّف `groupId_studentId`. */
const joinRequestDoc = (groupId, studentId, overrides = {}) => ({
  groupId,
  groupTitle: 'التفاضل',
  teacherId: 'teacher-1',
  studentId,
  studentName: 'طالب',
  status: 'pending',
  requestedAt: now(),
  ...overrides,
});

const joinPath = (groupId, studentId) => `groupJoinRequests/${groupId}_${studentId}`;

/** موعد أسبوعي (P9) — `groupId` منسوخ في المستند. */
const sessionDoc = (groupId, teacherId, overrides = {}) => ({
  groupId,
  teacherId,
  title: 'التفاضل — مراجعة',
  weekday: 'saturday',
  startMinutes: 17 * 60,
  durationMinutes: 90,
  locationNote: 'سنتر المعادي',
  isCancelled: false,
  createdAt: now(),
  ...overrides,
});

/** رسالة محادثة (P9). */
const messageDoc = (groupId, senderId, overrides = {}) => ({
  groupId,
  senderId,
  senderName: 'طالب',
  senderRole: 'student',
  text: 'إلى اللقاء السبت',
  sentAt: now(),
  ...overrides,
});

/** صف قائمة انتظار (P9) — للمجموعة المكتملة فقط، والمعرّف مشتق. */
const waitlistDoc = (groupId, studentId, overrides = {}) => ({
  groupId,
  groupTitle: 'التفاضل',
  teacherId: 'teacher-1',
  studentId,
  studentName: 'طالب',
  status: 'waiting',
  addedAt: now(),
  ...overrides,
});

const waitlistPath = (groupId, studentId) => `groupWaitlist/${groupId}_${studentId}`;

const bookingDoc = (studentId, teacherId, overrides = {}) => ({
  studentId,
  teacherId,
  studentName: 'طالب',
  teacherName: 'أ. سارة',
  subject: 'الرياضيات',
  requestedAt: now(),
  status: 'pending',
  ...overrides,
});

/** يكتب بيانات التهيئة متجاوزًا القواعد (لأن اختبار القراءة لا يخص الكتابة). */
async function seed(writes) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const { path, data } of writes) {
      await setDoc(doc(db, path), data);
    }
  });
}

const asStudent = () => testEnv.authenticatedContext('student-1').firestore();
const asTeacher = () => testEnv.authenticatedContext('teacher-1').firestore();
const asOther = () => testEnv.authenticatedContext('stranger-9').firestore();
const asAdmin = () =>
  testEnv.authenticatedContext('admin-1', { admin: true }).firestore();
const asGuest = () => testEnv.unauthenticatedContext().firestore();

/** يقرأ مستندًا متجاوزًا القواعد — للتحقق من الحالة النهائية لا من الصلاحية. */
async function readAsAdmin(path) {
  let data = null;
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const snap = await getDoc(doc(context.firestore(), path));
    data = snap.exists() ? snap.data() : null;
  });
  return data;
}

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

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

// ═════════════════════════════════════════════════════════════════════════════
describe('users/{uid} — صاحب الحساب فقط والدور ثابت', () => {
  it('صاحب الحساب ينشئ مستنده بدور صالح', async () => {
    await assertSucceeds(
      setDoc(doc(asStudent(), 'users/student-1'), userDoc('student-1')),
    );
  });

  it('دور غير معروف يُرفض عند الإنشاء', async () => {
    await assertFails(
      setDoc(
        doc(asStudent(), 'users/student-1'),
        userDoc('student-1', 'admin'),
      ),
    );
  });

  it('لا ينشئ مستخدمًا لغيره', async () => {
    await assertFails(
      setDoc(doc(asOther(), 'users/student-1'), userDoc('student-1')),
    );
  });

  it('صاحب الحساب يقرأ مستنده، والغريب لا يقرأ', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertSucceeds(getDoc(doc(asStudent(), 'users/student-1')));
    await assertFails(getDoc(doc(asOther(), 'users/student-1')));
    await assertFails(getDoc(doc(asGuest(), 'users/student-1')));
  });

  it('تغيير الدور مرفوض (الدور يُختار مرة واحدة)', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), { role: 'teacher' }),
    );
  });

  it('الحقول غير المصرّح بها مرفوضة', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), { isAdmin: true }),
    );
  });

  it('تحديث الاسم مسموح، والحذف من التطبيق مرفوض', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertSucceeds(
      updateDoc(doc(asStudent(), 'users/student-1'), { displayName: 'اسم جديد' }),
    );
    await assertFails(deleteDoc(doc(asStudent(), 'users/student-1')));
  });

  it('الإدارة تقرأ أي مستخدم (لأغراض المراجعة)', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertSucceeds(getDoc(doc(asAdmin(), 'users/student-1')));
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe('teacherProfiles/{uid} — الظهور للمعتمد فقط', () => {
  it('الملف غير المعتمد مخفي عن الطلاب والزوار', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: teacherDoc('teacher-1') },
    ]);

    await assertFails(getDoc(doc(asStudent(), 'teacherProfiles/teacher-1')));
    await assertFails(getDoc(doc(asGuest(), 'teacherProfiles/teacher-1')));
  });

  it('الملف المعتمد مقروء للجميع (بحث الطلاب)', async () => {
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: teacherDoc('teacher-1', { status: 'approved' }),
      },
    ]);

    await assertSucceeds(getDoc(doc(asGuest(), 'teacherProfiles/teacher-1')));
    await assertSucceeds(
      getDocs(
        query(
          collection(asStudent(), 'teacherProfiles'),
          where('status', '==', 'approved'),
        ),
      ),
    );
  });

  it('المدرس يرى ملفه في أي حالة', async () => {
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: teacherDoc('teacher-1', { status: 'rejected' }),
      },
    ]);

    await assertSucceeds(getDoc(doc(asTeacher(), 'teacherProfiles/teacher-1')));
  });

  it('الإنشاء يبدأ دائمًا بـpendingReview', async () => {
    await assertSucceeds(
      setDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), teacherDoc('teacher-1')),
    );

    await assertFails(
      setDoc(
        doc(asTeacher(), 'teacherProfiles/teacher-1'),
        teacherDoc('teacher-1', { status: 'approved' }),
      ),
    );
  });

  it('لا ينشئ ملفًا لغيره، ولا ينشئ ملفًا بحقول إدارة', async () => {
    await assertFails(
      setDoc(
        doc(asOther(), 'teacherProfiles/teacher-1'),
        teacherDoc('teacher-1', { ownerId: 'teacher-1' }),
      ),
    );

    await assertFails(
      setDoc(
        doc(asTeacher(), 'teacherProfiles/teacher-1'),
        teacherDoc('teacher-1', { isFeatured: true }),
      ),
    );
  });

  it('المدرس يحدّث بياناته الوصفية ولا يغيّر الحالة', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: teacherDoc('teacher-1') },
    ]);

    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        bio: 'نبذة محدثة',
        priceHint: '180 ج.م',
      }),
    );

    await assertFails(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        status: 'approved',
      }),
    );
  });

  it('لا يكتب المدرس حقول الإدارة ولا يحذف ملفه', async () => {
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: teacherDoc('teacher-1', { status: 'approved' }),
      },
    ]);

    await assertFails(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), { rating: 5 }),
    );
    await assertFails(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), { isFeatured: true }),
    );
    await assertFails(deleteDoc(doc(asTeacher(), 'teacherProfiles/teacher-1')));
  });

  it('الإدارة تعتمد الملف (خارج التطبيق)', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: teacherDoc('teacher-1') },
    ]);

    await assertSucceeds(
      updateDoc(doc(asAdmin(), 'teacherProfiles/teacher-1'), { status: 'approved' }),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe('studyGroups — قراءة مقيّدة وكتابة للمالك فقط', () => {
  it('الطالب يقرأ المجموعة النشطة فقط', async () => {
    await seed([
      {
        path: 'studyGroups/g1',
        data: groupDoc('teacher-1', { seatsTaken: 9 }),
      },
      {
        path: 'studyGroups/g2',
        data: groupDoc('teacher-1', { title: 'موقوفة', isActive: false }),
      },
    ]);

    await assertSucceeds(getDoc(doc(asStudent(), 'studyGroups/g1')));
    await assertFails(getDoc(doc(asStudent(), 'studyGroups/g2')));
  });

  it('المدرس يرى مجموعته الموقوفة، والغريب لا يراها', async () => {
    await seed([
      {
        path: 'studyGroups/g2',
        data: groupDoc('teacher-1', { isActive: false }),
      },
    ]);

    await assertSucceeds(getDoc(doc(asTeacher(), 'studyGroups/g2')));
    await assertFails(getDoc(doc(asOther(), 'studyGroups/g2')));
    await assertFails(getDoc(doc(asGuest(), 'studyGroups/g2')));
  });

  it('استعلام الاستكشاف (isActive == true) يعمل للطالب', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1') },
      {
        path: 'studyGroups/g2',
        data: groupDoc('teacher-1', { title: 'موقوفة', isActive: false }),
      },
    ]);

    await assertSucceeds(
      getDocs(
        query(
          collection(asStudent(), 'studyGroups'),
          where('isActive', '==', true),
        ),
      ),
    );
  });

  // ── P7: الكتابة من المدرس صاحب المجموعة ──────────────────────────────────
  it('المدرس ينشئ مجموعته بحقول مسموحة', async () => {
    await assertSucceeds(
      setDoc(doc(asTeacher(), 'studyGroups/new-1'), groupDoc('teacher-1')),
    );
  });

  it('الإنشاء مرفوض إن لم يكن المالك هو المنشئ', async () => {
    await assertFails(
      setDoc(
        doc(asTeacher(), 'studyGroups/new-2'),
        groupDoc('teacher-2', { teacherId: 'teacher-2' }),
      ),
    );
  });

  it('الإنشاء مرفوض بمقاعد مشغولة مسبقًا', async () => {
    await assertFails(
      setDoc(
        doc(asTeacher(), 'studyGroups/new-3'),
        groupDoc('teacher-1', { seatsTaken: 5 }),
      ),
    );
  });

  it('الإنشاء مرفوض بسعة خارج 2..40 (حدّ صارم)', async () => {
    for (const seats of [0, 1, 41]) {
      await assertFails(
        setDoc(
          doc(asTeacher(), `studyGroups/seat-${seats}`),
          groupDoc('teacher-1', { seatsTotal: seats, seatsTaken: 0 }),
        ),
      );
    }
  });

  it('الإنشاء مرفوض بطريقة حضور أو عنوان غير صالحين', async () => {
    await assertFails(
      setDoc(
        doc(asTeacher(), 'studyGroups/bad-mode'),
        groupDoc('teacher-1', { meetingMode: 'telepathy' }),
      ),
    );
    await assertFails(
      setDoc(
        doc(asTeacher(), 'studyGroups/bad-title'),
        groupDoc('teacher-1', { title: 'ري' }),
      ),
    );
  });

  it('الإنشاء مرفوض بحقل غير معروف أو وصف موعد طويل', async () => {
    await assertFails(
      setDoc(
        doc(asTeacher(), 'studyGroups/extra'),
        groupDoc('teacher-1', { rating: 5 }),
      ),
    );
    await assertFails(
      setDoc(
        doc(asTeacher(), 'studyGroups/long-note'),
        groupDoc('teacher-1', { scheduleNote: 'س'.repeat(121) }),
      ),
    );
  });

  it('المدرس يعدّل مجموعته (العنوان والسعة والإيقاف)', async () => {
    await seed([{ path: 'studyGroups/g1', data: groupDoc('teacher-1') }]);

    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), {
        title: 'التفاضل المتقدم',
        seatsTotal: 14,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), { isActive: false }),
    );
  });

  it('لا يجوز تقليل السعة تحت عدد المنضمين', async () => {
    await seed([
      {
        path: 'studyGroups/g1',
        data: groupDoc('teacher-1', { seatsTotal: 12, seatsTaken: 9 }),
      },
    ]);

    await assertFails(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), { seatsTotal: 8 }),
    );
    // الحد نفسه مسموح.
    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), { seatsTotal: 9 }),
    );
  });

  it('المقاعد المشغولة تتغيّر بمقعد واحد فقط، والمالك لا يتغيّر', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken: 9 }) },
    ]);

    // نقص مقعدين مرفوض، ونقص مقعد واحد مقبول (إزالة عضو — P9).
    await assertFails(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), { seatsTaken: 7 }),
    );
    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), { seatsTaken: 8 }),
    );
    await assertFails(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), { teacherId: 'teacher-9' }),
    );
  });

  it('مدرس آخر لا يعدّل مجموعة غيره، والطالب لا يعدّل', async () => {
    await seed([{ path: 'studyGroups/g1', data: groupDoc('teacher-1') }]);

    await assertFails(
      updateDoc(
        doc(testEnv.authenticatedContext('teacher-2').firestore(),
            'studyGroups/g1'),
        { title: 'محاولة' },
      ),
    );
    await assertFails(
      updateDoc(doc(asStudent(), 'studyGroups/g1'), { title: 'محاولة' }),
    );
  });

  it('لا حذف من التطبيق (الإيقاف بدل الحذف)', async () => {
    await seed([{ path: 'studyGroups/g1', data: groupDoc('teacher-1') }]);

    await assertFails(deleteDoc(doc(asTeacher(), 'studyGroups/g1')));
  });

  it('الإدارة تستطيع الاعتماد على أي مجموعة', async () => {
    await seed([{ path: 'studyGroups/g1', data: groupDoc('teacher-1') }]);

    await assertSucceeds(
      updateDoc(doc(asAdmin(), 'studyGroups/g1'), { isActive: false }),
    );
  });
});

describe('studyGroups/{id}/members — خصوصية أسماء الطلاب', () => {
  const member = (uid) => ({ name: 'طالب', joinedAt: now(), status: 'active' });

  it('المدرس صاحب المجموعة يقرأ الأعضاء، والطالب لا', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1') },
      { path: 'studyGroups/g1/members/student-1', data: member('student-1') },
    ]);

    const memberDoc = (db) =>
      getDoc(doc(db, 'studyGroups/g1/members/student-1'));

    await assertSucceeds(memberDoc(asTeacher()));
    await assertFails(memberDoc(asStudent()));
    await assertFails(memberDoc(asOther()));
  });

  it('لا كتابة على الأعضاء من التطبيق', async () => {
    await seed([{ path: 'studyGroups/g1', data: groupDoc('teacher-1') }]);

    await assertFails(
      setDoc(
        doc(asStudent(), 'studyGroups/g1/members/student-1'),
        member('student-1'),
      ),
    );
  });
});


// ═════════════════════════════════════════════════════════════════════════════
describe('P8 — طلبات الانضمام: من ينشئها ومن يقرأها', () => {
  const seedGroup = (overrides = {}) =>
    seed([{ path: 'studyGroups/g1', data: groupDoc('teacher-1', overrides) }]);

  it('الطالب ينشئ طلبه لمجموعة منشورة وبها مقعد', async () => {
    await seedGroup({ seatsTaken: 3 });

    await assertSucceeds(
      setDoc(
        doc(asStudent(), joinPath('g1', 'student-1')),
        joinRequestDoc('g1', 'student-1'),
      ),
    );
  });

  it('لا ينشئ طالب طلبًا باسم طالب آخر', async () => {
    await seedGroup();

    await assertFails(
      setDoc(
        doc(asStudent(), joinPath('g1', 'student-2')),
        joinRequestDoc('g1', 'student-2'),
      ),
    );
  });

  it('المعرّف المشتق إلزامي (لا مستندان لطالب واحد)', async () => {
    await seedGroup();

    await assertFails(
      setDoc(
        doc(asStudent(), 'groupJoinRequests/طلب-عشوائي'),
        joinRequestDoc('g1', 'student-1'),
      ),
    );
  });

  it('المجموعة الموقوفة لا تقبل طلبات', async () => {
    await seedGroup({ isActive: false });

    await assertFails(
      setDoc(
        doc(asStudent(), joinPath('g1', 'student-1')),
        joinRequestDoc('g1', 'student-1'),
      ),
    );
  });

  it('المجموعة المكتملة لا تقبل طلبات', async () => {
    await seedGroup({ seatsTaken: 12 });

    await assertFails(
      setDoc(
        doc(asStudent(), joinPath('g1', 'student-1')),
        joinRequestDoc('g1', 'student-1'),
      ),
    );
  });

  it('لا يُنشأ طلب بحالة مقبولة، ولا بحقل إضافي، ولا بمالك مختلف', async () => {
    await seedGroup();

    await assertFails(
      setDoc(
        doc(asStudent(), joinPath('g1', 'student-1')),
        joinRequestDoc('g1', 'student-1', { status: 'accepted' }),
      ),
    );

    await assertFails(
      setDoc(
        doc(asStudent(), joinPath('g1', 'student-1')),
        joinRequestDoc('g1', 'student-1', { teacherId: 'teacher-2' }),
      ),
    );

    await assertFails(
      setDoc(
        doc(asStudent(), joinPath('g1', 'student-1')),
        { ...joinRequestDoc('g1', 'student-1'), isAdmin: true },
      ),
    );
  });

  it('المدرس يقرأ طلبات مجموعته، والطالب يقرأ طلبه فقط', async () => {
    await seedGroup();
    await seed([
      {
        path: joinPath('g1', 'student-1'),
        data: joinRequestDoc('g1', 'student-1'),
      },
    ]);

    const path = joinPath('g1', 'student-1');
    await assertSucceeds(getDoc(doc(asTeacher(), path)));
    await assertSucceeds(getDoc(doc(asStudent(), path)));
    await assertFails(getDoc(doc(asOther(), path)));

    // قائمة طلبات مجموعة: للمدرس فقط، ويجب أن يقيّدها الاستعلام بالمالك —
    // قواعد Firestore ترفض أي list لا يثبت انطباق شرط `resource.data` عليه.
    const listFor = (db, groupId, teacherId) =>
      getDocs(
        query(
          collection(db, 'groupJoinRequests'),
          where('groupId', '==', groupId),
          where('teacherId', '==', teacherId),
        ),
      );
    await assertSucceeds(listFor(asTeacher(), 'g1', 'teacher-1'));
    await assertFails(listFor(asStudent(), 'g1', 'teacher-1'));

    // وبدون تقييد المالك يُرفض الاستعلام كاملًا حتى للمدرس نفسه.
    await assertFails(
      getDocs(
        query(collection(asTeacher(), 'groupJoinRequests'), where('groupId', '==', 'g1')),
      ),
    );
  });
});

describe('P8 — القبول الذرّي وحجز المقعد', () => {
  const seedFull = (seatsTaken) =>
    seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken }) },
      {
        path: joinPath('g1', 'student-1'),
        data: joinRequestDoc('g1', 'student-1'),
      },
    ]);

  it('القبول يزيد المقعد واحدًا بالضبط ويغيّر الطلب', async () => {
    await seedFull(3);

    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), { seatsTaken: 4 }),
    );
    await assertSucceeds(
      updateDoc(doc(asTeacher(), joinPath('g1', 'student-1')), {
        status: 'accepted',
        decidedAt: now(),
        decidedBy: 'teacher-1',
      }),
    );
  });

  it('لا يمكن زيادة أكثر من مقعد، ولا تغيير حقل آخر مع الزيادة', async () => {
    await seedFull(3);

    await assertFails(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), { seatsTaken: 5 }),
    );
    await assertFails(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), {
        seatsTaken: 4,
        title: 'عنوان جديد',
      }),
    );
  });

  it('لا قبول عندما تكون المجموعة مكتملة', async () => {
    await seedFull(12);

    await assertFails(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), { seatsTaken: 13 }),
    );
  });

  it('المجموعة الموقوفة لا تُقبل طلباتها', async () => {
    await seed([
      {
        path: 'studyGroups/g1',
        data: groupDoc('teacher-1', { seatsTaken: 3, isActive: false }),
      },
      {
        path: joinPath('g1', 'student-1'),
        data: joinRequestDoc('g1', 'student-1'),
      },
    ]);

    await assertFails(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), { seatsTaken: 4 }),
    );
  });

  it('الطالب لا يقبل طلبه، ولا يعدّل طلب غيره، والطالب الآخر لا يقرر', async () => {
    await seedFull(3);

    await assertFails(
      updateDoc(doc(asStudent(), joinPath('g1', 'student-1')), {
        status: 'accepted',
        decidedAt: now(),
        decidedBy: 'student-1',
      }),
    );
    await assertFails(
      updateDoc(doc(asOther(), joinPath('g1', 'student-1')), {
        status: 'rejected',
        decidedAt: now(),
        decidedBy: 'stranger-9',
      }),
    );
  });

  it('لا قرار على طلب تم البتّ فيه', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken: 3 }) },
      {
        path: joinPath('g1', 'student-1'),
        data: joinRequestDoc('g1', 'student-1', { status: 'accepted' }),
      },
    ]);

    await assertFails(
      updateDoc(doc(asTeacher(), joinPath('g1', 'student-1')), {
        status: 'rejected',
        decidedAt: now(),
        decidedBy: 'teacher-1',
      }),
    );
  });

  it('آخر مقعد: معاملتان متزامنتان، واحدة فقط تحجز', async () => {
    // السعة 12 والمشغول 11: مقعد واحد متبقٍّ. معاملتان تُعيدان القراءة،
    // والقواعد ترفض أي زيادة تتجاوز السعة، فلا يمكن أن يحصل الطالبان معًا.
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken: 11 }) },
    ]);

    const db = asTeacher();
    const accept = () =>
      runTransaction(db, async (tx) => {
        const snap = await tx.get(doc(db, 'studyGroups/g1'));
        const data = snap.data();
        if (data.seatsTaken >= data.seatsTotal) {
          throw new Error('group is full');
        }
        tx.update(doc(db, 'studyGroups/g1'), { seatsTaken: data.seatsTaken + 1 });
      });

    const results = await Promise.allSettled([accept(), accept()]);
    const succeeded = results.filter((r) => r.status === 'fulfilled').length;

    assert.equal(succeeded, 1, 'يجب أن تنجح معاملة واحدة فقط على المقعد الأخير');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(doc(context.firestore(), 'studyGroups/g1'));
      assert.equal(snap.data().seatsTaken, 12, 'لا يُحجز المقعد مرتين');
    });
  });

  it('إنشاء العضو: المالك فقط وبمعرّف الطالب نفسه', async () => {
    await seedFull(3);
    const member = (studentId, groupId = 'g1') => ({
      studentId,
      groupId,
      name: 'طالب',
      joinedAt: now(),
      status: 'active',
    });

    await assertSucceeds(
      setDoc(doc(asTeacher(), 'studyGroups/g1/members/student-1'), member('student-1')),
    );
    await assertFails(
      setDoc(doc(asTeacher(), 'studyGroups/g1/members/student-1'), member('student-9')),
    );
    await assertFails(
      setDoc(doc(asStudent(), 'studyGroups/g1/members/student-1'), member('student-1')),
    );
  });
});

describe('P8 — إلغاء الطلب وإعادة إرساله', () => {
  it('الطالب يلغي طلبه المعلّق، ولا يلغي طلبًا مقبولًا', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken: 3 }) },
      {
        path: joinPath('g1', 'student-1'),
        data: joinRequestDoc('g1', 'student-1'),
      },
      {
        path: joinPath('g1', 'student-2'),
        data: joinRequestDoc('g1', 'student-2', { status: 'accepted' }),
      },
    ]);

    await assertSucceeds(
      updateDoc(doc(asStudent(), joinPath('g1', 'student-1')), {
        status: 'cancelled',
      }),
    );
    await assertFails(
      updateDoc(doc(asStudent(), joinPath('g1', 'student-2')), {
        status: 'cancelled',
      }),
    );
  });

  it('إعادة الطلب بعد الرفض مسموحة ما دام هناك مقعد', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken: 3 }) },
      {
        path: joinPath('g1', 'student-1'),
        data: joinRequestDoc('g1', 'student-1', { status: 'rejected' }),
      },
    ]);

    await assertSucceeds(
      setDoc(
        doc(asStudent(), joinPath('g1', 'student-1')),
        joinRequestDoc('g1', 'student-1'),
      ),
    );
  });

  it('لا حذف لطلب من التطبيق', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1') },
      {
        path: joinPath('g1', 'student-1'),
        data: joinRequestDoc('g1', 'student-1'),
      },
    ]);

    await assertFails(
      deleteDoc(doc(asStudent(), joinPath('g1', 'student-1'))),
    );
    await assertFails(
      deleteDoc(doc(asTeacher(), joinPath('g1', 'student-1'))),
    );
  });
});


// ═════════════════════════════════════════════════════════════════════════════
describe('P9 — الجدول الأسبوعي: أعضاء المجموعة يقرأون، والمالك يكتب', () => {
  const withGroup = (overrides = {}, members = ['student-1']) =>
    seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', overrides) },
      ...members.map((uid) => ({
        path: `studyGroups/g1/members/${uid}`,
        data: { studentId: uid, name: 'طالب', joinedAt: now(), status: 'active' },
      })),
    ]);

  it('العضو والمالك يقرأان المواعيد، والغريب لا', async () => {
    await withGroup();
    await seed([
      { path: 'studyGroups/g1/sessions/s1', data: sessionDoc('g1', 'teacher-1') },
    ]);

    const read = (db) => getDoc(doc(db, 'studyGroups/g1/sessions/s1'));
    await assertSucceeds(read(asTeacher()));
    await assertSucceeds(read(asStudent()));
    await assertFails(read(asOther()));
    await assertFails(read(asGuest()));
  });

  it('قائمة المواعيد مسموحة للعضو ومرفوضة لغير العضو', async () => {
    await withGroup();
    await seed([
      { path: 'studyGroups/g1/sessions/s1', data: sessionDoc('g1', 'teacher-1') },
    ]);
    const list = (db) => getDocs(collection(db, 'studyGroups/g1/sessions'));
    await assertSucceeds(list(asTeacher()));
    await assertSucceeds(list(asStudent()));
    await assertFails(list(asOther()));
  });

  it('المالك يضيف موعدًا صالحًا، والطالب لا يضيف', async () => {
    await withGroup();

    await assertSucceeds(
      setDoc(
        doc(asTeacher(), 'studyGroups/g1/sessions/s1'),
        sessionDoc('g1', 'teacher-1'),
      ),
    );
    await assertFails(
      setDoc(
        doc(asStudent(), 'studyGroups/g1/sessions/s2'),
        sessionDoc('g1', 'teacher-1'),
      ),
    );
  });

  it('الإنشاء يرفض: مالِكًا آخر، مجموعة أخرى، يومًا غير معروف، مدة/وقتًا خارج النطاق', async () => {
    await withGroup();
    const write = (data, uid = 'teacher-1') =>
      setDoc(doc(testEnv.authenticatedContext(uid).firestore(), 'studyGroups/g1/sessions/s1'), data);

    await assertFails(write(sessionDoc('g1', 'teacher-2')));
    await assertFails(write(sessionDoc('g2', 'teacher-1')));
    await assertFails(write(sessionDoc('g1', 'teacher-1', { weekday: 'funday' })));
    await assertFails(write(sessionDoc('g1', 'teacher-1', { durationMinutes: 5 })));
    await assertFails(write(sessionDoc('g1', 'teacher-1', { startMinutes: 1400 })));
    // 23:30 + 60 دقيقة تعبر منتصف الليل ⇒ مرفوضة.
    await assertFails(
      write(sessionDoc('g1', 'teacher-1', { startMinutes: 1410, durationMinutes: 60 })),
    );
    await assertFails(write(sessionDoc('g1', 'teacher-1', { title: 'أب' })));
    await assertFails(write({ ...sessionDoc('g1', 'teacher-1'), isFeatured: true }));
    // وإنشاء موعد ملغى مباشرة مرفوض.
    await assertFails(write(sessionDoc('g1', 'teacher-1', { isCancelled: true })));
  });

  it('المالك يعدّل ويُلغي، والطالب لا، ولا يجوز نقل الموعد لمجموعة/مالك آخر', async () => {
    await withGroup();
    await seed([
      { path: 'studyGroups/g1/sessions/s1', data: sessionDoc('g1', 'teacher-1') },
    ]);

    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'studyGroups/g1/sessions/s1'), {
        startMinutes: 18 * 60,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'studyGroups/g1/sessions/s1'), {
        isCancelled: true,
      }),
    );
    await assertFails(
      updateDoc(doc(asStudent(), 'studyGroups/g1/sessions/s1'), {
        startMinutes: 19 * 60,
      }),
    );
    await assertFails(
      updateDoc(doc(asTeacher(), 'studyGroups/g1/sessions/s1'), {
        teacherId: 'teacher-2',
      }),
    );
    await assertFails(
      updateDoc(doc(asTeacher(), 'studyGroups/g1/sessions/s1'), {
        durationMinutes: 300,
      }),
    );
  });

  it('لا حذف موعد من التطبيق', async () => {
    await withGroup();
    await seed([
      { path: 'studyGroups/g1/sessions/s1', data: sessionDoc('g1', 'teacher-1') },
    ]);

    await assertFails(deleteDoc(doc(asTeacher(), 'studyGroups/g1/sessions/s1')));
  });
});

describe('P9 — محادثة المجموعة: العضوية والمرسل', () => {
  const withGroup = () =>
    seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1') },
      {
        path: 'studyGroups/g1/members/student-1',
        data: { studentId: 'student-1', name: 'طالب', joinedAt: now(), status: 'active' },
      },
    ]);

  it('المالك والعضو يقرأان، وغير العضو لا', async () => {
    await withGroup();
    await seed([
      {
        path: 'studyGroups/g1/messages/m1',
        data: messageDoc('g1', 'student-1'),
      },
    ]);

    const read = (db) => getDoc(doc(db, 'studyGroups/g1/messages/m1'));
    await assertSucceeds(read(asTeacher()));
    await assertSucceeds(read(asStudent()));
    await assertFails(read(asOther()));
    await assertFails(read(asGuest()));
  });

  it('العضو يرسل باسمه، ولا ينشر باسم غيره', async () => {
    await withGroup();

    await assertSucceeds(
      setDoc(
        doc(asStudent(), 'studyGroups/g1/messages/m1'),
        messageDoc('g1', 'student-1'),
      ),
    );
    await assertFails(
      setDoc(
        doc(asStudent(), 'studyGroups/g1/messages/m2'),
        messageDoc('g1', 'student-2'),
      ),
    );
    await assertFails(
      setDoc(
        doc(asOther(), 'studyGroups/g1/messages/m3'),
        messageDoc('g1', 'stranger-9'),
      ),
    );
  });

  it('المدرس صاحب المجموعة يرسل بوسم مدرس', async () => {
    await withGroup();

    await assertSucceeds(
      setDoc(
        doc(asTeacher(), 'studyGroups/g1/messages/m1'),
        messageDoc('g1', 'teacher-1', {
          senderRole: 'teacher',
          senderName: 'أ. سارة',
        }),
      ),
    );
  });

  it('رسالة فارغة أو طويلة أو بحقل إضافي أو دور غير معروف مرفوضة', async () => {
    await withGroup();
    const write = (data) =>
      setDoc(doc(asStudent(), 'studyGroups/g1/messages/m1'), data);

    await assertFails(write(messageDoc('g1', 'student-1', { text: '' })));
    await assertFails(
      write(messageDoc('g1', 'student-1', { text: 'ا'.repeat(501) })),
    );
    await assertFails(
      write(messageDoc('g1', 'student-1', { senderRole: 'admin' })),
    );
    await assertFails(
      write({ ...messageDoc('g1', 'student-1'), pinned: true }),
    );
    await assertFails(
      write(messageDoc('g2', 'student-1')),
    );
  });

  it('لا تعديل ولا حذف لرسالة بعد إرسالها', async () => {
    await withGroup();
    await seed([
      {
        path: 'studyGroups/g1/messages/m1',
        data: messageDoc('g1', 'student-1'),
      },
    ]);

    await assertFails(
      updateDoc(doc(asStudent(), 'studyGroups/g1/messages/m1'), {
        text: 'نص مختلف',
      }),
    );
    await assertFails(
      deleteDoc(doc(asStudent(), 'studyGroups/g1/messages/m1')),
    );
    await assertFails(
      deleteDoc(doc(asTeacher(), 'studyGroups/g1/messages/m1')),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe('bookingRequests — الطرفان فقط', () => {
  it('الطالب والمدرس يقرآن الطلب، والغريب لا', async () => {
    await seed([
      { path: 'bookingRequests/b1', data: bookingDoc('student-1', 'teacher-1') },
    ]);

    const read = () => getDoc(doc(asStudent(), 'bookingRequests/b1'));
    const readTeacher = () => getDoc(doc(asTeacher(), 'bookingRequests/b1'));

    await assertSucceeds(read());
    await assertSucceeds(readTeacher());
    await assertFails(getDoc(doc(asOther(), 'bookingRequests/b1')));
    await assertFails(getDoc(doc(asGuest(), 'bookingRequests/b1')));
  });

  it('استعلام «طلباتي» يعمل لكل دور', async () => {
    await seed([
      { path: 'bookingRequests/b1', data: bookingDoc('student-1', 'teacher-1') },
      { path: 'bookingRequests/b2', data: bookingDoc('student-2', 'teacher-1') },
    ]);

    await assertSucceeds(
      getDocs(
        query(
          collection(asStudent(), 'bookingRequests'),
          where('studentId', '==', 'student-1'),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        query(
          collection(asTeacher(), 'bookingRequests'),
          where('teacherId', '==', 'teacher-1'),
        ),
      ),
    );
  });

  it('لا كتابة من التطبيق (مرحلة P8 لم تبدأ)', async () => {
    await assertFails(
      setDoc(
        doc(asStudent(), 'bookingRequests/b9'),
        bookingDoc('student-1', 'teacher-1'),
      ),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe('الرفض الافتراضي', () => {
  it('أي مجموعة غير مذكورة مرفوضة للقراءة والكتابة', async () => {
    await assertFails(getDoc(doc(asStudent(), 'secretStuff/a')));
    await assertFails(setDoc(doc(asStudent(), 'secretStuff/a'), { x: 1 }));
    // حتى الإدارة لا تمرّ من مسار غير مذكور.
    await assertFails(getDoc(doc(asAdmin(), 'secretStuff/a')));
  });

  it('لا قراءة ولا كتابة بلا مصادقة على المجموعات المعروفة', async () => {
    await assertFails(
      setDoc(doc(asGuest(), 'users/guest-1'), userDoc('guest-1')),
    );
    await assertFails(getDocs(collection(asGuest(), 'studyGroups')));
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe('P9 — إزالة العضو تحرّر مقعدًا واحدًا فقط', () => {
  const seedMember = (seatsTaken = 9) =>
    seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken }) },
      {
        path: 'studyGroups/g1/members/student-1',
        data: { studentId: 'student-1', name: 'طالب', joinedAt: now(), status: 'active' },
      },
    ]);

  it('المالك يحذف العضو وينقص المقعد في نفس العملية', async () => {
    await seedMember(9);
    const db = asTeacher();

    await assertSucceeds(deleteDoc(doc(db, 'studyGroups/g1/members/student-1')));
    await assertSucceeds(
      updateDoc(doc(db, 'studyGroups/g1'), { seatsTaken: 8 }),
    );

    const group = await getDoc(doc(db, 'studyGroups/g1'));
    assert.equal(group.data().seatsTaken, 8);
  });

  it('الطالب لا يحذف عضوًا ولا ينقص المقعد', async () => {
    await seedMember(9);
    const db = asStudent();

    await assertFails(deleteDoc(doc(db, 'studyGroups/g1/members/student-1')));
    await assertFails(updateDoc(doc(db, 'studyGroups/g1'), { seatsTaken: 8 }));
  });

  it('لا نقص بأكثر من مقعد، ولا نقص مع تغيير حقل آخر', async () => {
    await seedMember(9);
    const db = asTeacher();

    await assertFails(updateDoc(doc(db, 'studyGroups/g1'), { seatsTaken: 7 }));
    await assertFails(
      updateDoc(doc(db, 'studyGroups/g1'), { seatsTaken: 8, title: 'عنوان آخر' }),
    );
  });

  it('لا مقعد سالب', async () => {
    await seedMember(0);
    await assertFails(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), { seatsTaken: -1 }),
    );
  });
});

describe('P9 — قائمة الانتظار: للمجموعة المكتملة فقط', () => {
  const seedFull = (overrides = {}) =>
    seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken: 12, ...overrides }) },
    ]);

  it('الطالب ينضم لقائمة انتظار مجموعة مكتملة', async () => {
    await seedFull();

    await assertSucceeds(
      setDoc(doc(asStudent(), waitlistPath('g1', 'student-1')), waitlistDoc('g1', 'student-1')),
    );
  });

  it('المجموعة التي بها مقعد لا تقبل انتظارًا', async () => {
    await seed([{ path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken: 9 }) }]);

    await assertFails(
      setDoc(doc(asStudent(), waitlistPath('g1', 'student-1')), waitlistDoc('g1', 'student-1')),
    );
  });

  it('المجموعة الموقوفة لا تقبل انتظارًا', async () => {
    await seedFull({ isActive: false });

    await assertFails(
      setDoc(doc(asStudent(), waitlistPath('g1', 'student-1')), waitlistDoc('g1', 'student-1')),
    );
  });

  it('لا يضيف المنتظر صفًا باسم طالب آخر ولا بمعرّف غير مشتق', async () => {
    await seedFull();

    await assertFails(
      setDoc(
        doc(asStudent(), waitlistPath('g1', 'student-2')),
        waitlistDoc('g1', 'student-2'),
      ),
    );
    await assertFails(
      setDoc(doc(asStudent(), 'groupWaitlist/anything'), waitlistDoc('g1', 'student-1')),
    );
  });

  it('لا يُكتب الصف بحالة غير waiting ولا بحقول إضافية', async () => {
    await seedFull();

    await assertFails(
      setDoc(
        doc(asStudent(), waitlistPath('g1', 'student-1')),
        waitlistDoc('g1', 'student-1', { status: 'promoted' }),
      ),
    );
    await assertFails(
      setDoc(
        doc(asStudent(), waitlistPath('g1', 'student-1')),
        waitlistDoc('g1', 'student-1', { position: 1 }),
      ),
    );
  });

  it('الطالب يقرأ صفّه، والمدرس يقرأ صفوف مجموعته، وغيرهما لا', async () => {
    await seedFull();
    await seed([
      {
        path: waitlistPath('g1', 'student-1'),
        data: waitlistDoc('g1', 'student-1'),
      },
    ]);

    await assertSucceeds(
      getDoc(doc(asStudent(), waitlistPath('g1', 'student-1'))),
    );
    await assertSucceeds(getDoc(doc(asTeacher(), waitlistPath('g1', 'student-1'))));
    await assertFails(getDoc(doc(asOther(), waitlistPath('g1', 'student-1'))));

    // قائمة المدرس مقيّدة بالمالك (القاعدة تقرأ teacherId).
    const listFor = (db, teacherId) =>
      getDocs(query(collection(db, 'groupWaitlist'), where('groupId', '==', 'g1'), where('teacherId', '==', teacherId)));

    await assertSucceeds(listFor(asTeacher(), 'teacher-1'));
    await assertFails(listFor(asStudent(), 'teacher-1'));
  });
});

describe('P9 — قبول المنتظر: مقعد واحد وعضوية واحدة', () => {
  const seedQueue = (seatsTaken = 11) =>
    seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken }) },
      { path: waitlistPath('g1', 'student-1'), data: waitlistDoc('g1', 'student-1') },
    ]);

  it('المدرس يقبل منتظرًا: الصف promoted والمقعد يزيد واحدًا والعضوية تُنشأ', async () => {
    await seedQueue(11);
    const db = asTeacher();

    await assertSucceeds(
      updateDoc(doc(db, waitlistPath('g1', 'student-1')), {
        status: 'promoted',
        decidedAt: now(),
        decidedBy: 'teacher-1',
      }),
    );
    await assertSucceeds(updateDoc(doc(db, 'studyGroups/g1'), { seatsTaken: 12 }));
    await assertSucceeds(
      setDoc(doc(db, 'studyGroups/g1/members/student-1'), {
        studentId: 'student-1',
        groupId: 'g1',
        name: 'طالب',
        joinedAt: now(),
        status: 'active',
      }),
    );
  });

  it('لا قبول من غير المالك ولا من الطالب نفسه', async () => {
    await seedQueue(11);
    const change = (db) =>
      updateDoc(doc(db, waitlistPath('g1', 'student-1')), {
        status: 'promoted',
        decidedAt: now(),
        decidedBy: 'teacher-1',
      });

    await assertFails(change(asStudent()));
    await assertFails(change(asOther()));
  });

  it('لا قبول بلا حقل قرار، ولا بحالة أخرى، ولا بحقل إضافي', async () => {
    await seedQueue(11);
    const db = asTeacher();

    await assertFails(
      updateDoc(doc(db, waitlistPath('g1', 'student-1')), { status: 'promoted' }),
    );
    await assertFails(
      updateDoc(doc(db, waitlistPath('g1', 'student-1')), {
        status: 'left',
        decidedAt: now(),
      }),
    );
    await assertFails(
      updateDoc(doc(db, waitlistPath('g1', 'student-1')), {
        status: 'promoted',
        decidedAt: now(),
        decidedBy: 'teacher-1',
        position: 1,
      }),
    );
  });

  it('الطالب يغادر القائمة، ولا يعود إلا لمجموعة ما زالت مكتملة', async () => {
    // مكتملة تمامًا: الغياب والعودة كلاهما على الطابور نفسه.
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken: 12 }) },
      { path: waitlistPath('g1', 'student-1'), data: waitlistDoc('g1', 'student-1') },
    ]);
    const db = asStudent();

    await assertSucceeds(
      updateDoc(doc(db, waitlistPath('g1', 'student-1')), { status: 'left' }),
    );

    // عودة سليمة ما دامت مكتملة (الصف نفسه يعود waiting).
    await assertSucceeds(
      updateDoc(doc(db, waitlistPath('g1', 'student-1')), {
        status: 'waiting',
        addedAt: now(),
      }),
    );

    // بعد تحرر مقعد: لا عودة للطابور.
    await seed([
      { path: waitlistPath('g1', 'student-1'), data: waitlistDoc('g1', 'student-1', { status: 'left' }) },
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken: 9 }) },
    ]);
    await assertFails(
      updateDoc(doc(db, waitlistPath('g1', 'student-1')), {
        status: 'waiting',
        addedAt: now(),
      }),
    );
  });

  it('لا حذف صف الانتظار من التطبيق', async () => {
    await seedQueue(11);

    await assertFails(
      deleteDoc(doc(asStudent(), waitlistPath('g1', 'student-1'))),
    );
    await assertFails(
      deleteDoc(doc(asTeacher(), waitlistPath('g1', 'student-1'))),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe('P9 — سعة المجموعة: حدّ صارم 40 ولا تنزل تحت المنضمين', () => {
  const seedGroup = (overrides = {}) =>
    seed([
      {
        path: 'studyGroups/g1',
        data: groupDoc('teacher-1', { seatsTotal: 12, seatsTaken: 9, ...overrides }),
      },
    ]);

  it('المالك يرفع السعة في أي وقت بدون تغيير المشغول', async () => {
    await seedGroup();
    const db = asTeacher();

    await assertSucceeds(
      updateDoc(doc(db, 'studyGroups/g1'), { seatsTotal: 20 }),
    );
    const snap = await getDoc(doc(db, 'studyGroups/g1'));
    assert.equal(snap.data().seatsTotal, 20);
    assert.equal(snap.data().seatsTaken, 9, 'seatsTaken لم يتغيّر');
  });

  it('السعة القصوى 40: 41 مرفوضة و40 مقبولة', async () => {
    await seedGroup();
    const db = asTeacher();

    await assertFails(updateDoc(doc(db, 'studyGroups/g1'), { seatsTotal: 41 }));
    await assertSucceeds(updateDoc(doc(db, 'studyGroups/g1'), { seatsTotal: 40 }));
  });

  it('لا تنزل السعة تحت المنضمين', async () => {
    await seedGroup({ seatsTaken: 9 });

    await assertFails(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), { seatsTotal: 8 }),
    );
    // الحد نفسه (9) مسموح.
    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), { seatsTotal: 9 }),
    );
  });

  it('لا تُعدَّل السعة مع المقاعد المشغولة في كتابة واحدة', async () => {
    await seedGroup({ seatsTaken: 9 });

    await assertFails(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), {
        seatsTotal: 20,
        seatsTaken: 10,
      }),
    );
  });

  it('مدرس آخر والطالب لا يعدّلان السعة', async () => {
    await seedGroup();

    await assertFails(
      updateDoc(
        doc(testEnv.authenticatedContext('teacher-2').firestore(), 'studyGroups/g1'),
        { seatsTotal: 20 },
      ),
    );
    await assertFails(
      updateDoc(doc(asStudent(), 'studyGroups/g1'), { seatsTotal: 20 }),
    );
  });
});

describe('P9 — نقل العضو بين مجموعتين (معاملة واحدة)', () => {
  const seedTwoGroups = ({
    fromTaken = 3,
    toTotal = 5,
    toTaken = 2,
    toActive = true,
  } = {}) =>
    seed([
      {
        path: 'studyGroups/g1',
        data: groupDoc('teacher-1', { seatsTotal: 6, seatsTaken: fromTaken }),
      },
      {
        path: 'studyGroups/g2',
        data: groupDoc('teacher-1', {
          title: 'الفيزياء',
          seatsTotal: toTotal,
          seatsTaken: toTaken,
          isActive: toActive,
        }),
      },
      {
        path: 'studyGroups/g1/members/student-1',
        data: {
          studentId: 'student-1',
          groupId: 'g1',
          name: 'طالب',
          joinedAt: now(),
          status: 'active',
        },
      },
    ]);

  /** نقل كما ينفّذه التطبيق: قراءة ثم أربع كتابات. */
  const move = (db, { check = true } = {}) =>
    runTransaction(db, async (tx) => {
      const fromSnap = await tx.get(doc(db, 'studyGroups/g1'));
      const toSnap = await tx.get(doc(db, 'studyGroups/g2'));
      if (!fromSnap.exists() || !toSnap.exists()) {
        throw new Error('missing group');
      }
      const from = fromSnap.data();
      const to = toSnap.data();
      if (check && to.seatsTaken >= to.seatsTotal) {
        throw new Error('target full');
      }
      tx.update(doc(db, 'studyGroups/g1'), { seatsTaken: from.seatsTaken - 1 });
      tx.update(doc(db, 'studyGroups/g2'), { seatsTaken: to.seatsTaken + 1 });
      tx.delete(doc(db, 'studyGroups/g1/members/student-1'));
      tx.set(doc(db, 'studyGroups/g2/members/student-1'), {
        studentId: 'student-1',
        groupId: 'g2',
        name: 'طالب',
        joinedAt: now(),
        status: 'active',
      });
    });

  const snapshot = readAsAdmin;

  it('النقل يحرّك مقعدًا في كل اتجاه وينقل ارتباط العضو', async () => {
    await seedTwoGroups();

    await assertSucceeds(move(asTeacher()));

    assert.equal((await snapshot('studyGroups/g1')).seatsTaken, 2);
    assert.equal((await snapshot('studyGroups/g2')).seatsTaken, 3);
    assert.equal(await snapshot('studyGroups/g1/members/student-1'), null);
    const moved = await snapshot('studyGroups/g2/members/student-1');
    assert.equal(moved.groupId, 'g2');
    assert.equal(moved.studentId, 'student-1');
  });

  it('الهدف المكتمل: القواعد ترفض النقل ولو تجاهل العميل الفحص', async () => {
    await seedTwoGroups({ toTotal: 3, toTaken: 3 });

    await assertFails(move(asTeacher(), { check: false }));

    // ولا كتابة جزئية: المصدر والعضوية كما كانا.
    assert.equal((await snapshot('studyGroups/g1')).seatsTaken, 3);
    assert.notEqual(await snapshot('studyGroups/g1/members/student-1'), null);
  });

  it('الهدف الموقوف لا يستقبل نقلًا', async () => {
    await seedTwoGroups({ toActive: false });

    await assertFails(move(asTeacher(), { check: false }));
  });

  it('الطالب ومدرس آخر لا ينقلان', async () => {
    await seedTwoGroups();

    await assertFails(move(asStudent()));
    await assertFails(
      move(testEnv.authenticatedContext('teacher-2').firestore()),
    );
  });

  it('المقعد الأخير: النقل إلى آخر مقعد حر ينجح', async () => {
    // الهدف 5/5 بعد النقل: لو فحصت القواعد «مقعد حر» على حالة ما بعد
    // المعاملة لرفضت هذا النقل — وهو أخطر خطأ ممكن في هذا النموذج.
    await seedTwoGroups({ toTotal: 5, toTaken: 4 });

    await assertSucceeds(move(asTeacher()));

    assert.equal((await snapshot('studyGroups/g2')).seatsTaken, 5);
    assert.equal((await snapshot('studyGroups/g1')).seatsTaken, 2);
  });

  it('ربط العضو بالمجموعة إلزامي ومطابق للمسار', async () => {
    await seed([
      {
        path: 'studyGroups/g2',
        data: groupDoc('teacher-1', { seatsTotal: 5, seatsTaken: 2 }),
      },
    ]);

    const member = (groupId) => ({
      studentId: 'student-7',
      groupId,
      name: 'طالب',
      joinedAt: now(),
      status: 'active',
    });

    // ربط مغلوط ⇒ رفض.
    await assertFails(
      setDoc(doc(asTeacher(), 'studyGroups/g2/members/student-7'), member('g1')),
    );
    // بلا groupId (حقل ناقص) ⇒ رفض.
    await assertFails(
      setDoc(doc(asTeacher(), 'studyGroups/g2/members/student-7'), {
        studentId: 'student-7',
        name: 'طالب',
        joinedAt: now(),
        status: 'active',
      }),
    );
    // حقل زائد ⇒ رفض.
    await assertFails(
      setDoc(
        doc(asTeacher(), 'studyGroups/g2/members/student-7'),
        { ...member('g2'), seatsTotal: 3 },
      ),
    );
    // الربط الصحيح ⇒ قبول.
    await assertSucceeds(
      setDoc(doc(asTeacher(), 'studyGroups/g2/members/student-7'), member('g2')),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe('P9 — تنظيف صفوف الطلبات والانتظار عند نقل العضو', () => {
  const requestDoc = (groupId, studentId, status = 'pending') => ({
    groupId,
    groupTitle: 'الرياضيات',
    teacherId: 'teacher-1',
    studentId,
    studentName: 'طالب',
    status,
    requestedAt: now(),
    ...(status === 'pending' ? {} : { decidedAt: now(), decidedBy: 'teacher-1' }),
  });

  const waitlistDoc = (groupId, studentId, status = 'waiting') => ({
    groupId,
    groupTitle: 'الرياضيات',
    teacherId: 'teacher-1',
    studentId,
    studentName: 'طالب',
    status,
    addedAt: now(),
    ...(status === 'waiting' ? {} : { decidedAt: now(), decidedBy: 'teacher-1' }),
  });

  const requestPath = joinPath;

  it('المالك يحذف صف طالب ليس عضوًا (طلب انضمام)', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1') },
      { path: requestPath('g1', 'student-9'), data: requestDoc('g1', 'student-9', 'accepted') },
    ]);

    await assertSucceeds(
      deleteDoc(doc(asTeacher(), requestPath('g1', 'student-9'))),
    );
    assert.equal(
      await readAsAdmin(requestPath('g1', 'student-9')),
      null,
    );
  });

  it('لا يُحذف صف طالب عضو في المجموعة', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken: 1 }) },
      {
        path: 'studyGroups/g1/members/student-1',
        data: { studentId: 'student-1', groupId: 'g1', name: 'طالب', joinedAt: now(), status: 'active' },
      },
      { path: requestPath('g1', 'student-1'), data: requestDoc('g1', 'student-1', 'accepted') },
    ]);

    await assertFails(deleteDoc(doc(asTeacher(), requestPath('g1', 'student-1'))));
  });

  it('مدرس آخر والطالب لا يحذفان صفوف الطلبات', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1') },
      { path: requestPath('g1', 'student-9'), data: requestDoc('g1', 'student-9', 'rejected') },
    ]);

    await assertFails(
      deleteDoc(
        doc(testEnv.authenticatedContext('teacher-2').firestore(), requestPath('g1', 'student-9')),
      ),
    );
    await assertFails(
      deleteDoc(doc(asStudent(), requestPath('g1', 'student-9'))),
    );
  });

  it('المالك يحذف صف انتظار لطالب ليس عضوًا فقط', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTotal: 6, seatsTaken: 6 }) },
      { path: waitlistPath('g1', 'student-9'), data: waitlistDoc('g1', 'student-9', 'promoted') },
    ]);

    await assertFails(
      deleteDoc(doc(asStudent(), waitlistPath('g1', 'student-9'))),
    );
    await assertSucceeds(
      deleteDoc(doc(asTeacher(), waitlistPath('g1', 'student-9'))),
    );
  });

  it('لا يُحذف صف انتظار طالب عضو في المجموعة', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTotal: 6, seatsTaken: 6 }) },
      {
        path: 'studyGroups/g1/members/student-1',
        data: { studentId: 'student-1', groupId: 'g1', name: 'طالب', joinedAt: now(), status: 'active' },
      },
      { path: waitlistPath('g1', 'student-1'), data: waitlistDoc('g1', 'student-1', 'waiting') },
    ]);

    await assertFails(deleteDoc(doc(asTeacher(), waitlistPath('g1', 'student-1'))));
  });

  it('المعاملة الكاملة: نقل + تنظيف في دفعة واحدة', async () => {
    await seed([
      {
        path: 'studyGroups/g1',
        data: groupDoc('teacher-1', { seatsTotal: 6, seatsTaken: 3 }),
      },
      {
        path: 'studyGroups/g2',
        data: groupDoc('teacher-1', { title: 'الفيزياء', seatsTotal: 5, seatsTaken: 2 }),
      },
      {
        path: 'studyGroups/g1/members/student-1',
        data: { studentId: 'student-1', groupId: 'g1', name: 'طالب', joinedAt: now(), status: 'active' },
      },
      // سجل قديم في المصدر + صفوف مفتوحة في الهدف.
      { path: requestPath('g1', 'student-1'), data: requestDoc('g1', 'student-1', 'accepted') },
      { path: requestPath('g2', 'student-1'), data: requestDoc('g2', 'student-1', 'pending') },
      { path: waitlistPath('g2', 'student-1'), data: waitlistDoc('g2', 'student-1', 'waiting') },
    ]);

    const db = asTeacher();
    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const fromSnap = await tx.get(doc(db, 'studyGroups/g1'));
        const toSnap = await tx.get(doc(db, 'studyGroups/g2'));
        const from = fromSnap.data();
        const to = toSnap.data();

        tx.update(doc(db, 'studyGroups/g1'), { seatsTaken: from.seatsTaken - 1 });
        tx.update(doc(db, 'studyGroups/g2'), { seatsTaken: to.seatsTaken + 1 });

        tx.delete(doc(db, 'studyGroups/g1/members/student-1'));
        tx.set(doc(db, 'studyGroups/g2/members/student-1'), {
          studentId: 'student-1',
          groupId: 'g2',
          name: 'طالب',
          joinedAt: now(),
          status: 'active',
          movedAt: now(),
          movedFromGroupTitle: 'الرياضيات',
        });

        // الهدف: إغلاق الصفوف المفتوحة.
        tx.update(doc(db, requestPath('g2', 'student-1')), {
          status: 'accepted',
          decidedAt: now(),
          decidedBy: 'teacher-1',
        });
        tx.update(doc(db, waitlistPath('g2', 'student-1')), {
          status: 'promoted',
          decidedAt: now(),
          decidedBy: 'teacher-1',
        });

        // المصدر: حذف السجل الذي صار بلا معنى.
        tx.delete(doc(db, requestPath('g1', 'student-1')));
      }),
    );

    const movedMember = await readAsAdmin('studyGroups/g2/members/student-1');
    assert.equal(movedMember.groupId, 'g2');
    assert.equal(movedMember.movedFromGroupTitle, 'الرياضيات');
    assert.ok(movedMember.movedAt, 'أثر النقل مكتوب');

    assert.equal(await readAsAdmin(requestPath('g1', 'student-1')), null, 'سجل المصدر محذوف');
    assert.equal((await readAsAdmin(requestPath('g2', 'student-1'))).status, 'accepted');
    assert.equal((await readAsAdmin(waitlistPath('g2', 'student-1'))).status, 'promoted');
    assert.equal((await readAsAdmin('studyGroups/g1')).seatsTaken, 2);
    assert.equal((await readAsAdmin('studyGroups/g2')).seatsTaken, 3);
  });

  it('العضو مع أثر النقل: حقول مسموحة بأنواع صحيحة فقط', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken: 2 }) },
    ]);

    const base = {
      studentId: 'student-5',
      groupId: 'g1',
      name: 'طالب',
      joinedAt: now(),
      status: 'active',
    };
    const path = 'studyGroups/g1/members/student-5';

    await assertFails(
      setDoc(doc(asTeacher(), path), { ...base, movedAt: 'أمس' }),
    );
    await assertFails(
      setDoc(doc(asTeacher(), path), { ...base, movedFromGroupTitle: 42 }),
    );
    await assertSucceeds(
      setDoc(doc(asTeacher(), path), {
        ...base,
        movedAt: now(),
        movedFromGroupTitle: 'الرياضيات',
      }),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe('سلامة المحاكي نفسه (حماية من اختبارات وهمية)', () => {
  it('البيانات التجريبية تُكتب فعلًا مع تجاوز القواعد', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const snapshot = await getDoc(doc(context.firestore(), 'users/student-1'));
      assert.equal(snapshot.exists(), true);
    });
  });
});
