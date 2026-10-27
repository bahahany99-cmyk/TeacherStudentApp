import 'package:flutter/material.dart';

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
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/group_waitlist_entry.dart';
import 'package:teacher_student_app/data/models/member_move.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';
import 'package:teacher_student_app/data/validation/group_rules.dart';
import 'package:teacher_student_app/data/validation/move_rules.dart';
import 'package:teacher_student_app/data/validation/waitlist_rules.dart';

/// أعضاء المجموعة وإدارتها (P9) — واجهة المدرس صاحب المجموعة.
///
/// ثلاث أدوات في شاشة واحدة لأنها تُستخدم معًا في القرار نفسه:
/// 1. **قائمة الأعضاء** بعدّاد سعة حقيقي (لا تقدير من الواجهة).
/// 2. **إزالة عضو** — تُحرّر المقعد في المعاملة نفسها، فيصبح المقعد متاحًا
///    لقبول منتظر. لا حذف نهائي للبيانات: السجل يبقى في الطلبات.
/// 3. **قائمة الانتظار** بترتيبها الزمني، وقبول أول المنتظرين عند تحرر مقعد.
///
/// الإزالة والقبول **لا يُنفَّذان على بيانات الشاشة**: كلاهما يمرّ بمعاملة
/// تقرأ المجموعة طازجة. الشاشة تعرض، والقاعدة تحكم.
class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final TextEditingController _search = TextEditingController();
  int _revision = 0;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _revision++);

  Future<_MembersData> _load() async {
    final SessionController session = SessionScope.read(context);
    final services = AppServicesScope.of(context);

    final StudyGroup? group = await services.groups.findById(widget.groupId);
    if (group == null) {
      throw const AppException.notFound(debugMessage: 'group missing');
    }

    final bool isTeacherView = session.role == UserRole.teacher;
    final String viewerId = isTeacherView
        ? CurrentTeacher.idOf(session)
        : '';
    final bool isOwner = isTeacherView && group.teacherId == viewerId;

    final List<GroupMember> members = isOwner
        ? await services.groups.listMembers(group.id)
        : const <GroupMember>[];

    final List<GroupWaitlistEntry> waitlist = isOwner
        ? await services.groups.listWaitlist(
            group.id,
            teacherId: group.teacherId,
          )
        : const <GroupWaitlistEntry>[];

    // مجموعات المدرس نفسه — هي وحدها أهداف النقل المسموحة.
    final List<StudyGroup> ownedGroups = isOwner
        ? await services.groups.listForTeacher(group.teacherId)
        : const <StudyGroup>[];

    return _MembersData(
      group: group,
      teacherId: viewerId,
      members: members,
      waitlist: waitlist,
      ownedGroups: ownedGroups,
      isOwner: isOwner,
    );
  }

  Future<void> _removeMember(_MembersData data, GroupMember member) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('إزالة عضو'),
        content: Text(
          'سيُزال «${member.name}» من المجموعة ويُحرَّر مقعده. '
          'سجل طلب انضمامه يبقى في الطلبات.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final GroupRepository groups = AppServicesScope.of(context).groups;
    setState(() => _busy = true);
    try {
      await groups.removeMember(
        groupId: data.group.id,
        memberId: member.id,
        teacherId: data.teacherId,
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        'أُزيل العضو وتحرّر مقعد.',
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

  Future<void> _promote(_MembersData data, GroupWaitlistEntry entry) async {
    final GroupRepository groups = AppServicesScope.of(context).groups;
    setState(() => _busy = true);
    try {
      await groups.promoteFromWaitlist(
        entry: entry,
        teacherId: data.teacherId,
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        'قُبل «${entry.studentName}» وأصبح عضوًا بمقعد.',
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

  /// ورقة اختيار المجموعة الهدف ثم تنفيذ النقل.
  ///
  /// الهدف المكتمل **يُعرض** مع سبب الرفض بدل إخفائه: المدرس يرى لماذا لا
  /// يستطيع النقل، والضغط عليه يعطي التنبيه الصريح نفسه الذي ترفعه القاعدة.
  Future<void> _moveMember(_MembersData data, GroupMember member) async {
    final List<StudyGroup> targets = MoveRules.targets(
      from: data.group,
      ownedGroups: data.ownedGroups,
    );
    if (targets.isEmpty) {
      AppSnackBar.show(
        context,
        'لا توجد مجموعة أخرى لنقل العضو إليها.',
        type: AppMessageType.warning,
      );
      return;
    }

    final String? targetId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _MoveSheet(
        member: member,
        source: data.group,
        targets: targets,
      ),
    );
    if (targetId == null || !mounted) {
      return;
    }

    final GroupRepository groups = AppServicesScope.of(context).groups;
    setState(() => _busy = true);
    try {
      final MemberMove move = await groups.moveMember(
        memberId: member.id,
        fromGroupId: data.group.id,
        toGroupId: targetId,
        teacherId: data.teacherId,
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        'نُقل «${move.member.name}» إلى «${move.to.title}»'
        '${move.summary}',
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

  /// تعديل سعة المجموعة — الحد الأقصى [GroupRules.maxSeats] ولا تقل عن المنضمين.
  Future<void> _editCapacity(_MembersData data) async {
    final int? seatsTotal = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _CapacitySheet(group: data.group),
    );
    if (seatsTotal == null || !mounted) {
      return;
    }

    final GroupRepository groups = AppServicesScope.of(context).groups;
    setState(() => _busy = true);
    try {
      await groups.updateGroupCapacity(
        groupId: data.group.id,
        teacherId: data.teacherId,
        seatsTotal: seatsTotal,
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        'حُدّثت السعة إلى $seatsTotal مقعدًا.',
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

  String _formatDate(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // شفاف لعرض الخلفية العالمية (v4.2): الأبيض للصفحة، والتدرّج شريط علوي.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('أعضاء المجموعة')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: AsyncView<_MembersData>(
                key: ValueKey<int>(_revision),
                load: _load,
                builder: (BuildContext context, _MembersData data) {
                  if (!data.isOwner) {
                    return const EmptyState(
                      icon: Icons.lock_outline,
                      title: 'الأعضاء لصاحب المجموعة',
                      message:
                          'قائمة الأعضاء وإدارتها تظهر للمدرس صاحب المجموعة '
                          'فقط. الطالب لا يرى أسماء بقية الطلاب.',
                    );
                  }
                  return _body(context, data);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, _MembersData data) {
    final ThemeData theme = Theme.of(context);
    final StudyGroup group = data.group;
    final String needle = _search.text.trim();
    final List<GroupMember> visible = needle.isEmpty
        ? data.members
        : data.members
              .where((GroupMember m) => m.name.contains(needle))
              .toList(growable: false);
    final List<GroupWaitlistEntry> waiting = WaitlistRules.waitingOnly(
      data.waitlist,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const DemoBanner(),

        // ── بطاقة السعة ─────────────────────────────────────────────────────
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      group.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  StatusChip(
                    label: group.isFull ? 'مكتملة' : 'فيها مقعد',
                    color: group.isFull
                        ? AppColors.statusRejected
                        : AppColors.statusAccepted,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              PillRow(
                children: <Widget>[
                  PillChip(
                    label: '${group.seatsTaken} / ${group.seatsTotal} مقعد',
                    icon: Icons.event_seat_outlined,
                    dense: true,
                  ),
                  PillChip(
                    label: '${group.seatsAvailable} متاح',
                    icon: Icons.check_circle_outline,
                    dense: true,
                  ),
                  PillChip(
                    label: '${waiting.length} منتظر',
                    icon: Icons.hourglass_empty,
                    dense: true,
                    color: waiting.isEmpty ? null : AppColors.statusPending,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                WaitlistRules.summaryLine(
                  waiting: waiting.length,
                  seatsAvailable: group.seatsAvailable,
                ),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _editCapacity(data),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('تعديل السعة'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        // ── الأعضاء ─────────────────────────────────────────────────────────
        SectionHeader(
          title: 'الأعضاء',
          subtitle: '${data.members.length} عضوًا يشغلون مقاعدهم',
          icon: Icons.groups_2_outlined,
        ),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'ابحث باسم الطالب',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (visible.isEmpty)
          EmptyState(
            icon: needle.isEmpty
                ? Icons.person_add_alt_outlined
                : Icons.search_off,
            title: needle.isEmpty ? 'لا يوجد أعضاء بعد' : 'لا نتائج',
            message: needle.isEmpty
                ? 'قبول طلب انضمام يضيف العضو ويشغل مقعدًا.'
                : 'لا طالب بهذا الاسم في المجموعة.',
          )
        else
          for (final GroupMember member in visible)
            Padding(
              padding: AppSpacing.listGap,
              child: AppCard(
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: AppSpacing.avatarSm / 2,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(member.initials),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            member.name,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'انضم في ${_formatDate(member.joinedAt)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (member.wasMoved) ...<Widget>[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'نُقل من '
                              '«${member.movedFromGroupTitle ?? 'مجموعة أخرى'}» '
                              'في ${_formatDate(member.movedAt!)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'نقل إلى مجموعة أخرى',
                      onPressed: _busy ? null : () => _moveMember(data, member),
                      icon: const Icon(Icons.swap_horiz, size: 20),
                      color: theme.colorScheme.primary,
                    ),
                    IconButton(
                      tooltip: 'إزالة العضو',
                      onPressed: _busy
                          ? null
                          : () => _removeMember(data, member),
                      icon: const Icon(Icons.person_remove_outlined, size: 20),
                      color: AppColors.statusRejected,
                    ),
                  ],
                ),
              ),
            ),

        const SizedBox(height: AppSpacing.sectionGap),

        // ── قائمة الانتظار ──────────────────────────────────────────────────
        const SectionHeader(
          title: 'قائمة الانتظار',
          subtitle: 'الترتيب حسب وقت الانضمام — الأقدم أولًا',
          icon: Icons.hourglass_empty,
        ),
        if (data.waitlist.isEmpty)
          const EmptyState(
            icon: Icons.hourglass_disabled_outlined,
            title: 'لا أحد في قائمة الانتظار',
            message: 'عند اكتمال المجموعة يدخلها من يطلب الانضمام.',
          )
        else
          for (int index = 0; index < data.waitlist.length; index++)
            Padding(
              padding: AppSpacing.listGap,
              child: _WaitlistCard(
                entry: data.waitlist[index],
                position: index + 1,
                seatsAvailable: group.seatsAvailable,
                canPromote: !_busy,
                onPromote: () => _promote(data, data.waitlist[index]),
                joinedLabel: _formatDate(data.waitlist[index].addedAt),
              ),
            ),

        const SizedBox(height: AppSpacing.sm),
        const InfoNote(
          text:
              'الإزالة وقبول المنتظر يحدثان في معاملة واحدة على الخادم: '
              'أنقص/أزد مقعدًا واحدًا وغيّر العضوية معًا، فلا يبقى مقعد '
              'محسوبًا بلا عضو ولا عضو بلا مقعد. لا إشعار تلقائي للمنتظر في '
              'هذه المرحلة — القبول يدوي.',
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// بيانات شاشة الأعضاء في كائن واحد.
class _MembersData {
  const _MembersData({
    required this.group,
    required this.teacherId,
    required this.members,
    required this.waitlist,
    required this.ownedGroups,
    required this.isOwner,
  });

  final StudyGroup group;
  final String teacherId;
  final List<GroupMember> members;
  final List<GroupWaitlistEntry> waitlist;

  /// كل مجموعات المدرس — أهداف النقل المحتملة.
  final List<StudyGroup> ownedGroups;
  final bool isOwner;
}

/// صف قائمة انتظار: الموضع والاسم وحالة الصف وزر القبول.
class _WaitlistCard extends StatelessWidget {
  const _WaitlistCard({
    required this.entry,
    required this.position,
    required this.seatsAvailable,
    required this.canPromote,
    required this.onPromote,
    required this.joinedLabel,
  });

  final GroupWaitlistEntry entry;
  final int position;
  final int seatsAvailable;
  final bool canPromote;
  final VoidCallback onPromote;
  final String joinedLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool waiting = entry.isWaiting;
    final bool canAccept = waiting && seatsAvailable > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: AppSpacing.avatarSm / 2 - 2,
                backgroundColor: waiting
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHigh,
                child: Text(
                  waiting ? '$position' : '•',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.studentName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      waiting
                          ? 'في الانتظار منذ $joinedLabel'
                          : entry.status.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: waiting ? 'منتظر' : entry.status.label,
                color: waiting
                    ? AppColors.statusPending
                    : AppColors.statusNeutral,
              ),
            ],
          ),
          if (waiting) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton(
                onPressed: (canAccept && canPromote) ? onPromote : null,
                child: Text(
                  seatsAvailable > 0
                      ? 'قبول ومنح مقعد'
                      : 'لا مقعد متاح',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ورقة اختيار المجموعة الهدف للنقل.
///
/// كل مجموعة تظهر مع سعتها؛ والمكتملة تُعرض مع السبب **وتُعيد رفضًا صريحًا**
/// عند الضغط (`MoveRules.targetFullMessage`)، ولا تُستدعى المعاملة أصلًا.
class _MoveSheet extends StatelessWidget {
  const _MoveSheet({
    required this.member,
    required this.source,
    required this.targets,
  });

  final GroupMember member;
  final StudyGroup source;
  final List<StudyGroup> targets;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.pageGutter,
        AppSpacing.md,
        AppSpacing.pageGutter,
        AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('نقل العضو', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '«${member.name}» من «${source.title}» إلى:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final StudyGroup target in targets)
              Padding(
                padding: AppSpacing.listGap,
                child: _MoveTargetTile(
                  target: target,
                  onTap: () {
                    final String? blocked = MoveRules.targetBlockReason(target);
                    if (blocked != null) {
                      AppSnackBar.show(
                        context,
                        blocked,
                        type: AppMessageType.error,
                      );
                      return;
                    }
                    Navigator.of(context).pop(target.id);
                  },
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            const InfoNote(
              text:
                  'النقل يحدث في معاملة واحدة: مقعد ينقص في المجموعة الحالية، '
                  'ومقعد يزيد في الجديدة، وارتباط العضو ينتقل معه. المجموعة '
                  'المكتملة لا تستقبل نقلًا، ولا تُوسّع سعتها تلقائيًا.',
            ),
          ],
        ),
      ),
    );
  }
}

/// صف هدف نقل: العنوان والسعة وحالة القبول.
class _MoveTargetTile extends StatelessWidget {
  const _MoveTargetTile({required this.target, required this.onTap});

  final StudyGroup target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? blocked = MoveRules.targetBlockReason(target);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(
            blocked == null ? Icons.swap_horiz : Icons.block,
            color: blocked == null
                ? theme.colorScheme.primary
                : AppColors.statusRejected,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  target.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  blocked ?? '${target.seatsAvailable} مقعد متاح',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: blocked == null
                        ? theme.colorScheme.onSurfaceVariant
                        : AppColors.statusRejected,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          PillChip(
            label: '${target.seatsTaken} / ${target.seatsTotal}',
            dense: true,
            color: blocked == null ? null : AppColors.statusRejected,
          ),
        ],
      ),
    );
  }
}

/// ورقة تعديل السعة — الحد الأقصى [GroupRules.maxSeats] والأرضية عدد المنضمين.
class _CapacitySheet extends StatefulWidget {
  const _CapacitySheet({required this.group});

  final StudyGroup group;

  @override
  State<_CapacitySheet> createState() => _CapacitySheetState();
}

class _CapacitySheetState extends State<_CapacitySheet> {
  late int _seats = widget.group.seatsTotal;

  /// الأرضية: عدد المنضمين (ولا تقل عن حدّ المجموعة الأدنى).
  int get _min => GroupRules.minAllowedSeats(widget.group.seatsTaken);

  String? get _error => GroupRules.capacityBlockReason(
    seatsTotal: _seats,
    seatsTaken: widget.group.seatsTaken,
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.pageGutter,
        AppSpacing.md,
        AppSpacing.pageGutter,
        AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('سعة المجموعة', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'بين ${GroupRules.minSeats} و${GroupRules.maxSeats} مقعدًا، '
              'ولا تقل عن ${widget.group.seatsTaken} منضمًا حاليًا.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'عدد المقاعد',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'تقليل',
                  onPressed: _seats > _min
                      ? () => setState(() => _seats--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_seats',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: 'زيادة',
                  onPressed: _seats < GroupRules.maxSeats
                      ? () => setState(() => _seats++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                _error!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.statusRejected,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: _error != null
                  ? null
                  : () => Navigator.of(context).pop(_seats),
              child: const Text('حفظ السعة'),
            ),
          ],
        ),
      ),
    );
  }
}
