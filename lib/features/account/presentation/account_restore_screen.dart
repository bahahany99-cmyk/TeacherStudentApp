import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/account_status.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/validation/account_deletion_rules.dart';
import 'package:teacher_student_app/features/auth/presentation/auth_flow.dart';

/// شاشة استعادة الحساب المجدول للحذف (P17).
///
/// تظهر فقط لحساب حالته `pending_deletion` بعد تسجيل الدخول داخل مهلة السماح.
/// حالتان:
/// 1. **داخل المهلة**: زر «استعادة حسابي» يعيد الحساب نشطًا ويدخله التطبيق.
/// 2. **انتهت المهلة** (أو لا موعد محفوظ): لا استعادة من التطبيق — إجراء
///    إداري. نعرض ذلك صريحًا بدل زر يفشل على الخادم.
class AccountRestoreScreen extends StatefulWidget {
  const AccountRestoreScreen({super.key, this.now});

  /// ساعة الاختبار: تُحقن لتثبيت الحالة (داخل المهلة / منتهية) في الاختبارات.
  final DateTime? now;

  @override
  State<AccountRestoreScreen> createState() => _AccountRestoreScreenState();
}

class _AccountRestoreScreenState extends State<AccountRestoreScreen> {
  bool _busy = false;

  Future<void> _restore(SessionController session) async {
    setState(() => _busy = true);
    try {
      await session.restoreAccount();
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        'تمت استعادة حسابك — أُلغي موعد الحذف.',
        type: AppMessageType.success,
      );
      await continueAfterAuth(context, session);
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

  Future<void> _signOut() async {
    final NavigatorState navigator = Navigator.of(context);
    final SessionController session = SessionScope.read(context);
    setState(() => _busy = true);
    // تسجيل الخروج لا يفشل عمليًا، لكننا لا نترك المستخدم عالقًا لو حدث.
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
    await navigator.pushNamedAndRemoveUntil(
      RoutePaths.login,
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SessionController session = SessionScope.of(context);
    final AppUser? user = session.user;
    final DateTime now = widget.now ?? DateTime.now();
    final DateTime? scheduledAt = user?.scheduledDeletionAt;

    final bool canRestore = user != null &&
        AccountDeletionRules.canRestore(
          status: user.status,
          scheduledAt: scheduledAt,
          now: now,
        );
    final bool expired = scheduledAt != null &&
        AccountDeletionRules.isExpired(scheduledAt: scheduledAt, now: now);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('استعادة الحساب')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (session.isDemoSession) const DemoBanner(),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.lock_clock_outlined,
                              size: 28,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'حسابك مجدول للحذف',
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xxs,
                          runSpacing: AppSpacing.xxs,
                          children: <Widget>[
                            StatusChip(
                              label: user?.role.label ?? '—',
                              color: theme.colorScheme.primary,
                            ),
                            StatusChip(
                              label: AccountStatus.pendingDeletion.label,
                              color: theme.colorScheme.error,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          user?.displayName ?? 'مستخدم',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          user?.email ?? 'لا يوجد بريد مرتبط',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (canRestore && scheduledAt != null)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            AccountDeletionRules.restoreBody(
                              scheduledAt: scheduledAt,
                              now: now,
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton.icon(
                            onPressed: _busy ? null : () => _restore(session),
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.restore),
                            label: const Text(
                              AccountDeletionRules.restoreAction,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            expired
                                ? AccountDeletionRules.expiredNotice
                                : AccountDeletionRules.missingScheduleNotice,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const InfoNote(
                            text:
                                'طلب الاستعادة بعد انتهاء المهلة يمرّ عبر '
                                'المسؤول (سياسة الاحتفاظ بالبيانات) وليس من '
                                'التطبيق.',
                            icon: Icons.support_agent,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  const InfoNote(
                    text:
                        'لا يمكن استخدام التطبيق قبل الاستعادة: الحساب '
                        'المجدول للحذف لا يدخل الواجهة ولا تظهر ملفاته في '
                        'البحث.',
                    icon: Icons.visibility_off_outlined,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text(AccountDeletionRules.signOutAction),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
