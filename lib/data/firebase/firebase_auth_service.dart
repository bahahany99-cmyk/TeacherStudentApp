import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/errors/firebase_error_mapper.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';

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
/// }
/// ```
/// ⚠️ الحقول أعلاه هي **كل** ما يكتبه التطبيق. أي حقل إداري (approved،
/// isFeatured، isAdmin…) لا يُكتب من التطبيق إطلاقًا.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String usersCollection = 'users';

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
    await _auth.signOut();
  }

  @override
  Future<AuthResult> signInWithGoogle() {
    return _guard(() async {
      final UserCredential credential = await _auth.signInWithProvider(
        GoogleAuthProvider(),
      );
      final User? user = credential.user;
      if (user == null) {
        throw AppException(
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
          return AppUser(
            id: uid,
            displayName: displayName,
            role: stored,
            email: email,
          );
        }
      }

      await doc.set(<String, Object?>{
        'displayName': displayName,
        'email': email,
        'role': role.name,
        'createdAt': existing.exists
            ? (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp())
            : FieldValue.serverTimestamp(),
        'roleChosenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return AppUser(
        id: uid,
        displayName: displayName,
        role: role,
        email: email,
      );
    } on FirebaseException catch (error) {
      throw firebaseCodeToException(error.code, debugMessage: error.message);
    }
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

    return AuthSignedIn(
      AppUser(
        id: user.uid,
        displayName: displayName,
        role: role,
        email: user.email,
      ),
    );
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
