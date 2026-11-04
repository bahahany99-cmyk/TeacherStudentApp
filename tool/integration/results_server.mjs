/**
 * قناة نتائج محلية لاختبار التكامل (P32 — محاولة أخيرة).
 *
 * **لماذا؟** ثبَت أن `flutter drive` على الويب قد يطبع «All tests passed.»
 * **بعدد صفر** من الاختبارات (أخطاء معروفة في Flutter: 94434، 150358، 151480)،
 * وأن سجلات Actions نفسها غير قابلة للتنزيل من بيئة التطوير. فبدل الاعتماد على
 * مُبلِّغ `flutter drive`، يجمع هذا الخادم تقارير **من داخل التطبيق نفسه**:
 * كل اختبار يُرسل نتيجة JSON إلى `http://127.0.0.1:<PORT>/result`.
 *
 * وبهذا أيضًا صار في الإمكان تمييز ثلاث حالات بدقة:
 *   1. التطبيق لم يبدأ أصلًا  ⇒ لا نتائج إطلاقًا.
 *   2. التطبيق بدأ وبعض الاختبارات فشلت ⇒ نتائج ناقصة/فاشلة.
 *   3. التطبيق نفّذ الاختبارات كلها ونجحت ⇒ 9 نتائج ناجحة.
 *
 * الاستخدام:
 *   node tool/integration/results_server.mjs serve  <port> <out-file> &
 *   node tool/integration/results_server.mjs verify <port> <out-file> <expected>
 */

import { createServer } from 'node:http';
import { appendFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs';

const [, , mode, portArg, file, expectedArg] = process.argv;
const port = Number(portArg || 4445);
const expected = Number(expectedArg || 9);

if (mode === 'serve') {
  writeFileSync(file, '');
  const server = createServer((request, response) => {
    const chunks = [];
    request.on('data', (chunk) => chunks.push(chunk));
    request.on('end', () => {
      const body = Buffer.concat(chunks).toString('utf8');
      // سطر واحد لكل تقرير: يسهل عدّه وفحصه.
      if (body.trim().length > 0) {
        appendFileSync(file, `${body.trim()}\n`);
      }
      // `no-cors` في المتصفح لا يقرأ الرد؛ نردّ بأي حال.
      response.writeHead(204, {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': '*',
      });
      response.end();
    });
  });
  server.listen(port, '127.0.0.1', () => {
    console.log(`نتائج-الاختبار: الخادم يسمع على 127.0.0.1:${port}`);
  });
  // لا يخرج من تلقاء نفسه: تُنهيه الخطوة التالية.
} else if (mode === 'verify') {
  if (!existsSync(file)) {
    console.error(`::error::لا ملف نتائج (${file}) — التطبيق لم يُرسل أي تقرير: لم يبدأ أصلًا في المتصفح.`);
    process.exit(1);
  }
  const lines = readFileSync(file, 'utf8')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);

  const parsed = [];
  for (const line of lines) {
    try {
      parsed.push(JSON.parse(line));
    } catch {
      // سطر غير صالح لا يُحتسب.
    }
  }

  const beacons = new Set(
    parsed.filter((item) => item.name.startsWith('__')).map((item) => item.name),
  );
  const results = parsed.filter((item) => !item.name.startsWith('__'));
  const passed = results.filter((item) => item.ok === true);
  const failed = results.filter((item) => item.ok !== true);

  console.log(`إشارات التشغيل: ${[...beacons].join(', ') || 'لا شيء'}`);
  console.log(`نتائج اختبارات: ${results.length}/${expected} (ناجح ${passed.length})`);

  const names = results.map((item) => `${item.ok ? '✓' : '✗'} ${item.name}`);
  for (const name of names) {
    console.log(`  ${name}`);
  }
  for (const item of failed) {
    console.log(`  سبب الفشل: ${item.name} — ${item.error ?? 'بلا رسالة'}`);
  }

  // السجلات غير قابلة للتنزيل من بيئة التطوير ⇒ ننشر الخلاصة كـannotation.
  const summary = [
    `إشارات: ${[...beacons].join(',') || 'لا شيء'}`,
    `نتائج: ${results.length}/${expected}`,
    ...names,
  ]
    .join(' · ')
    .replaceAll('%', '%25')
    .slice(0, 1200);
  console.log(`::notice title=repositories-results::${summary}`);

  // تشخيص دقيق للحالات الثلاث.
  if (!beacons.has('__main')) {
    console.error(
      '::error::لم تصل إشارة بدء التطبيق — الصفحة لم تُحمَّل/لم يعمل الاختبار في المتصفح إطلاقًا.',
    );
    process.exit(1);
  }
  if (!beacons.has('__registered')) {
    console.error(
      '::error::التطبيق بدأ ولم يكتمل تسجيل الاختبارات — التهيئة (Firebase.initializeApp) أو setUpAll تعطّل.',
    );
    process.exit(1);
  }
  if (results.length < expected) {
    console.error(
      `::error::وصل ${results.length} تقريرًا فقط من ${expected} — الاختبارات سُجّلت ولم تُنفَّذ كلها.`,
    );
    process.exit(1);
  }
  if (failed.length > 0) {
    console.error(`::error::${failed.length} اختبارًا فشل داخل التطبيق.`);
    process.exit(1);
  }
  console.log('✅ كل الاختبارات نُفِّذت داخل التطبيق ونجحت على محاكيي Firestore وAuth.');
} else {
  console.error('الاستخدام: results_server.mjs serve|verify <port> <file> [expected]');
  process.exit(2);
}
