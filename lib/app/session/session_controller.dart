import 'package:flutter/foundation.dart';

import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/features/admin/domain/admin_roles.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';

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

  /// تسجيل الدخول بـGoogle (يفتح واجهة Google عبر Firebase).
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
      case final AuthNeedsRole needsRole:
        _user = null;
        _pendingRole = needsRole;
        _status = SessionStatus.needsRole;
    }
  }
}
