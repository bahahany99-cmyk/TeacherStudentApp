import 'package:integration_test/integration_test_driver.dart';

/// سائق `flutter drive` لاختبارات التكامل (P32 — مراجعة).
///
/// يُشغَّل على VM بينما التطبيق يعمل في Chrome:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/p32_firestore_repositories_test.dart \
///     -d web-server
Future<void> main() => integrationDriver();
