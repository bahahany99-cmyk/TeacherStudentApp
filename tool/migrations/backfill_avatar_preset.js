#!/usr/bin/env node
/**
 * ترحيل لمرة واحدة: تعيين صورة رمزية افتراضية للحسابات التي لا تملك واحدة.
 *
 * ## ما يفعله بالضبط
 *
 * لكل مستند في `users` **لا يحمل** `avatarPreset`:
 *
 *   users/{uid}.avatarPreset = حتميّ من المعرّف (0..23)
 *   avatars/{uid}.presetId   = نفس الرقم   (merge، لا يمسّ صورة مرفوعة)
 *
 * ## لماذا الحتمي من المعرّف لا العشوائي؟
 *
 * الحساب القديم **يرى الآن** صورة حتمية (`AvatarPresets.forId`) لأن الواجهة
 * تعرضها عند غياب الحقل. لو عيَّنّا عشوائيًا لتغيّرت صورة كل مستخدم قائم فجأة
 * — وهو ما طلب صاحب المشروع تجنّبه («بصورة آمنة دون التأثير على بياناتها»).
 * الحتمي يعني: **لا تغيير مرئي**، ومع ذلك يصبح الحقل موجودًا ومحفوظًا وثابتًا
 * على كل جهاز.
 *
 * ## الأمان المطبَّق هنا
 *
 * 1. **الوضع الافتراضي معاينة (Dry Run)** — لا كتابة إطلاقًا. الكتابة تحتاج
 *    `--apply` صريحًا.
 * 2. **لا يُلمس أي مستند يحمل `avatarPreset`** — بأي قيمة، صحيحة كانت أو لا.
 * 3. **حقل واحد في `users`، وحقل واحد في `avatars`** — لا حذف ولا تعديل لأي
 *    حقل آخر (لا `role`، لا `status`، لا توثيق، لا `teacherProfiles` إطلاقًا).
 * 4. **لا يمسّ الصور المرفوعة**: الكتابة `merge` وبلا `imageBase64`/`mimeType`.
 * 5. **آمن للتكرار:** التشغيل الثاني يجد «0 مستندًا».
 * 6. **فشل مستند لا يوقف البقية:** تُجمع الأخطاء وتُعرض.
 *
 * ## التشغيل
 *
 *   # 1) معاينة فقط (آمنة):
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/service-account.json \
 *     node tool/migrations/backfill_avatar_preset.js --project <PROJECT_ID>
 *
 *   # 2) التنفيذ الفعلي (بعد مراجعة العدد وبعد موافقة صاحب المشروع):
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/service-account.json \
 *     node tool/migrations/backfill_avatar_preset.js --project <PROJECT_ID> --apply
 *
 * خيارات: `--page 500` (حجم الصفحة)، `--verbose` (طباعة كل معرّف).
 *
 * ⚠️ لا يُشغَّل على قاعدة الإنتاج إلا بموافقة صاحب المشروع. ليس جزءًا من
 * التطبيق ولا من CI.
 */

'use strict';

const USERS = 'users';
const AVATARS = 'avatars';
const FIELD = 'avatarPreset';
const PRESET_COUNT = 24;
const PAGE_DEFAULT = 500;

function parseArgs(argv) {
  const args = { apply: false, verbose: false, project: null, page: PAGE_DEFAULT };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--apply') args.apply = true;
    else if (arg === '--verbose') args.verbose = true;
    else if (arg === '--project') args.project = argv[++i];
    else if (arg === '--page') args.page = Number.parseInt(argv[++i], 10);
    else if (arg === '--help' || arg === '-h') args.help = true;
    else throw new Error(`خيار غير معروف: ${arg}`);
  }
  return args;
}

function usage() {
  return [
    'الاستخدام:',
    '  node tool/migrations/backfill_avatar_preset.js --project <PROJECT_ID> [--apply] [--verbose]',
    '',
    '  --project   معرّف مشروع Firebase (إلزامي)',
    '  --apply     تنفيذ الكتابة (بدونه: معاينة فقط)',
    '  --page      حجم صفحة القراءة (افتراضي 500)',
    '  --verbose   طباعة كل معرّف',
  ].join('\n');
}

/** نفس خوارزمية `AvatarPresets.forId` في التطبيق — لا تُغيَّر إلا معها. */
function presetForId(id) {
  if (!id) return 0;
  let hash = 0;
  for (let i = 0; i < id.length; i += 1) {
    hash = (hash * 31 + id.charCodeAt(i)) & 0x7fffffff;
  }
  return hash % PRESET_COUNT;
}

function needsBackfill(data) {
  return !Object.prototype.hasOwnProperty.call(data || {}, FIELD);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(usage());
    return 0;
  }
  if (!args.project) {
    console.error('✖ مطلوب --project <PROJECT_ID> (حماية من التشغيل على مشروع غير مقصود).\n');
    console.error(usage());
    return 2;
  }
  if (!Number.isFinite(args.page) || args.page < 1 || args.page > 5000) {
    console.error('✖ قيمة --page غير صالحة (1..5000).');
    return 2;
  }

  let admin;
  try {
    // eslint-disable-next-line global-require
    admin = require('firebase-admin');
  } catch (error) {
    console.error('✖ الحزمة firebase-admin غير مثبّتة. ثبّتها في مجلد العمل المؤقت:');
    console.error('    npm install --no-save firebase-admin');
    return 2;
  }

  admin.initializeApp({ projectId: args.project });
  const db = admin.firestore();
  const ref = db.collection(USERS);

  const mode = args.apply ? 'تنفيذ (كتابة فعلية)' : 'معاينة (Dry Run — لا كتابة)';
  console.log(`▶ الوضع: ${mode}`);
  console.log(`▶ المشروع: ${args.project} · المجموعة: ${USERS}\n`);

  let scanned = 0;
  let lastDoc = null;
  let page = 0;
  const pending = [];

  for (;;) {
    let query = ref.orderBy(admin.firestore.FieldPath.documentId()).limit(args.page);
    if (lastDoc) query = query.startAfter(lastDoc);
    // eslint-disable-next-line no-await-in-loop
    const snapshot = await query.get();
    if (snapshot.empty) break;

    snapshot.forEach((doc) => {
      scanned += 1;
      if (needsBackfill(doc.data())) {
        pending.push({ id: doc.id, preset: presetForId(doc.id) });
      }
    });

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    page += 1;
    console.log(`  … قُرئت ${scanned} مستندًا (صفحة ${page}) — ينقصها الحقل: ${pending.length}`);
    if (snapshot.size < args.page) break;
  }

  console.log(`\n■ الفحص انتهى: ${scanned} مستندًا، منها ${pending.length} ينقصها \`${FIELD}\`.\n`);

  if (pending.length === 0) {
    console.log('✔ لا شيء يحتاج ترحيلًا — كل حساب له صورة رمزية محفوظة.');
    return 0;
  }

  if (args.verbose || !args.apply) {
    const shown = pending.slice(0, 100);
    console.log('  المعرّفات (ومعرّف الصورة الذي سيُعيَّن):');
    for (const entry of shown) console.log(`   - ${entry.id} ⇒ ${entry.preset}`);
    if (pending.length > shown.length) {
      console.log(`   … و${pending.length - shown.length} أخرى.`);
    }
    console.log('');
  }

  if (!args.apply) {
    console.log('ℹ️  هذه معاينة فقط. لم يُكتب أي شيء.');
    console.log('   للتنفيذ (بعد الموافقة): أضف --apply إلى نفس الأمر.');
    return 0;
  }

  const failures = [];
  const CHUNK = 200; // مستندان لكل مستخدم ⇒ 400 عملية في الدفعة (حدّ Firestore 500)
  for (let start = 0; start < pending.length; start += CHUNK) {
    const chunk = pending.slice(start, start + CHUNK);
    const batch = db.batch();
    for (const entry of chunk) {
      batch.update(ref.doc(entry.id), { [FIELD]: entry.preset });
      // merge: لا يمسّ صورة مرفوعة إن وُجدت.
      batch.set(
        db.collection(AVATARS).doc(entry.id),
        { ownerId: entry.id, presetId: entry.preset },
        { merge: true },
      );
    }
    try {
      // eslint-disable-next-line no-await-in-loop
      await batch.commit();
      console.log(`  ✔ كُتب ${Math.min(start + CHUNK, pending.length)} / ${pending.length}`);
    } catch (error) {
      console.error(`  ✖ فشلت دفعة تبدأ عند ${start}: ${error.message}`);
      for (const entry of chunk) {
        try {
          // eslint-disable-next-line no-await-in-loop
          await ref.doc(entry.id).update({ [FIELD]: entry.preset });
          // eslint-disable-next-line no-await-in-loop
          await db.collection(AVATARS).doc(entry.id).set(
            { ownerId: entry.id, presetId: entry.preset },
            { merge: true },
          );
        } catch (singleError) {
          failures.push({ id: entry.id, message: singleError.message });
        }
      }
    }
  }

  const updated = pending.length - failures.length;
  console.log('\n══ الملخص ══');
  console.log(`  المستندات المقروءة: ${scanned}`);
  console.log(`  التي كانت بلا صورة رمزية: ${pending.length}`);
  console.log(`  التي حُدِّثت: ${updated}`);
  console.log(`  التي فشلت: ${failures.length}`);
  for (const failure of failures.slice(0, 20)) {
    console.log(`   ✖ ${failure.id}: ${failure.message}`);
  }
  return failures.length === 0 ? 0 : 1;
}

main()
  .then((code) => process.exit(code))
  .catch((error) => {
    console.error(`✖ فشل غير متوقع: ${error.message}`);
    process.exit(1);
  });
