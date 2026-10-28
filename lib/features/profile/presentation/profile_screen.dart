import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';

/// صفحة الحساب والملف الشخصي.
///
/// تعرض بيانات الجلسة، وتتيح إنهاء الجلسة، وتبديل واجهة المعاينة في الوضع
/// التجريبي فقط.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final SessionController session = SessionScope.read(context);
    await session.signOut();
    await navigator.pushNamedAndRemoveUntil(
      RoutePaths.login,
      (Route<dynamic> route) => false,
    );
  }

  void _switchRole(BuildContext context, UserRole role) {
    SessionScope.read(context).switchDemoRole(role);
  }

  void _showComingSoon(BuildContext context) {
    AppSnackBar.show(context, AppStrings.comingSoon);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SessionController session = SessionScope.of(context);
    final AppUser? user = session.user;

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (session.isDemoSession) const DemoBanner(),
              AppCard(
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: AppSpacing.avatarLg / 2.6,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        user?.initials ?? '؟',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            user?.displayName ?? 'مستخدم غير معروف',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Wrap(
                            spacing: AppSpacing.xxs,
                            runSpacing: AppSpacing.xxs,
                            children: <Widget>[
                              StatusChip(
                                label: user?.role.label ?? '—',
                                color: theme.colorScheme.primary,
                              ),
                              if (session.isDemoSession)
                                const StatusChip(
                                  label: 'حساب تجريبي',
                                  color: Color(0xFFB26A00),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            user?.email ?? 'لا يوجد بريد مرتبط بعد',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'البيانات أعلاه من الجلسة الحالية فقط. عند ربط Firebase '
                'Authentication ستأتي من حساب Google، وسيُقرأ الدور من مستند '
                'المستخدم في Firestore — لا يختاره التطبيق.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader(title: 'إعدادات الحساب'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    // (P14) الإدارة فقط: مدخل اللوحة. القرار الحقيقي في القواعد،
                    // و`AdminGuard` يمنع الوصول لو فُتح المسار من حساب آخر.
                    if (session.isAdmin) ...<Widget>[
                      _ProfileTile(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'لوحة الإدارة',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(RoutePaths.adminDashboard),
                      ),
                      const Divider(height: 1),
                    ],
                    if (user?.role == UserRole.teacher) ...<Widget>[
                      _ProfileTile(
                        icon: Icons.badge_outlined,
                        label: 'ملفي التعريفي',
                        onTap: () => Navigator.of(context).pushNamed(
                          RoutePaths.myTeacherProfile,
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    _ProfileTile(
                      icon: Icons.forum_outlined,
                      label: 'المحادثات',
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(RoutePaths.directChats),
                    ),
                    const Divider(height: 1),
                    _ProfileTile(
                      icon: Icons.person_outline,
                      label: 'بياناتي',
                      onTap: () => _showComingSoon(context),
                    ),
                    const Divider(height: 1),
                    // المفضلة للطالب (P13): المدرس لا يحفظ مدرسين ولا مجموعات.
                    if (user?.role == UserRole.student) ...<Widget>[
                      _ProfileTile(
                        icon: Icons.favorite_border,
                        label: 'المفضلة',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(RoutePaths.favorites),
                      ),
                      const Divider(height: 1),
                    ],
                    _ProfileTile(
                      icon: Icons.notifications_none,
                      label: 'الإشعارات',
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(RoutePaths.notifications),
                    ),
                    const Divider(height: 1),
                    _ProfileTile(
                      icon: Icons.help_outline,
                      label: 'المساعدة والدعم',
                      onTap: () => _showComingSoon(context),
                    ),
                    const Divider(height: 1),
                    _ProfileTile(
                      icon: Icons.privacy_tip_outlined,
                      label: 'الشروط وسياسة الخصوصية',
                      onTap: () => _showComingSoon(context),
                    ),
                  ],
                ),
              ),
              if (session.isDemoSession) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const SectionHeader(
                  title: 'معاينة الواجهات',
                  subtitle: 'للاختبار المحلي فقط — لا يمنح أي صلاحية',
                ),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: () =>
                            _switchRole(context, UserRole.student),
                        child: const Text('واجهة الطالب'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton(
                        onPressed: () =>
                            _switchRole(context, UserRole.teacher),
                        child: const Text('واجهة المدرس'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton(
                        onPressed: () => _switchRole(context, UserRole.admin),
                        child: const Text('واجهة الإدارة (تجريبي)'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pushNamed(
                          RoutePaths.designGallery,
                        ),
                        child: const Text('معرض المكونات (تطوير)'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_left, size: 20),
      onTap: onTap,
    );
  }
}
