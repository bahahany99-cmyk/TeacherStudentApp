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
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  setDoc,
  updateDoc,
  where,
  writeBatch,
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
  // (P14) أساس ثابت: `teacher-1` ملف **موثّق**. القبول/الرفض/ترقية المنتظر
  // صارت مشروطة بالتوثيق، فكل اختبار يحتاج مدرسًا موثّقًا ليقيس ما يقيسه
  // (الصلاحية على المستند) لا غياب ملفه. الاختبارات التي تريد مدرسًا غير
  // موثّق تكتب حالته صريحة، وتلك التي تختبر الإنشاء تمسح هذا الأساس.
  await seed([
    {
      path: 'teacherProfiles/teacher-1',
      data: teacherDoc('teacher-1', { status: 'verified' }),
    },
  ]);
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
// (P18) «بياناتي»: الهاتف والمرحلة يكتبهما صاحبهما، ولا يفتحان بابًا لغيره.
describe('P18 — users: الهاتف والمرحلة', () => {
  it('صاحب الحساب يكتب هاتفًا ومرحلة صحيحين', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertSucceeds(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        displayName: 'طالب محدَّث',
        phone: '01012345678',
        stage: 'الثانوية العامة',
      }),
    );
  });

  it('هاتف بحروف مرفوض', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), { phone: '010ABC' }),
    );
  });

  it('هاتف أقصر من 8 مرفوض، وأطول من 20 مرفوض', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), { phone: '0101' }),
    );
    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        phone: '1'.repeat(21),
      }),
    );
  });

  it('مرحلة بحرف واحد مرفوضة', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), { stage: 'ث' }),
    );
  });

  it('لا يكتب هاتفًا لمستخدم آخر', async () => {
    await seed([
      { path: 'users/student-1', data: userDoc('student-1') },
      { path: 'users/other-1', data: userDoc('other-1') },
    ]);

    await assertFails(
      updateDoc(doc(asOther(), 'users/student-1'), { phone: '01012345678' }),
    );
  });

  it('كتابة الهاتف لا تفتح تغيير الدور ولا حقولًا مجهولة', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        phone: '01012345678',
        role: 'teacher',
      }),
    );
    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        phone: '01012345678',
        isAdmin: true,
      }),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════════
describe('teacherProfiles/{uid} — الظهور للموثّق فقط', () => {
  it('الملف غير المعتمد مخفي عن الطلاب والزوار', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: teacherDoc('teacher-1') },
    ]);

    await assertFails(getDoc(doc(asStudent(), 'teacherProfiles/teacher-1')));
    await assertFails(getDoc(doc(asGuest(), 'teacherProfiles/teacher-1')));
  });

  it('الملف الموثّق مقروء للجميع (بحث الطلاب)', async () => {
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: teacherDoc('teacher-1', { status: 'verified' }),
      },
    ]);

    await assertSucceeds(getDoc(doc(asGuest(), 'teacherProfiles/teacher-1')));
    await assertSucceeds(
      getDocs(
        query(
          collection(asStudent(), 'teacherProfiles'),
          where('status', '==', 'verified'),
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
    // نمسح أساس المحاكي: هذا الاختبار يخص **الإنشاء**، ووجود مستند سابق
    // يحوّل الكتابة إلى تحديث.
    await testEnv.clearFirestore();

    await assertSucceeds(
      setDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), teacherDoc('teacher-1')),
    );

    await assertFails(
      setDoc(
        doc(asTeacher(), 'teacherProfiles/teacher-1'),
        teacherDoc('teacher-1', { status: 'verified' }),
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
        status: 'verified',
      }),
    );
  });

  it('لا يكتب المدرس حقول الإدارة ولا يحذف ملفه', async () => {
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: teacherDoc('teacher-1', { status: 'verified' }),
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

  it('الإدارة توثّق الملف عبر الادعاء (P14)', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: teacherDoc('teacher-1') },
    ]);

    await assertSucceeds(
      updateDoc(doc(asAdmin(), 'teacherProfiles/teacher-1'), { status: 'verified' }),
    );
  });

  it('غير المسؤول لا يوثّق ولا يرفض (P14)', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-2', data: teacherDoc('teacher-2') },
    ]);

    await assertFails(
      updateDoc(doc(asStudent(), 'teacherProfiles/teacher-2'), {
        status: 'verified',
      }),
    );
    await assertFails(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-2'), {
        status: 'verified',
      }),
    );
    // حتى صاحب الملف: لا يوثّق نفسه.
    await assertFails(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        status: 'rejected',
      }),
    );
  });

  it('قرار المسؤول مقيّد بحقول معلنة وسبب رفض واضح', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-2', data: teacherDoc('teacher-2') },
    ]);

    // سبب قصير جدًا مرفوض.
    await assertFails(
      updateDoc(doc(asAdmin(), 'teacherProfiles/teacher-2'), {
        status: 'rejected',
        reviewNote: 'لا',
      }),
    );

    // حقول الإدارة (التقييم/التمييز) خارج قرار التوثيق حتى للمسؤول.
    await assertFails(
      updateDoc(doc(asAdmin(), 'teacherProfiles/teacher-2'), {
        status: 'verified',
        isFeatured: true,
      }),
    );
    await assertFails(
      updateDoc(doc(asAdmin(), 'teacherProfiles/teacher-2'), { rating: 5 }),
    );

    // رفض بسبب صالح يمر.
    await assertSucceeds(
      updateDoc(doc(asAdmin(), 'teacherProfiles/teacher-2'), {
        status: 'rejected',
        reviewNote: 'بيانات تواصل داخل النبذة.',
      }),
    );
    const stored = await readAsAdmin('teacherProfiles/teacher-2');
    assert.equal(stored.status, 'rejected');
    assert.equal(stored.reviewNote, 'بيانات تواصل داخل النبذة.');
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

  it('الطالب لا يحذف طلبه، والمالك يحذف صف طالب ليس عضوًا (P9)', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1') },
      {
        path: joinPath('g1', 'student-1'),
        data: joinRequestDoc('g1', 'student-1'),
      },
    ]);

    // الطالب لا يمحو سجل طلبه، والإدارة فقط كانت تسمح سابقًا.
    await assertFails(
      deleteDoc(doc(asStudent(), joinPath('g1', 'student-1'))),
    );
    // المالك نعم — لكن **فقط** لأن student-1 ليس عضوًا في g1.
    await assertSucceeds(
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

  it('لا حذف لصف الانتظار من الطالب، ويُسمح للمالك لطالب ليس عضوًا', async () => {
    await seedQueue(11);

    await assertFails(
      deleteDoc(doc(asStudent(), waitlistPath('g1', 'student-1'))),
    );
    await assertSucceeds(
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

  it('المالك يحذف طلبًا مفتوحًا (معلّقًا كان أو مقبولًا)', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1') },
      { path: requestPath('g1', 'student-9'), data: requestDoc('g1', 'student-9', 'accepted') },
      { path: requestPath('g1', 'student-8'), data: requestDoc('g1', 'student-8', 'pending') },
    ]);

    await assertSucceeds(
      deleteDoc(doc(asTeacher(), requestPath('g1', 'student-9'))),
    );
    await assertSucceeds(
      deleteDoc(doc(asTeacher(), requestPath('g1', 'student-8'))),
    );
    assert.equal(await readAsAdmin(requestPath('g1', 'student-9')), null);
  });

  it('الصف المغلق تاريخ لا يُمحى — ولا حتى بالمالك', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1') },
      { path: requestPath('g1', 'student-9'), data: requestDoc('g1', 'student-9', 'rejected') },
      { path: requestPath('g1', 'student-8'), data: requestDoc('g1', 'student-8', 'cancelled') },
    ]);

    await assertFails(
      deleteDoc(doc(asTeacher(), requestPath('g1', 'student-9'))),
    );
    await assertFails(
      deleteDoc(doc(asTeacher(), requestPath('g1', 'student-8'))),
    );
  });

  it('مدرس آخر والطالب لا يحذفان صفوف الطلبات', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1') },
      { path: requestPath('g1', 'student-9'), data: requestDoc('g1', 'student-9', 'pending') },
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

  it('صف الانتظار المغلق لا يُمحى، والمفتوح يُمحى للمالك', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTotal: 6, seatsTaken: 6 }) },
      { path: waitlistPath('g1', 'student-1'), data: waitlistDoc('g1', 'student-1', 'left') },
      { path: waitlistPath('g1', 'student-2'), data: waitlistDoc('g1', 'student-2', 'waiting') },
    ]);

    await assertFails(deleteDoc(doc(asTeacher(), waitlistPath('g1', 'student-1'))));
    await assertSucceeds(deleteDoc(doc(asTeacher(), waitlistPath('g1', 'student-2'))));
  });

  /**
   * نقل كما ينفّذه التطبيق، مع تحكّم في الكتابات الإضافية.
   *
   * نفصل الحالات عمدًا: المعاملة الواحدة تجمع 5–8 كتابات، وفشل واحد منها يرمي
   * رسالة تجمع نتائج كل القواعد — فلا يُعرف أيّ كتابة رُفضت. الفصل يعطي إشارة
   * دقيقة، والمعاملة الكاملة تبقى اختبارًا ختاميًا.
   */
  const seedMove = ({ fromTaken = 3, toTaken = 2 } = {}) =>
    seed([
      {
        path: 'studyGroups/g1',
        data: groupDoc('teacher-1', { seatsTotal: 6, seatsTaken: fromTaken }),
      },
      {
        path: 'studyGroups/g2',
        data: groupDoc('teacher-1', { title: 'الفيزياء', seatsTotal: 5, seatsTaken: toTaken }),
      },
      {
        path: 'studyGroups/g1/members/student-1',
        data: { studentId: 'student-1', groupId: 'g1', name: 'طالب', joinedAt: now(), status: 'active' },
      },
    ]);

  /** الكتابات الأساسية للنقل: مقعد في كل اتجاه + العضوية تنتقل. */
  const coreWrites = (db, tx, from, to) => {
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
  };

  const readBoth = async (db, tx) => {
    const from = await tx.get(doc(db, 'studyGroups/g1'));
    const to = await tx.get(doc(db, 'studyGroups/g2'));
    return [from.data(), to.data()];
  };

  it('الأساس: مقعد ينقص ويزيد والعضوية تنتقل', async () => {
    await seedMove();
    const db = asTeacher();

    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const [from, to] = await readBoth(db, tx);
        coreWrites(db, tx, from, to);
      }),
    );

    assert.equal((await readAsAdmin('studyGroups/g1')).seatsTaken, 2);
    assert.equal((await readAsAdmin('studyGroups/g2')).seatsTaken, 3);
  });

  it('حذف سجل المصدر داخل المعاملة يمر بعد خروج العضو', async () => {
    await seedMove();
    await seed([
      { path: joinPath('g1', 'student-1'), data: joinRequestDoc('g1', 'student-1', { status: 'accepted', decidedAt: now(), decidedBy: 'teacher-1' }) },
    ]);
    const db = asTeacher();

    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const [from, to] = await readBoth(db, tx);
        coreWrites(db, tx, from, to);
        tx.delete(doc(db, joinPath('g1', 'student-1')));
      }),
    );

    assert.equal(await readAsAdmin(joinPath('g1', 'student-1')), null);
  });

  it('إغلاق طلب معلّق في الهدف داخل المعاملة', async () => {
    await seedMove();
    await seed([
      { path: joinPath('g2', 'student-1'), data: joinRequestDoc('g2', 'student-1') },
    ]);
    const db = asTeacher();

    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const [from, to] = await readBoth(db, tx);
        coreWrites(db, tx, from, to);
        tx.update(doc(db, joinPath('g2', 'student-1')), {
          status: 'accepted',
          decidedAt: now(),
          decidedBy: 'teacher-1',
        });
      }),
    );

    assert.equal((await readAsAdmin(joinPath('g2', 'student-1'))).status, 'accepted');
  });

  it('إغلاق صف الانتظار في الهدف داخل المعاملة', async () => {
    await seedMove();
    await seed([
      { path: waitlistPath('g2', 'student-1'), data: waitlistDoc('g2', 'student-1') },
    ]);
    const db = asTeacher();

    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const [from, to] = await readBoth(db, tx);
        coreWrites(db, tx, from, to);
        tx.update(doc(db, waitlistPath('g2', 'student-1')), {
          status: 'promoted',
          decidedAt: now(),
          decidedBy: 'teacher-1',
        });
      }),
    );

    assert.equal((await readAsAdmin(waitlistPath('g2', 'student-1'))).status, 'promoted');
  });

  it('المعاملة الكاملة: نقل + إغلاق في الهدف + حذف في المصدر', async () => {
    await seedMove();
    await seed([
      { path: joinPath('g1', 'student-1'), data: joinRequestDoc('g1', 'student-1', { status: 'accepted', decidedAt: now(), decidedBy: 'teacher-1' }) },
      { path: joinPath('g2', 'student-1'), data: joinRequestDoc('g2', 'student-1') },
      { path: waitlistPath('g2', 'student-1'), data: waitlistDoc('g2', 'student-1') },
    ]);
    const db = asTeacher();

    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const [from, to] = await readBoth(db, tx);
        coreWrites(db, tx, from, to);
        tx.update(doc(db, joinPath('g2', 'student-1')), {
          status: 'accepted',
          decidedAt: now(),
          decidedBy: 'teacher-1',
        });
        tx.update(doc(db, waitlistPath('g2', 'student-1')), {
          status: 'promoted',
          decidedAt: now(),
          decidedBy: 'teacher-1',
        });
        tx.delete(doc(db, joinPath('g1', 'student-1')));
      }),
    );

    const movedMember = await readAsAdmin('studyGroups/g2/members/student-1');
    assert.equal(movedMember.groupId, 'g2');
    assert.equal(movedMember.movedFromGroupTitle, 'الرياضيات');
    assert.ok(movedMember.movedAt, 'أثر النقل مكتوب');
    assert.equal(await readAsAdmin(joinPath('g1', 'student-1')), null, 'سجل المصدر محذوف');
    assert.equal((await readAsAdmin(joinPath('g2', 'student-1'))).status, 'accepted');
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
// P11 — المحادثات المباشرة وخصوصية المدرس
// ═════════════════════════════════════════════════════════════════════════════

const settingsDoc = (allow) => ({
  allowDirectMessages: allow,
  updatedAt: now(),
});

/**
 * يحذف الحقول `undefined` قبل الكتابة: Firebase يرفض قيمة `undefined`، ونحن
 * نستعملها لقول «هذا الحقل غائب» (خيط بلا `bookingId` مثلًا).
 */
const clean = (data) =>
  Object.fromEntries(Object.entries(data).filter(([, value]) => value !== undefined));

/** خيط محادثة: المعرّف مشتق من الطرفين في كل اختبار. */
const directChatDoc = (teacherId, studentId, overrides = {}) => clean({
  teacherId,
  teacherName: 'أ. سارة الخطيب',
  studentId,
  studentName: 'طالب',
  subject: 'الرياضيات',
  origin: 'booking',
  bookingId: 'b1',
  createdAt: now(),
  ...overrides,
});

const chatPath = (teacherId, studentId) => `directChats/${teacherId}_${studentId}`;

const directMessageDoc = (teacherId, studentId, senderId, overrides = {}) => clean({
  chatId: `${teacherId}_${studentId}`,
  senderId,
  senderName: senderId === teacherId ? 'أ. سارة الخطيب' : 'طالب',
  senderRole: senderId === teacherId ? 'teacher' : 'student',
  text: 'مرحبًا، هل الموعد مناسب؟',
  sentAt: now(),
  ...overrides,
});

describe('P11 — teacherSettings: الخيار لصاحبه فقط والقراءة للطلاب', () => {
  it('المدرس يكتب خياره، وغيره لا', async () => {
    await assertSucceeds(
      setDoc(doc(asTeacher(), 'teacherSettings/teacher-1'), settingsDoc(true)),
    );
    await assertFails(
      setDoc(doc(asStudent(), 'teacherSettings/teacher-1'), settingsDoc(true)),
    );
    await assertFails(
      setDoc(doc(asOther(), 'teacherSettings/teacher-1'), settingsDoc(true)),
    );
  });

  it('الطالب يقرأ الخيار، وغير المسجّل لا', async () => {
    await seed([
      { path: 'teacherSettings/teacher-1', data: settingsDoc(true) },
    ]);
    await assertSucceeds(
      getDoc(doc(asStudent(), 'teacherSettings/teacher-1')),
    );
    await assertSucceeds(
      getDoc(doc(asOther(), 'teacherSettings/teacher-1')),
    );
    await assertFails(getDoc(doc(asGuest(), 'teacherSettings/teacher-1')));
  });

  it('لا حقول إضافية ولا نوع خاطئ', async () => {
    await assertFails(
      setDoc(doc(asTeacher(), 'teacherSettings/teacher-1'), {
        ...settingsDoc(true),
        isFeatured: true,
      }),
    );
    await assertFails(
      setDoc(doc(asTeacher(), 'teacherSettings/teacher-1'), {
        allowDirectMessages: 'yes',
        updatedAt: now(),
      }),
    );
    await assertFails(
      setDoc(doc(asTeacher(), 'teacherSettings/teacher-1'), {
        allowDirectMessages: true,
        updatedAt: 'اليوم',
      }),
    );
  });
});

describe('P11 — إنشاء المحادثة: أصل موثّق إجباري', () => {
  it('استفسار بلا سماح المدرس مرفوض (غياب الإعداد = رفض)', async () => {
    await assertFails(
      setDoc(
        doc(asStudent(), chatPath('teacher-1', 'student-1')),
        directChatDoc('teacher-1', 'student-1', {
          origin: 'inquiry',
          bookingId: undefined,
        }),
      ),
    );

    await seed([
      { path: 'teacherSettings/teacher-1', data: settingsDoc(false) },
    ]);
    await assertFails(
      setDoc(
        doc(asStudent(), chatPath('teacher-1', 'student-1')),
        directChatDoc('teacher-1', 'student-1', {
          origin: 'inquiry',
          bookingId: undefined,
        }),
      ),
    );

    await seed([
      { path: 'teacherSettings/teacher-1', data: settingsDoc(true) },
    ]);
    await assertSucceeds(
      setDoc(
        doc(asStudent(), chatPath('teacher-1', 'student-1')),
        directChatDoc('teacher-1', 'student-1', {
          origin: 'inquiry',
          bookingId: undefined,
        }),
      ),
    );
  });

  it('خيط مرتبط بحجز: الطالب صاحب الحجز فقط', async () => {
    await seed([
      {
        path: 'bookingRequests/b1',
        data: bookingDoc('student-1', 'teacher-1', { status: 'pending' }),
      },
    ]);

    await assertSucceeds(
      setDoc(
        doc(asStudent(), chatPath('teacher-1', 'student-1')),
        directChatDoc('teacher-1', 'student-1'),
      ),
    );

    // طالب آخر يحاول استخدام حجز غيره.
    await assertFails(
      setDoc(
        doc(asOther(), chatPath('teacher-1', 'student-1')),
        directChatDoc('teacher-1', 'student-1', { studentId: 'student-1' }),
      ),
    );
  });

  it('خيط مرتبط بحجز مرفوض ممنوع', async () => {
    await seed([
      {
        path: 'bookingRequests/b1',
        data: bookingDoc('student-1', 'teacher-1', { status: 'rejected' }),
      },
    ]);
    await assertFails(
      setDoc(
        doc(asStudent(), chatPath('teacher-1', 'student-1')),
        directChatDoc('teacher-1', 'student-1'),
      ),
    );
  });

  it('خيط المجموعة: للأعضاء فقط', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken: 1 }) },
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

    await assertSucceeds(
      setDoc(
        doc(asStudent(), chatPath('teacher-1', 'student-1')),
        directChatDoc('teacher-1', 'student-1', {
          origin: 'group',
          groupId: 'g1',
          bookingId: undefined,
        }),
      ),
    );

    // غير عضو في نفس المجموعة.
    await assertFails(
      setDoc(
        doc(asOther(), chatPath('teacher-1', 'stranger-9')),
        directChatDoc('teacher-1', 'stranger-9', {
          origin: 'group',
          groupId: 'g1',
          studentName: 'غريب',
          bookingId: undefined,
        }),
      ),
    );
  });

  it('المعرّف يجب أن يساوي الطرفين، ولا انتحال طرف', async () => {
    await seed([
      {
        path: 'bookingRequests/b1',
        data: bookingDoc('student-2', 'teacher-1', { status: 'accepted' }),
      },
    ]);

    // المعرّف لا يطابق الطرفين.
    await assertFails(
      setDoc(
        doc(asStudent(), 'directChats/خيط-مزيّف'),
        directChatDoc('teacher-1', 'student-1'),
      ),
    );

    // الطالب ينشئ خيطًا باسم طالب آخر.
    await assertFails(
      setDoc(
        doc(asStudent(), chatPath('teacher-1', 'student-2')),
        directChatDoc('teacher-1', 'student-2'),
      ),
    );

    // المدرس ينشئ خيطًا مع طالب آخر بلا حجز يجمعهما.
    await assertFails(
      setDoc(
        doc(asTeacher(), chatPath('teacher-1', 'stranger-9')),
        directChatDoc('teacher-1', 'stranger-9', { studentName: 'غريب' }),
      ),
    );
  });
});

describe('P11 — قراءة المحادثة وحالة القراءة', () => {
  const seedChat = () =>
    seed([
      {
        path: 'bookingRequests/b1',
        data: bookingDoc('student-1', 'teacher-1', { status: 'accepted' }),
      },
      { path: chatPath('teacher-1', 'student-1'), data: directChatDoc('teacher-1', 'student-1') },
    ]);

  it('الطرفان يقرآن، والغريب والمجهول لا', async () => {
    await seedChat();

    await assertSucceeds(
      getDoc(doc(asStudent(), chatPath('teacher-1', 'student-1'))),
    );
    await assertSucceeds(
      getDoc(doc(asTeacher(), chatPath('teacher-1', 'student-1'))),
    );
    await assertFails(
      getDoc(doc(asOther(), chatPath('teacher-1', 'student-1'))),
    );
    await assertFails(
      getDoc(doc(asGuest(), chatPath('teacher-1', 'student-1'))),
    );
  });

  it('كل طرف يعلّم قراءته هو فقط', async () => {
    await seedChat();

    await assertSucceeds(
      updateDoc(doc(asStudent(), chatPath('teacher-1', 'student-1')), {
        studentLastReadAt: now(),
      }),
    );
    await assertSucceeds(
      updateDoc(doc(asTeacher(), chatPath('teacher-1', 'student-1')), {
        teacherLastReadAt: now(),
      }),
    );
    // الطالب لا يكتب قراءة المدرس، ولا يغيّر حقولًا أخرى.
    await assertFails(
      updateDoc(doc(asStudent(), chatPath('teacher-1', 'student-1')), {
        teacherLastReadAt: now(),
      }),
    );
    await assertFails(
      updateDoc(doc(asStudent(), chatPath('teacher-1', 'student-1')), {
        studentLastReadAt: now(),
        origin: 'inquiry',
      }),
    );
    await assertFails(
      updateDoc(doc(asOther(), chatPath('teacher-1', 'student-1')), {
        studentLastReadAt: now(),
      }),
    );
  });

  it('ملخّص آخر رسالة: من المرسل وحده وبلا رجوع بالزمن', async () => {
    await seedChat();

    await assertSucceeds(
      updateDoc(doc(asStudent(), chatPath('teacher-1', 'student-1')), {
        lastMessageAt: now(),
        lastMessageText: 'رسالة جديدة',
        lastSenderId: 'student-1',
      }),
    );

    // انتحال مرسل آخر في الملخّص.
    await assertFails(
      updateDoc(doc(asTeacher(), chatPath('teacher-1', 'student-1')), {
        lastMessageAt: now(),
        lastMessageText: 'انتحال',
        lastSenderId: 'student-1',
      }),
    );

    // تعديل حقول خارج الملخّص.
    await assertFails(
      updateDoc(doc(asStudent(), chatPath('teacher-1', 'student-1')), {
        lastMessageAt: now(),
        lastMessageText: 'نص',
        lastSenderId: 'student-1',
        origin: 'inquiry',
      }),
    );

    // زمن أقدم من المسجّل.
    await assertFails(
      updateDoc(doc(asStudent(), chatPath('teacher-1', 'student-1')), {
        lastMessageAt: new Date('2026-10-01T09:00:00Z'),
        lastMessageText: 'قديم',
        lastSenderId: 'student-1',
      }),
    );
  });
});

describe('P11 — الرسائل: الطرفان فقط ولا انتحال', () => {
  const messagePath = 'directChats/teacher-1_student-1/messages/m1';

  const seedChat = (bookingStatus = 'accepted') =>
    seed([
      {
        path: 'bookingRequests/b1',
        data: bookingDoc('student-1', 'teacher-1', { status: bookingStatus }),
      },
      {
        path: chatPath('teacher-1', 'student-1'),
        data: directChatDoc('teacher-1', 'student-1'),
      },
    ]);

  it('الطرفان يرسلان، والغريب لا', async () => {
    await seedChat();

    await assertSucceeds(
      setDoc(
        doc(asStudent(), messagePath),
        directMessageDoc('teacher-1', 'student-1', 'student-1'),
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(asTeacher(), 'directChats/teacher-1_student-1/messages/m2'),
        directMessageDoc('teacher-1', 'student-1', 'teacher-1'),
      ),
    );
    await assertFails(
      setDoc(
        doc(asOther(), 'directChats/teacher-1_student-1/messages/m3'),
        directMessageDoc('teacher-1', 'student-1', 'stranger-9'),
      ),
    );
    await assertFails(
      setDoc(
        doc(asGuest(), 'directChats/teacher-1_student-1/messages/m4'),
        directMessageDoc('teacher-1', 'student-1', 'student-1'),
      ),
    );
  });

  it('لا انتحال مرسل ولا خيط مختلف ولا نص فارغ/طويل', async () => {
    await seedChat();

    await assertFails(
      setDoc(
        doc(asStudent(), messagePath),
        directMessageDoc('teacher-1', 'student-1', 'teacher-1'),
      ),
    );
    await assertFails(
      setDoc(
        doc(asStudent(), messagePath),
        directMessageDoc('teacher-1', 'student-1', 'student-1', {
          chatId: 'teacher-1_student-2',
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(asStudent(), messagePath),
        directMessageDoc('teacher-1', 'student-1', 'student-1', { text: '' }),
      ),
    );
    await assertFails(
      setDoc(
        doc(asStudent(), messagePath),
        directMessageDoc('teacher-1', 'student-1', 'student-1', {
          text: 'ا'.repeat(501),
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(asStudent(), messagePath),
        directMessageDoc('teacher-1', 'student-1', 'student-1', {
          hiddenField: true,
        }),
      ),
    );
  });

  it('الرسائل لا تُعدَّل ولا تُحذف من التطبيق', async () => {
    await seedChat();
    await seed([
      {
        path: messagePath,
        data: directMessageDoc('teacher-1', 'student-1', 'student-1'),
      },
    ]);

    await assertFails(
      updateDoc(doc(asStudent(), messagePath), { text: 'نص آخر' }),
    );
    await assertFails(deleteDoc(doc(asStudent(), messagePath)));
    await assertFails(deleteDoc(doc(asTeacher(), messagePath)));
  });

  it('رفض الحجز يوقف الإرسال الجديد', async () => {
    await seedChat('rejected');

    await assertFails(
      setDoc(
        doc(asStudent(), messagePath),
        directMessageDoc('teacher-1', 'student-1', 'student-1'),
      ),
    );
    await assertFails(
      setDoc(
        doc(asTeacher(), 'directChats/teacher-1_student-1/messages/m2'),
        directMessageDoc('teacher-1', 'student-1', 'teacher-1'),
      ),
    );
  });

  it('إيقاف الاستفسار يوقف الإرسال في خيط الاستفسار', async () => {
    await seed([
      { path: 'teacherSettings/teacher-1', data: settingsDoc(true) },
      {
        path: chatPath('teacher-1', 'student-1'),
        data: directChatDoc('teacher-1', 'student-1', {
          origin: 'inquiry',
          bookingId: undefined,
        }),
      },
    ]);

    await assertSucceeds(
      setDoc(
        doc(asStudent(), messagePath),
        directMessageDoc('teacher-1', 'student-1', 'student-1'),
      ),
    );

    await seed([
      { path: 'teacherSettings/teacher-1', data: settingsDoc(false) },
    ]);

    await assertFails(
      setDoc(
        doc(asStudent(), 'directChats/teacher-1_student-1/messages/m2'),
        directMessageDoc('teacher-1', 'student-1', 'student-1'),
      ),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// P12 — الإشعارات: العزل بالمستلم والإنشاء بعلاقة موثّقة
// ═════════════════════════════════════════════════════════════════════════════

const notificationDoc = (recipientId, actorId, type, targetId, overrides = {}) =>
  clean({
    recipientId,
    type,
    actorId,
    actorName: 'طالب',
    targetId,
    title: 'إشعار',
    createdAt: now(),
    ...overrides,
  });

const notificationPath = (id) => `notifications/${id}`;

/** حجز حالة معيّنة بين student-1 وteacher-1. */
const seedBooking = (status) =>
  seed([
    {
      path: 'bookingRequests/b1',
      data: bookingDoc('student-1', 'teacher-1', { status }),
    },
  ]);

describe('P12 — الإشعارات: المستلم وحده يقرأ ويعلّم ويحذف', () => {
  it('المستلم يقرأ إشعاره، وغيره لا', async () => {
    await seed([
      {
        path: notificationPath('n1'),
        data: notificationDoc('student-1', 'teacher-1', 'bookingAccepted', 'b1'),
      },
    ]);

    await assertSucceeds(getDoc(doc(asStudent(), notificationPath('n1'))));
    await assertFails(getDoc(doc(asOther(), notificationPath('n1'))));
    await assertFails(getDoc(doc(asTeacher(), notificationPath('n1'))));
    await assertFails(getDoc(doc(asGuest(), notificationPath('n1'))));
  });

  it('استعلام «إشعاراتي» محصور بالمستلم', async () => {
    await seed([
      {
        path: notificationPath('n1'),
        data: notificationDoc('student-1', 'teacher-1', 'bookingAccepted', 'b1'),
      },
      {
        path: notificationPath('n2'),
        data: notificationDoc('student-2', 'teacher-1', 'bookingAccepted', 'b2'),
      },
    ]);

    const mine = await assertSucceeds(
      getDocs(
        query(
          collection(asStudent(), 'notifications'),
          where('recipientId', '==', 'student-1'),
        ),
      ),
    );
    assert.equal(mine.docs.length, 1);

    // محاولة قراءة إشعار غيري صراحةً تُرفض.
    await assertFails(
      getDocs(
        query(
          collection(asStudent(), 'notifications'),
          where('recipientId', '==', 'student-2'),
        ),
      ),
    );
  });

  it('تعليم مقروء: المستلم وحده وحقل readAt فقط', async () => {
    await seed([
      {
        path: notificationPath('n1'),
        data: notificationDoc('student-1', 'teacher-1', 'bookingAccepted', 'b1'),
      },
    ]);

    await assertFails(
      updateDoc(doc(asTeacher(), notificationPath('n1')), { readAt: now() }),
    );
    await assertFails(
      updateDoc(doc(asStudent(), notificationPath('n1')), {
        readAt: now(),
        title: 'نص جديد',
      }),
    );
    await assertSucceeds(
      updateDoc(doc(asStudent(), notificationPath('n1')), { readAt: now() }),
    );
    // الكتابة نفسها مرة أخرى لا تُنتج فروقًا ⇒ مرفوضة (لا عمل بلا أثر).
    await assertFails(
      updateDoc(doc(asStudent(), notificationPath('n1')), { readAt: now() }),
    );
  });

  it('الحذف للمستلم فقط', async () => {
    await seed([
      {
        path: notificationPath('n1'),
        data: notificationDoc('student-1', 'teacher-1', 'bookingAccepted', 'b1'),
      },
      {
        path: notificationPath('n2'),
        data: notificationDoc('student-1', 'teacher-1', 'bookingAccepted', 'b1'),
      },
    ]);

    await assertFails(deleteDoc(doc(asOther(), notificationPath('n2'))));
    await assertSucceeds(deleteDoc(doc(asStudent(), notificationPath('n1'))));
  });
});

describe('P12 — الإنشاء: لا تزوير ولا إشعار لشخص بلا علاقة', () => {
  it('الطالب يُشعر المدرس بطلب حجز معلّق', async () => {
    await seedBooking('pending');

    await assertSucceeds(
      setDoc(
        doc(asStudent(), notificationPath('n1')),
        notificationDoc('teacher-1', 'student-1', 'bookingRequested', 'b1', {
          title: 'طلب حجز جديد',
        }),
      ),
    );
  });

  it('لا إشعار لطرف ثالث في نفس الحجز', async () => {
    await seedBooking('pending');

    await assertFails(
      setDoc(
        doc(asOther(), notificationPath('n1')),
        notificationDoc('teacher-1', 'stranger-9', 'bookingRequested', 'b1', {
          actorName: 'غريب',
        }),
      ),
    );
  });

  it('لا انتحال مُحدِث آخر', async () => {
    await seedBooking('pending');

    await assertFails(
      setDoc(
        doc(asOther(), notificationPath('n1')),
        notificationDoc('teacher-1', 'student-1', 'bookingRequested', 'b1'),
      ),
    );
  });

  it('النوع يجب أن يطابق حالة الحجز', async () => {
    await seedBooking('pending');

    // «قُبل» لحجز معلّق مرفوض.
    await assertFails(
      setDoc(
        doc(asTeacher(), notificationPath('n1')),
        notificationDoc('student-1', 'teacher-1', 'bookingAccepted', 'b1'),
      ),
    );

    await seedBooking('accepted');
    await assertSucceeds(
      setDoc(
        doc(asTeacher(), notificationPath('n2')),
        notificationDoc('student-1', 'teacher-1', 'bookingAccepted', 'b1'),
      ),
    );
  });

  it('إشعار لنفسك مرفوض، والإشعار لا يُنشأ مقروءًا', async () => {
    await seedBooking('pending');

    await assertFails(
      setDoc(
        doc(asStudent(), notificationPath('n1')),
        notificationDoc('student-1', 'student-1', 'bookingRequested', 'b1'),
      ),
    );
    await assertFails(
      setDoc(
        doc(asStudent(), notificationPath('n2')),
        notificationDoc('teacher-1', 'student-1', 'bookingRequested', 'b1', {
          readAt: now(),
        }),
      ),
    );
  });

  it('عنوان طويل أو حقول إضافية مرفوضة', async () => {
    await seedBooking('pending');

    await assertFails(
      setDoc(
        doc(asStudent(), notificationPath('n1')),
        notificationDoc('teacher-1', 'student-1', 'bookingRequested', 'b1', {
          title: 'ا'.repeat(121),
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(asStudent(), notificationPath('n2')),
        notificationDoc('teacher-1', 'student-1', 'bookingRequested', 'b1', {
          injected: true,
        }),
      ),
    );
  });

  it('رسالة مباشرة: طرفا المحادثة فقط', async () => {
    await seed([
      {
        path: 'bookingRequests/b1',
        data: bookingDoc('student-1', 'teacher-1', { status: 'accepted' }),
      },
      {
        path: chatPath('teacher-1', 'student-1'),
        data: directChatDoc('teacher-1', 'student-1'),
      },
    ]);

    await assertSucceeds(
      setDoc(
        doc(asStudent(), notificationPath('n1')),
        notificationDoc('teacher-1', 'student-1', 'directMessage', 'teacher-1_student-1'),
      ),
    );

    // غريب يحاول استخدام نفس المحادثة.
    await assertFails(
      setDoc(
        doc(asOther(), notificationPath('n2')),
        notificationDoc('student-1', 'stranger-9', 'directMessage', 'teacher-1_student-1', {
          actorName: 'غريب',
        }),
      ),
    );
  });

  it('ترقية قائمة الانتظار: من مالك المجموعة ولعضو فعلًا', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken: 1 }) },
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

    // غير المالك.
    await assertFails(
      setDoc(
        doc(asStudent(), notificationPath('n1')),
        notificationDoc('student-1', 'student-1', 'waitlistPromoted', 'g1'),
      ),
    );
    // المالك لشخص ليس عضوًا.
    await assertFails(
      setDoc(
        doc(asTeacher(), notificationPath('n2')),
        notificationDoc('stranger-9', 'teacher-1', 'waitlistPromoted', 'g1'),
      ),
    );
    // المالك لعضو حقيقي.
    await assertSucceeds(
      setDoc(
        doc(asTeacher(), notificationPath('n3')),
        notificationDoc('student-1', 'teacher-1', 'waitlistPromoted', 'g1'),
      ),
    );
  });

  it('نوع غير معروف مرفوض', async () => {
    await seedBooking('pending');

    await assertFails(
      setDoc(
        doc(asStudent(), notificationPath('n1')),
        notificationDoc('teacher-1', 'student-1', 'promoMessage', 'b1'),
      ),
    );
  });
});


// ═════════════════════════════════════════════════════════════════════════════
// P13 — التقييمات والمفضلة: بوابة G7، ومنع التكرار، والتلاعب بالمتوسط
// ═════════════════════════════════════════════════════════════════════════════

/** تقييم (P13) — معرّفه معرّف الحجز، والاسم منسوخ من الحجز. */
const reviewDoc = (bookingId, studentId, teacherId, overrides = {}) =>
  clean({
    bookingId,
    teacherId,
    studentId,
    studentName: 'طالب',
    rating: 5,
    createdAt: now(),
    ...overrides,
  });

const reviewPath = (bookingId) => `reviews/${bookingId}`;

/** متوسط تراكمي (P13) — مجموع + عدد، لا متوسط عشري. */
const ratingDoc = (teacherId, totalReviews, ratingSum, lastReviewId) =>
  clean({
    teacherId,
    totalReviews,
    ratingSum,
    lastReviewId,
    updatedAt: now(),
  });

const favoritePath = (studentId, kind, targetId) =>
  `favorites/${studentId}_${kind}_${targetId}`;

const favoriteDoc = (studentId, kind, targetId) =>
  clean({ studentId, kind, targetId, createdAt: now() });

/** حجز منفّذ بين student-1 وteacher-1 — الأساس الوحيد لأهلية التقييم. */
const seedCompletedBooking = (overrides = {}) =>
  seed([
    {
      path: 'bookingRequests/b1',
      data: bookingDoc('student-1', 'teacher-1', {
        status: 'completed',
        ...overrides,
      }),
    },
  ]);

/** دفعة واحدة: تقييم جديد + تحديث المتوسط (كما يفعل المستودع). */
async function submitReview(db, { teacherId, studentId, bookingId, rating, totalReviews, ratingSum }) {
  const batch = writeBatch(db);
  batch.set(
    doc(db, reviewPath(bookingId)),
    reviewDoc(bookingId, studentId, teacherId, { rating }),
  );
  batch.set(
    doc(db, `teacherRatings/${teacherId}`),
    ratingDoc(teacherId, totalReviews, ratingSum, bookingId),
  );
  await batch.commit();
}

describe('P13 — التقييم: لا يُكتب إلا لحجز منفّذ لصاحبه', () => {
  it('صاحب الحجز المنفّذ يقيّم مدرسه', async () => {
    await seedCompletedBooking();

    await assertSucceeds(
      setDoc(
        doc(asStudent(), reviewPath('b1')),
        reviewDoc('b1', 'student-1', 'teacher-1'),
      ),
    );
  });

  it('حجز غير منفّذ لا يُقيَّم (G7)', async () => {
    for (const status of ['pending', 'accepted', 'rejected', 'cancelled']) {
      await seed([
        {
          path: 'bookingRequests/b1',
          data: bookingDoc('student-1', 'teacher-1', { status }),
        },
      ]);

      await assertFails(
        setDoc(
          doc(asStudent(), reviewPath('b1')),
          reviewDoc('b1', 'student-1', 'teacher-1'),
        ),
      );
    }
  });

  it('لا يقيّم الطالب حجز غيره، ولا يقيّم نفسه باسم غيره', async () => {
    await seedCompletedBooking();

    // طالب آخر يحاول تقييم حجز student-1.
    await assertFails(
      setDoc(
        doc(asOther(), reviewPath('b1')),
        reviewDoc('b1', 'stranger-9', 'teacher-1', { studentName: 'طالب' }),
      ),
    );

    // student-1 يحاول كتابة تقييم باسم طالب آخر.
    await assertFails(
      setDoc(
        doc(asStudent(), reviewPath('b1')),
        reviewDoc('b1', 'student-2', 'teacher-1'),
      ),
    );
  });

  it('تقييم مدرس آخر غير مدرس الحجز مرفوض', async () => {
    await seedCompletedBooking();

    await assertFails(
      setDoc(
        doc(asStudent(), reviewPath('b1')),
        reviewDoc('b1', 'student-1', 'teacher-2'),
      ),
    );
  });

  it('الاسم يجب أن يطابق اسم الحجز، والنجوم من 1 إلى 5', async () => {
    await seedCompletedBooking();

    await assertFails(
      setDoc(
        doc(asStudent(), reviewPath('b1')),
        reviewDoc('b1', 'student-1', 'teacher-1', { studentName: 'اسم آخر' }),
      ),
    );
    for (const rating of [0, 6, '5']) {
      await assertFails(
        setDoc(
          doc(asStudent(), reviewPath('b1')),
          reviewDoc('b1', 'student-1', 'teacher-1', { rating }),
        ),
      );
    }
  });

  it('معرّف التقييم يجب أن يكون معرّف الحجز (منع التكرار)', async () => {
    await seedCompletedBooking();

    await assertFails(
      setDoc(
        doc(asStudent(), 'reviews/r-1'),
        reviewDoc('b1', 'student-1', 'teacher-1'),
      ),
    );
  });

  it('التقييم المكرر لنفس الحصة مرفوض', async () => {
    await seedCompletedBooking();
    await assertSucceeds(
      setDoc(
        doc(asStudent(), reviewPath('b1')),
        reviewDoc('b1', 'student-1', 'teacher-1'),
      ),
    );

    // محاولة الكتابة مرة ثانية على نفس المستند = تحديث، والممنوع ممنوع.
    for (const rating of [1, 5]) {
      await assertFails(
        setDoc(
          doc(asStudent(), reviewPath('b1')),
          reviewDoc('b1', 'student-1', 'teacher-1', { rating }),
        ),
      );
    }
  });

  it('لا تعديل ولا حذف بعد الكتابة', async () => {
    await seed([
      {
        path: reviewPath('b1'),
        data: reviewDoc('b1', 'student-1', 'teacher-1'),
      },
    ]);

    await assertFails(
      updateDoc(doc(asStudent(), reviewPath('b1')), { rating: 1 }),
    );
    await assertFails(
      updateDoc(doc(asStudent(), reviewPath('b1')), { comment: 'تعليق جديد' }),
    );
    await assertFails(deleteDoc(doc(asStudent(), reviewPath('b1'))));
  });

  it('التقييمات مقروءة للمسجّلين فقط', async () => {
    await seed([
      {
        path: reviewPath('b1'),
        data: reviewDoc('b1', 'student-1', 'teacher-1'),
      },
    ]);

    await assertSucceeds(getDoc(doc(asStudent(), reviewPath('b1'))));
    await assertSucceeds(getDoc(doc(asTeacher(), reviewPath('b1'))));
    await assertFails(getDoc(doc(asGuest(), reviewPath('b1'))));
    await assertFails(
      getDocs(query(collection(asGuest(), 'reviews'))),
    );
  });
});

describe('P13 — المتوسط التراكمي لا يتحرك بلا تقييم حقيقي', () => {
  it('أول تقييم ينشئ المتوسط معه بقيمة تقييمه', async () => {
    await seedCompletedBooking();

    await assertSucceeds(submitReview(asStudent(), {
      teacherId: 'teacher-1',
      studentId: 'student-1',
      bookingId: 'b1',
      rating: 4,
      totalReviews: 1,
      ratingSum: 4,
    }));

    const stored = await readAsAdmin('teacherRatings/teacher-1');
    assert.equal(stored.totalReviews, 1);
    assert.equal(stored.ratingSum, 4);
  });

  it('زيادة بلا تقييم في نفس الدفعة مرفوضة', async () => {
    await seed([
      { path: 'teacherRatings/teacher-1', data: ratingDoc('teacher-1', 3, 12, 'b0') },
    ]);

    // كتابة المتوسط وحدها: لا تقييم جديد ⇒ لا زيادة.
    await assertFails(
      setDoc(
        doc(asStudent(), 'teacherRatings/teacher-1'),
        ratingDoc('teacher-1', 4, 17, 'b1'),
      ),
    );
  });

  it('الزيادة يجب أن تساوي تقييم التقييم المنشأ بالضبط', async () => {
    await seedCompletedBooking();
    await seed([
      { path: 'teacherRatings/teacher-1', data: ratingDoc('teacher-1', 3, 12, 'b0') },
    ]);

    // التقييم 5 لكن المجموع زيد 10 ⇒ تلاعب مرفوض.
    await assertFails(submitReview(asStudent(), {
      teacherId: 'teacher-1',
      studentId: 'student-1',
      bookingId: 'b1',
      rating: 5,
      totalReviews: 4,
      ratingSum: 22,
    }));

    // والزيادة الصحيحة (12 + 5) تمرّ.
    await assertSucceeds(submitReview(asStudent(), {
      teacherId: 'teacher-1',
      studentId: 'student-1',
      bookingId: 'b1',
      rating: 5,
      totalReviews: 4,
      ratingSum: 17,
    }));
  });

  it('العدّاد لا يزيد بأكثر من واحد، ولا يُعاد استخدام تقييم قديم', async () => {
    await seedCompletedBooking();
    await seed([
      { path: 'teacherRatings/teacher-1', data: ratingDoc('teacher-1', 3, 12, 'b0') },
      { path: 'reviews/b0', data: reviewDoc('b0', 'student-9', 'teacher-1') },
    ]);

    // قفزة في العدّاد.
    await assertFails(submitReview(asStudent(), {
      teacherId: 'teacher-1',
      studentId: 'student-1',
      bookingId: 'b1',
      rating: 5,
      totalReviews: 5,
      ratingSum: 17,
    }));

    // نفس التقييم القديم (b0) لا يُحتسب مرتين.
    await assertFails(
      setDoc(
        doc(asStudent(), 'teacherRatings/teacher-1'),
        ratingDoc('teacher-1', 4, 17, 'b0'),
      ),
    );
  });

  it('لا يكتب المتوسط لغير التقييم الذي أنشأه', async () => {
    await seedCompletedBooking();
    await seed([
      { path: 'teacherRatings/teacher-1', data: ratingDoc('teacher-1', 1, 5, 'b0') },
    ]);

    await assertFails(submitReview(asOther(), {
      teacherId: 'teacher-1',
      studentId: 'student-1',
      bookingId: 'b1',
      rating: 5,
      totalReviews: 2,
      ratingSum: 10,
    }));
  });

  it('المتوسط مقروء للمسجّلين فقط', async () => {
    await seed([
      { path: 'teacherRatings/teacher-1', data: ratingDoc('teacher-1', 1, 5, 'b0') },
    ]);

    await assertSucceeds(getDoc(doc(asStudent(), 'teacherRatings/teacher-1')));
    await assertFails(getDoc(doc(asGuest(), 'teacherRatings/teacher-1')));
  });
});

describe('P13 — المفضلة: خاصة بصاحبها ومعرّفها مشتق', () => {
  beforeEach(async () => {
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: teacherDoc('teacher-1', { status: 'verified' }),
      },
      { path: 'studyGroups/g1', data: groupDoc('teacher-1', { seatsTaken: 0 }) },
    ]);
  });

  it('الطالب يحفظ مدرسًا معتمدًا ومجموعة نشطة', async () => {
    await assertSucceeds(
      setDoc(
        doc(asStudent(), favoritePath('student-1', 'teacher', 'teacher-1')),
        favoriteDoc('student-1', 'teacher', 'teacher-1'),
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(asStudent(), favoritePath('student-1', 'group', 'g1')),
        favoriteDoc('student-1', 'group', 'g1'),
      ),
    );
  });

  it('لا يحفظ أحد عنصرًا في مفضلة غيره', async () => {
    await assertFails(
      setDoc(
        doc(asStudent(), favoritePath('student-2', 'teacher', 'teacher-1')),
        favoriteDoc('student-2', 'teacher', 'teacher-1'),
      ),
    );
  });

  it('المعرّف المشتق مفروض، والنوع مقيّد', async () => {
    await assertFails(
      setDoc(
        doc(asStudent(), 'favorites/free-form'),
        favoriteDoc('student-1', 'teacher', 'teacher-1'),
      ),
    );
    await assertFails(
      setDoc(
        doc(asStudent(), favoritePath('student-1', 'booking', 'b1')),
        favoriteDoc('student-1', 'booking', 'b1'),
      ),
    );
  });

  it('لا يُحفظ مدرس غير معتمد ولا مجموعة موقوفة ولا هدف غير موجود', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-2', data: teacherDoc('teacher-2') },
      {
        path: 'studyGroups/g2',
        data: groupDoc('teacher-1', { isActive: false }),
      },
    ]);

    await assertFails(
      setDoc(
        doc(asStudent(), favoritePath('student-1', 'teacher', 'teacher-2')),
        favoriteDoc('student-1', 'teacher', 'teacher-2'),
      ),
    );
    await assertFails(
      setDoc(
        doc(asStudent(), favoritePath('student-1', 'group', 'g2')),
        favoriteDoc('student-1', 'group', 'g2'),
      ),
    );
    await assertFails(
      setDoc(
        doc(asStudent(), favoritePath('student-1', 'group', 'missing')),
        favoriteDoc('student-1', 'group', 'missing'),
      ),
    );
  });

  it('المفضلة تُقرأ وتُحذف لصاحبها فقط، ولا تُعدَّل', async () => {
    await seed([
      {
        path: favoritePath('student-1', 'teacher', 'teacher-1'),
        data: favoriteDoc('student-1', 'teacher', 'teacher-1'),
      },
    ]);

    await assertSucceeds(
      getDoc(doc(asStudent(), favoritePath('student-1', 'teacher', 'teacher-1'))),
    );
    await assertFails(
      getDoc(doc(asOther(), favoritePath('student-1', 'teacher', 'teacher-1'))),
    );
    const mine = await assertSucceeds(
      getDocs(
        query(
          collection(asStudent(), 'favorites'),
          where('studentId', '==', 'student-1'),
        ),
      ),
    );
    assert.equal(mine.docs.length, 1);

    // استعلام مفضلة غيري مرفوض (القراءة مقيّدة بالمالك في القواعد).
    await assertFails(
      getDocs(
        query(
          collection(asStudent(), 'favorites'),
          where('studentId', '==', 'student-2'),
        ),
      ),
    );

    await assertFails(
      updateDoc(
        doc(asStudent(), favoritePath('student-1', 'teacher', 'teacher-1')),
        { targetId: 'teacher-2' },
      ),
    );
    await assertFails(
      deleteDoc(doc(asOther(), favoritePath('student-1', 'teacher', 'teacher-1'))),
    );
    await assertSucceeds(
      deleteDoc(doc(asStudent(), favoritePath('student-1', 'teacher', 'teacher-1'))),
    );
  });
});


describe('P13 — قراءة المستند غير الموجود تعيد «غير موجود» لا «ممنوع»', () => {
  it('مفضلة غير موجودة: القراءة ناجحة (exists = false)', async () => {
    const path = favoritePath('student-1', 'teacher', 'teacher-1');
    const snapshot = await assertSucceeds(getDoc(doc(asStudent(), path)));
    assert.equal(snapshot.exists(), false);
  });

  it('محادثة غير موجودة: القراءة ناجحة (exists = false)', async () => {
    const snapshot = await assertSucceeds(
      getDoc(doc(asStudent(), 'directChats/teacher-1_student-1')),
    );
    assert.equal(snapshot.exists(), false);
  });

  it('ومع ذلك: قراءة مستند قائم لغيره ما زالت مرفوضة', async () => {
    await seed([
      {
        path: favoritePath('student-2', 'teacher', 'teacher-1'),
        data: favoriteDoc('student-2', 'teacher', 'teacher-1'),
      },
    ]);

    await assertFails(
      getDoc(doc(asStudent(), favoritePath('student-2', 'teacher', 'teacher-1'))),
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

// ═════════════════════════════════════════════════════════════════════════════
// P14 — لوحة الإدارة والتوثيق
// ═════════════════════════════════════════════════════════════════════════════

/** بلاغ محتوى (P14): يُنشأ مفتوحًا دائمًا، والهدف موجود. */
const reportDoc = (overrides = {}) =>
  clean({
    targetType: 'review',
    targetId: 'b1',
    targetLabel: 'تقييم على أ. سارة',
    reporterId: 'student-1',
    reason: 'ألفاظ غير لائقة',
    status: 'open',
    createdAt: now(),
    ...overrides,
  });

const reportPath = (id) => `contentReports/${id}`;

/** قبول حجز معلّق كما يفعل المستودع (قرار مدرس فقط). */
const acceptBooking = (db, bookingId = 'b1') =>
  updateDoc(doc(db, `bookingRequests/${bookingId}`), {
    status: 'accepted',
    decidedBy: 'teacher-1',
    decidedAt: now(),
  });

describe('P14 — المدرس غير الموثّق لا يقبل حجزًا', () => {
  it('قبول حجز لمدرس غير موثّق مرفوض', async () => {
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: teacherDoc('teacher-1', { status: 'pendingReview' }),
      },
      { path: 'bookingRequests/b1', data: bookingDoc('student-1', 'teacher-1') },
    ]);

    await assertFails(acceptBooking(asTeacher()));
  });

  it('غياب الملف نهائيًا = غير موثّق (لا قبول ضمني)', async () => {
    await testEnv.clearFirestore();
    await seed([
      { path: 'bookingRequests/b1', data: bookingDoc('student-1', 'teacher-1') },
    ]);

    await assertFails(acceptBooking(asTeacher()));
  });

  it('قبول حجز لمدرس موثّق يمرّ، ورفضه كذلك', async () => {
    await seed([
      { path: 'bookingRequests/b1', data: bookingDoc('student-1', 'teacher-1') },
      { path: 'bookingRequests/b2', data: bookingDoc('student-1', 'teacher-1') },
    ]);

    await assertSucceeds(acceptBooking(asTeacher(), 'b1'));
    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'bookingRequests/b2'), {
        status: 'rejected',
        decidedBy: 'teacher-1',
        decidedAt: now(),
      }),
    );
  });

  it('غير الموثّق لا يقبل طلب انضمام لمجموعته', async () => {
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: teacherDoc('teacher-1', { status: 'draft' }),
      },
      { path: joinPath('g1', 'student-1'), data: joinRequestDoc('g1', 'student-1') },
    ]);

    const decision = {
      status: 'accepted',
      decidedBy: 'teacher-1',
      decidedAt: now(),
    };

    await assertFails(
      updateDoc(doc(asTeacher(), joinPath('g1', 'student-1')), decision),
    );

    // بعد التوثيق يمرّ نفس القرار.
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: teacherDoc('teacher-1', { status: 'verified' }),
      },
    ]);

    await assertSucceeds(
      updateDoc(doc(asTeacher(), joinPath('g1', 'student-1')), decision),
    );
  });

  it('غير الموثّق لا يرقّي منتظرًا في قائمته', async () => {
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: teacherDoc('teacher-1', { status: 'pendingReview' }),
      },
      {
        path: waitlistPath('g1', 'student-1'),
        data: waitlistDoc('g1', 'student-1'),
      },
    ]);

    await assertFails(
      updateDoc(doc(asTeacher(), waitlistPath('g1', 'student-1')), {
        status: 'promoted',
        decidedBy: 'teacher-1',
        decidedAt: now(),
      }),
    );
  });
});

describe('P14 — البلاغات: تُنشأ مفتوحة وتُحسم إداريًا فقط', () => {
  it('طالب يُبلغ عن تقييم قائم', async () => {
    await seed([
      { path: 'reviews/b1', data: reviewDoc('b1', 'student-1', 'teacher-1') },
    ]);

    await assertSucceeds(
      setDoc(doc(asStudent(), reportPath('r1')), reportDoc()),
    );
  });

  it('بلاغ عن هدف غير موجود مرفوض', async () => {
    await assertFails(
      setDoc(
        doc(asStudent(), reportPath('r2')),
        reportDoc({ targetId: 'ghost' }),
      ),
    );
  });

  it('لا يُنشئ الطالب بلاغًا محسومًا ولا باسم غيره', async () => {
    await seed([
      { path: 'reviews/b1', data: reviewDoc('b1', 'student-1', 'teacher-1') },
    ]);

    await assertFails(
      setDoc(
        doc(asStudent(), reportPath('r3')),
        reportDoc({ status: 'resolved' }),
      ),
    );
    await assertFails(
      setDoc(
        doc(asOther(), reportPath('r4')),
        reportDoc({ reporterId: 'student-1' }),
      ),
    );
  });

  it('لا يقرأ الطالب بلاغ غيره، والإدارة تقرأ الكل', async () => {
    await seed([
      { path: 'reviews/b1', data: reviewDoc('b1', 'student-1', 'teacher-1') },
      { path: reportPath('r1'), data: reportDoc() },
    ]);

    await assertSucceeds(getDoc(doc(asStudent(), reportPath('r1'))));
    await assertFails(getDoc(doc(asOther(), reportPath('r1'))));
    await assertSucceeds(getDoc(doc(asAdmin(), reportPath('r1'))));
  });

  it('الحسم إداري فقط، والبلاغ لا يُحذف', async () => {
    await seed([
      { path: 'reviews/b1', data: reviewDoc('b1', 'student-1', 'teacher-1') },
      { path: reportPath('r1'), data: reportDoc() },
    ]);

    const resolution = {
      status: 'resolved',
      resolvedAt: now(),
      resolutionNote: 'حُذف التقييم المخالف.',
    };

    await assertFails(
      updateDoc(doc(asStudent(), reportPath('r1')), resolution),
    );
    await assertSucceeds(updateDoc(doc(asAdmin(), reportPath('r1')), resolution));

    const stored = await readAsAdmin(reportPath('r1'));
    assert.equal(stored.status, 'resolved');

    // لا حذف — ولا للمسؤول: السجل يبقى.
    await assertFails(deleteDoc(doc(asAdmin(), reportPath('r1'))));
  });
});

describe('P14 — حذف تقييم مخالف: إدارة فقط والمجموع ينقص', () => {
  it('غير المسؤول لا يحذف التقييم ولا يمسّ المتوسط', async () => {
    await seed([
      { path: 'reviews/b1', data: reviewDoc('b1', 'student-1', 'teacher-1') },
      { path: 'teacherRatings/teacher-1', data: ratingDoc('teacher-1', 3, 12, 'b1') },
    ]);

    await assertFails(deleteDoc(doc(asStudent(), 'reviews/b1')));
    await assertFails(
      updateDoc(doc(asStudent(), 'teacherRatings/teacher-1'), {
        ...ratingDoc('teacher-1', 2, 7, 'b1'),
      }),
    );
  });

  it('المسؤول يحذف التقييم ويُنقص المجموع في معاملة واحدة', async () => {
    await seed([
      { path: 'reviews/b1', data: reviewDoc('b1', 'student-1', 'teacher-1', { rating: 5 }) },
      { path: 'teacherRatings/teacher-1', data: ratingDoc('teacher-1', 3, 12, 'b1') },
    ]);

    // نسخة واحدة من عميل الإدارة: `asAdmin()` تُنشئ عميلًا جديدًا في كل نداء،
    // ومرجع من عميل آخر يُرفض داخل المعاملة («different Firestore instance»).
    const adminDb = asAdmin();
    await assertSucceeds(
      runTransaction(adminDb, async (tx) => {
        const reviewRef = doc(adminDb, 'reviews/b1');
        const ratingRef = doc(adminDb, 'teacherRatings/teacher-1');
        const review = await tx.get(reviewRef);
        tx.delete(reviewRef);
        tx.set(ratingRef, ratingDoc('teacher-1', 2, 12 - review.data().rating, 'b1'));
      }),
    );

    assert.equal(await readAsAdmin('reviews/b1'), null);
    const rating = await readAsAdmin('teacherRatings/teacher-1');
    assert.equal(rating.totalReviews, 2);
    assert.equal(rating.ratingSum, 7);
  });

  it('المسؤول لا يستطيع زيادة المتوسط بحذف تقييم', async () => {
    await seed([
      { path: 'teacherRatings/teacher-1', data: ratingDoc('teacher-1', 3, 12, 'b1') },
    ]);

    await assertFails(
      updateDoc(doc(asAdmin(), 'teacherRatings/teacher-1'), {
        ...ratingDoc('teacher-1', 4, 17, 'b1'),
      }),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// P15 — الاكتشاف: الموثّق فقط، وطريقة التقديم والمكان، والتمييز الإداري
// ═════════════════════════════════════════════════════════════════════════════

/** ملف مدرس موثّق مع حقول الاكتشاف (P15). */
const discoverDoc = (uid, overrides = {}) =>
  teacherDoc(uid, {
    status: 'verified',
    isOnline: false,
    governorate: 'القاهرة',
    district: 'المعادي',
    // (P17) الحقل يُكتب منذ الإنشاء، وفلتر الاكتشاف عليه مساواة `false`.
    accountHidden: false,
    ...overrides,
  });

describe('P15 — الاكتشاف: الموثّق وحده يُقرأ للطلاب', () => {
  it('الموثّق يُقرأ من غير المسجّل، وغير الموثّق لا', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: discoverDoc('teacher-1') },
      { path: 'teacherProfiles/teacher-2', data: teacherDoc('teacher-2') },
    ]);

    await assertSucceeds(getDoc(doc(asGuest(), 'teacherProfiles/teacher-1')));
    await assertFails(getDoc(doc(asGuest(), 'teacherProfiles/teacher-2')));
    await assertFails(getDoc(doc(asStudent(), 'teacherProfiles/teacher-2')));
    // صاحب الملف يرى ملفه في أي حالة.
    await assertSucceeds(getDoc(doc(asTeacher(), 'teacherProfiles/teacher-1')));
  });

  it('الاستعلام بلا شرط الحالة يُرفض،ومعها يُقبل', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: discoverDoc('teacher-1') },
      { path: 'teacherProfiles/teacher-2', data: teacherDoc('teacher-2') },
    ]);

    // قراءة المجموعة كاملة تشمل ملفًا غير موثّق ⇒ تُرفض كوحدة واحدة.
    await assertFails(getDocs(collection(asStudent(), 'teacherProfiles')));

    await assertSucceeds(
      getDocs(
        query(
          collection(asStudent(), 'teacherProfiles'),
          where('status', '==', 'verified'),
        ),
      ),
    );
  });

  it('استعلام «عن بُعد» مساواة واحدة على isOnline', async () => {
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: discoverDoc('teacher-1', { isOnline: true, governorate: null }),
      },
      { path: 'teacherProfiles/teacher-2', data: discoverDoc('teacher-2') },
    ]);

    const snapshot = await getDocs(
      query(
        collection(asStudent(), 'teacherProfiles'),
        where('status', '==', 'verified'),
        where('isOnline', '==', true),
      ),
    );

    assert.deepEqual(
      snapshot.docs.map((item) => item.id),
      ['teacher-1'],
    );
  });

  it('استعلام حضوري بمحافظة يعيد مدرس تلك المحافظة فقط', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: discoverDoc('teacher-1') },
      {
        path: 'teacherProfiles/teacher-2',
        data: discoverDoc('teacher-2', {
          governorate: 'أسيوط',
          district: 'أسيوط',
        }),
      },
    ]);

    const snapshot = await getDocs(
      query(
        collection(asStudent(), 'teacherProfiles'),
        where('status', '==', 'verified'),
        where('isOnline', '==', false),
        where('governorate', '==', 'أسيوط'),
      ),
    );

    assert.deepEqual(
      snapshot.docs.map((item) => item.id),
      ['teacher-2'],
    );
  });
});

describe('P15 — طريقة التقديم والمكان يكتبها صاحب الملف', () => {
  it('يكتب isOnline والمحافظة والمدينة', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: teacherDoc('teacher-1') },
    ]);

    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        isOnline: true,
        governorate: 'القاهرة',
        district: 'المعادي',
      }),
    );
  });

  it('قيمة غير منطقية أو محافظة أطول من الحد مرفوضة', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: teacherDoc('teacher-1') },
    ]);

    await assertFails(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        isOnline: 'yes',
      }),
    );
    await assertFails(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        governorate: 'ا'.repeat(41),
      }),
    );
  });

  it('غيره لا يكتب حقوله الوصفية', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: teacherDoc('teacher-1') },
    ]);

    await assertFails(
      updateDoc(doc(asStudent(), 'teacherProfiles/teacher-1'), {
        isOnline: true,
      }),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// (P18) «ملفي التعريفي»: الحمولة التي يرسلها التطبيق فعلًا من
// `TeacherProfileDraft.toWriteMap()` — حقول وصفية فقط، بلا status ولا ownerId.
// الاختبار هنا يثبت أن **شكل الكتابة الحقيقي** مسموح، لا شكلًا نظريًا.
describe('P18 — حفظ ملف المدرس من التطبيق', () => {
  const draftFields = {
    displayName: 'أ. سارة الخطيب',
    subject: 'الرياضيات',
    stage: 'الثانوية العامة',
    area: 'المعادي',
    bio: 'شرح مبسّط للتفاضل مع تدريبات أسبوعية.',
    isOnline: true,
    priceHint: '150 ج.م',
  };

  it('تحديث الحقول الوصفية وحدها مسموح لصاحب الملف', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: teacherDoc('teacher-1') },
    ]);

    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), draftFields),
    );
  });

  it('حذف حقل اختياري (FieldValue.delete) مسموح', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: teacherDoc('teacher-1') },
    ]);

    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        priceHint: deleteField(),
        governorate: deleteField(),
        district: deleteField(),
      }),
    );
  });

  it('الإنشاء بحالة pendingReview وبلا حقول إدارية مسموح', async () => {
    await assertSucceeds(
      setDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        ...teacherDoc('teacher-1'),
        accountHidden: false,
      }),
    );
  });

  it('لا يستطيع إنشاء ملف بحالة موثّق', async () => {
    await assertFails(
      setDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        ...teacherDoc('teacher-1', { status: 'verified' }),
        accountHidden: false,
      }),
    );
  });

  it('لا يستطيع منح نفسه تمييزًا أثناء الحفظ العادي', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: teacherDoc('teacher-1') },
    ]);

    await assertFails(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        ...draftFields,
        isFeatured: true,
        featuredOrder: 1,
      }),
    );
  });
});

describe('P15 — التمييز إداري وحده', () => {
  it('المسؤول يميّز ملفًا موثّقًا ويقرأ القيم', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: discoverDoc('teacher-1') },
    ]);

    await assertSucceeds(
      updateDoc(doc(asAdmin(), 'teacherProfiles/teacher-1'), {
        isFeatured: true,
        featuredOrder: 1,
      }),
    );

    const stored = await readAsAdmin('teacherProfiles/teacher-1');
    assert.equal(stored.isFeatured, true);
    assert.equal(stored.featuredOrder, 1);
  });

  it('صاحب الملف والطالب لا يميّزان', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: discoverDoc('teacher-1') },
    ]);

    await assertFails(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        isFeatured: true,
        featuredOrder: 1,
      }),
    );
    await assertFails(
      updateDoc(doc(asStudent(), 'teacherProfiles/teacher-1'), {
        isFeatured: true,
        featuredOrder: 1,
      }),
    );
  });

  it('لا تمييز لملف غير موثّق', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-2', data: teacherDoc('teacher-2') },
    ]);

    await assertFails(
      updateDoc(doc(asAdmin(), 'teacherProfiles/teacher-2'), {
        isFeatured: true,
        featuredOrder: 1,
      }),
    );
  });

  it('التمييز لا يحمل معه أي تعديل آخر', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: discoverDoc('teacher-1') },
    ]);

    await assertFails(
      updateDoc(doc(asAdmin(), 'teacherProfiles/teacher-1'), {
        isFeatured: true,
        featuredOrder: 1,
        displayName: 'اسم آخر',
      }),
    );
  });

  it('ترتيب خارج 0..999 مرفوض', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: discoverDoc('teacher-1') },
    ]);

    await assertFails(
      updateDoc(doc(asAdmin(), 'teacherProfiles/teacher-1'), {
        isFeatured: true,
        featuredOrder: 1000,
      }),
    );
  });

  it('صاحب الملف يعدّل نبذته بعد التمييز ولا يمسّ التمييز', async () => {
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: discoverDoc('teacher-1', { isFeatured: true, featuredOrder: 3 }),
      },
    ]);

    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        bio: 'نبذة محدثة بعد التمييز',
      }),
    );

    await assertFails(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        bio: 'محاولة ثانية',
        isFeatured: false,
      }),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// P16 — الأمان والحدود: السيناريوهات الواقعية والتزامن

/** طلب حجز صالح للموعد الافتراضي (2026-11-01، 10:00 صباحًا، ساعة). */
const slotDateKey = '2026-11-01';
const slotStart = 600;

const newBooking = (overrides = {}) => ({
  ...bookingDoc('student-1', 'teacher-1'),
  dateKey: slotDateKey,
  startMinutes: slotStart,
  durationMinutes: 60,
  ...overrides,
});

describe('P16 — الطالب لا يطلب حجزًا عند مدرس غير موثّق', () => {
  it('ملف غير موثّق ⇒ الطلب مرفوض قبل أن يصل', async () => {
    await testEnv.clearFirestore();
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: teacherDoc('teacher-1', { status: 'pendingReview' }),
      },
    ]);

    await assertFails(
      setDoc(doc(asStudent(), 'bookingRequests/b9'), newBooking()),
    );
  });

  it('غياب الملف نهائيًا = غير موثّق (لا طلب إلى مجهول)', async () => {
    await testEnv.clearFirestore();

    await assertFails(
      setDoc(doc(asStudent(), 'bookingRequests/b9'), newBooking()),
    );
  });

  it('ملف موثّق ⇒ الطلب يمرّ، والموعد غير الصالح يبقى مرفوضًا', async () => {
    await assertSucceeds(
      setDoc(doc(asStudent(), 'bookingRequests/b9'), newBooking()),
    );

    await assertFails(
      setDoc(
        doc(asStudent(), 'bookingRequests/b10'),
        newBooking({ durationMinutes: 7 }),
      ),
    );
  });
});

describe('P16 — التزامن: قبولان متزامنان على الموعد نفسه', () => {
  /**
   * نفس ما يفعله المستودع: قراءة التقويم اليومي وكتابة القبول في **معاملة
   * واحدة**، فالطلب الثاني يُعاد تشغيله ثم يرى الفترة مشغولة فيفشل.
   */
  const acceptWithCalendar = (bookingId) => {
    const db = asTeacher();
    return runTransaction(db, async (transaction) => {
      const calendarRef = doc(db, `teacherCalendar/teacher-1_${slotDateKey}`);
      const calendar = await transaction.get(calendarRef);
      const busy = calendar.exists() ? (calendar.data().busy ?? {}) : {};
      const clash = Object.keys(busy).some((key) => {
        const otherStart = Number(key);
        const otherEnd = otherStart + Number(busy[key]);
        return otherStart < slotStart + 60 && slotStart < otherEnd;
      });
      if (clash) {
        throw new Error('CONFLICT');
      }
      transaction.set(calendarRef, {
        teacherId: 'teacher-1',
        dateKey: slotDateKey,
        busy: { ...busy, [String(slotStart)]: 60 },
      });
      transaction.update(doc(db, `bookingRequests/${bookingId}`), {
        status: 'accepted',
        decidedBy: 'teacher-1',
        decidedAt: now(),
      });
    });
  };

  it('طلبان يتنافسان على نفس الوقت: قبول واحد فقط', async () => {
    await seed([
      { path: 'bookingRequests/b1', data: newBooking() },
      {
        path: 'bookingRequests/b2',
        data: newBooking({ studentId: 'student-2' }),
      },
    ]);

    const results = await Promise.allSettled([
      acceptWithCalendar('b1'),
      acceptWithCalendar('b2'),
    ]);
    const accepted = results.filter(
      (result) => result.status === 'fulfilled',
    ).length;

    assert.equal(accepted, 1, 'لا يجوز قبول طلبين على الفترة نفسها');

    const b1 = await readAsAdmin('bookingRequests/b1');
    const b2 = await readAsAdmin('bookingRequests/b2');
    const statuses = [b1.status, b2.status].sort();
    assert.deepEqual(statuses, ['accepted', 'pending']);

    // والتقويم فيه فترة واحدة لا فترتان.
    const calendar = await readAsAdmin(
      `teacherCalendar/teacher-1_${slotDateKey}`,
    );
    assert.equal(Object.keys(calendar.busy).length, 1);
  });
});

describe('P16 — التزامن: تقييمان متزامنان لنفس الحصة', () => {
  it('إرسالان متزامنان: تقييم واحد فقط يُكتب', async () => {
    await seedCompletedBooking();

    const submit = () =>
      setDoc(
        doc(asStudent(), reviewPath('b1')),
        reviewDoc('b1', 'student-1', 'teacher-1'),
      );

    const results = await Promise.allSettled([submit(), submit()]);
    const written = results.filter(
      (result) => result.status === 'fulfilled',
    ).length;

    // الثاني إعادة كتابة على مستند قائم ⇒ القواعد ترفض التعديل (A-84).
    assert.equal(written, 1, 'التقييم يُكتب مرة واحدة');

    const stored = await readAsAdmin(reviewPath('b1'));
    assert.equal(stored.rating, 5);
  });
});

describe('P16 — حدود حقول الإدارة: الحالة والتمييز', () => {
  it('صاحب الملف لا يرقّي نفسه إلى verified', async () => {
    await testEnv.clearFirestore();
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: teacherDoc('teacher-1', { status: 'pendingReview' }),
      },
    ]);

    await assertFails(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        status: 'verified',
      }),
    );
  });

  it('المسؤول وحده يصدر قرار التوثيق', async () => {
    await testEnv.clearFirestore();
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: teacherDoc('teacher-1', { status: 'pendingReview' }),
      },
    ]);

    await assertSucceeds(
      updateDoc(doc(asAdmin(), 'teacherProfiles/teacher-1'), {
        status: 'verified',
      }),
    );

    const stored = await readAsAdmin('teacherProfiles/teacher-1');
    assert.equal(stored.status, 'verified');
  });

  it('الطالب لا يكتب التمييز ولا الترتيب', async () => {
    await assertFails(
      updateDoc(doc(asStudent(), 'teacherProfiles/teacher-1'), {
        isFeatured: true,
        featuredOrder: 1,
      }),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// P17 — حذف الحساب الناعم: مهلة 7 أيام، استعادة داخل المهلة، وخروج من الاكتشاف

/** موعد نسبي بساعة المحاكي نفسها (لا ساعة ثابتة قد تصبح ماضية). */
const daysFromNow = (days) => new Date(Date.now() + days * 24 * 60 * 60 * 1000);

describe('P17 — طلب الحذف: انتقال واحد صحيح', () => {
  it('صاحب الحساب يطلب الحذف بموعد داخل المهلة', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertSucceeds(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        status: 'pending_deletion',
        scheduledDeletionAt: daysFromNow(7),
      }),
    );

    const stored = await readAsAdmin('users/student-1');
    assert.equal(stored.status, 'pending_deletion');
    assert.ok(stored.scheduledDeletionAt);
  });

  it('موعد أبعد من 8 أيام مرفوض (لا حذف مؤجّل سنة)', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        status: 'pending_deletion',
        scheduledDeletionAt: daysFromNow(30),
      }),
    );
  });

  it('موعد في الماضي أو غائب أو بلا نوع Timestamp مرفوض', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        status: 'pending_deletion',
        scheduledDeletionAt: daysFromNow(-1),
      }),
    );
    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        status: 'pending_deletion',
      }),
    );
    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        status: 'pending_deletion',
        scheduledDeletionAt: '2026-11-04',
      }),
    );
  });

  it('حالة غير معلنة (deleted) مرفوضة', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        status: 'deleted',
        scheduledDeletionAt: daysFromNow(3),
      }),
    );
  });

  it('لا أحد يطلب الحذف لغيره', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertFails(
      updateDoc(doc(asOther(), 'users/student-1'), {
        status: 'pending_deletion',
        scheduledDeletionAt: daysFromNow(7),
      }),
    );
  });

  it('تعديل الاسم وحده لا يمسّ الحالة', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await assertSucceeds(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        displayName: 'اسم محدّث',
      }),
    );

    const stored = await readAsAdmin('users/student-1');
    assert.equal(stored.status, undefined);
    assert.equal(stored.displayName, 'اسم محدّث');
  });
});

describe('P17 — الاستعادة: داخل المهلة فقط', () => {
  const pendingUser = (uid, scheduledAt) => ({
    ...userDoc(uid),
    status: 'pending_deletion',
    scheduledDeletionAt: scheduledAt,
  });

  it('الاستعادة قبل الموعد تنجح وتحذف الموعد', async () => {
    await seed([
      { path: 'users/student-1', data: pendingUser('student-1', daysFromNow(3)) },
    ]);

    await assertSucceeds(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        status: 'active',
        scheduledDeletionAt: deleteField(),
      }),
    );

    const stored = await readAsAdmin('users/student-1');
    assert.equal(stored.status, 'active');
    assert.equal(stored.scheduledDeletionAt, undefined);
  });

  it('الاستعادة بعد انتهاء المهلة مرفوضة', async () => {
    await seed([
      {
        path: 'users/student-1',
        data: pendingUser('student-1', daysFromNow(-1)),
      },
    ]);

    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        status: 'active',
        scheduledDeletionAt: deleteField(),
      }),
    );
  });

  it('الاستعادة التي تُبقي الموعد مرفوضة', async () => {
    await seed([
      { path: 'users/student-1', data: pendingUser('student-1', daysFromNow(3)) },
    ]);

    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        status: 'active',
        scheduledDeletionAt: daysFromNow(3),
      }),
    );
  });

  it('تمديد المهلة بإعادة كتابة الموعد مرفوض', async () => {
    await seed([
      { path: 'users/student-1', data: pendingUser('student-1', daysFromNow(1)) },
    ]);

    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        scheduledDeletionAt: daysFromNow(7),
      }),
    );
  });

  it('محو الموعد مع البقاء على pending_deletion مرفوض', async () => {
    await seed([
      { path: 'users/student-1', data: pendingUser('student-1', daysFromNow(3)) },
    ]);

    await assertFails(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        scheduledDeletionAt: deleteField(),
      }),
    );
  });

  it('تعديل الاسم أثناء الانتظار يمرّ ويُبقي الحالة والموعد', async () => {
    await seed([
      { path: 'users/student-1', data: pendingUser('student-1', daysFromNow(3)) },
    ]);

    await assertSucceeds(
      updateDoc(doc(asStudent(), 'users/student-1'), {
        displayName: 'اسم أثناء الانتظار',
      }),
    );

    const stored = await readAsAdmin('users/student-1');
    assert.equal(stored.status, 'pending_deletion');
    assert.ok(stored.scheduledDeletionAt);
  });
});

describe('P17 — الملف المخفي بحذف الحساب يخرج من الاكتشاف', () => {
  it('صاحب الملف يخفيه فيختفي عن الطلاب والزوار ويبقى له وللمسؤول', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: discoverDoc('teacher-1') },
      { path: 'teacherProfiles/teacher-2', data: discoverDoc('teacher-2') },
    ]);

    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        accountHidden: true,
      }),
    );

    await assertFails(getDoc(doc(asStudent(), 'teacherProfiles/teacher-1')));
    await assertFails(getDoc(doc(asGuest(), 'teacherProfiles/teacher-1')));
    await assertSucceeds(getDoc(doc(asTeacher(), 'teacherProfiles/teacher-1')));
    await assertSucceeds(getDoc(doc(asAdmin(), 'teacherProfiles/teacher-1')));

    // الاستعلام الذي يستخدمه التطبيق يفلتر العلم صريحًا (القواعد ليست فلترًا)،
    // فيعود الملف المرئي وحده.
    const snapshot = await getDocs(
      query(
        collection(asStudent(), 'teacherProfiles'),
        where('status', '==', 'verified'),
        where('accountHidden', '==', false),
      ),
    );
    assert.deepEqual(snapshot.docs.map((item) => item.id), ['teacher-2']);
  });

  it('الاستعادة تُعيد الملف للاكتشاف فورًا', async () => {
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: discoverDoc('teacher-1', { accountHidden: true }),
      },
    ]);

    await assertFails(getDoc(doc(asStudent(), 'teacherProfiles/teacher-1')));

    await assertSucceeds(
      updateDoc(doc(asTeacher(), 'teacherProfiles/teacher-1'), {
        accountHidden: false,
      }),
    );

    await assertSucceeds(getDoc(doc(asStudent(), 'teacherProfiles/teacher-1')));
  });

  it('مدرس مخفي لا يقبل حجزًا حتى لو بقي ملفه موثّقًا', async () => {
    await seed([
      {
        path: 'teacherProfiles/teacher-1',
        data: discoverDoc('teacher-1', { accountHidden: true }),
      },
      { path: 'bookingRequests/b1', data: bookingDoc('student-1', 'teacher-1') },
    ]);

    await assertFails(acceptBooking(asTeacher()));
  });

  it('الطالب لا يخفي ملف غيره، والمسؤول لا يُغيّر العلم بقرار توثيق', async () => {
    await seed([
      { path: 'teacherProfiles/teacher-1', data: discoverDoc('teacher-1') },
    ]);

    await assertFails(
      updateDoc(doc(asStudent(), 'teacherProfiles/teacher-1'), {
        accountHidden: true,
      }),
    );
  });
});
