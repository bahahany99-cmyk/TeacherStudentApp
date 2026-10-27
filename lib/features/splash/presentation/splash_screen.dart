import 'dart:async';

import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// شاشة البداية: هوية بسيطة ثم توجيه حسب حالة الجلسة.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_routeAfterSplash());
  }

  Future<void> _routeAfterSplash() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }

    final SessionController session = SessionScope.read(context);
    // حساب بلا دور محفوظ ← شاشة اختيار الدور (أول دخول فقط).
    final String nextRoute = switch (session.status) {
      SessionStatus.signedIn => RoutePaths.shell,
      SessionStatus.needsRole => RoutePaths.roleSelection,
      SessionStatus.signedOut || SessionStatus.unknown => RoutePaths.login,
    };

    unawaited(
      Navigator.of(context).pushNamedAndRemoveUntil(
        nextRoute,
        (Route<dynamic> route) => false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      // شفاف: الخلفية العالمية (بلاش علوي ← أبيض) ترسم خلف الشاشة كلها.
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // الشعار: الموضع الوحيد المسموح فيه بتدرّج مشبع (A-54).
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: AppGradients.hero,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    boxShadow: AppShadows.hero,
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppStrings.appName,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.appTagline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'المرحلة 4 — أساسيات Firebase',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
