/// أسماء المسارات في التطبيق (مكان واحد).
///
/// التنقل الحالي بسيط (اسمي). إذا احتجنا لاحقًا إلى روابط أعمق
/// (مثل `/teachers/:id`) يمكن الانتقال إلى `go_router` دون تغيير أسماء
/// المسارات هنا (انظر T-05 في `docs/ARCHITECTURE_DECISIONS.md`).
abstract final class RoutePaths {
  static const String splash = '/';
  static const String login = '/login';
  static const String shell = '/app';

  // مسارات مستقبلية (غير مسجّلة بعد):
  // '/teacher/:id', '/group/:id', '/booking/:id', '/chat/:id', '/admin'
}
