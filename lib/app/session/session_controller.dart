import 'package:flutter/foundation.dart';

import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';

/// حالة الجلسة.
enum SessionStatus {
  /// لم تُقرأ الجلسة بعد (شاشة البداية).
  unknown,

  /// لا يوجد مستخدم.
  signedOut,

  /// يوجد مستخدم.
  signedIn,
}

/// إدارة حالة الجلسة والدور على مستوى الواجهة.
///
/// ⚠️ قواعد أمنية مهمة:
/// - الدور هنا **للعرض فقط**. أي قرار صلاحية حقيقي يُفرض في Firestore
///   Rules / Cloud Functions، لا هنا.
/// - الجلسة التجريبية (`startDemoSession`) موجودة حصريًا لمعاينة الواجهات،
///   ومعلَّمة بـ `isDemoAccount`. يجب ألا تُستخدم في أي مسار إنتاجي، ويجب
///   إزالتها/تعطيلها عند ربط المصادقة الحقيقية (Phase 4).
class SessionController extends ChangeNotifier {
  SessionController(this._auth);

  final AuthService _auth;

  SessionStatus _status = SessionStatus.unknown;
  AppUser? _user;

  SessionStatus get status => _status;

  AppUser? get user => _user;

  bool get isSignedIn => _status == SessionStatus.signedIn && _user != null;

  bool get isDemoSession => _user?.isDemoAccount ?? false;

  /// دور المستخدم الحالي؛ يُستخدم لاختيار واجهة (طالب/مدرس) فقط.
  UserRole? get role => _user?.role;

  /// استرجاع الجلسة عند الإقلاع.
  Future<void> restore() async {
    final AppUser? restored = await _auth.restoreSession();
    _user = restored;
    _status = restored == null ? SessionStatus.signedOut : SessionStatus.signedIn;
    notifyListeners();
  }

  /// بدء جلسة معاينة محلية بدور محدد.
  ///
  /// هذه ليست مصادقة ولا تُنشئ حسابًا. موجودة لأن المرحلة 2 لا تحتوي مشروع
  /// Firebase ولا يمكنها اختبار واجهتي الطالب والمدرس بدونه.
  void startDemoSession(UserRole role) {
    assert(role.isEndUser, 'لا يمكن بدء جلسة معاينة بدور إداري.');
    _user = AppUser(
      id: 'demo-${role.name}',
      displayName: role == UserRole.teacher
          ? DemoData.teacherName
          : DemoData.studentName,
      role: role,
      isDemoAccount: true,
    );
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
    _status = SessionStatus.signedOut;
    notifyListeners();
  }
}
