#!/usr/bin/env node
/**
 * ترحيل لمرة واحدة: إضافة `accountHidden: false` إلى ملفات المدرسين الناقصة.
 *
 * ## المشكلة التي يحلّها
 *
 * استعلامات اكتشاف المدرسين في التطبيق تفلتر:
 *   where('status' == 'verified') && where('accountHidden' == false)
 * وفي Firestore **غياب الحقل ≠ `false`**، فأي ملف بلا `accountHidden` لا يظهر في
 * صفحة المدرسين ولا في «المميزين» ولا يوفّر خيارات محافظات — مع أن قواعد
 * القراءة تسمح به (تستخدم `get('accountHidden', false)`).
 * التفاصيل الكاملة: docs/P29_DIAGNOSIS.md
 *
 * ## الأمان المطبَّق هنا
 *
 * 1. **الوضع الافتراضي معاينة (Dry Run)** — لا كتابة إطلاقًا. الكتابة تحتاج
 *    `--apply` صريحًا.
 * 2. **لا يُلمس أي مستند يحمل الحقل** — بأي قيمة. لا «تصحيح» ولا إعادة إظهار
 *    لحساب أخفاه صاحبه أو المسؤول.
 * 3. **لا حذف ولا تعديل لأي حقل آخر** — العملية `{ accountHidden: false }` وحدها.
 * 4. **آمن للتكرار:** تشغيله بعد نجاحه يجد «0 مستندًا» لأنه لا يحدّث إلا الناقص.
 * 5. **فشل مستند لا يوقف البقية:** تُجمع الأخطاء وتُعرض، وتُعاد المحاولة على
 *    ما تبقّى.
 * 6. **لا يستخدم قواعد الأمان** (Admin SDK) — وهذا مقصود: تحديث إداري من
 *    التطبيق يشترط أن تكون كل مفاتيح المستند ضمن `adminDecisionKeys`، وهو ما
 *    ترفضه ملفات عليها `isFeatured`/`featuredOrder`.
 *
 * ## التشغيل
 *
 *   # 1) معاينة فقط (آمنة، لا تكتب شيئًا):
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/service-account.json \
 *     node tool/migrations/backfill_account_hidden.js --project <PROJECT_ID>
 *
 *   # 2) التنفيذ الفعلي (بعد مراجعة عدد المستندات في المعاينة وبعد الموافقة):
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/service-account.json \
 *     node tool/migrations/backfill_account_hidden.js --project <PROJECT_ID> --apply
 *
 * خيارات إضافية: `--collection teacherProfiles` (افتراضي)، `--page 500`
 * (حجم الصفحة)، `--verbose` (طباعة كل معرّف).
 *
 * ⚠️ **لا يُشغَّل على قاعدة الإنتاج إلا بموافقة صاحب المشروع.** السكربت موجود
 * للتنفيذ الواعي، لا كجزء من التطبيق ولا من CI.
 */

'use strict';

const COLLECTION_DEFAULT = 'teacherProfiles';
const PAGE_DEFAULT = 500;
const FIELD = 'accountHidden';

function parseArgs(argv) {
  const args = { apply: false, verbose: false, project: null, collection: COLLECTION_DEFAULT, page: PAGE_DEFAULT };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--apply') args.apply = true;
    else if (arg === '--verbose') args.verbose = true;
    else if (arg === '--project') args.project = argv[++i];
    else if (arg === '--collection') args.collection = argv[++i];
    else if (arg === '--page') args.page = Number.parseInt(argv[++i], 10);
    else if (arg === '--help' || arg === '-h') args.help = true;
    else throw new Error(`خيار غير معروف: ${arg}`);
  }
  return args;
}

function usage() {
  return [
    'الاستخدام:',
    '  node tool/migrations/backfill_account_hidden.js --project <PROJECT_ID> [--apply] [--verbose]',
    '',
    '  --project      معرّف مشروع Firebase (إلزامي، يمنع التشغيل على مشروع غير مقصود)',
    '  --apply        تنفيذ الكتابة (بدونه: معاينة فقط)',
    '  --collection   اسم المجموعة (افتراضي teacherProfiles)',
    '  --page         حجم صفحة القراءة (افتراضي 500)',
    '  --verbose      طباعة كل معرّف ينقصه الحقل',
  ].join('\n');
}

/** هل المستند بحاجة إلى الترحيل؟ (غياب الحقل فقط — القيمة الحالية لا تهم) */
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
    console.error('✖ مطلوب --project <PROJECT_ID> (حماية من تشغيل الترحيل على مشروع غير مقصود).\n');
    console.error(usage());
    return 2;
  }
  if (!Number.isFinite(args.page) || args.page < 1 || args.page > 5000) {
    console.error('✖ قيمة --page غير صالحة (1..5000).');
    return 2;
  }

  // الاستيراد المتأخر: يسمح بعرض رسالة واضحة إن لم تُثبَّت الحزمة، بدل انهيار
  // غامض قبل قراءة الخيارات.
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
  const ref = db.collection(args.collection);

  const mode = args.apply ? 'تنفيذ (كتابة فعلية)' : 'معاينة (Dry Run — لا كتابة)';
  console.log(`▶ الوضع: ${mode}`);
  console.log(`▶ المشروع: ${args.project} · المجموعة: ${args.collection}\n`);

  let scanned = 0;
  let lastDoc = null;
  let page = 0;
  const pending = [];
  const failures = [];

  // ── 1) فحص كل المستندات (قراءة صفحية لا تُحمّل المجموعة كاملة في الذاكرة) ──
  for (;;) {
    let query = ref.orderBy(admin.firestore.FieldPath.documentId()).limit(args.page);
    if (lastDoc) query = query.startAfter(lastDoc);
    // eslint-disable-next-line no-await-in-loop
    const snapshot = await query.get();
    if (snapshot.empty) break;

    snapshot.forEach((doc) => {
      scanned += 1;
      if (needsBackfill(doc.data())) pending.push(doc.ref);
    });

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    page += 1;
    console.log(`  … قُرئت ${scanned} مستندًا (صفحة ${page}) — ينقصها الحقل حتى الآن: ${pending.length}`);
    if (snapshot.size < args.page) break;
  }

  console.log(`\n■ الفحص انتهى: ${scanned} مستندًا، منها ${pending.length} ينقصها \`${FIELD}\`.\n`);

  if (pending.length === 0) {
    console.log('✔ لا شيء يحتاج ترحيلًا — البيانات سليمة أصلًا (أو سبق ترحيلها).');
    return 0;
  }

  if (args.verbose || !args.apply) {
    const shown = pending.slice(0, 100);
    console.log('  المعرّفات:');
    for (const docRef of shown) console.log(`   - ${docRef.id}`);
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

  // ── 2) الكتابة: مجموعات من 400 عملية (حد Firestore هو 500) ──────────────
  const CHUNK = 400;
  for (let start = 0; start < pending.length; start += CHUNK) {
    const chunk = pending.slice(start, start + CHUNK);
    const batch = db.batch();
    for (const docRef of chunk) {
      // حقل واحد فقط: لا حذف ولا تعديل لأي بيانات أخرى.
      batch.update(docRef, { [FIELD]: false });
    }
    try {
      // eslint-disable-next-line no-await-in-loop
      await batch.commit();
      console.log(`  ✔ كُتب ${Math.min(start + CHUNK, pending.length)} / ${pending.length}`);
    } catch (error) {
      // فشل الدفعة: نسجّل ونعيد المحاولة لكل مستند على حدة لمعرفة المتعثّر
      // بدقة (المستندات الأخرى في الدفعة قد تكون سليمة).
      console.error(`  ✖ فشلت دفعة تبدأ عند ${start}: ${error.message}`);
      for (const docRef of chunk) {
        try {
          // eslint-disable-next-line no-await-in-loop
          await docRef.update({ [FIELD]: false });
        } catch (singleError) {
          failures.push({ id: docRef.id, message: singleError.message });
        }
      }
    }
  }

  const updated = pending.length - failures.length;
  console.log('\n══ الملخص ══');
  console.log(`  المستندات المقروءة: ${scanned}`);
  console.log(`  التي كانت ينقصها الحقل: ${pending.length}`);
  console.log(`  التي حُدِّثت: ${updated}`);
  console.log(`  التي فشلت: ${failures.length}`);
  if (failures.length > 0) {
    console.log('\n  المتعثّرة (أعِد تشغيل السكربت بعد إصلاح السبب — التشغيل آمن ومتكرّر):');
    for (const failure of failures) console.log(`   - ${failure.id}: ${failure.message}`);
    return 1;
  }
  console.log('\n✔ الترحيل انتهى. أعِد تشغيل المعاينة للتأكد أن الناتج «0 مستندًا».');
  return 0;
}

if (require.main === module) {
  main()
    .then((code) => process.exit(code))
    .catch((error) => {
      console.error('✖ توقف الترحيل:', error.message);
      process.exit(1);
    });
}

module.exports = { needsBackfill, parseArgs };
