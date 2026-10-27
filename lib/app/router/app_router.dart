import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/shell/app_shell.dart';
import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/features/auth/presentation/login_screen.dart';
import 'package:teacher_student_app/features/design_gallery/presentation/design_gallery_screen.dart';
import 'package:teacher_student_app/features/splash/presentation/splash_screen.dart';

/// موجّه التنقل المركزي.
///
/// كل شاشة تُسجَّل هنا فقط؛ لا يوجد `Navigator.push` بنوع شاشة مباشر في
/// الشاشات (إلا للانتقال بالاسم)، ما يسمح بتغيير التنقل لاحقًا من مكان واحد.
abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RoutePaths.splash:
        return _page(const SplashScreen(), settings);
      case RoutePaths.login:
        return _page(const LoginScreen(), settings);
      case RoutePaths.shell:
        return _page(const AppShell(), settings);
      case RoutePaths.designGallery:
        return _page(const DesignGalleryScreen(), settings);
      default:
        return _page(const UnknownRouteScreen(), settings);
    }
  }

  static MaterialPageRoute<dynamic> _page(Widget child, RouteSettings settings) {
    return MaterialPageRoute<dynamic>(
      builder: (BuildContext context) => child,
      settings: settings,
    );
  }
}

/// شاشة احتياطية لمسار غير معروف.
class UnknownRouteScreen extends StatelessWidget {
  const UnknownRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.unknownRoute)),
      body: Center(
        child: EmptyState(
          icon: Icons.search_off,
          title: AppStrings.unknownRoute,
          message: 'المسار المطلوب غير مسجّل في التطبيق.',
          actionLabel: AppStrings.backToHome,
          onActionTap: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              RoutePaths.splash,
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
    );
  }
}
