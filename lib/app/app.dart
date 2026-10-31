import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:teacher_student_app/app/router/app_router.dart';
import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/config/app_identity.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/app_background.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// جذر التطبيق: اللغة، الاتجاه (RTL)، الثيم، التنقل، وحدود طبقة الخدمات.
class TeacherStudentApp extends StatelessWidget {
  const TeacherStudentApp({
    super.key,
    required this.services,
    required this.session,
  });

  final AppServices services;
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return AppServicesScope(
      services: services,
      child: SessionScope(
        controller: session,
        child: MaterialApp(
          title: AppIdentity.displayName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          // العربية هي اللغة الوحيدة في الإصدار الأول → اتجاه RTL تلقائيًا.
          locale: const Locale('ar', 'EG'),
          supportedLocales: const <Locale>[Locale('ar', 'EG'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          onGenerateRoute: AppRouter.onGenerateRoute,
          initialRoute: RoutePaths.splash,
          builder: (BuildContext context, Widget? child) {
            // 1) خلفية التدرّج **العالمية** (نسخة 3): تُرسم مرة واحدة خلف كل
            //    المسارات، والـScaffolds شفافة — فلا تحتاج كل شاشة إلى نسخ
            //    الخلفية، ولا يظهر شريط أسود أعلى أي شاشة (Edge-to-Edge).
            // 2) تأكيد الاتجاه حتى لو تغيّر مصدر اللغة مستقبلًا.
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AppBackground(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        ),
      ),
    );
  }
}
