import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';
import 'package:teacher_student_app/data/validation/group_rules.dart';
import 'package:teacher_student_app/data/validation/model_validators.dart';

/// إنشاء مجموعة دراسية جديدة أو تعديل مجموعة قائمة (P7).
///
/// قواعد العمل المنفَّذة:
/// - السعة بين [GroupRules.minSeats] و[GroupRules.maxSeats] (2..50).
/// - عند التعديل **لا يمكن** تقليل السعة تحت عدد المنضمين فعلًا.
/// - المجموعة يمكن إيقافها (`isActive = false`) بدل حذفها، فتُخفى عن الطلاب
///   ويبقى سجل أعضائها.
/// - الموعد في هذه المرحلة **وصف نصي** فقط (الجدولة الحقيقية مؤجلة — Q-13)،
///   بطول محدود يُفحص هنا وفي القواعد.
///
/// ⚠️ كل ما سبق يُفرض أيضًا على الخادم؛ هذا التحقق لتجربة أفضل ورسالة أوضح.
class GroupFormScreen extends StatefulWidget {
  const GroupFormScreen({super.key, this.groupId});

  /// `null` = إنشاء جديد.
  final String? groupId;

  bool get isEditing => groupId != null;

  @override
  State<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends State<GroupFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _title = TextEditingController();
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _stage = TextEditingController();
  final TextEditingController _schedule = TextEditingController();

  GroupMeetingMode _meetingMode = GroupMeetingMode.online;
  int _seats = 10;
  bool _isActive = true;

  /// المجموعة الأصلية عند التعديل (تُستخدم للسعة المشغولة والتحقق).
  StudyGroup? _original;
  bool _loading = false;
  bool _saving = false;
  String? _formError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isEditing && _original == null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    final StudyGroup? group = await AppServicesScope.of(
      context,
    ).groups.findById(widget.groupId!);
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _original = group;
      if (group != null) {
        _title.text = group.title;
        _subject.text = group.subject;
        _stage.text = group.stage;
        _schedule.text = group.scheduleNote ?? '';
        _meetingMode = group.meetingMode;
        _seats = group.seatsTotal;
        _isActive = group.isActive;
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _stage.dispose();
    _schedule.dispose();
    super.dispose();
  }

  GroupDraft get _draft => GroupDraft(
    title: _title.text,
    subject: _subject.text,
    stage: _stage.text,
    meetingMode: _meetingMode,
    seatsTotal: _seats,
    scheduleNote: _schedule.text,
  );

  int get _seatsTaken => _original?.seatsTaken ?? 0;

  /// أقل سعة مسموحة الآن: 2 للإنشاء، وعدد المنضمين عند التعديل.
  int get _minSeats => GroupRules.minAllowedSeats(_seatsTaken);

  Future<void> _save() async {
    setState(() => _formError = null);

    final bool fieldsValid = _formKey.currentState?.validate() ?? false;
    final ValidationResult result = GroupRules.validateDraft(
      _draft,
      seatsTaken: _seatsTaken,
    );

    if (!fieldsValid || !result.isValid) {
      setState(() {
        _formError =
            result.firstMessage ?? 'تحقّق من الحقول المعلَّمة ثم أعد المحاولة.';
      });
      return;
    }

    setState(() => _saving = true);
    final String teacherId = CurrentTeacher.idOf(SessionScope.read(context));
    final String teacherName = CurrentTeacher.nameOf(
      SessionScope.read(context),
    );

    try {
      final GroupRepository groups = AppServicesScope.of(context).groups;
      if (widget.isEditing) {
        await groups.updateGroup(
          groupId: widget.groupId!,
          teacherId: teacherId,
          draft: _draft,
          isActive: _isActive,
        );
      } else {
        await groups.createGroup(
          teacherId: teacherId,
          teacherName: teacherName,
          draft: _draft,
        );
      }
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        widget.isEditing ? 'تم حفظ تعديلات المجموعة.' : 'تم إنشاء المجموعة.',
        type: AppMessageType.success,
      );
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _formError = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('المجموعة')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.isEditing && _original == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('المجموعة')),
        body: const EmptyState(
          icon: Icons.groups_outlined,
          title: 'المجموعة غير موجودة',
          message: 'ربما حُذفت أو تغيّر الرابط.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'تعديل المجموعة' : 'مجموعة جديدة'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              ResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    const SectionHeader(
                      title: 'بيانات المجموعة',
                      subtitle: 'تظهر للطلاب في صفحة الاستكشاف بعد الحفظ',
                      icon: Icons.groups_outlined,
                    ),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            controller: _title,
                            textInputAction: TextInputAction.next,
                            maxLength: ModelLimits.groupTitle,
                            decoration: const InputDecoration(
                              labelText: 'عنوان المجموعة',
                              hintText: 'مثال: التفاضل والتكامل — مجموعة السبت',
                              prefixIcon: Icon(Icons.title),
                            ),
                            validator: (String? value) => _firstIssue(
                              validateGroupDraft(
                                title: value,
                                subject: _subject.text,
                                stage: _stage.text,
                                seatsTotal: _seats,
                                scheduleNote: _schedule.text,
                              ),
                              'title',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          TextFormField(
                            controller: _subject,
                            textInputAction: TextInputAction.next,
                            maxLength: ModelLimits.subject,
                            decoration: const InputDecoration(
                              labelText: 'المادة',
                              prefixIcon: Icon(Icons.menu_book_outlined),
                            ),
                            validator: (String? value) => _firstIssue(
                              validateGroupDraft(
                                title: _title.text,
                                subject: value,
                                stage: _stage.text,
                                seatsTotal: _seats,
                                scheduleNote: _schedule.text,
                              ),
                              'subject',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          TextFormField(
                            controller: _stage,
                            textInputAction: TextInputAction.next,
                            maxLength: ModelLimits.stage,
                            decoration: const InputDecoration(
                              labelText: 'المرحلة الدراسية',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            validator: (String? value) => _firstIssue(
                              validateGroupDraft(
                                title: _title.text,
                                subject: _subject.text,
                                stage: value,
                                seatsTotal: _seats,
                                scheduleNote: _schedule.text,
                              ),
                              'stage',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),

                    // ── السعة ──────────────────────────────────────────────
                    const SectionHeader(
                      title: 'السعة',
                      subtitle: 'بين 2 و50 مقعدًا · لا تقل عن عدد المنضمين',
                      icon: Icons.event_seat_outlined,
                    ),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'عدد المقاعد',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              _SeatStepper(
                                value: _seats,
                                min: _minSeats,
                                max: GroupRules.maxSeats,
                                onChanged: (int value) {
                                  setState(() => _seats = value);
                                  _formKey.currentState?.validate();
                                },
                              ),
                            ],
                          ),
                          if (_original != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              GroupRules.capacitySummary(_original!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (_seatsTaken > 0) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            InfoNote(
                              icon: Icons.lock_outline,
                              text:
                                  'لديك $_seatsTaken عضوًا منضمًا؛ لا يمكن '
                                  'تقليل السعة عنهم. إدارة الأعضاء في شاشة '
                                  'الأعضاء.',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),

                    // ── طريقة الحضور ───────────────────────────────────────
                    const SectionHeader(
                      title: 'طريقة الحضور',
                      subtitle: 'اختر واحدة',
                      icon: Icons.place_outlined,
                    ),
                    PillRow(
                      children: <Widget>[
                        for (final GroupMeetingMode mode
                            in GroupMeetingMode.values)
                          PillChip(
                            label: mode.label,
                            selected: _meetingMode == mode,
                            icon: _iconFor(mode),
                            onTap: () => setState(() => _meetingMode = mode),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),

                    // ── الموعد ────────────────────────────────────────────
                    const SectionHeader(
                      title: 'الموعد',
                      subtitle: 'وصف نصي الآن — الجدولة الأسبوعية في مرحلة قادمة',
                      icon: Icons.schedule_outlined,
                    ),
                    AppCard(
                      child: TextFormField(
                        controller: _schedule,
                        maxLength: ModelLimits.scheduleNote,
                        maxLines: 2,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'الموعد (اختياري)',
                          hintText: 'مثال: السبت والثلاثاء 5 مساءً',
                          prefixIcon: Icon(Icons.schedule_outlined),
                        ),
                        validator: (String? value) => _firstIssue(
                          validateGroupDraft(
                            title: _title.text,
                            subject: _subject.text,
                            stage: _stage.text,
                            seatsTotal: _seats,
                            scheduleNote: value,
                          ),
                          'scheduleNote',
                        ),
                      ),
                    ),

                    if (widget.isEditing) ...<Widget>[
                      const SizedBox(height: AppSpacing.sectionGap),
                      const SectionHeader(
                        title: 'حالة النشر',
                        subtitle: 'الإيقاف يخفي المجموعة دون حذف أعضائها',
                        icon: Icons.visibility_outlined,
                      ),
                      AppCard(
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _isActive,
                          onChanged: (bool value) =>
                              setState(() => _isActive = value),
                          title: Text(
                            _isActive ? 'منشورة للطلاب' : 'موقوفة',
                            style: theme.textTheme.titleSmall,
                          ),
                          subtitle: Text(
                            _isActive
                                ? 'تظهر في الاستكشاف وتقبل الطلبات.'
                                : 'مخفية عن الطلاب، ويبقى سجل الأعضاء.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (_formError != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      // رسالة الخطأ بنفس مكوّن الملاحظات: لا نمط جديد لخطأ واحد.
                      InfoNote(icon: Icons.error_outline, text: _formError!),
                    ],

                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.isEditing
                                  ? 'حفظ التعديلات'
                                  : 'إنشاء المجموعة',
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InfoNote(
                      icon: Icons.cloud_off_outlined,
                      text: SessionScope.of(context).isDemoSession
                          ? 'وضع الزائر: يُحفظ التغيير في الذاكرة المحلية فقط '
                                'ويُفقد عند إغلاق التطبيق.'
                          : 'يُحفظ التغيير في الخادم؛ وقواعد الأمان ترفض أي '
                                'تعديل من غير صاحب المجموعة.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// رسالة أول مشكلة تخص حقلًا واحدًا، أو `null` إن كان سليمًا.
  String? _firstIssue(ValidationResult result, String field) {
    for (final ValidationProblem problem in result.problems) {
      if (problem.field == field) {
        return problem.issue == FieldIssue.missing
            ? 'هذا الحقل مطلوب.'
            : problem.issue == FieldIssue.tooShort
            ? 'أدخل 3 أحرف على الأقل.'
            : problem.issue == FieldIssue.tooLong
            ? 'تجاوزت الطول المسموح.'
            : 'قيمة غير صالحة.';
      }
    }
    return null;
  }

  IconData _iconFor(GroupMeetingMode mode) => switch (mode) {
    GroupMeetingMode.online => Icons.videocam_outlined,
    GroupMeetingMode.home => Icons.home_outlined,
    GroupMeetingMode.center => Icons.location_on_outlined,
  };
}

/// زر زيادة/إنقاص المقاعد — بدون كتابة يدوية (يمنع قيمًا غريبة).
class _SeatStepper extends StatelessWidget {
  const _SeatStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StepButton(
          icon: Icons.remove,
          enabled: value > min,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(value - 1);
          },
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 44),
          alignment: Alignment.center,
          child: Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          enabled: value < max,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(value + 1);
          },
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 18),
      tooltip: icon == Icons.add ? 'زيادة' : 'إنقاص',
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.primary.withAlpha(enabled ? 20 : 8),
        foregroundColor: theme.colorScheme.primary,
        minimumSize: const Size(38, 38),
        shape: const CircleBorder(),
      ),
    );
  }
}
