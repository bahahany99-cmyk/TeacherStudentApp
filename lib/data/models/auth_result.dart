import 'package:teacher_student_app/data/models/app_user.dart';

/// نتيجة محاولة مصادقة.
///
/// السبب: بعد تسجيل الدخول قد نحتاج خطوة إضافية (اختيار الدور عند أول دخول)،
/// فلا يكفي `AppUser?`. الفصل هنا يمنع أي شاشة من «تخمين» الدور.
sealed class AuthResult {
  const AuthResult();
}

/// مستخدم معروف الدور ونشط — جاهز للدخول إلى التطبيق.
final class AuthSignedIn extends AuthResult {
  const AuthSignedIn(this.user);

  final AppUser user;
}

/// الحساب موجود في Firebase لكن لم يختر دوره بعد.
///
/// الدور يُحفظ مرة واحدة في `users/{uid}` ثم يُقرأ من الخادم في كل دخول.
final class AuthNeedsRole extends AuthResult {
  const AuthNeedsRole({
    required this.uid,
    required this.displayName,
    this.email,
  });

  final String uid;
  final String displayName;
  final String? email;
}

/// الحساب مسجّل لكنه **مجدول للحذف** (P17).
///
/// لا ندخله إلى التطبيق: يُوجَّه إلى شاشة الاستعادة ليعيد حسابه نشطًا داخل
/// مهلة السماح، أو يرى أن المهلة انتهت. حالة منفصلة (لا `AuthSignedIn` بحالة
/// داخلية) حتى لا يستطيع أي كود عرضي — أو شرط `if` منسي — أن يعامل هذا
/// المستخدم كمستخدم عادي، فيمنعه المترجم من الوصول إلى `user` بلا معالجة.
final class AuthPendingDeletion extends AuthResult {
  const AuthPendingDeletion(this.user);

  /// صاحب الحساب، وحالته دائمًا `pendingDeletion`.
  final AppUser user;
}
