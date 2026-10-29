import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/user_role.dart';

/// عقد خدمة المصادقة.
///
/// التنفيذ الحقيقي (`FirebaseAuthService`) يستخدم:
/// - `google_sign_in` (SDK أصلي) للحصول على `idToken` من Google
/// - `firebase_auth` للبريد/كلمة المرور، ولتبديل بيانات اعتماد Google
///   بـ`signInWithCredential` (P18)
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
  /// يفتح قائمة الحسابات المدمجة في النظام عبر `google_sign_in` (SDK أصلي)
  /// ثم يمرّر `idToken` إلى Firebase؛ لا نطلب كلمة مرور Google أبدًا داخل
  /// التطبيق، ولا نفتح متصفحًا.
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

  /// طلب حذف الحساب (حذف ناعم) — P17.
  ///
  /// يكتب `status = 'pending_deletion'` و`scheduledDeletionAt` (بعد 7 أيام) في
  /// `users/{uid}`، ويعيد الموعد الذي حُفظ فعلًا. لا يحذف شيئًا ولا يُنهي
  /// الجلسة: مناديه (`SessionController`) هو من يسجّل الخروج بعد نجاح الكتابة،
  /// حتى لا يخرج المستخدم بلا سبب إن فشلت العملية.
  Future<DateTime> requestAccountDeletion({required String uid});

  /// استعادة حساب مجدول للحذف **داخل** مهلة السماح — P17.
  ///
  /// يعيد الحالة `active` ويحذف موعد الحذف. القاعدة على الخادم ترفض الاستعادة
  /// بعد انتهاء المهلة، فلا تعتمد على الساعة المحلية وحدها.
  Future<void> restoreAccount({required String uid});

  /// تحديث الحقول الشخصية التي يحرّرها صاحب الحساب (P18): الاسم الظاهر،
  /// الهاتف، المرحلة.
  ///
  /// يكتب في `users/{uid}` **فقط**، ولا يمسّ الدور أو حالة الحذف (القواعد
  /// ترفض أي تغيير فيهما، و`AppUser.withPersonalInfo` لا يملكهما أصلًا).
  /// لا يعيد شيئًا: الجلسة تُحدَّث محليًا بنفس القيم المدخلة، فلا نخترع دورًا
  /// أو حالة من عندنا (الدور والحالة يملكهما الخادم وحده).
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    String? phone,
    String? stage,
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
