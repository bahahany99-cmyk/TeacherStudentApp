import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/app_tab.dart';
import 'package:teacher_student_app/app/shell/shell_controller.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/core/utils/greetings.dart';
import 'package:teacher_student_app/data/validation/booking_rules.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/teacher_groups_section.dart';
import 'package:teacher_student_app/features/teacher/presentation/widgets/teacher_profile_status_card.dart';

/// الصفحة الرئيسية لواجهة المدرس — **مبنية على يوم المدرس لا على ملفه**.
///
/// ## ما تغيّر (P28)
///
/// كانت الصفحة تبدأ ببطاقة ضخمة عن «ملفك موثق» تستهلك نصف الشاشة، ثم قائمة
/// طلبات، ثم قسم مجموعات، ثم ملاحظة. النتيجة: أهم معلومة للمدرس (هل هناك طالب
/// ينتظرني؟ كم مقعدًا متاح؟) كانت مدفونة، وأول ما يراه هو بطاقة عن ملفه هو.
///
/// الترتيب الجديد يتبع ما يفعله المدرس عند فتح التطبيق:
/// 1. **تحية قصيرة** بالاسم (لا بطاقة).
/// 2. **حالة الملف** كصف واحد مضغوط — معلومة لا تحتلّ الشاشة.
/// 3. **أرقام اليوم**: طلبات تنتظر قرارك، مجموعات نشطة، مقاعد متاحة، محادثات
///    غير مقروءة — كلها من مصادر حقيقية، وتظهر `—` حين لا تُعرف بعد (لا رقم
///    مختلق).
/// 4. **اختصارات** أربعة: الطلبات، مجموعاتي، المحادثات، ملفي التعريفي.
/// 5. **طلبات تنتظر قرارك** (معاينة أول ثلاثة) ثم **مجموعاتي**.
///
/// كل قسم يعتمد على بثّ/قراءة حقيقية، وكل حالة فراغ تشرح الخطوة التالية.
class TeacherHomeScreen extends StatelessWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController session = SessionScope.of(context);
    final ThemeData theme = Theme.of(context);
    final String teacherId = CurrentTeacher.idOf(session);
    final String name = session.user?.displayName ?? 'أستاذنا';
    final DateTime now = DateTime.now();

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 1) تحية قصيرة — سطران بلا بطاقة.
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'أهلًا $name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          '${Greetings.lineFor(now)} · يومك التعليمي يبدأ من هنا',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // (P21) جلسة استعراض: وسم قصير بلغة المنتج لا لغة التطوير.
                  if (session.isDemoSession)
                    const StatusChip(
                      label: 'جولة',
                      color: AppColors.attentionForeground,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // 2) حالة الملف: صف مضغوط واحد بدل نصف شاشة.
              TeacherProfileStatusCard(teacherId: teacherId),
              const SizedBox(height: AppSpacing.sm),

              // 3) أرقام اليوم من مصادر حقيقية.
              _TodayStats(teacherId: teacherId),
              const SizedBox(height: AppSpacing.sm),

              // 4) اختصارات الأقسام الأساسية — بلا تكرار لأي بطاقة.
              const _QuickActions(),
              const SizedBox(height: AppSpacing.md),

              // 5) طلبات تنتظر قرارك.
              SectionHeader(
                title: 'طلبات تنتظر قرارك',
                subtitle: 'طلبات الانضمام والحجز تصل هنا لحظة إرسالها',
                icon: Icons.inbox_outlined,
                actionLabel: 'كل الطلبات',
                onActionTap: () => ShellScope.read(context).goTo(AppTab.bookings),
              ),
              _PendingRequestsPreview(teacherId: teacherId),
              const SizedBox(height: AppSpacing.md),

              // 6) مجموعاتي (نفس القسم المستخدم في التبويب، بلا تكرار منطق).
              const TeacherGroupsSection(maxItems: 3),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'الدفع يتم بينك وبين الطالب خارج التطبيق. السعر في '
                        'ملفك استرشادي، والتطبيق لا يحتفظ بأي مبالغ.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }
}

/// صف الأرقام: طلبات · مجموعات نشطة · مقاعد متاحة · محادثات غير مقروءة.
///
/// **لا أرقام وهمية:** كل بطاقة تعرض `—` حتى تصل بياناتها، وتعرض صفرًا فقط
/// حين يكون الصفر هو الحقيقة (قائمة فارغة وصلت فعلًا).
class _TodayStats extends StatelessWidget {
  const _TodayStats({required this.teacherId});

  final String teacherId;

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // الطلبات: بثّان (انضمام + حجز) — نفس مصدر صفحة الطلبات.
        StreamBuilder<List<GroupJoinRequest>>(
          stream: services.groups.watchIncomingRequests(teacherId),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<GroupJoinRequest>> joinSnapshot,
          ) {
            return StreamBuilder<List<BookingRequest>>(
              stream: services.bookings.watchMine(),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<BookingRequest>> bookingSnapshot,
              ) {
                final bool ready =
                    joinSnapshot.hasData && bookingSnapshot.hasData;
                final int pendingJoins =
                    (joinSnapshot.data ?? const <GroupJoinRequest>[])
                        .where((GroupJoinRequest r) => r.isPending)
                        .length;
                final int pendingBookings =
                    (bookingSnapshot.data ?? const <BookingRequest>[])
                        .where(
                          (BookingRequest b) =>
                              b.teacherId == teacherId && b.waitingForTeacher,
                        )
                        .length;

                return AsyncView<List<StudyGroup>>(
                  load: () => services.groups.listForTeacher(teacherId),
                  builder: (BuildContext context, List<StudyGroup> groups) {
                    int activeGroups = 0;
                    int freeSeats = 0;
                    for (final StudyGroup group in groups) {
                      if (!group.isActive) {
                        continue;
                      }
                      activeGroups++;
                      freeSeats += group.seatsAvailable;
                    }

                    return StreamBuilder<List<DirectChat>>(
                      stream: services.chats.watchMine(teacherId),
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<List<DirectChat>> chatSnapshot,
                      ) {
                        final int unreadChats =
                            (chatSnapshot.data ?? const <DirectChat>[])
                                .where(
                                  (DirectChat chat) =>
                                      chat.hasUnreadFor(teacherId),
                                )
                                .length;

                        return Row(
                          children: <Widget>[
                            Expanded(
                              child: _StatTile(
                                key: const Key('teacher-stat-pending'),
                                icon: Icons.inbox_outlined,
                                label: 'تنتظر قرارك',
                                value: ready
                                    ? '${pendingJoins + pendingBookings}'
                                    : '—',
                                color: AppColors.statusPending,
                                highlight: ready &&
                                    (pendingJoins + pendingBookings) > 0,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: _StatTile(
                                key: const Key('teacher-stat-groups'),
                                icon: Icons.groups_outlined,
                                label: 'مجموعات نشطة',
                                value: '$activeGroups',
                                color: AppColors.statusAccepted,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: _StatTile(
                                key: const Key('teacher-stat-seats'),
                                icon: Icons.event_seat_outlined,
                                label: 'مقاعد متاحة',
                                value: '$freeSeats',
                                color: AppColors.statusInfo,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: _StatTile(
                                key: const Key('teacher-stat-chats'),
                                icon: Icons.forum_outlined,
                                label: 'رسائل جديدة',
                                value: chatSnapshot.hasData
                                    ? '$unreadChats'
                                    : '—',
                                color: AppColors.accent,
                                highlight: unreadChats > 0,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// بلاطة رقم واحدة: أيقونة + رقم كبير + تسمية صغيرة.
class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  /// رقم يستحق انتباهًا الآن (طلبات معلّقة، رسائل غير مقروءة).
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(
          color: highlight ? color.withAlpha(90) : theme.colorScheme.outlineVariant,
          width: highlight ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: color),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: highlight ? color : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// اختصارات: الطلبات · مجموعاتي · المحادثات · ملفي.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ShellController shell = ShellScope.read(context);

    final List<_QuickAction> actions = <_QuickAction>[
      _QuickAction(
        key: const Key('teacher-quick-requests'),
        icon: Icons.assignment_outlined,
        label: 'الطلبات',
        onTap: () => shell.goTo(AppTab.bookings),
      ),
      _QuickAction(
        key: const Key('teacher-quick-groups'),
        icon: Icons.groups_2_outlined,
        label: 'مجموعاتي',
        onTap: () => shell.goTo(AppTab.groups),
      ),
      _QuickAction(
        key: const Key('teacher-quick-chats'),
        icon: Icons.forum_outlined,
        label: 'المحادثات',
        onTap: () =>
            Navigator.of(context).pushNamed(RoutePaths.directChats),
      ),
      _QuickAction(
        key: const Key('teacher-quick-profile'),
        icon: Icons.badge_outlined,
        label: 'ملفي',
        onTap: () =>
            Navigator.of(context).pushNamed(RoutePaths.myTeacherProfile),
      ),
    ];

    return Row(
      children: <Widget>[
        for (int i = 0; i < actions.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: actions[i].key,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                onTap: actions[i].onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(18),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: Icon(
                          actions[i].icon,
                          size: 19,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        actions[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// معاينة الطلبات: أول ثلاثة (انضمام ثم حجز)، وضغطة واحدة تفتح التفاصيل.
class _PendingRequestsPreview extends StatelessWidget {
  const _PendingRequestsPreview({required this.teacherId});

  final String teacherId;

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);

    return StreamBuilder<List<GroupJoinRequest>>(
      stream: services.groups.watchIncomingRequests(teacherId),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<GroupJoinRequest>> joinSnapshot,
      ) {
        return StreamBuilder<List<BookingRequest>>(
          stream: services.bookings.watchMine(),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<BookingRequest>> bookingSnapshot,
          ) {
            if (!joinSnapshot.hasData && !bookingSnapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final List<GroupJoinRequest> joins =
                (joinSnapshot.data ?? const <GroupJoinRequest>[])
                    .where((GroupJoinRequest r) => r.isPending)
                    .toList(growable: false);
            final List<BookingRequest> bookings =
                (bookingSnapshot.data ?? const <BookingRequest>[])
                    .where(
                      (BookingRequest b) =>
                          b.teacherId == teacherId && b.waitingForTeacher,
                    )
                    .toList(growable: false);

            if (joins.isEmpty && bookings.isEmpty) {
              return const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'لا توجد طلبات جديدة',
                message: 'سيظهر هنا كل طلب حجز أو انضمام لحظة إرساله.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final GroupJoinRequest request in joins.take(2))
                  Padding(
                    padding: AppSpacing.listGap,
                    child: _RequestRow(
                      icon: Icons.person_add_alt_1_outlined,
                      title: request.studentName,
                      subtitle: 'طلب انضمام · ${request.groupTitle}',
                      color: AppColors.statusPending,
                      onTap: () => Navigator.of(context).pushNamed(
                        RoutePaths.groupRequests,
                        arguments: request.groupId,
                      ),
                    ),
                  ),
                for (final BookingRequest booking
                    in bookings.take(3 - joins.take(2).length))
                  Padding(
                    padding: AppSpacing.listGap,
                    child: _RequestRow(
                      icon: Icons.event_available_outlined,
                      title: booking.studentName,
                      subtitle:
                          'طلب حجز · ${booking.subject} · '
                          '${BookingRules.slotLabel(booking)}',
                      color: AppColors.statusInfo,
                      onTap: () => Navigator.of(context).pushNamed(
                        RoutePaths.bookingDetails,
                        arguments: booking.id,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// صف طلب مختصر: أيقونة نوع + اسم الطالب + سياق + سهم.
class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_left,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
          ),
        ],
      ),
    );
  }
}
