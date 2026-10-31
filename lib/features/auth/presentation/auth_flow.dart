import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';

/// الوجهة بعد أي مصادقة ناجحة.
///
/// المستخدم الجديد (بلا دور) يذهب إلى شاشة اختيار الدور، والحساب المعروف
/// يدخل الهيكل مباشرة، والحساب المجدول للحذف يذهب إلى شاشة الاستعادة (P17).
/// نضعها في مكان واحد حتى لا تختلف وجهة التسجيل عن وجهة الدخول أو الدخول
/// عبر Google.
Future<void> continueAfterAuth(
  BuildContext context,
  SessionController session,
) {
  final String target = switch (session.status) {
    SessionStatus.pendingDeletion => RoutePaths.accountRestore,
    SessionStatus.needsRole => RoutePaths.roleSelection,
    _ => RoutePaths.shell,
  };

  return Navigator.of(context).pushNamedAndRemoveUntil(
    target,
    (Route<dynamic> route) => false,
  );
}
