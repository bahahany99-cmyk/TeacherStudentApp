import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/app.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/core/config/firebase_bootstrap.dart';
import 'package:teacher_student_app/data/services/app_services.dart';

/// تسلسل الإقلاع الموحّد:
/// 1) تهيئة Flutter.
/// 2) محاولة تهيئة Firebase (تُتجاهل بأمان إن لم يكن المشروع معدًّا).
/// 3) بناء حزمة الخدمات (تجريبية في هذه المرحلة).
/// 4) استرجاع الجلسة قبل الرسم (لتجنب وميض الشاشات).
/// 5) التشغيل.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseBootstrap.initialize();

  final AppServices services = AppServices.demo();
  final SessionController session = SessionController(services.auth);
  await session.restore();

  runApp(TeacherStudentApp(services: services, session: session));
}
