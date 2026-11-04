/// إرسال نتائج الاختبار من **داخل التطبيق** إلى خادم محلي
/// (`tool/integration/results_server.mjs`) — نسخة الويب.
///
/// الفكرة: `flutter drive` على الويب قد يطبع «All tests passed.» بعدد صفر
/// اختبارات (أخطاء Flutter المعروفة 94434، 150358، 151480)، وسجلات Actions
/// غير قابلة للتنزيل من بيئة التطوير. فالتقرير المُرسل من التطبيق نفسه هو
/// الدليل القابل للتحقق على أن الاختبار جرى فعلًا.
library;

import 'dart:js_interop';

/// منفذ خادم النتائج المحلي.
const int resultsPort = 4445;

@JS('fetch')
external JSPromise<JSAny?> _fetch(JSString url, [JSAny? init]);

/// يرسل نتيجة اختبار واحد إلى الخادم المحلي.
void reportTestResult(String name, {required bool ok, String? error}) {
  try {
    final String body = _encode(name, ok: ok, error: error);
    _fetch(
      'http://127.0.0.1:$resultsPort/result'.toJS,
      <String, Object?>{
        'method': 'POST',
        // `no-cors` + جسم نصي ⇒ طلب بسيط بلا preflight، والخادم يستقبله.
        'mode': 'no-cors',
        'body': body,
      }.jsify() as JSObject,
    ).toDart.ignore();
  } catch (_) {
    // لا يجوز أن يُفشل الإبلاغُ الاختبارَ نفسه.
  }
}

/// ترميز JSON بسيط بلا `dart:convert` (لا داعي لاستيراد).
String _encode(String name, {required bool ok, String? error}) {
  String esc(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ');
  final String err =
      error == null ? '' : ',"error":"${esc(error.length > 300 ? error.substring(0, 300) : error)}"';
  return '{"name":"${esc(name)}","ok":$ok$err}';
}
