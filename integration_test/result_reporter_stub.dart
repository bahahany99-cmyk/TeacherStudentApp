/// نسخة غير-ويب من مُبلِّغ النتائج: لا تفعل شيئًا.
///
/// `integration_test` هنا يُبنى للويب فقط (`flutter drive -d web-server`)، لكن
/// وجود هذه النسخة يضمن أن التحليل الساكن والبناء لأي منصّة أخرى لا يتعطّل.
library;

/// منفذ خادم النتائج المحلي (غير مستخدم هنا).
const int resultsPort = 4445;

/// لا شيء: خارج الويب لا يوجد خادم نتائج محلي.
void reportTestResult(String name, {required bool ok, String? error}) {}
