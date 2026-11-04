import 'package:integration_test/integration_test_driver.dart';

/// سائق `flutter drive` لاختبارات التكامل على الويب (P32).
///
/// يُشغَّل على VM بينما التطبيق يعمل في Chrome:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/p32_firestore_repositories_test.dart \
///     -d web-server --browser-name=chrome
///
/// **تحذير موثَّق:** قد يطبع هذا السائق «All tests passed» بلا أن يُنفَّذ اختبار
/// واحد (flutter#94434، #150358، #151480) — لذلك لا نعتمد على خرجه، بل على
/// تقارير `tool/integration/results_server.mjs` القادمة من داخل التطبيق.
Future<void> main() => integrationDriver();
