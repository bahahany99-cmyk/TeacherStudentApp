/**
 * تهيئة بيانات اختبارات تنفيذ Firestore على متصفح حقيقي (P32 — مراجعة نهائية).
 *
 * **لماذا سكربت Node منفصل؟** لأن اختبارات Dart على الويب تعمل بعميل حقيقي
 * يمرّ على **نفس قواعد Firestore**، والقواعد تمنع إنشاء الإشعارات ورسائل
 * المجموعات إلا بعلاقات حقيقية (حجز/عضوية/طلب). تهيئة البيانات عبر العميل
 * نفسه كانت ستُحوّل الاختبار إلى اختبار كتابة لا اختبار **قراءة**.
 * هنا نكتب البيانات متجاوزين القواعد (rules-unit-testing، `withSecurityRulesDisabled`)
 * ثم نترك عميل Dart يُنفّذ الاستعلامات الحقيقية تحت القواعد.
 *
 * **مستخدمو المصادقة:** يُنشؤون على محاكي Auth **قبل** كتابة البيانات، لأن
 * `recipientId` في القواعد هو `request.auth.uid` — فنكتب البيانات بمعرّف uid
 * الفعلي الذي ستحصل عليه اختبارات Dart عند تسجيل الدخول بنفس البريد.
 *
 * يُشغَّل من **جذر المستودع** داخل `firebase emulators:exec` (ليجد
 * `firestore.rules` في الجذر، وليجد حزمه في `tool/rules_tests/node_modules`):
 *   node tool/rules_tests/seed_web_emulator.mjs
 */

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Timestamp, doc, setDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-darsly';
const FIRESTORE_PORT = 8080;
const AUTH_HOST = 'http://127.0.0.1:9099';

/** كلمة مرور الاختبار — ليست سرًا ولا تخصّ أي مشروع إنتاجي. */
export const PASSWORD = 'Password1!';

const ACCOUNTS = {
  pages: 'pages@example.test',
  student: 'student@example.test',
  teacher: 'teacher@example.test',
};

const RULES = readFileSync(resolve('firestore.rules'), 'utf8');

const minutesFromNow = (minutes) =>
  new Date(Date.now() + minutes * 60 * 1000);

const timestamp = (date) => Timestamp.fromDate(date);

/**
 * ينشئ حسابًا على محاكي Auth (أو يسجّل الدخول إن كان موجودًا) ويعيد `localId`.
 *
 * **لماذا نأخذ uid من المحاكي بدل تثبيته؟** لأن القواعد تقارن
 * `recipientId` بـ`request.auth.uid`؛ أخذ uid الفعلي يجعل البيانات والعميل
 * متطابقين مهما كان توليد المحاكي للمعرّفات، بلا افتراضات عن دعم `localId`.
 */
async function upsertAccount(email) {
  const signUp = await fetch(
    `${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: PASSWORD, returnSecureToken: true }),
    },
  );
  const created = await signUp.json();
  if (signUp.ok && created.localId) {
    return created.localId;
  }

  const signIn = await fetch(
    `${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: PASSWORD, returnSecureToken: true }),
    },
  );
  const existing = await signIn.json();
  if (!signIn.ok || !existing.localId) {
    throw new Error(
      `تعذّر إنشاء/دخول الحساب ${email}: ${JSON.stringify(created)} / ${JSON.stringify(existing)}`,
    );
  }
  return existing.localId;
}

const notification = (recipientId, overrides = {}) => ({
  recipientId,
  type: 'bookingAccepted',
  actorId: 'seed-actor',
  actorName: 'طرف آخر',
  targetId: 'seed-target',
  title: 'إشعار اختبار',
  createdAt: timestamp(minutesFromNow(-10)),
  // `null` صريح: Firestore لا يُطابق غياب الحقل بشرط `readAt == null`.
  readAt: null,
  ...overrides,
});

const groupMessage = (groupId, senderId, sentAt) => ({
  groupId,
  senderId,
  senderName: senderId,
  senderRole: 'student',
  text: 'رسالة اختبار',
  sentAt: timestamp(sentAt),
});

async function seedFirestore(uids) {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: RULES,
      host: '127.0.0.1',
      port: FIRESTORE_PORT,
    },
  });

  try {
    await testEnv.clearFirestore();

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const writes = [];

      // ── 1) تصفّح الإشعارات: 45 إشعارًا بأوقات متزايدة + 3 متساوية الوقت ──
      for (let i = 0; i < 45; i++) {
        writes.push([
          `notifications/p${String(i).padStart(2, '0')}`,
          notification(uids.pages, {
            createdAt: timestamp(minutesFromNow(-200 + i)),
          }),
        ]);
      }
      for (const id of ['same-a', 'same-b', 'same-c']) {
        writes.push([
          `notifications/${id}`,
          notification(uids.pages, { createdAt: timestamp(minutesFromNow(-1)) }),
        ]);
      }

      // ── 2) تعليم إشعارات محادثة واحدة ──
      writes.push(
        [
          'notifications/dm-1',
          notification(uids.student, {
            type: 'directMessage',
            targetId: 'chat-1',
          }),
        ],
        [
          'notifications/dm-2',
          notification(uids.student, {
            type: 'directMessage',
            targetId: 'chat-1',
          }),
        ],
        [
          'notifications/dm-read',
          notification(uids.student, {
            type: 'directMessage',
            targetId: 'chat-1',
            readAt: timestamp(minutesFromNow(-5)),
          }),
        ],
        [
          'notifications/dm-other-chat',
          notification(uids.student, {
            type: 'directMessage',
            targetId: 'chat-2',
          }),
        ],
        [
          'notifications/booking-same-target',
          notification(uids.student, {
            type: 'bookingAccepted',
            targetId: 'chat-1',
          }),
        ],
        // إشعار المستخدم الآخر عن **نفس** المحادثة: يجب ألا يُمسّ.
        [
          'notifications/dm-teacher',
          notification(uids.teacher, {
            type: 'directMessage',
            targetId: 'chat-1',
          }),
        ],
      );

      // ── 3) عدّاد المجموعة: g1 فيها علامة قراءة، g2 بلا علامة ──
      writes.push(
        [
          'studyGroups/g1',
          {
            teacherId: uids.teacher,
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
        ],
        [
          'studyGroups/g1/members/student',
          {
            studentId: uids.student,
            name: 'طالب',
            joinedAt: timestamp(minutesFromNow(-600)),
            status: 'active',
          },
        ],
        // آخر قراءة قبل 120 دقيقة: كل الرسائل التالية «غير مقروءة».
        [
          'studyGroups/g1/reads/student',
          { lastReadAt: timestamp(minutesFromNow(-120)) },
        ],
        [
          'studyGroups/g2',
          {
            teacherId: uids.teacher,
            teacherName: 'أ. سارة الخطيب',
            title: 'الهندسة',
            subject: 'الرياضيات',
            stage: 'الثانوية العامة',
            seatsTotal: 12,
            seatsTaken: 1,
            meetingMode: 'center',
            scheduleNote: 'الأحد 6 م',
            isActive: true,
          },
        ],
        [
          'studyGroups/g2/members/student',
          {
            studentId: uids.student,
            name: 'طالب',
            joinedAt: timestamp(minutesFromNow(-600)),
            status: 'active',
          },
        ],
      );

      // g1: 10 رسائل من الطالب نفسه بعد آخر قراءة، ثم رسالة واحدة من المدرس.
      for (let i = 0; i < 10; i++) {
        writes.push([
          `studyGroups/g1/messages/mine-${i}`,
          groupMessage('g1', uids.student, minutesFromNow(-100 + i)),
        ]);
      }
      writes.push([
        'studyGroups/g1/messages/other-1',
        groupMessage('g1', uids.teacher, minutesFromNow(-30)),
      ]);

      // g2: بلا `reads` إطلاقًا (عضو قديم) — رسالتان من المدرس وواحدة من الطالب.
      writes.push(
        [
          'studyGroups/g2/messages/other-1',
          groupMessage('g2', uids.teacher, minutesFromNow(-50)),
        ],
        [
          'studyGroups/g2/messages/other-2',
          groupMessage('g2', uids.teacher, minutesFromNow(-40)),
        ],
        [
          'studyGroups/g2/messages/mine-1',
          groupMessage('g2', uids.student, minutesFromNow(-30)),
        ],
      );

      for (const [path, data] of writes) {
        await setDoc(doc(db, path), data);
      }
    });

    console.log('✅ بيانات اختبارات الويب جاهزة');
    console.log(`   pages=${uids.pages} student=${uids.student} teacher=${uids.teacher}`);
  } finally {
    await testEnv.cleanup();
  }
}

const uids = {
  pages: await upsertAccount(ACCOUNTS.pages),
  student: await upsertAccount(ACCOUNTS.student),
  teacher: await upsertAccount(ACCOUNTS.teacher),
};

await seedFirestore(uids);
