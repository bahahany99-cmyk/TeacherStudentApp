import 'package:flutter/widgets.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';

/// (P18) أَدوات جلسة للاختبارات — لازمة بعد أن صار `DemoBanner` **متحققًا
/// ذاتيًا** من الجلسة.
///
/// قبل ذلك كان يكفي `pumpWidget(DemoBanner())` لرؤية الشريحة. الآن الشريحة
/// تُعرض فقط في جلسة تجريبية حقيقية، فالاختبارات التي تقيس شكلها تحتاج جلسة
/// تجريبية، واختبارات «الحساب الحقيقي» تحتاج جلسة بلا `isDemoAccount`.
///
/// ⚠️ لا نستخدم `firebase_auth` هنا إطلاقًا: الجلسة تُبنى من خدمة مصادقة
/// مزيّفة، فتبقى الاختبارات سريعة وبلا خادم.

/// خدمة مصادقة مزيّفة تُعيد مستخدمًا **حقيقيًا** (غير تجريبي) عند الاسترجاع.
class _RealSessionAuthService implements AuthService {
  const _RealSessionAuthService({
    this.user = const AppUser(
      id: 'uid-real',
      displayName: 'مستخدم حقيقي',
      role: UserRole.student,
      email: 'real@example.com',
    ),
  });

  final AppUser user;

  @override
  Future<AuthResult?> restoreSession() async => AuthSignedIn(user);

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResult> signInWithGoogle() async => AuthSignedIn(user);

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async => AuthSignedIn(user);

  @override
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async => AuthSignedIn(user);

  @override
  Future<DateTime> requestAccountDeletion({required String uid}) async =>
      DateTime.now().add(const Duration(days: 7));

  @override
  Future<void> restoreAccount({required String uid}) async {}

  @override
  Future<AppUser> assignRole({
    required String uid,
    required String displayName,
    required UserRole role,
    String? email,
  }) async => user;
}

/// جلسة **تجريبية** (زائر) جاهزة للمزامنة — تُستدعى بلا `await`.
SessionController demoSession({UserRole role = UserRole.student}) {
  final SessionController session = SessionController(
    const _RealSessionAuthService(),
  );
  session.startDemoSession(role);
  return session;
}

/// جلسة **حقيقية** مسجّلة الدخول، لكن `isDemoAccount == false`.
Future<SessionController> realSession({
  UserRole role = UserRole.student,
}) async {
  final SessionController session = SessionController(
    _RealSessionAuthService(
      user: AppUser(
        id: 'uid-real',
        displayName: 'مستخدم حقيقي',
        role: role,
        email: 'real@example.com',
      ),
    ),
  );
  await session.restore();
  return session;
}

/// جلسة بلا تسجيل دخول (مجهولة).
SessionController signedOutSession() =>
    SessionController(const _RealSessionAuthService());

/// يلفّ [child] بنطاق جلسة، فيصبح قادرًا على قراءة `isDemoSession`.
Widget withSession(SessionController session, {required Widget child}) {
  return SessionScope(controller: session, child: child);
}
