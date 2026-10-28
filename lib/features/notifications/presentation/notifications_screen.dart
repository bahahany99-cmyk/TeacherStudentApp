import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/notification_rules.dart';

/// شاشة الإشعارات (P12).
///
/// **القراءة فقط لما يخصّك:** القائمة تُقرأ بمستلم الجلسة، والقواعد ترفض أي
/// مستند لغيره — العزل في الخادم لا في هذه الشاشة.
///
/// **الفتح يقود إلى مكانه:** كل نوع إشعار يعرف وجهته (حجز/محادثة/مجموعة)،
/// والضغط يعلّمه مقروءًا ثم يفتح الشاشة المناسبة.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _revision = 0;
  bool _markingAll = false;

  String _viewerId(SessionController session) {
    return session.role == UserRole.teacher
        ? CurrentTeacher.idOf(session)
        : CurrentStudent.idOf(session);
  }

  Future<void> _open(AppNotification notification, String viewerId) async {
    final String route = switch (notification.target) {
      NotificationTarget.booking => RoutePaths.bookingDetails,
      NotificationTarget.chat => RoutePaths.directChat,
      NotificationTarget.group => RoutePaths.groupDetails,
    };

    try {
      if (!notification.isRead) {
        await AppServicesScope.of(context).notifications.markRead(
          notificationId: notification.id,
          recipientId: viewerId,
        );
      }
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        error.overrideMessage ?? error.message,
        type: AppMessageType.error,
      );
      return;
    }

    if (!mounted) {
      return;
    }
    await Navigator.of(
      context,
    ).pushNamed(route, arguments: notification.targetId);
    // بعد العودة قد تكون الحالة تغيّرت داخل الشاشة المفتوحة.
    if (mounted) {
      setState(() => _revision++);
    }
  }

  Future<void> _markAll(String viewerId) async {
    setState(() => _markingAll = true);
    try {
      await AppServicesScope.of(
        context,
      ).notifications.markAllRead(viewerId);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        error.overrideMessage ?? error.message,
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _markingAll = false;
          _revision++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = SessionScope.of(context);
    final String viewerId = _viewerId(session);

    return Scaffold(
      // شفاف لعرض تدرّج الخلفية العالمي (نسخة 3).
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: <Widget>[
          IconButton(
            tooltip: 'تعليم الكل مقروءًا',
            onPressed: _markingAll ? null : () => _markAll(viewerId),
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const DemoBanner(),
                  const SectionHeader(
                    title: 'آخر التحديثات',
                    subtitle: 'حجوزاتك ورسائلك ومقاعدك — في مكان واحد',
                  ),
                  AsyncView<List<AppNotification>>(
                    key: ValueKey<int>(_revision),
                    load: () => AppServicesScope.of(
                      context,
                    ).notifications.listMine(viewerId),
                    builder:
                        (
                          BuildContext context,
                          List<AppNotification> items,
                        ) {
                          if (items.isEmpty) {
                            return const EmptyState(
                              icon: Icons.notifications_none,
                              title: 'لا إشعارات',
                              message:
                                  'سيصلك إشعار عند تحرّك طلب حجز أو وصول رسالة '
                                  'أو توفّر مقعد في مجموعة.',
                            );
                          }
                          return Column(
                            children: <Widget>[
                              for (final AppNotification item in items)
                                Padding(
                                  padding: AppSpacing.listGap,
                                  child: _NotificationTile(
                                    notification: item,
                                    onTap: () => _open(item, viewerId),
                                  ),
                                ),
                            ],
                          );
                        },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const InfoNote(
                    icon: Icons.lock_outline,
                    text:
                        'لا يرى أحد إشعاراتك، ولا يمكن لأحد إنشاء إشعار لك إلا '
                        'بناءً على حجز أو محادثة أو عضوية مجموعة بينكما.',
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.type) {
    NotificationType.bookingRequested => Icons.event_available_outlined,
    NotificationType.bookingAccepted => Icons.check_circle_outline,
    NotificationType.bookingRejected => Icons.cancel_outlined,
    NotificationType.rescheduleProposed => Icons.swap_horiz,
    NotificationType.directMessage => Icons.forum_outlined,
    NotificationType.waitlistPromoted => Icons.groups_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool unread = !notification.isRead;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: AppSpacing.avatarMd / 2.8,
            backgroundColor: unread
                ? theme.colorScheme.primaryContainer
                : AppColors.statusNeutral.withAlpha(60),
            child: Icon(
              _icon,
              size: 20,
              color: unread
                  ? theme.colorScheme.onPrimaryContainer
                  : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        notification.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsetsDirectional.only(
                          start: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (notification.body != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    notification.body!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  NotificationRules.relativeTime(
                    notification.createdAt,
                    now: DateTime.now(),
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
