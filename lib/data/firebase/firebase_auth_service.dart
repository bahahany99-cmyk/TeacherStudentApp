import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/errors/firebase_error_mapper.dart';
import 'package:teacher_student_app/data/models/account_status.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/firebase/google_sign_in_gateway.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';
import 'package:teacher_student_app/data/validation/account_deletion_rules.dart';

/// تنفيذ المصادقة بـ Firebase.
///
/// يُنشأ فقط بعد نجاح `FirebaseBootstrap.initialize()`، لذلك لا يلمس
/// `FirebaseAuth.instance` في الوضع التجريبي.
///
/// مستند المستخدم: `users/{uid}`
/// ```
/// {
///   displayName: String,
///   email: String?,
///   role: 'student' | 'teacher',
///   createdAt: Timestamp,
///   roleChosenAt: Timestamp,
///   status: 'active' | 'pending_deletion',   // P17 — غيابه يعني active
///   scheduledDeletionAt: Timestamp,          // P17 — مع pending_deletion فقط
/// }
/// ```
/// وعند اختيار الدور «مدرس» يُنشأ أيضًا `teacherProfiles/{uid}`:
/// ```
/// {
///   ownerId: uid,
///   displayName: String,
///   status: 'draft',   // لا يصبح 'verified' إلا بقرار إداري
///   createdAt: Timestamp,
/// }
/// ```
/// ⚠️ الحقول أعلاه هي **كل** ما يكتبه التطبيق. لا يكتب `verified` ولا
/// `isFeatured` ولا `isAdmin`؛ تغيير الحالة الإدارية خارج التطبيق تمامًا.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleIdTokenProvider? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn ?? GoogleSignInGateway();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// مصدر `idToken` من Google — يُحقن في الاختبارات، ويُستخدم التنفيذ الأصلي
  /// افتراضيًا (P18).
  final GoogleIdTokenProvider _googleSignIn;

  static const String usersCollection = 'users';

  /// حقل حالة الحساب (P17) — `active` أو `pending_deletion`.
  static const String statusField = 'status';

  /// حقل موعد الحذف المجدول (P17) — `Timestamp` في القاعدة.
  static const String scheduledDeletionField = 'scheduledDeletionAt';

  /// علم إخفاء ملف المدرس عند حذف الحساب (P17) — على `teacherProfiles/{uid}`.
  ///
  /// يُكتب في **نفس** حزمة الكتابة مع حالة الحساب، فلا توجد لحظة يظهر فيها ملف
  /// مدرس محذوفًا في البحث. القواعد تقرأه من الملف نفسه (لا من `users`، لأن
  /// `get()` على مستند غائب في القواعد خطأ لا `false`).
  static const String accountHiddenField = 'accountHidden';

  /// ملفات المدرسين. يُنشأ المستند تلقائيًا بحالة `pendingReview` عند اختيار
  /// الدور «مدرس» (قرار صاحب المشروع 2026-10-27).
  static const String teacherProfilesCollection = 'teacherProfiles';

  @override
  Future<AuthResult?> restoreSession() async {
    final User? current = _auth.currentUser;
    if (current == null) {
      return null;
    }
    return _guard(() => _resolve(current));
  }

  @override
  Future<void> signOut() async {
    // الخروج من Google أولًا (لا يرمي) ثم من Firebase: حتى لا تعود قائمة
    // الحسابات إلى الحساب السابق عند الدخول التالي.
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// تسجيل الدخول بـGoogle عبر الـSDK الأصلي (P18).
  ///
  /// المسار: قائمة حسابات Google المدمجة ← `idToken` ←
  /// `GoogleAuthProvider.credential` ← `signInWithCredential`.
  ///
  /// لماذا تغيّر هذا؟ `signInWithProvider` يفتح متصفحًا/redirect، وكان يفشل
  /// على أندرويد برسالة «لا يوجد اتصال بالإنترنت» رغم وجود شبكة.
  @override
  Future<AuthResult> signInWithGoogle() {
    return _guard(() async {
      final String idToken = await _googleSignIn.obtainIdToken();
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );
      final UserCredential credentialResult = await _auth.signInWithCredential(
        credential,
      );
      final User? user = credentialResult.user;
      if (user == null) {
        throw const AppException(
          AppErrorKind.unknown,
          debugMessage: 'Google sign-in returned no user',
        );
      }
      return _resolve(user);
    });
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _guard(() async {
      final UserCredential credential = await _auth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
      final User? user = credential.user;
      if (user == null) {
        throw const AppException(
          AppErrorKind.unknown,
          debugMessage: 'email sign-in returned no user',
        );
      }
      return _resolve(user);
    });
  }

  @override
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _guard(() async {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
      final User? user = credential.user;
      if (user == null) {
        throw const AppException(
          AppErrorKind.unknown,
          debugMessage: 'register returned no user',
        );
      }

      final String trimmed = displayName.trim();
      if (trimmed.isNotEmpty) {
        await user.updateDisplayName(trimmed);
      }

      // لا نكتب الدور هنا: يُكتب مرة واحدة بعد اختيار المستخدم في شاشة
      // اختيار الدور (assignRole).
      return AuthNeedsRole(
        uid: user.uid,
        displayName: trimmed.isEmpty
            ? (user.displayName ?? 'مستخدم جديد')
            : trimmed,
        email: user.email,
      );
    });
  }

  @override
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    String? phone,
    String? stage,
  }) async {
    final String name = displayName.trim();
    final String? cleanPhone = _clean(phone);
    final String? cleanStage = _clean(stage);

    try {
      // `update` لا `set`: المستند موجود بحكم أن المستخدم مسجّل ومعه دور،
      // و`update` يفشل بوضوح لو اختفى المستند بدل أن ينشئ مستندًا بلا دور.
      await _firestore.collection(usersCollection).doc(uid).update(
        <String, Object?>{
          'displayName': name,
          // الحذف لا `null`: القاعدة تقرأ الحقول المسموحة فقط، والحقل الفارغ
          // يجب أن يختفي بدل أن يُخزَّن كـnull في كل قراءة.
          'phone': cleanPhone ?? FieldValue.delete(),
          'stage': cleanStage ?? FieldValue.delete(),
        },
      );
    } on FirebaseException catch (error) {
      throw firebaseCodeToException(error.code, debugMessage: error.message);
    }
  }

  String? _clean(String? value) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }

  @override
  Future<DateTime> requestAccountDeletion({required String uid}) async {
    final DocumentReference<Map<String, dynamic>> doc = _firestore
        .collection(usersCollection)
        .doc(uid);

    // الموعد يُحسب على العميل لأن القواعد تحدّده بسقف (7 أيام + هامش ساعة
    // للفروق بين ساعة الجهاز وساعة الخادم) وترفض ما يخرج عنه.
    final DateTime scheduledAt = AccountDeletionRules.scheduledAt(
      DateTime.now(),
    );

    try {
      final DocumentSnapshot<Map<String, dynamic>> existing = await doc.get();
      if (existing.data()?['role'] == null) {
        // حذف حساب لم يكتمل إعداده يترك مستندًا بلا دور؛ شاشة الحساب لا تُفتح
        // أصلًا قبل اختيار الدور، لكن نمنعه صراحةً لا اعتمادًا على المسار.
        throw const AppException(
          AppErrorKind.invalidInput,
          debugMessage: 'cannot delete an account without a role',
          overrideTitle: 'الحساب غير مكتمل',
          overrideMessage: 'أكمل اختيار نوع الحساب قبل طلب الحذف.',
        );
      }

      final WriteBatch batch = _firestore.batch();
      batch.update(doc, <String, Object?>{
        statusField: AccountStatus.pendingDeletionWire,
        scheduledDeletionField: scheduledAt,
      });

      // المدرس: إخفاء الملف في نفس الحزمة الذرّية. غياب الملف ليس خطأً —
      // الحساب قد يكون طالبًا، أو مدرسًا لم يُنشأ ملفه بعد.
      final DocumentReference<Map<String, dynamic>> teacherProfile =
          _firestore.collection(teacherProfilesCollection).doc(uid);
      if ((await teacherProfile.get()).exists) {
        batch.update(teacherProfile, <String, Object?>{
          accountHiddenField: true,
        });
      }

      await batch.commit();
      return scheduledAt;
    } on FirebaseException catch (error) {
      throw firebaseCodeToException(error.code, debugMessage: error.message);
    }
  }

  @override
  Future<void> restoreAccount({required String uid}) async {
    try {
      final WriteBatch batch = _firestore.batch();
      batch.update(
        _firestore.collection(usersCollection).doc(uid),
        <String, Object?>{
          statusField: AccountStatus.activeWire,
          // الحذف (لا `null`) حتى يختفي الحقل: القاعدة ترفض بقاءه مع `active`.
          scheduledDeletionField: FieldValue.delete(),
        },
      );

      // إعادة الملف إلى الاكتشاف في نفس الحزمة (المدرس وحده له ملف).
      final DocumentReference<Map<String, dynamic>> teacherProfile =
          _firestore.collection(teacherProfilesCollection).doc(uid);
      if ((await teacherProfile.get()).exists) {
        // `false` لا حذفًا للحقل: الاستعلام يفلتر `accountHidden == false`،
        // فمستند بلا الحقل لا يعود في نتائج الاكتشاف.
        batch.update(teacherProfile, <String, Object?>{
          accountHiddenField: false,
        });
      }

      await batch.commit();
    } on FirebaseException catch (error) {
      throw firebaseCodeToException(error.code, debugMessage: error.message);
    }
  }

  @override
  Future<AppUser> assignRole({
    required String uid,
    required String displayName,
    required UserRole role,
    String? email,
  }) async {
    if (!role.isEndUser) {
      // الدور الإداري لا يُمنح من التطبيق؛ يُضاف يدويًا/بأداة إدارية.
      throw const AppException(
        AppErrorKind.permission,
        debugMessage: 'admin role cannot be self-assigned',
        overrideTitle: 'الدور غير متاح',
        overrideMessage: 'الدور الإداري لا يُختار من التطبيق.',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> doc = _firestore
          .collection(usersCollection)
          .doc(uid);

      final DocumentSnapshot<Map<String, dynamic>> existing = await doc.get();
      final Object? existingRole = existing.data()?['role'];

      if (existingRole is String && existingRole.isNotEmpty) {
        // الدور محفوظ مسبقًا: نقرأه ولا نغيّره. تغييره يحتاج إجراءً إداريًا.
        final UserRole? stored = _roleFrom(existingRole);
        if (stored != null) {
          final Object? preset = existing.data()?['avatarPreset'];
          return AppUser(
            id: uid,
            displayName: displayName,
            role: stored,
            email: email,
            avatarPreset: preset is int ? preset : null,
          );
        }
      }

      final WriteBatch batch = _firestore.batch();

      // (P22) صورة افتراضية عند إنشاء الحساب: الحساب لا يُنشأ بصورة فارغة.
      // نكتبها **مرة واحدة** فقط: لو اختار المستخدم صورة أخرى لاحقًا فلا
      // نُعيد ضبطها عند أي نداء تالٍ لاختيار الدور.
      final Object? storedPreset = existing.data()?['avatarPreset'];

      batch.set(doc, <String, Object?>{
        'displayName': displayName,
        'email': email,
        'role': role.name,
        if (storedPreset == null) 'avatarPreset': AvatarPresets.forId(uid),
        'createdAt': existing.exists
            ? (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp())
            : FieldValue.serverTimestamp(),
        'roleChosenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (role == UserRole.teacher) {
        await _ensureTeacherProfile(
          batch: batch,
          uid: uid,
          displayName: displayName,
        );
      }

      await batch.commit();

      return AppUser(
        id: uid,
        displayName: displayName,
        role: role,
        email: email,
        avatarPreset: storedPreset is int
            ? storedPreset
            : AvatarPresets.forId(uid),
      );
    } on FirebaseException catch (error) {
      throw firebaseCodeToException(error.code, debugMessage: error.message);
    }
  }


  /// ينشئ ملف المدرس إن لم يكن موجودًا، بحالة `draft` فقط.
  ///
  /// (P22) `draft` لا `pendingReview`: اختيار الدور «مدرس» لا يعني أن الملف
  /// جاهز — الصورة والنبذة والمادة لم تُكتب بعد، والقواعد ترفض إرسال ملف
  /// للمراجعة بلا صورة. الإرسال الفعلي يحدث عند أول حفظ للنموذج
  /// (`saveMyProfile`) حيث توجد الصورة.
  ///
  /// - لا نلمس ملفًا موجودًا: لو كان معتمدًا سابقًا (أو مرفوضًا) فالحالة قرار
  ///   إداري لا يُعاد ضبطه من التطبيق.
  /// - الحقول الوصفية (المادة/المرحلة/النبذة) يكمّلها المدرس من «ملفي»؛
  ///   نكتب الاسم فقط حتى لا نخترع بيانات.
  Future<void> _ensureTeacherProfile({
    required WriteBatch batch,
    required String uid,
    required String displayName,
  }) async {
    final DocumentReference<Map<String, dynamic>> profile = _firestore
        .collection(teacherProfilesCollection)
        .doc(uid);

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await profile.get();
    if (snapshot.exists) {
      return;
    }

    batch.set(profile, <String, Object?>{
      'ownerId': uid,
      'displayName': displayName,
      'status': TeacherProfileStatus.draft.wireValue,
      // (P17) الحقل موجود منذ الإنشاء: استعلامات الاكتشاف تفلتر عليه، ومستند
      // بلا الحقل لا يظهر في `where(accountHidden == false)`.
      accountHiddenField: false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// يقرأ الدور من `users/{uid}`؛ إن لم يوجد فالحساب يحتاج اختيار الدور.
  Future<AuthResult> _resolve(User user) async {
    String displayName = user.displayName ?? '';
    if (displayName.trim().isEmpty) {
      final String email = user.email ?? '';
      displayName = email.contains('@') ? email.split('@').first : 'مستخدم';
    }

    final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
        .collection(usersCollection)
        .doc(user.uid)
        .get();

    final Object? rawRole = doc.data()?['role'];
    final UserRole? role = _roleFrom(rawRole);

    if (role == null) {
      return AuthNeedsRole(
        uid: user.uid,
        displayName: displayName,
        email: user.email,
      );
    }

    final AccountStatus status = AccountStatus.fromWire(
      doc.data()?[statusField],
    );
    final DateTime? scheduledDeletionAt = _dateFrom(
      doc.data()?[scheduledDeletionField],
    );

    // (P22) الصورة الافتراضية: قيمة قديمة/غير رقمية تُتجاهل وتُشتق من
    // المعرّف، فلا ينكسر الحساب بسبب حقل عرض واحد.
    final Object? rawPreset = doc.data()?['avatarPreset'];

    final AppUser resolved = AppUser(
      id: user.uid,
      displayName: displayName,
      role: role,
      email: user.email,
      hasAdminClaim: await _readAdminClaim(user),
      status: status,
      scheduledDeletionAt: scheduledDeletionAt,
      // (P18) الحقول الشخصية الاختيارية: القراءة متسامحة — مستند قديم بلا
      // الحقلين يعمل كما هو، فلا حاجة إلى ترحيل بيانات.
      phone: _clean(doc.data()?['phone'] as String?),
      stage: _clean(doc.data()?['stage'] as String?),
      avatarPreset: rawPreset is int ? rawPreset : null,
    );

    // حساب مجدول للحذف لا يدخل التطبيق: يُوجَّه إلى شاشة الاستعادة.
    return status == AccountStatus.pendingDeletion
        ? AuthPendingDeletion(resolved)
        : AuthSignedIn(resolved);
  }

  /// يقرأ الادعاء الإداري من رمز الهوية (P14).
  ///
  /// `getIdTokenResult()` يحدّث الرمز إن لزم، وقد يفشل بلا شبكة؛ في هذه الحالة
  /// نعيد `false` بدل إفشال تسجيل الدخول: أسوأ ما يحدث أن تُخفى لوحة الإدارة
  /// حتى إعادة المحاولة، والقواعد تبقى الحكم النهائي على الخادم.
  Future<bool> _readAdminClaim(User user) async {
    try {
      final IdTokenResult token = await user.getIdTokenResult();
      // `claims` نوعها يختلف بين إصدارات firebase_auth (قابلة للعدم أو لا)،
      // فنقرؤها كـ`Object?` ثم نضيّقها — بلا `?.` ولا تحذير ثابت.
      final Object? claims = token.claims;
      if (claims is Map) {
        return claims['admin'] == true;
      }
      return false;
    } on Object {
      return false;
    }
  }

  /// يحوّل قيمة حقل تاريخ إلى `DateTime` بصرف النظر عن نوعها القادم.
  ///
  /// `cloud_firestore` يعيد `Timestamp`، والبيانات التجريبية/الاختبارات تستخدم
  /// `DateTime` مباشرة. أي نوع آخر ⇒ `null` (لا نرمي داخل مسار الدخول).
  DateTime? _dateFrom(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return null;
  }

  UserRole? _roleFrom(Object? raw) {
    for (final UserRole role in UserRole.values) {
      if (role.name == raw) {
        return role;
      }
    }
    return null;
  }

  /// ترميز أخطاء Firebase إلى [AppException] عربية.
  Future<AuthResult> _guard(Future<AuthResult> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      throw firebaseCodeToException(error.code, debugMessage: error.message);
    } on FirebaseException catch (error) {
      throw firebaseCodeToException(error.code, debugMessage: error.message);
    }
  }
}
