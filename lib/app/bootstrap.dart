import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // ── Edge-to-Edge حقيقي (نسخة 3) ────────────────────────────────────────────
  // المشكلة المرصودة على الجهاز: شريط أسود أعلى الشاشة في «التطبيقات الحديثة»
  // وفي أعلى الصفحة. سببه أن شريط الحالة يُرسم بلون النظام الافتراضي (أسود)
  // خلف واجهتنا الفاتحة.
  //
  // الحل: وضع `edgeToEdge` (المحتوى يمتد خلف شريطي الحالة والتنقّل) + خلفيتان
  // شفافتان + أيقونات داكنة (لأن خلفيتنا فاتحة). الحشو الآمن يبقى مسؤولية
  // `SafeArea` داخل الشاشات، فتظل النصوص بعيدة عن النوتش.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // أندرويد
      statusBarBrightness: Brightness.light, // iOS
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      // يمنع النظام من إضافة طبقة تعتيم على شريط التنقّل فوق تدرّجنا.
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ),
  );

  await FirebaseBootstrap.initialize();

  // المصادقة الحقيقية إن كان Firebase جاهزًا، وإلا الحزمة التجريبية.
  final AppServices services = AppServices.bootstrap();
  final SessionController session = SessionController(services.auth);
  await session.restore();

  runApp(TeacherStudentApp(services: services, session: session));
}
