import 'package:flutter/foundation.dart';

import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/features/admin/domain/admin_roles.dart';
import 'package:teacher_student_app/data/models/account_status.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';
import 'package:teacher_student_app/data/validation/account_deletion_rules.dart';

/// حالة الجلسة.
enum SessionStatus {
  /// لم تُقرأ الجلسة بعد (شاشة البداية).
  unknown,

  /// لا يوجد مستخدم.
  signedOut,

  /// الحساب مسجّل لكنه لم يختر دوره بعد (أول دخول).
  needsRole,

  /// يوجد مستخدم بدور معروف.
  signedIn,

  /// الحساب مجدول للحذف (P17): لا يدخل التطبيق، بل شاشة الاستعادة.
  pendingDeletion,
}

/// إدارة حالة الجلسة والدور على مستوى الواجهة.
///
/// ⚠️ قواعد أمنية مهمة:
/// - الدور هنا **للعرض فقط**. أي قرار صلاحية حقيقي يُفرض في Firestore
///   Rules / Cloud Functions، لا هنا.
/// - الدور يُختار **مرة واحدة** عند أول دخول ويُحفظ في `users/{uid}`؛
///   التطبيق لا يعرض شاشة الاختيار مرة أخرى بعد ذلك.
/// - الجلسة التجريبية (`startDemoSession`) موجودة حصريًا لمعاينة الواجهات،
///   ومعلَّمة بـ `isDemoAccount`، وتُعطَّل تلقائيًا حين تعمل المصادقة الحقيقية
///   (انظر `AppConfig.isDemoMode`).
class SessionController extends ChangeNotifier {
  SessionController(this._auth);

  final AuthService _auth;

  SessionStatus _status = SessionStatus.unknown;
  AppUser? _user;
  AuthNeedsRole? _pendingRole;

  SessionStatus get status => _status;

  AppUser? get user => _user;

  bool get isSignedIn => _status == SessionStatus.signedIn && _user != null;

  /// هل نحتاج شاشة اختيار الدور؟ (أول دخول بحساب حقيقي)
  bool get needsRoleSelection => _status == SessionStatus.needsRole;

  /// الاسم المعروض في شاشة اختيار الدور (قبل تحديد الدور).
  String? get pendingDisplayName => _pendingRole?.displayName;

  /// بريد الحساب المنتظر اختيار الدور له.
  String? get pendingEmail => _pendingRole?.email;

  bool get isDemoSession => _user?.isDemoAccount ?? false;

  /// هل الحساب الحالي مجدول للحذف؟ (P17)
  bool get isPendingDeletion => _status == SessionStatus.pendingDeletion;

  /// موعد الحذف المجدول للحساب الحالي — `null` في الحساب النشط.
  DateTime? get scheduledDeletionAt => _user?.scheduledDeletionAt;

  /// دور المستخدم الحالي؛ يُستخدم لاختيار واجهة (طالب/مدرس/إدارة) فقط.
  UserRole? get role => _user?.role;

  /// قيمة الادعاء الإداري كما قرأها الخادم (`request.auth.token.admin`).
  bool get hasAdminClaim => _user?.hasAdminClaim ?? false;

  /// هل الجلسة الحالية مسؤولة؟ (P14)
  ///
  /// ⚠️ **للعرض والحراسة فقط.** كل كتابة إدارية تُفحص في `firestore.rules`
  /// عبر `request.auth.token.admin == true`، فلا قيمة أمنية لهذه القيمة هنا.
  bool get isAdmin =>
      AdminRoles.isAdmin(role: role, hasAdminClaim: hasAdminClaim);

  /// استرجاع الجلسة عند الإقلاع.
  Future<void> restore() async {
    final AuthResult? result = await _auth.restoreSession();
    _apply(result);
    notifyListeners();
  }

  /// تسجيل الدخول بـGoogle (قائمة الحسابات الأصلية في النظام ثم Firebase).
  Future<void> signInWithGoogle() async {
    _apply(await _auth.signInWithGoogle());
    notifyListeners();
  }

  /// تسجيل الدخول بالبريد وكلمة المرور.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _apply(await _auth.signInWithEmail(email: email, password: password));
    notifyListeners();
  }

  /// إنشاء حساب جديد بالبريد وكلمة المرور.
  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _apply(
      await _auth.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
    notifyListeners();
  }

  /// حفظ الدور المختار عند أول دخول.
  ///
  /// تُرمى الأخطاء كما هي ([AppException]) لتعرضها الشاشة.
  Future<void> completeRoleSelection(UserRole role) async {
    final AuthNeedsRole? pending = _pendingRole;
    if (pending == null) {
      throw StateError('لا يوجد حساب بانتظار اختيار الدور.');
    }

    final AppUser user = await _auth.assignRole(
      uid: pending.uid,
      displayName: pending.displayName,
      email: pending.email,
      role: role,
    );

    _user = user;
    _pendingRole = null;
    _status = SessionStatus.signedIn;
    notifyListeners();
  }

  /// حفظ الحقول الشخصية (الاسم/الهاتف/المرحلة) ثم تحديث الجلسة.
  ///
  /// الترتيب مقصود: **الكتابة أولًا ثم الحالة**. لو حدّثنا الواجهة قبل نجاح
  /// الكتابة لعرضنا قيمة لم تُحفظ، وهو نفس الخطأ الذي نرفضه في أي شاشة.
  /// تُرمى الأخطاء كما هي لتعرضها الشاشة.
  Future<void> updatePersonalInfo({
    required String displayName,
    String? phone,
    String? stage,
  }) async {
    final AppUser? current = _user;
    if (current == null) {
      throw StateError('لا توجد جلسة نشطة.');
    }

    final String name = displayName.trim();
    await _auth.updateProfile(
      uid: current.id,
      displayName: name,
      phone: phone,
      stage: stage,
    );

    _user = current.withPersonalInfo(
      displayName: name,
      phone: (phone ?? '').trim().isEmpty ? null : phone!.trim(),
      stage: (stage ?? '').trim().isEmpty ? null : stage!.trim(),
    );
    notifyListeners();
  }

  /// بدء جلسة معاينة محلية بدور محدد (طالب/مدرس/إدارة).
  ///
  /// هذه ليست مصادقة ولا تُنشئ حسابًا؛ معطّلة عندما تعمل المصادقة الحقيقية.
  ///
  /// جلسة الإدارة (P14) **معاينة فقط**: تُعلَّم بأنها تجريبية وتحمل
  /// `hasAdminClaim == true` محليًا حتى تُعرض لوحة الإدارة في الاختبارات
  /// والمعاينة. لا تمنح أي صلاحية على خادم حقيقي — القواعد تقرأ رمز الهوية،
  /// لا حالة الجلسة هنا.
  void startDemoSession(UserRole role) {
    _user = AppUser(
      id: 'demo-${role.name}',
      displayName: switch (role) {
        UserRole.teacher => DemoData.teacherName,
        UserRole.admin => DemoData.adminName,
        UserRole.student => DemoData.studentName,
      },
      role: role,
      isDemoAccount: true,
      hasAdminClaim: role == UserRole.admin,
    );
    _pendingRole = null;
    _status = SessionStatus.signedIn;
    notifyListeners();
  }

  /// تبديل واجهة المعاينة بين طالب ومدرس (متاح في الوضع التجريبي فقط).
  void switchDemoRole(UserRole role) {
    if (!isDemoSession) {
      return;
    }
    startDemoSession(role);
  }

  /// طلب حذف الحساب (حذف ناعم) ثم إنهاء الجلسة — P17.
  ///
  /// الترتيب مقصود: الكتابة أولًا، والخروج بعد نجاحها فقط. لو خرجنا أولًا ثم
  /// فشلت الكتابة لبقي المستخدم خارج التطبيق وهو يظن أن طلبه سُجّل.
  ///
  /// يعيد موعد الحذف المجدول لعرضه في رسالة التأكيد، أو `null` إن لم تكن هناك
  /// جلسة. الجلسة التجريبية تُعالج محليًا (لا مستند Firestore) وتُعلِم
  /// المستخدم بأن الأثر محلي فقط.
  Future<DateTime?> requestAccountDeletion() async {
    final AppUser? user = _user;
    if (user == null) {
      return null;
    }

    final DateTime scheduledAt = user.isDemoAccount
        ? AccountDeletionRules.scheduledAt(DateTime.now())
        : await _auth.requestAccountDeletion(uid: user.id);

    await signOut();
    return scheduledAt;
  }

  /// استعادة الحساب المجدول للحذف (داخل مهلة السماح) — P17.
  ///
  /// بعد النجاح يصبح الحساب نشطًا وتدخل الجلسة الحالة `signedIn` مباشرة، فلا
  /// يحتاج المستخدم إلى تسجيل دخول آخر.
  Future<void> restoreAccount() async {
    final AppUser? user = _user;
    if (user == null || !user.isPendingDeletion) {
      throw StateError('لا يوجد حساب مجدول للحذف.');
    }

    if (!user.isDemoAccount) {
      await _auth.restoreAccount(uid: user.id);
    }

    _user = user.withAccountStatus(AccountStatus.active);
    _status = SessionStatus.signedIn;
    notifyListeners();
  }

  /// إنهاء الجلسة.
  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _pendingRole = null;
    _status = SessionStatus.signedOut;
    notifyListeners();
  }

  void _apply(AuthResult? result) {
    switch (result) {
      case null:
        _user = null;
        _pendingRole = null;
        _status = SessionStatus.signedOut;
      case AuthSignedIn(:final AppUser user):
        _user = user;
        _pendingRole = null;
        _status = SessionStatus.signedIn;
      case AuthPendingDeletion(:final AppUser user):
        // نُيبقي المستخدم في الجلسة لأن شاشة الاستعادة تحتاجه، لكن الحالة
        // ليست `signedIn`: لا هيكل ولا تبويبات ولا وصول للبيانات.
        _user = user;
        _pendingRole = null;
        _status = SessionStatus.pendingDeletion;
      case final AuthNeedsRole needsRole:
        _user = null;
        _pendingRole = needsRole;
        _status = SessionStatus.needsRole;
    }
  }
}
