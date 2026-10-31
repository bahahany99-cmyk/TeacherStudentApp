import 'package:teacher_student_app/data/models/account_status.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';
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
    this.phone,
    this.stage,
    this.avatarPreset,
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

  /// رقم الهاتف (P18) — يكتبه صاحبه من «بياناتي»، و`null` إن لم يُدخله.
  ///
  /// لا يُستخدم للتحقق من الهوية ولا للدخول: مجرد وسيلة تواصل يراها صاحب
  /// الحساب والمسؤول. القواعد تفرض حدوده (8..20 محرفًا رقميًا).
  final String? phone;

  /// المرحلة الدراسية للطالب (P18) — اختيارية، تُستخدم في تخصيص العرض لاحقًا.
  final String? stage;

  /// معرّف الصورة الافتراضية المرسومة (P22) — يُثبَّت عند أول دخول.
  ///
  /// `null` يعني «لم يُثبَّت بعد»، والواجهة تعرض الصورة الحتمية المشتقة من
  /// المعرّف (`AvatarPresets.forId`). لا صورة مخصّصة هنا: تلك تُقرأ من
  /// `avatars/{uid}` عند العرض فقط، حتى لا يُقرأ ~30KB في كل تسجيل دخول.
  final int? avatarPreset;

  /// معرّف الصورة الافتراضية المعروض الآن (يستوعب قيمة قديمة/خارجة عن المدى).
  int get resolvedAvatarPreset => AvatarPresets.normalize(avatarPreset, id);

  /// هل الحساب مجدول للحذف؟
  bool get isPendingDeletion => status == AccountStatus.pendingDeletion;

  /// نسخة بعدّل الحقول الشخصية التي يحرّرها صاحب الحساب.
  ///
  /// لا نكشف `copyWith` عامًا: الدور والادعاء الإداري وحالة الحذف **ليست**
  /// حقولًا يحرّرها المستخدم، وتوقيع صريح يمنع تعديلها بالخطأ.
  AppUser withPersonalInfo({
    required String displayName,
    required String? phone,
    required String? stage,
  }) {
    return AppUser(
      id: id,
      displayName: displayName,
      role: role,
      email: email,
      isDemoAccount: isDemoAccount,
      hasAdminClaim: hasAdminClaim,
      status: status,
      scheduledDeletionAt: scheduledDeletionAt,
      phone: phone,
      stage: stage,
      avatarPreset: avatarPreset,
    );
  }

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
      phone: phone,
      stage: stage,
      avatarPreset: avatarPreset,
    );
  }

  /// نسخة باختيار صورة افتراضية آخر (P22) — يكتبه صاحب الحساب وحده.
  AppUser withAvatarPreset(int preset) {
    return AppUser(
      id: id,
      displayName: displayName,
      role: role,
      email: email,
      isDemoAccount: isDemoAccount,
      hasAdminClaim: hasAdminClaim,
      status: status,
      scheduledDeletionAt: scheduledDeletionAt,
      phone: phone,
      stage: stage,
      avatarPreset: AvatarPresets.normalize(preset, id),
    );
  }

  String get initials {
    final String trimmed = displayName.trim();
    return trimmed.isEmpty ? '؟' : trimmed.substring(0, 1);
  }
}
