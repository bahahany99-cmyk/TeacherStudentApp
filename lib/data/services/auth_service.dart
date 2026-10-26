import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/user_role.dart';

/// عقد خدمة المصادقة.
///
/// التنفيذ الحقيقي (Phase 4) سيستخدم:
/// - `firebase_auth` مع `GoogleAuthProvider`
/// - `google_sign_in` للحصول على idToken
/// - قراءة مستند المستخدم من Firestore لمعرفة الدور
///
/// الدور القادم من الخادم هو المرجع الوحيد؛ لا يختاره المستخدم بحرية.
abstract interface class AuthService {
  /// استرجاع الجلسة الحالية (أو null إن لم يوجد مستخدم مسجّل).
  Future<AppUser?> restoreSession();

  /// تسجيل الخروج.
  Future<void> signOut();

  /// بدء تسجيل الدخول عبر Google.
  ///
  /// غير منفّذ في المرحلة 2.
  Future<AppUser> signInWithGoogle(UserRole requestedRole);
}
