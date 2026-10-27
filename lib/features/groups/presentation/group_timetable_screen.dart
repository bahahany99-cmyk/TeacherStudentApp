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
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/group_session.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/schedule_repository.dart';
import 'package:teacher_student_app/data/validation/model_validators.dart';
import 'package:teacher_student_app/data/validation/session_rules.dart';

/// الجدول الأسبوعي للمجموعة (P9).
///
/// - **المدرس صاحب المجموعة:** يضيف ويعدّل ويُلغي المواعيد.
/// - **العضو المقبول:** يقرأ الجدول فقط.
/// - **غير العضو:** رسالة صريحة أن الجدول لأعضاء المجموعة.
///
/// التداخل الزمني يُمنع في الواجهة (رسالة عربية قبل الشبكة) وفي المستودع،
/// والقواعد تتحقق من الحدود لا من التداخل (التداخل يحتاج قراءة كل المواعيد،
/// وهو قرار تجربة استخدام لا قرار أمني).
class GroupTimetableScreen extends StatefulWidget {
  const GroupTimetableScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupTimetableScreen> createState() => _GroupTimetableScreenState();
}

class _GroupTimetableScreenState extends State<GroupTimetableScreen> {
  int _revision = 0;

  void _reload() => setState(() => _revision++);

  Future<_TimetableData> _load() async {
    final SessionController session = SessionScope.read(context);
    final services = AppServicesScope.of(context);
    final StudyGroup? group = await services.groups.findById(widget.groupId);
    if (group == null) {
      throw const AppException.notFound(debugMessage: 'group missing');
    }

    // الهوية حسب الدور: معرّف المدرس لا يصلح للطالب (وفي وضع الزائر يعيد
    // معرّف المدرس التجريبي دائمًا، وهو ما كان سيجعل كل طالب «مالكًا»).
    final bool isTeacherView = session.role == UserRole.teacher;
    final String viewerId = isTeacherView
        ? CurrentTeacher.idOf(session)
        : CurrentStudent.idOf(session);

    final bool isOwner = isTeacherView && group.teacherId == viewerId;
    final bool isMember = isOwner
        ? true
        : await services.groups.isMember(
            groupId: group.id,
            userId: viewerId,
          );

    final List<GroupSession> sessions = isOwner || isMember
        ? await services.schedules.listForGroup(group.id)
        : const <GroupSession>[];

    return _TimetableData(
      group: group,
      sessions: sessions,
      isOwner: isOwner,
      isMember: isMember,
    );
  }

  Future<void> _openForm(_TimetableData data, {GroupSession? session}) async {
    final SessionDraft? draft = await showModalBottomSheet<SessionDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _SessionFormSheet(
        existing: data.sessions,
        session: session,
      ),
    );

    if (draft == null || !mounted) {
      return;
    }

    final ScheduleRepository schedules = AppServicesScope.of(context).schedules;
    final String teacherId = CurrentTeacher.idOf(SessionScope.read(context));
    try {
      if (session == null) {
        await schedules.createSession(
          groupId: data.group.id,
          teacherId: teacherId,
          draft: draft,
        );
      } else {
        await schedules.updateSession(
          session: session,
          teacherId: teacherId,
          draft: draft,
        );
      }
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        session == null ? 'أُضيف الموعد إلى الجدول.' : 'حُدّث الموعد.',
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
        _reload();
      }
    }
  }

  Future<void> _toggleCancelled(
    _TimetableData data,
    GroupSession session,
  ) async {
    final ScheduleRepository schedules = AppServicesScope.of(context).schedules;
    final String teacherId = CurrentTeacher.idOf(SessionScope.read(context));
    try {
      await schedules.setCancelled(
        session: session,
        teacherId: teacherId,
        isCancelled: !session.isCancelled,
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        session.isCancelled ? 'أُعيد تفعيل الموعد.' : 'أُلغي الموعد.',
        type: AppMessageType.info,
      );
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, error.message, type: AppMessageType.error);
    } finally {
      if (mounted) {
        _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('جدول المجموعة')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: AsyncView<_TimetableData>(
                key: ValueKey<int>(_revision),
                load: _load,
                builder: (BuildContext context, _TimetableData data) =>
                    _TimetableBody(
                      data: data,
                      onAdd: () => _openForm(data),
                      onEdit: (GroupSession session) =>
                          _openForm(data, session: session),
                      onToggleCancelled: (GroupSession session) =>
                          _toggleCancelled(data, session),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بيانات الشاشة في كائن واحد: مجموعة + مواعيد + صلاحية العرض.
class _TimetableData {
  const _TimetableData({
    required this.group,
    required this.sessions,
    required this.isOwner,
    required this.isMember,
  });

  final StudyGroup group;
  final List<GroupSession> sessions;
  final bool isOwner;
  final bool isMember;

  bool get canView => isOwner || isMember;
}

class _TimetableBody extends StatelessWidget {
  const _TimetableBody({
    required this.data,
    required this.onAdd,
    required this.onEdit,
    required this.onToggleCancelled,
  });

  final _TimetableData data;
  final VoidCallback onAdd;
  final ValueChanged<GroupSession> onEdit;
  final ValueChanged<GroupSession> onToggleCancelled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (!data.canView) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const DemoBanner(),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('الجدول لأعضاء المجموعة', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'بعد قبول طلب انضمامك سيظهر جدول الحصص هنا، ويمكنك مراسلة '
                  'المدرس وبقية الأعضاء.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () => Navigator.of(context).pushNamed(
                    RoutePaths.groupDetails,
                    arguments: data.group.id,
                  ),
                  child: const Text('عرض المجموعة وإرسال طلب'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final List<MapEntry<GroupWeekday, List<GroupSession>>> days =
        SessionRules.byWeekday(data.sessions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const DemoBanner(),
        AppCard(
          child: Row(
            children: <Widget>[
              Icon(
                Icons.calendar_month_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(data.group.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      SessionRules.weeklySummary(data.sessions),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (data.isOwner)
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إضافة'),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        if (days.isEmpty)
          EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'لا مواعيد في الجدول بعد',
            message: data.isOwner
                ? 'أضف أول موعد ليظهر لجميع أعضاء المجموعة.'
                : 'سيظهر الجدول هنا بعد أن ينشره المدرس.',
            actionLabel: data.isOwner ? 'إضافة موعد' : null,
            onActionTap: data.isOwner ? onAdd : null,
          )
        else
          for (final MapEntry<GroupWeekday, List<GroupSession>> day in days)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SectionHeader(
                    title: day.key.label,
                    subtitle:
                        '${day.value.where((GroupSession s) => !s.isCancelled).length} حصة',
                    icon: Icons.today_outlined,
                  ),
                  for (final GroupSession session in day.value)
                    Padding(
                      padding: AppSpacing.listGap,
                      child: _SessionCard(
                        session: session,
                        isOwner: data.isOwner,
                        onEdit: () => onEdit(session),
                        onToggleCancelled: () => onToggleCancelled(session),
                      ),
                    ),
                ],
              ),
            ),
        const SizedBox(height: AppSpacing.sm),
        InfoNote(
          text: data.isOwner
              ? 'الجدول أسبوعي متكرر: إلغاء موعد يُبقيه في السجل بوسم «ملغاة» '
                    'بدل حذفه، فلا يضيع سجل الحصص.'
              : 'الجدول ينشره المدرس، وأي تعديل يظهر عند فتح الشاشة من جديد.',
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.isOwner,
    required this.onEdit,
    required this.onToggleCancelled,
  });

  final GroupSession session;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onToggleCancelled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool cancelled = session.isCancelled;

    return AppCard(
      onTap: isOwner ? onEdit : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  session.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cancelled
                        ? theme.colorScheme.onSurfaceVariant
                        : AppColors.textPrimary,
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (cancelled)
                const StatusChip(label: 'ملغاة', color: AppColors.statusNeutral),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xxs,
            children: <Widget>[
              PillChip(
                label: SessionRules.formatMinutes(session.startMinutes),
                icon: Icons.play_circle_outline,
                dense: true,
              ),
              PillChip(
                label: SessionRules.formatDuration(session.durationMinutes),
                icon: Icons.timelapse_outlined,
                dense: true,
              ),
              if (session.locationNote != null)
                PillChip(
                  label: session.locationNote!,
                  icon: Icons.place_outlined,
                  dense: true,
                ),
            ],
          ),
          if (isOwner) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xxs,
              children: <Widget>[
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('تعديل'),
                ),
                TextButton.icon(
                  onPressed: onToggleCancelled,
                  icon: Icon(
                    cancelled ? Icons.event_available : Icons.event_busy,
                    size: 18,
                  ),
                  label: Text(cancelled ? 'إعادة تفعيل' : 'إلغاء الموعد'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// نموذج إضافة/تعديل موعد — ورقة سفلية تعيد [SessionDraft] عند الحفظ.
class _SessionFormSheet extends StatefulWidget {
  const _SessionFormSheet({required this.existing, this.session});

  final List<GroupSession> existing;
  final GroupSession? session;

  @override
  State<_SessionFormSheet> createState() => _SessionFormSheetState();
}

class _SessionFormSheetState extends State<_SessionFormSheet> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late SessionDraft _draft;
  String? _error;

  @override
  void initState() {
    super.initState();
    final GroupSession? session = widget.session;
    _draft = session == null
        ? SessionDraft.empty()
        : SessionDraft.fromSession(session);
    _title = TextEditingController(text: _draft.title);
    _location = TextEditingController(text: _draft.locationNote ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _draft.startMinutes ~/ 60,
        minute: _draft.startMinutes % 60,
      ),
      helpText: 'بداية الحصة',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(startMinutes: picked.hour * 60 + picked.minute);
      _error = null;
    });
  }

  void _save() {
    final SessionDraft candidate = _draft.copyWith(
      title: _title.text,
      locationNote: _location.text,
    );

    final String? conflict = SessionRules.conflictMessage(
      candidate,
      widget.existing,
      ignoreSessionId: widget.session?.id,
    );
    if (conflict != null) {
      setState(() => _error = conflict);
      return;
    }

    final ValidationResult result = SessionRules.validateDraft(
      candidate,
      existing: widget.existing,
      ignoreSessionId: widget.session?.id,
    );
    if (!result.isValid) {
      setState(() {
        _error = _messageFor(result.problems.first.field);
      });
      return;
    }

    Navigator.of(context).pop(candidate);
  }

  String _messageFor(String field) {
    return switch (field) {
      'title' => 'عنوان الحصة من 3 إلى 60 حرفًا.',
      'startMinutes' => 'وقت البداية يجب أن يكون قبل 11 مساءً.',
      'durationMinutes' => 'المدة بين 15 و240 دقيقة، ولا تعبر منتصف الليل.',
      'locationNote' => 'مكان الحصة لا يزيد عن 60 حرفًا.',
      _ => 'تحقّق من بيانات الموعد.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
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
              Text(
                widget.session == null ? 'موعد جديد' : 'تعديل الموعد',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'عنوان الحصة',
                  hintText: 'مثال: التفاضل — مراجعة',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('اليوم', style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              PillRow(
                children: <Widget>[
                  for (final GroupWeekday day in GroupWeekday.values)
                    PillChip(
                      label: day.label,
                      selected: _draft.weekday == day,
                      onTap: () => setState(() {
                        _draft = _draft.copyWith(weekday: day);
                        _error = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_outlined, size: 18),
                      label: Text(SessionRules.formatMinutes(_draft.startMinutes)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('المدة', style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              PillRow(
                children: <Widget>[
                  for (final int minutes in SessionRules.durationOptions)
                    PillChip(
                      label: SessionRules.formatDuration(minutes),
                      selected: _draft.durationMinutes == minutes,
                      onTap: () => setState(() {
                        _draft = _draft.copyWith(durationMinutes: minutes);
                        _error = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'المكان (اختياري)',
                  hintText: 'سنتر المعادي، أو رابط الحصة',
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.statusRejected,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _save,
                child: Text(widget.session == null ? 'إضافة الموعد' : 'حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
