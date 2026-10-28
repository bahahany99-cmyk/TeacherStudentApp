import 'package:teacher_student_app/data/models/account_status.dart';
import 'package:teacher_student_app/data/models/user_role.dart';

/// مستخدم التطبيق كما يحتاجه الواجهة.
///
/// الحقول هنا للعرض فقط. أي بيانات حسّاسة (صلاحية الإدارة، حالة اعتماد المدرس)
/// تُقرأ من الخادم ولا يعتمد التطبيق على قيمتها المحلية في أي قرار أمني.
class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.role,
    this.email,
    this.isDemoAccount = false,
    this.hasAdminClaim = false,
    this.status = AccountStatus.active,
    this.scheduledDeletionAt,
  });

  final String id;
  final String displayName;
  final UserRole role;
  final String? email;

  /// `true` عندما يكون الحساب مُصطنعًا محليًا للعرض فقط (لا Firebase).
  ///
  /// تُستخدم لعرض شريط "وضع تجريبي" ومنع أي كود من التعامل معه كحساب حقيقي.
  final bool isDemoAccount;

  /// قيمة الادعاء الإداري (`admin`) المقروءة من رمز الهوية (P14).
  ///
  /// تُقرأ من Firebase Auth مرة واحدة عند الدخول/الاسترجاع، ولا يكتبها
  /// التطبيق. `false` تعني «ليس مسؤولًا» — لا تعني «طُرد».
  final bool hasAdminClaim;

  /// حالة الحساب (P17): نشط أو بانتظار الحذف.
  ///
  /// ⚠️ **للعرض والتوجيه فقط**: الحارس الحقيقي هو `users.status` في
  /// `firestore.rules`، فالواجهة قد تعرض حسابًا نشطًا بينما الخادم يرفض كتابته.
  final AccountStatus status;

  /// موعد الحذف المجدول (P17) — `null` في الحساب النشط.
  ///
  /// يُكتب مرة واحدة عند الطلب، ويُحذف عند الاستعادة.
  final DateTime? scheduledDeletionAt;

  /// هل الحساب مجدول للحذف؟
  bool get isPendingDeletion => status == AccountStatus.pendingDeletion;

  /// نسخة بحالة حساب أخرى، مع ضبط الموعد أو محوه.
  ///
  /// نستخدم هذا بدل `copyWith` عام: الحقول هنا مترابطة (الموعد يلزم مع
  /// `pendingDeletion` ويلزم غيابه مع `active`)، وتوقيع صريح يمنع تركيبة خاطئة.
  AppUser withAccountStatus(
    AccountStatus next, {
    DateTime? scheduledDeletionAt,
  }) {
    return AppUser(
      id: id,
      displayName: displayName,
      role: role,
      email: email,
      isDemoAccount: isDemoAccount,
      hasAdminClaim: hasAdminClaim,
      status: next,
      scheduledDeletionAt: next == AccountStatus.active
          ? null
          : scheduledDeletionAt,
    );
  }

  String get initials {
    final String trimmed = displayName.trim();
    return trimmed.isEmpty ? '؟' : trimmed.substring(0, 1);
  }
}
