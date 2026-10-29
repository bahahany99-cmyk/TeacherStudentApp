import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/validation/account_deletion_rules.dart';
import 'package:teacher_student_app/features/account/presentation/account_deletion_dialog.dart';

/// صفحة الحساب والملف الشخصي — **مشتركة** بين الطالب والمدرس (تبويب «حسابي»).
///
/// تعرض بيانات الجلسة، وأدوات الحساب: تسجيل الخروج، وطلب حذف الحساب بمهلة
/// سماح 7 أيام (P17)، وتبديل واجهة المعاينة في الوضع التجريبي فقط.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.now});

  /// ساعة الاختبار: تُمرَّر إلى حوار الحذف ليثبت الموعد المعروض.
  final DateTime? now;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// عملية حسابية جارية (خروج/حذف). نُقفل الأزرار أثناءها حتى لا يُرسل
  /// المستخدم الطلب مرتين، وحتى لا يُغادر الشاشة قبل اكتمال الكتابة.
  bool _busy = false;

  void _switchRole(UserRole role) {
    SessionScope.read(context).switchDemoRole(role);
  }

  void _showComingSoon() {
    AppSnackBar.show(context, AppStrings.comingSoon);
  }

  /// تسجيل الخروج: تأكيد ← إنهاء الجلسة ← شاشة الدخول.
  ///
  /// ننتظر `signOut()` قبل التنقل: لو تنقّلنا أولًا لبقي رمز الهوية صالحًا
  /// لحظات، وظهرت شاشة الدخول بينما الجلسة ما زالت قائمة.
  Future<void> _signOut() async {
    if (_busy) {
      return;
    }
    final bool confirmed = await confirmSignOut(context);
    if (!confirmed || !mounted) {
      return;
    }

    final NavigatorState navigator = Navigator.of(context);
    final SessionController session = SessionScope.read(context);
    setState(() => _busy = true);

    try {
      await session.signOut();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      AppSnackBar.show(
        context,
        toAppException(error).message,
        type: AppMessageType.error,
      );
      return;
    }

    if (!mounted) {
      return;
    }
    await navigator.pushNamedAndRemoveUntil(
      RoutePaths.login,
      (Route<dynamic> route) => false,
    );
  }

  /// طلب حذف الحساب (حذف ناعم، مهلة 7 أيام) ← خروج ← شاشة الدخول.
  Future<void> _deleteAccount() async {
    if (_busy) {
      return;
    }
    final bool confirmed = await confirmAccountDeletion(
      context,
      now: widget.now,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final NavigatorState navigator = Navigator.of(context);
    final SessionController session = SessionScope.read(context);
    final bool demo = session.isDemoSession;
    setState(() => _busy = true);

    try {
      final DateTime? scheduledAt = await session.requestAccountDeletion();
      if (!mounted) {
        return;
      }
      if (scheduledAt == null) {
        setState(() => _busy = false);
        return;
      }
      // التنبيه قبل التنقل: الـ`ScaffoldMessenger` أعلى الموجّه، فيبقى ظاهرًا
      // على شاشة الدخول بعد إزالة الشاشة الحالية.
      AppSnackBar.show(
        context,
        demo
            ? 'طلبك مسجّل محليًا فقط (وضع تجريبي). في الحساب الحقيقي تبدأ '
                  'مهلة ${AccountDeletionRules.gracePeriod.inDays} أيام.'
            : 'سُجّل طلب الحذف وسُجّل خروجك. لديك '
                  '${AccountDeletionRules.gracePeriod.inDays} أيام لاستعادة '
                  'الحساب بتسجيل الدخول من جديد.',
        type: AppMessageType.warning,
        duration: const Duration(seconds: 7),
      );
      await navigator.pushNamedAndRemoveUntil(
        RoutePaths.login,
        (Route<dynamic> route) => false,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      AppSnackBar.show(
        context,
        toAppException(error).message,
        type: AppMessageType.error,
      );
    }
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
              // (P18) لا شرط هنا: `DemoBanner` يتحقق من الجلسة ذاتيًا.
              const DemoBanner(),
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
                      onTap: _showComingSoon,
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
                      onTap: _showComingSoon,
                    ),
                    const Divider(height: 1),
                    _ProfileTile(
                      icon: Icons.privacy_tip_outlined,
                      label: 'الشروط وسياسة الخصوصية',
                      onTap: _showComingSoon,
                    ),
                    const Divider(height: 1),
                    // (P17) زر الخروج داخل «إعدادات الحساب»: نفس المكان في
                    // واجهة الطالب والمدرس لأن الشاشة مشتركة.
                    _ProfileTile(
                      key: const Key('profile-sign-out'),
                      icon: Icons.logout,
                      label: AccountDeletionRules.signOutAction,
                      danger: true,
                      busy: _busy,
                      onTap: _busy ? null : _signOut,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader(
                title: 'منطقة الخطر',
                subtitle: 'إجراءات لا تُنفَّذ فورًا ولا تُلغى تلقائيًا',
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    _ProfileTile(
                      key: const Key('profile-delete-account'),
                      icon: Icons.delete_forever_outlined,
                      label: AccountDeletionRules.deleteTitle,
                      subtitle:
                          'مهلة ${AccountDeletionRules.gracePeriod.inDays} '
                          'أيام للتراجع قبل الحذف النهائي',
                      danger: true,
                      busy: _busy,
                      onTap: _busy ? null : _deleteAccount,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const InfoNote(
                text:
                    'حذف الحساب في هذه النسخة حذف ناعم: يخفي حسابك من البحث '
                    'ويوقف استخدامه، ويبدأ مهلة استعادة. الحذف النهائي '
                    'للبيانات إجراء إداري.',
                icon: Icons.shield_outlined,
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
                        onPressed: () => _switchRole(UserRole.student),
                        child: const Text('واجهة الطالب'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton(
                        onPressed: () => _switchRole(UserRole.teacher),
                        child: const Text('واجهة المدرس'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton(
                        onPressed: () => _switchRole(UserRole.admin),
                        child: const Text('واجهة الإدارة (تجريبي)'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed(RoutePaths.designGallery),
                        child: const Text('معرض المكونات (تطوير)'),
                      ),
                    ],
                  ),
                ),
              ],
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
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.danger = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  /// لون تحذيري (خروج/حذف) بدل اللون الافتراضي.
  final bool danger;

  /// عملية جارية: تُعرض دائرة تقدّم بدل سهم الانتقال.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color foreground = danger
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return ListTile(
      enabled: onTap != null || busy,
      leading: Icon(icon, color: foreground),
      title: Text(label, style: TextStyle(color: foreground)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.chevron_left,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
      onTap: onTap,
    );
  }
}
