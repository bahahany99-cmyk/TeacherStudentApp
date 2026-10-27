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
import 'package:teacher_student_app/core/widgets/detail_row.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';
import 'package:teacher_student_app/data/validation/join_rules.dart';

/// تفاصيل مجموعة دراسية — الشاشة الداخلية الأهم في P8.
///
/// شاشة واحدة للدورين، والفرق محدود ومقصود:
/// - **الطالب:** يرى السعة والموعد، ويرسل طلب انضمام واحدًا، ويتابع حالته
///   (معلّق/مقبول/مرفوض) ويمكنه إلغاء المعلّق.
/// - **المدرس:** لا يرى زر انضمام؛ يرى بدلًا منه مداخل الإدارة: تعديل البيانات،
///   الأعضاء، وطلبات الانضمام.
///
/// ⚠️ إخفاء زر لا يعني صلاحية: كل قراءة/كتابة تُفرض في `firestore.rules`،
/// وحجز المقعد يحدث في معاملة على الخادم لا في هذه الشاشة.
class GroupDetailsScreen extends StatefulWidget {
  const GroupDetailsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  /// عدّاد إعادة القراءة بعد العودة من نموذج التعديل أو من شاشة الطلبات.
  int _revision = 0;

  Future<void> _openEditForm() async {
    final bool? saved = await Navigator.of(
      context,
    ).pushNamed<bool>(RoutePaths.groupForm, arguments: widget.groupId);
    if (saved == true && mounted) {
      setState(() => _revision++);
    }
  }

  Future<void> _openRequests(StudyGroup group) async {
    await Navigator.of(context).pushNamed<void>(
      RoutePaths.groupRequests,
      arguments: group.id,
    );
    if (mounted) {
      setState(() => _revision++);
    }
  }

  Future<void> _openMembers() async {
    await Navigator.of(
      context,
    ).pushNamed<void>(RoutePaths.groupMembers, arguments: widget.groupId);
    if (mounted) {
      setState(() => _revision++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // شفاف لعرض تدرّج الخلفية العالمي (v4.1).
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('تفاصيل المجموعة')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: AsyncView<StudyGroup?>(
                key: ValueKey<int>(_revision),
                load: () => AppServicesScope.of(
                  context,
                ).groups.findById(widget.groupId),
                emptyBuilder: (BuildContext context) => const EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'المجموعة غير موجودة',
                  message: 'ربما حُذفت المجموعة أو تغيّر الرابط.',
                ),
                builder: (BuildContext context, StudyGroup? group) {
                  if (group == null) {
                    return const EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'المجموعة غير موجودة',
                    );
                  }
                  return _GroupDetailsBody(
                    group: group,
                    onEditTap: _openEditForm,
                    onMembersTap: _openMembers,
                    onRequestsTap: () => _openRequests(group),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupDetailsBody extends StatelessWidget {
  const _GroupDetailsBody({
    required this.group,
    required this.onEditTap,
    required this.onMembersTap,
    required this.onRequestsTap,
  });

  final StudyGroup group;

  /// فتح نموذج التعديل (P7) — للمدرس صاحب المجموعة.
  final VoidCallback onEditTap;
  final VoidCallback onMembersTap;

  /// فتح شاشة طلبات الانضمام (P8) — للمدرس صاحب المجموعة.
  final VoidCallback onRequestsTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SessionController session = SessionScope.of(context);
    final bool isTeacherView = session.role == UserRole.teacher;
    final int seatsTaken = group.seatsTaken;
    final int seatsTotal = group.seatsTotal == 0 ? 1 : group.seatsTotal;
    final double fill = (seatsTaken / seatsTotal).clamp(0, 1).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const DemoBanner(),

        // ── بطاقة الرأس: العنوان والحالة والتصنيفات ─────────────────────────
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      group.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  StatusChip(
                    label: group.isActive
                        ? (group.isFull ? 'مكتملة' : 'متاحة')
                        : 'موقوفة',
                    color: !group.isActive
                        ? AppColors.statusNeutral
                        : (group.isFull
                              ? AppColors.statusRejected
                              : AppColors.statusAccepted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${group.subject} • ${group.stage}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PillRow(
                children: <Widget>[
                  PillChip(
                    label: group.meetingMode.label,
                    icon: Icons.videocam_outlined,
                    dense: true,
                  ),
                  PillChip(
                    label: JoinRules.capacityLine(group),
                    icon: Icons.event_seat_outlined,
                    dense: true,
                    color: group.seatsAvailable <= 0
                        ? AppColors.statusRejected
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── تفاصيل الحصة ────────────────────────────────────────────────────
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('تفاصيل الحصة', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              DetailRow(
                icon: Icons.person_outline,
                label: 'المدرس',
                value: group.teacherName,
              ),
              DetailRow(
                icon: Icons.videocam_outlined,
                label: 'طريقة الحضور',
                value: group.meetingMode.label,
              ),
              if (group.scheduleNote != null)
                DetailRow(
                  icon: Icons.schedule_outlined,
                  label: 'الموعد',
                  value: group.scheduleNote!,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── المقاعد ─────────────────────────────────────────────────────────
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'المقاعد',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    '$seatsTaken / ${group.seatsTotal}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                child: LinearProgressIndicator(
                  value: fill,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.primary.withAlpha(20),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                group.isFull
                    ? 'لا توجد مقاعد متاحة حاليًا'
                    : 'متاح ${group.seatsAvailable} مقعد',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        if (isTeacherView) ...<Widget>[
          const SizedBox(height: AppSpacing.sectionGap),
          const SectionHeader(
            title: 'إدارة المجموعة',
            subtitle: 'التعديل والإيقاف والقبول لصاحب المجموعة فقط',
            icon: Icons.tune,
          ),
          AppCard(
            onTap: onRequestsTap,
            margin: AppSpacing.listGap,
            child: _ManagementTile(
              icon: Icons.mark_email_unread_outlined,
              title: 'طلبات الانضمام',
              trailing: _PendingBadge(groupId: group.id),
            ),
          ),
          AppCard(
            onTap: onMembersTap,
            margin: AppSpacing.listGap,
            child: _ManagementTile(
              icon: Icons.groups_2_outlined,
              title: 'أعضاء المجموعة ($seatsTaken)',
            ),
          ),
          AppCard(
            onTap: onEditTap,
            child: const _ManagementTile(
              icon: Icons.edit_outlined,
              title: 'تعديل بيانات المجموعة',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const InfoNote(
            text:
                'قبول طلب يزيد المقعد المشغول وينشئ عضوية الطالب في معاملة '
                'واحدة على الخادم، فلا يمكن تجاوز السعة بطلبين متزامنين.',
          ),
        ] else ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _JoinPanel(group: group),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// سطر إدارة: أيقونة + عنوان + سهم، مع عنصر زائد اختياري.
class _ManagementTile extends StatelessWidget {
  const _ManagementTile({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) ...<Widget>[
          trailing!,
          const SizedBox(width: AppSpacing.xs),
        ],
        Icon(
          Icons.chevron_left,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

/// عدّاد الطلبات المعلّقة — يظهر فقط إن وُجدت طلبات (لا «0 جديد»).
class _PendingBadge extends StatefulWidget {
  const _PendingBadge({required this.groupId});

  final String groupId;

  @override
  State<_PendingBadge> createState() => _PendingBadgeState();
}

class _PendingBadgeState extends State<_PendingBadge> {
  Future<int>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // القراءة من المستودع تحتاج `context` جاهزًا؛ `didChangeDependencies` هو
    // أول موضع آمن لذلك (بخلاف `initState`).
    final String teacherId = CurrentTeacher.idOf(SessionScope.of(context));
    _future ??= AppServicesScope.of(context).groups
        .listRequestsForGroup(widget.groupId, teacherId: teacherId)
        .then(
          (List<GroupJoinRequest> requests) => requests
              .where((GroupJoinRequest request) => request.isPending)
              .length,
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        final int count = snapshot.data ?? 0;
        if (count <= 0) {
          return const SizedBox.shrink();
        }
        return PillBadge(
          label: '$count جديد',
          icon: Icons.notifications_none,
          color: AppColors.statusPending,
        );
      },
    );
  }
}

/// لوحة الانضمام (واجهة الطالب) — تعرض حالة طلب الطلب الحالي وتسمح بإرساله.
class _JoinPanel extends StatefulWidget {
  const _JoinPanel({required this.group});

  final StudyGroup group;

  @override
  State<_JoinPanel> createState() => _JoinPanelState();
}

class _JoinPanelState extends State<_JoinPanel> {
  Future<GroupJoinRequest?>? _future;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<GroupJoinRequest?> _load() {
    final SessionController session = SessionScope.of(context);
    final GroupRepository groups = AppServicesScope.of(context).groups;
    return groups.findMyRequest(
      groupId: widget.group.id,
      studentId: CurrentStudent.idOf(session),
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _sendRequest() async {
    final SessionController session = SessionScope.read(context);
    final GroupRepository groups = AppServicesScope.of(context).groups;
    setState(() => _busy = true);
    try {
      await groups.requestToJoin(
        group: widget.group,
        studentId: CurrentStudent.idOf(session),
        studentName: CurrentStudent.nameOf(session),
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        'أُرسل الطلب إلى المدرس، وستظهر الموافقة هنا.',
        type: AppMessageType.success,
      );
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
        _busy = false;
        _reload();
      }
    }
  }

  Future<void> _cancel(GroupJoinRequest request) async {
    final SessionController session = SessionScope.read(context);
    final GroupRepository groups = AppServicesScope.of(context).groups;
    setState(() => _busy = true);
    try {
      await groups.cancelJoinRequest(
        request: request,
        studentId: CurrentStudent.idOf(session),
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, 'تم إلغاء الطلب.', type: AppMessageType.info);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, error.message, type: AppMessageType.error);
    } finally {
      if (mounted) {
        _busy = false;
        _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GroupJoinRequest?>(
      future: _future,
      builder:
          (BuildContext context, AsyncSnapshot<GroupJoinRequest?> snapshot) {
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // سطر واحد مرن: عنوان اللوحة فقط. شريحة السعة في بطاقة
                  // المجموعة أعلاه، ووضعها هنا مع عنوان طويل يفيض على 360dp.
                  Text(
                    'الانضمام للمجموعة',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: LinearProgressIndicator(minHeight: 3),
                    )
                  else
                    _joinAction(context, snapshot.data),
                  const SizedBox(height: AppSpacing.sm),
                  const InfoNote(
                    text:
                        'المقعد يُحجز لحظة موافقة المدرس فقط، والسعة تُفرض في '
                        'معاملة على الخادم حتى لا يتجاوز العدد الحدّ المعلن.',
                  ),
                ],
              ),
            );
          },
    );
  }

  Widget _joinAction(BuildContext context, GroupJoinRequest? request) {
    // سبب إضافي غير مرتبط بالطلب نفسه (مجموعة موقوفة/مكتملة/أنت المدرس).
    final String? blocked = JoinRules.requestBlockReason(
      group: widget.group,
      viewerId: null,
      existingStatus: request?.status,
    );

    if (request != null && request.isPending) {
      return Row(
        children: <Widget>[
          const Expanded(
            child: Text('طلبك قيد مراجعة المدرس.'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _cancel(request),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      );
    }

    if (request != null && request.status.isAccepted) {
      return const Row(
        children: <Widget>[
          Icon(Icons.verified_outlined, color: AppColors.statusAccepted),
          SizedBox(width: AppSpacing.xs),
          Expanded(child: Text('أنت عضو في هذه المجموعة.')),
        ],
      );
    }

    final bool full = widget.group.isFull || !widget.group.isActive;
    final String label = request != null && request.status.allowsRetry
        ? 'إعادة إرسال الطلب'
        : 'طلب الانضمام';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (blocked != null) ...<Widget>[
          Text(
            blocked,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.statusNeutral,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_busy || full) ? null : _sendRequest,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(label),
          ),
        ),
      ],
    );
  }
}
