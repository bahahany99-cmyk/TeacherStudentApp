import 'package:flutter/widgets.dart';

import 'package:teacher_student_app/app/app.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/data/services/app_services.dart';

/// يبني التطبيق كاملًا ببيانات تجريبية (لا Firebase) للاختبار.
Widget buildTestApp() {
  final AppServices services = AppServices.demo();
  final SessionController session = SessionController(services.auth);
  return TeacherStudentApp(services: services, session: session);
}
