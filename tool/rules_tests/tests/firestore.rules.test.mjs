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
  seatsTaken: 9,
  meetingMode: 'center',
  scheduleNote: 'السبت 5 م',
  isActive: true,
  ...overrides,
});

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
describe('studyGroups — قراءة مقيّدة، وكل كتابة مرفوضة الآن', () => {
  it('الطالب يقرأ المجموعة النشطة فقط', async () => {
    await seed([
      { path: 'studyGroups/g1', data: groupDoc('teacher-1') },
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

  it('لا كتابة من التطبيق (مرحلة P7 لم تبدأ)', async () => {
    await seed([{ path: 'studyGroups/g1', data: groupDoc('teacher-1') }]);

    await assertFails(
      setDoc(doc(asTeacher(), 'studyGroups/g3'), groupDoc('teacher-1')),
    );
    await assertFails(
      updateDoc(doc(asTeacher(), 'studyGroups/g1'), { seatsTaken: 10 }),
    );
    await assertFails(deleteDoc(doc(asTeacher(), 'studyGroups/g1')));
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
describe('سلامة المحاكي نفسه (حماية من اختبارات وهمية)', () => {
  it('البيانات التجريبية تُكتب فعلًا مع تجاوز القواعد', async () => {
    await seed([{ path: 'users/student-1', data: userDoc('student-1') }]);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const snapshot = await getDoc(doc(context.firestore(), 'users/student-1'));
      assert.equal(snapshot.exists(), true);
    });
  });
});
