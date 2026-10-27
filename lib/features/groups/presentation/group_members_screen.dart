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
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';
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

    return _MembersData(
      group: group,
      teacherId: viewerId,
      members: members,
      waitlist: waitlist,
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
                        ],
                      ),
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
    required this.isOwner,
  });

  final StudyGroup group;
  final String teacherId;
  final List<GroupMember> members;
  final List<GroupWaitlistEntry> waitlist;
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
