/**
 * تهيئة بيانات اختبار التكامل لتنفيذ Firestore (P32 — محاولة أخيرة).
 *
 * **لماذا سكربت Node منفصل عن الاختبار؟** لأن الاختبار نفسه يعمل **تحت قواعد
 * المشروع** بعميل Dart حقيقي، والقواعد تمنع إنشاء الإشعارات وعلامات القراءة
 * إلا بعلاقات حقيقية. لو هيّأنا البيانات من داخل الاختبار لكان الاختبار
 * يختبر الكتابة لا القراءة. هنا نكتب البيانات متجاوزين القواعد
 * (`withSecurityRulesDisabled`)، ثم يُشغَّل الاختبار على القواعد الفعلية.
 *
 * **الحسابات:** تُنشأ على محاكي Auth أولًا، ونأخذ `uid` **الفعلي** لأن القواعد
 * تقارن `recipientId` بـ`request.auth.uid`. وبما أن الاختبار يسجّل الدخول بنفس
 * البريد وكلمة المرور، سيحصل على نفس `uid`.
 *
 * يُشغَّل من جذر المستودع داخل `firebase emulators:exec`:
 *   node tool/integration/seed_emulator.mjs
 */

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Timestamp, doc, setDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-darsly';
const FIRESTORE_HOST = '127.0.0.1';
const FIRESTORE_PORT = 8080;
const AUTH_HOST = 'http://127.0.0.1:9099';

/** كلمة مرور الاختبار على المحاكي — ليست سرًّا ولا تخصّ مشروعًا حقيقيًا. */
export const PASSWORD = 'Password1!';

export const ACCOUNTS = {
  pages: 'pages@example.test',
  student: 'student@example.test',
  teacher: 'teacher@example.test',
};

const RULES_PATH = resolve(
  fileURLToPath(new URL('.', import.meta.url)),
  '../../firestore.rules',
);
const RULES = readFileSync(RULES_PATH, 'utf8');

const minutesFromNow = (minutes) =>
  new Date(Date.now() + minutes * 60 * 1000);
const ts = (date) => Timestamp.fromDate(date);

/**
 * ينشئ حسابًا على محاكي Auth أو يسجّل الدخول إليه، ويعيد `localId` الفعلي.
 * يستخدم نقاط REST الخاصة بالمحاكي (بلا SDK) فلا يحتاج أي تبعية إضافية.
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
      `تعذّر إنشاء/دخول ${email}: ${JSON.stringify(created)} / ${JSON.stringify(existing)}`,
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
  createdAt: ts(minutesFromNow(-300)),
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
  sentAt: ts(sentAt),
});

const group = (teacherId, title) => ({
  teacherId,
  teacherName: 'أ. سارة الخطيب',
  title,
  subject: 'الرياضيات',
  stage: 'الثانوية العامة',
  seatsTotal: 12,
  seatsTaken: 1,
  meetingMode: 'center',
  scheduleNote: 'السبت 5 م',
  isActive: true,
});

async function seedFirestore(uids) {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: RULES, host: FIRESTORE_HOST, port: FIRESTORE_PORT },
  });

  try {
    await testEnv.clearFirestore();

    const writes = [];

    // ── 1) تصفّح الإشعارات: 45 إشعارًا متباعدًا + 3 متساوية الوقت ─────────
    const base = minutesFromNow(-300);
    for (let i = 0; i < 45; i++) {
      const createdAt = new Date(base.getTime() + i * 60 * 1000);
      writes.push([
        `notifications/p${String(i).padStart(2, '0')}`,
        notification(uids.pages, { createdAt: ts(createdAt) }),
      ]);
    }
    for (const id of ['same-a', 'same-b', 'same-c']) {
      writes.push([
        `notifications/${id}`,
        notification(uids.pages, { createdAt: ts(minutesFromNow(-1)) }),
      ]);
    }

    // ── 2) تعليم إشعارات محادثة واحدة ────────────────────────────────────
    writes.push(
      [
        'notifications/dm-1',
        notification(uids.student, { type: 'directMessage', targetId: 'chat-1' }),
      ],
      [
        'notifications/dm-2',
        notification(uids.student, { type: 'directMessage', targetId: 'chat-1' }),
      ],
      [
        'notifications/dm-read',
        notification(uids.student, {
          type: 'directMessage',
          targetId: 'chat-1',
          readAt: ts(minutesFromNow(-5)),
        }),
      ],
      [
        'notifications/dm-other-chat',
        notification(uids.student, { type: 'directMessage', targetId: 'chat-2' }),
      ],
      [
        'notifications/booking-same-target',
        notification(uids.student, { type: 'bookingAccepted', targetId: 'chat-1' }),
      ],
      // إشعار المستخدم الآخر عن **نفس** المحادثة: يجب ألا يُمسّ أبدًا.
      [
        'notifications/dm-teacher',
        notification(uids.teacher, { type: 'directMessage', targetId: 'chat-1' }),
      ],
    );

    // ── 3) مجموعتان: g1 بعلامة قراءة، وg2 بلا علامة ──────────────────────
    writes.push(
      ['studyGroups/g1', group(uids.teacher, 'التفاضل')],
      [
        `studyGroups/g1/members/${uids.student}`,
        {
          studentId: uids.student,
          name: 'طالب',
          joinedAt: ts(minutesFromNow(-600)),
          status: 'active',
        },
      ],
      // آخر قراءة قبل 120 دقيقة ⇒ كل ما بعدها «غير مقروء».
      [
        `studyGroups/g1/reads/${uids.student}`,
        { lastReadAt: ts(minutesFromNow(-120)) },
      ],
      ['studyGroups/g2', group(uids.teacher, 'الهندسة')],
      [
        `studyGroups/g2/members/${uids.student}`,
        {
          studentId: uids.student,
          name: 'طالب',
          joinedAt: ts(minutesFromNow(-600)),
          status: 'active',
        },
      ],
    );

    // g1: عشر رسائل من الطالب نفسه بعد آخر قراءة + واحدة من المدرس.
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

    // g2: بلا `reads` إطلاقًا (عضو قديم) — رسالتان من المدرس وواحدة منه.
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
        groupMessage('g2', uids.student, minutesFromNow(-20)),
      ],
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      for (const [path, data] of writes) {
        await setDoc(doc(db, path), data);
      }
    });

    console.log('✅ بيانات اختبار التكامل جاهزة');
    console.log(
      `   pages=${uids.pages} student=${uids.student} teacher=${uids.teacher}`,
    );
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
