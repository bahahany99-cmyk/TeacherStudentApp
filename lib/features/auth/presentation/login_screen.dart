import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/data/models/user_role.dart';

/// شاشة تسجيل الدخول (بنية عرض فقط في المرحلة 2).
///
/// - زر Google موجود لكنه **غير موصول** بـ Firebase Authentication؛ يظهر
///   تنبيه صريح عند الضغط.
/// - الدخول إلى واجهات المعاينة يتم عبر جلسة تجريبية معلّمة بوضوح، لأن مشروع
///   Firebase لم يُنشأ بعد.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _openDemoShell(BuildContext context, UserRole role) {
    SessionScope.read(context).startDemoSession(role);
    Navigator.of(context).pushNamedAndRemoveUntil(
      RoutePaths.shell,
      (Route<dynamic> route) => false,
    );
  }

  void _showNotConnectedNotice(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'تسجيل الدخول عبر Google يحتاج أولًا إعداد مشروع Firebase '
            'وتفعيل مزوّد Google (انظر docs/FIREBASE_SETUP.md).',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      size: 44,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.appName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  AppStrings.appTagline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('تسجيل الدخول', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'في الإصدار الأول يتم الدخول بحساب Google فقط. '
                  'نوع الحساب (طالب أو مدرس) يُحدَّد من بيانات حسابك على الخادم.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => _showNotConnectedNotice(context),
                  icon: const _GoogleGlyph(),
                  label: const Text('المتابعة باستخدام Google'),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'بالدخول أنت توافق على شروط الاستخدام وسياسة الخصوصية '
                  '(ستُنشر قبل الإطلاق).',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _DemoAccessCard(
                  onStudentTap: () => _openDemoShell(context, UserRole.student),
                  onTeacherTap: () => _openDemoShell(context, UserRole.teacher),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// حرف G بشكل بسيط بدل استخدام شعار Google الرسمي.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(
        'G',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// مدخل مؤقت لمعاينة الواجهات بلا Firebase.
class _DemoAccessCard extends StatelessWidget {
  const _DemoAccessCard({
    required this.onStudentTap,
    required this.onTeacherTap,
  });

  final VoidCallback onStudentTap;
  final VoidCallback onTeacherTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.science_outlined,
                size: 18,
                color: AppColors.demoForeground,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'معاينة الواجهات (بيانات تجريبية)',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'اختيار الدور هنا للعرض فقط ولا يُنشئ حسابًا ولا يمنح أي صلاحية. '
            'في الإنتاج يُقرأ الدور من الخادم ويُفرض عبر قواعد Firestore.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onStudentTap,
                  child: const Text('واجهة الطالب'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton(
                  onPressed: onTeacherTap,
                  child: const Text('واجهة المدرس'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
