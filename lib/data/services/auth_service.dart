import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/user_role.dart';

/// عقد خدمة المصادقة.
///
/// التنفيذ الحقيقي (`FirebaseAuthService`) يستخدم:
/// - `firebase_auth` للبريد/كلمة المرور وGoogle (`signInWithProvider`)
/// - `cloud_firestore` لقراءة `users/{uid}.role` وكتابته مرة واحدة عند الاختيار
///
/// ⚠️ قرار التصميم: الدور **يُقرأ من الخادم** بعد الدخول، ولا يختاره التطبيق
/// في كل مرة. الشاشة التي تختاره تظهر فقط عندما يكون المستند بلا دور.
///
/// كل الأخطاء تُرمى كـ`AppException` برسائل عربية (`firebase_error_mapper`)،
/// فلا تتسرّب رموز Firebase إلى الواجهة.
abstract interface class AuthService {
  /// استرجاع الجلسة الحالية، أو `null` إن لم يوجد مستخدم مسجّل.
  Future<AuthResult?> restoreSession();

  /// تسجيل الخروج (من Firebase أو من الجلسة التجريبية).
  Future<void> signOut();

  /// تسجيل الدخول بحساب Google.
  ///
  /// يفتح واجهة Google الأصلية عبر `signInWithProvider`؛ لا نطلب كلمة مرور
  /// Google أبدًا داخل التطبيق.
  Future<AuthResult> signInWithGoogle();

  /// تسجيل الدخول بالبريد وكلمة المرور.
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  });

  /// إنشاء حساب جديد بالبريد وكلمة المرور.
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  /// حفظ الدور المختار عند أول دخول، وإرجاع المستخدم جاهزًا.
  ///
  /// ⚠️ هذا ليس تصريحًا بالصلاحية: القواعد على الخادم هي ما يمنع تغيير الدور
  /// لاحقًا، وواجهة التطبيق لا تسمح بذلك.
  Future<AppUser> assignRole({
    required String uid,
    required String displayName,
    required UserRole role,
    String? email,
  });
}
