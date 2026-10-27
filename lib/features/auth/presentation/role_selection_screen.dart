import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/features/auth/presentation/auth_flow.dart';

/// اختيار الدور عند أول تسجيل دخول (قرار صاحب المشروع 2026-10-27).
///
/// - تظهر **مرة واحدة** فقط: بعد الحفظ في `users/{uid}` لا تعود الشاشة تظهر،
///   لأن الدور يُقرأ من الخادم في كل دخول تالٍ.
/// - اختيار هنا لا يمنح صلاحية بحد ذاته؛ القواعد على الخادم هي المرجع.
/// - تُحفظ كطالب/مدرس فقط. الدور الإداري لا يُختار من التطبيق.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole? _selected;
  bool _saving = false;

  Future<void> _confirm() async {
    final UserRole? role = _selected;
    if (role == null || _saving) {
      return;
    }

    final SessionController session = SessionScope.read(context);

    setState(() => _saving = true);
    try {
      await session.completeRoleSelection(role);
      if (!mounted) {
        return;
      }
      await continueAfterAuth(context, session);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      AppSnackBar.show(
        context,
        error.message,
        type: AppMessageType.error,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
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

    if (!session.needsRoleSelection) {
      // حالة غير متوقعة: فُتحت الشاشة بلا حساب ينتظر اختيار الدور.
      return Scaffold(
        appBar: AppBar(title: const Text('اختيار نوع الحساب')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: EmptyState(
              icon: Icons.info_outline,
              title: 'لا يوجد حساب بانتظار الاختيار',
              message:
                  'اختيار نوع الحساب يظهر مرة واحدة بعد أول تسجيل دخول فقط.',
              actionLabel: 'العودة لتسجيل الدخول',
              onActionTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                RoutePaths.login,
                (Route<dynamic> route) => false,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('اختيار نوع الحساب')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'أهلًا ${session.pendingDisplayName ?? ''}',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    session.pendingEmail ?? '',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'كيف ستستخدم ${AppStrings.appName}؟',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'هذا الخيار يُحفظ في حسابك ويُستخدم لعرض الواجهة المناسبة.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _RoleCard(
                    icon: Icons.school_outlined,
                    title: 'طالب',
                    description:
                        'أبحث عن مدرسين ومجموعات، وأتابع طلبات الحجز الخاصة بي.',
                    selected: _selected == UserRole.student,
                    onTap: () => setState(() => _selected = UserRole.student),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _RoleCard(
                    icon: Icons.co_present_outlined,
                    title: 'مدرس',
                    description:
                        'أنشر ملفي ومجموعاتي وأستقبل طلبات الحجز. ظهور الملف '
                        'للطلاب يحتاج اعتماد الإدارة.',
                    selected: _selected == UserRole.teacher,
                    onTap: () => setState(() => _selected = UserRole.teacher),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: _selected == null || _saving ? null : _confirm,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : const Text('متابعة'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const InfoNote(
                    text:
                        'اختيار الدور يُحفظ مرة واحدة. تغييره لاحقًا يحتاج '
                        'إجراءً إداريًا (غير منفّذ في التطبيق).',
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

/// بطاقة اختيار دور (قابلة للضغط، بحالة اختيار واضحة).
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      selected: selected,
      button: true,
      child: AppCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              icon,
              size: 28,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
