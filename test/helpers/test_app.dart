import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/app.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/data/services/app_services.dart';

/// مقاس هاتف واقعي للاختبارات (360×720 منطقيًا) بدلًا من 800×600 الافتراضي،
/// حتى تظهر مشاكل التخطيط التي تظهر على الهواتف فعلًا.
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2160);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// يبني التطبيق كاملًا ببيانات تجريبية (لا Firebase) للاختبار.
///
/// [services] اختيارية: بعض الاختبارات تحتاج تجهيز الحزمة قبل البناء (مثل
/// رفع صورة حساب قبل حفظ ملف مدرس، P22).
Widget buildTestApp({AppServices? services}) {
  final AppServices resolved = services ?? AppServices.demo();
  final SessionController session = SessionController(
    resolved.auth,
    avatars: resolved.avatars,
  );
  return TeacherStudentApp(services: resolved, session: session);
}

/// يضغط عنصرًا بعد التأكد من ظهوره داخل منطقة العرض (مع تمرير إن لزم).
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
