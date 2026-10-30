import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/app.dart';
import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/features/chat/presentation/direct_chat_screen.dart';

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

/// مُولِّد مسار المحادثة للاختبارات التي تبني `MaterialApp` مصغّرة.
///
/// (P24) صار إرسال طلب الانضمام (وكذلك إنشاء الحجز) يفتح المحادثة تلقائيًا،
/// فاختبار يبني شاشة واحدة بلا مُولِّد مسارات كان يفشل بخطأ «لا يوجد مُولِّد
/// للمسار /chat» — وهو عيب في بيئة الاختبار لا في التطبيق، لأن المسار موجود
/// في `AppRouter`. نُمرّره في `onGenerateRoute` بدل تكراره في كل ملف.
Route<dynamic>? chatRouteForTests(RouteSettings settings) {
  if (settings.name == RoutePaths.directChat) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          DirectChatScreen(chatId: settings.arguments! as String),
    );
  }
  return null;
}

/// يضغط عنصرًا بعد التأكد من ظهوره داخل منطقة العرض (مع تمرير إن لزم).
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
