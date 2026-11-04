import 'package:teacher_student_app/data/models/user_role.dart';

/// «من هو المسؤول؟» — قاعدة واحدة يقرؤها كل مكان إداري (P14).
///
/// **ثلاثة مصادر، وكلها خارج التطبيق:**
/// 1. **Custom Claim** اسمه `admin` يُضبط بمفتاح خدمة (Firebase Admin SDK).
///    وهو الذي تعتمده `firestore.rules` في `isAdmin()` (قراءة) و
///    `isAdminWriter()` (كتابة)، فلا يستطيع التطبيق منح نفسه صلاحية إدارية.
/// 2. **دور المستند** `users/{uid}.role == 'admin'` (P19): يضبطه مالك المشروع
///    من Console / Admin SDK. القواعد تقرؤه بـ`get()` وتقبله **للكتابة
///    الإدارية** (لاعتماد دور إداري مستقل عن الادعاء). ولا يستطيع صاحبه
///    كتابته: `allow create` يقبل `student|teacher`، و`allow update` يشترط
///    `role == resource.data.role`. (تفصيل الفصل بين قراءة وكتابة في
///    `firestore.rules` أعلى `isAdminDoc`.)
/// 3. **دور إداري محلي** (`UserRole.admin`) موجود **للمعاينة التجريبية فقط**،
///    ويُنشأ عبر `SessionController.startDemoSession` ولا يأتي من الخادم أبدًا.
///
/// ⚠️ هذه الدالة **للعرض والتنقل فقط** (إخفاء/إظهار الشاشات وحراسة المسارات).
/// الحماية الحقيقية في `firestore.rules`: كل كتابة إدارية تُفحص هناك، فحتى لو
/// تلاعب أحدهم بالواجهة لا يمرّ طلبه.
abstract final class AdminRoles {
  /// اسم الادعاء (claim) الذي تقرأه القواعد والعميل.
  static const String claimName = 'admin';

  /// هل الحساب مسؤول؟
  ///
  /// [role] دور الجلسة (قد يكون `null` قبل تحديده)، و[hasAdminClaim] قيمة
  /// الادعاء المقروءة من رمز الهوية (`FirebaseAuth.getIdTokenResult`).
  static bool isAdmin({required UserRole? role, required bool hasAdminClaim}) {
    return hasAdminClaim || role == UserRole.admin;
  }

  /// هل يستطيع هذا الحساب فتح مسار إداري؟ (اسم صريح للحراسة)
  static bool canAccessAdminPanel({
    required UserRole? role,
    required bool hasAdminClaim,
  }) => isAdmin(role: role, hasAdminClaim: hasAdminClaim);
}
