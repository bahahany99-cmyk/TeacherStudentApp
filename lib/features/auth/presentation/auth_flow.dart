import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';

/// الوجهة بعد أي مصادقة ناجحة.
///
/// المستخدم الجديد (بلا دور) يذهب إلى شاشة اختيار الدور، والحساب المعروف
/// يدخل الهيكل مباشرة. نضعها في مكان واحد حتى لا تختلف وجهة التسجيل عن
/// وجهة الدخول أو الدخول عبر Google.
Future<void> continueAfterAuth(
  BuildContext context,
  SessionController session,
) {
  final String target = session.needsRoleSelection
      ? RoutePaths.roleSelection
      : RoutePaths.shell;

  return Navigator.of(context).pushNamedAndRemoveUntil(
    target,
    (Route<dynamic> route) => false,
  );
}
