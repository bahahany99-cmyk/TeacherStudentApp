import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/config/app_config.dart';
import 'package:teacher_student_app/core/config/firebase_bootstrap.dart';
import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/features/auth/presentation/auth_flow.dart';
import 'package:teacher_student_app/features/auth/presentation/widgets/google_sign_in_button.dart';

/// شاشة تسجيل الدخول.
///
/// الطرق المتاحة (قرار صاحب المشروع 2026-10-27):
/// 1. Google — عبر الـSDK الأصلي `google_sign_in` (P18): قائمة الحسابات
///    المدمجة في أندرويد ثم تمرير `idToken` إلى Firebase. لا متصفح ولا redirect.
/// 2. بريد إلكتروني + كلمة مرور — شاشة [RoutePaths.emailAuth].
///
/// إن لم يكن Firebase مُهيَّأ (لا `--dart-define` ولا مشروع)، يُظهر الضغط
/// رسالة «الخدمة غير متاحة الآن» بدل تعطيل الأزرار بلا تفسير. وتبقى بطاقة
/// المعاينة المحلية متاحة لتجربة الواجهات بلا خادم.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _signInWithGoogle(BuildContext context) async {
    final SessionController session = SessionScope.read(context);

    try {
      await session.signInWithGoogle();
      if (!context.mounted) {
        return;
      }
      await continueAfterAuth(context, session);
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      final AppException failure = toAppException(error);
      AppSnackBar.show(
        context,
        '${failure.title} — ${failure.message}',
        // إلغاء المستخدم لقائمة الحسابات ليس خطأً: لا نُخيفه بلون تحذير.
        type: failure.kind == AppErrorKind.canceled
            ? AppMessageType.info
            : AppMessageType.warning,
      );
    }
  }

  void _openDemoShell(BuildContext context, UserRole role) {
    SessionScope.read(context).startDemoSession(role);
    Navigator.of(context).pushNamedAndRemoveUntil(
      RoutePaths.shell,
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: AppGradients.hero,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                        boxShadow: AppShadows.hero,
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 44,
                        color: Colors.white,
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
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text('تسجيل الدخول', style: theme.textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'سجّل الدخول بحساب Google أو ببريد إلكتروني. '
                          'نوع الحساب يُختار مرة واحدة بعد أول دخول ثم يُقرأ '
                          'من الخادم.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        GoogleSignInButton(
                          onPressed: () => _signInWithGoogle(context),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pushNamed(
                            RoutePaths.emailAuth,
                          ),
                          icon: const Icon(Icons.alternate_email, size: 20),
                          label: const Text('الدخول بالبريد الإلكتروني'),
                        ),
                        if (FirebaseBootstrap.status !=
                            FirebaseStatus.ready) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          const InfoNote(
                            icon: Icons.cloud_off_outlined,
                            text:
                                'المصادقة الحقيقية غير مُهيَّأة في هذه النسخة '
                                '(لا يوجد مشروع Firebase متصل)، لذلك سترى رسالة '
                                '«غير متاحة» عند المحاولة. راجع '
                                'docs/FIREBASE_SETUP.md.',
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'بالدخول أنت توافق على شروط الاستخدام وسياسة '
                          'الخصوصية (ستُنشر قبل الإطلاق).',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (AppConfig.isDemoMode)
                    _DemoAccessCard(
                      onStudentTap: () =>
                          _openDemoShell(context, UserRole.student),
                      onTeacherTap: () =>
                          _openDemoShell(context, UserRole.teacher),
                      onAdminTap: () =>
                          _openDemoShell(context, UserRole.admin),
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

/// مدخل مؤقت لمعاينة الواجهات بلا Firebase.
class _DemoAccessCard extends StatelessWidget {
  const _DemoAccessCard({
    required this.onStudentTap,
    required this.onTeacherTap,
    required this.onAdminTap,
  });

  final VoidCallback onStudentTap;
  final VoidCallback onTeacherTap;
  final VoidCallback onAdminTap;

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
                  'وضع الزائر (بدون حساب)',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'تصفّح كل الشاشات ببيانات تجريبية محلية دون تسجيل دخول ودون '
            'اتصال بخادم. اختيار الدور هنا للعرض فقط: لا يُنشئ حسابًا ولا يمنح '
            'أي صلاحية، وفي الإنتاج يُقرأ الدور من الخادم.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.75,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onStudentTap,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    textStyle: theme.textTheme.labelMedium,
                  ),
                  child: const Text(
                    'واجهة الطالب',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton(
                  onPressed: onTeacherTap,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    textStyle: theme.textTheme.labelMedium,
                  ),
                  child: const Text(
                    'واجهة المدرس',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // (P14) معاينة لوحة الإدارة: جلسة تجريبية فقط، ولا تمنح ادعاءً على
          // الخادم — القواعد تقرأ رمز الهوية لا حالة الواجهة.
          OutlinedButton.icon(
            onPressed: onAdminTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              textStyle: theme.textTheme.labelMedium,
            ),
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: const Text('لوحة الإدارة (معاينة)'),
          ),
        ],
      ),
    );
  }
}
