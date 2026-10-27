import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/data/models/group_filter.dart';
import 'package:teacher_student_app/data/models/study_group.dart';

/// شريط فلاتر الاستكشاف (P9).
///
/// **قاعدة بصرية من v3:** كل فلتر «حبة» في صف أفقي قابل للتمرير، ولا قوائم
/// منسدلة ولا لوحة فلاتر منبثقة — أقل نقرات وأوضح حالة: الحبة المختارة تُلوَّن.
///
/// المكوّن عرض فقط: يستقبل الفلتر الحالي ويعيد الفلتر الجديد عبر [onChanged]،
/// فلا يعرف مستودعًا ولا حالة.
class GroupFilterBar extends StatefulWidget {
  const GroupFilterBar({
    super.key,
    required this.filter,
    required this.subjectOptions,
    required this.stageOptions,
    required this.resultLabel,
    required this.onChanged,
  });

  final GroupFilter filter;

  /// خيارات مشتقة من البيانات المعروضة (لا قائمة نظرية).
  final List<String> subjectOptions;
  final List<String> stageOptions;

  /// «3 من 12 مجموعة» — يظهر بجانب عنوان القسم.
  final String resultLabel;

  final ValueChanged<GroupFilter> onChanged;

  @override
  State<GroupFilterBar> createState() => _GroupFilterBarState();
}

class _GroupFilterBarState extends State<GroupFilterBar> {
  late final TextEditingController _query = TextEditingController(
    text: widget.filter.query,
  );

  @override
  void didUpdateWidget(GroupFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // «تفريغ الفلاتر» من الخارج يجب أن يفرّغ الحقل أيضًا.
    if (widget.filter.query != _query.text &&
        widget.filter.query != oldWidget.filter.query) {
      _query.text = widget.filter.query;
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _pickedSubject(String subject) {
    final bool isSelected = widget.filter.subject == subject;
    widget.onChanged(
      widget.filter.copyWith(subject: isSelected ? null : subject),
    );
  }

  void _pickedStage(String stage) {
    final bool isSelected = widget.filter.stage == stage;
    widget.onChanged(widget.filter.copyWith(stage: isSelected ? null : stage));
  }

  void _pickedMode(GroupMeetingMode mode) {
    final bool isSelected = widget.filter.meetingMode == mode;
    widget.onChanged(
      widget.filter.copyWith(meetingMode: isSelected ? null : mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('استكشف المجموعات', style: theme.textTheme.titleSmall),
              ),
              PillChip(
                label: widget.resultLabel,
                icon: Icons.groups_outlined,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onChanged: (String value) =>
                widget.onChanged(widget.filter.copyWith(query: value)),
            decoration: InputDecoration(
              hintText: 'ابحث بالمادة أو المدرس أو المرحلة',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: widget.filter.query.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _query.clear();
                        widget.onChanged(widget.filter.copyWith(query: ''));
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
            ),
          ),
          if (widget.subjectOptions.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text('المادة', style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpacing.xxs),
            PillRow(
              children: <Widget>[
                for (final String subject in widget.subjectOptions)
                  PillChip(
                    label: subject,
                    selected: widget.filter.subject == subject,
                    onTap: () => _pickedSubject(subject),
                  ),
              ],
            ),
          ],
          if (widget.stageOptions.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text('المرحلة', style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpacing.xxs),
            PillRow(
              children: <Widget>[
                for (final String stage in widget.stageOptions)
                  PillChip(
                    label: stage,
                    selected: widget.filter.stage == stage,
                    onTap: () => _pickedStage(stage),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text('طريقة الحضور', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xxs),
          PillRow(
            children: <Widget>[
              for (final GroupMeetingMode mode in GroupMeetingMode.values)
                PillChip(
                  label: mode.label,
                  selected: widget.filter.meetingMode == mode,
                  onTap: () => _pickedMode(mode),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('المقاعد', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xxs),
          PillRow(
            children: <Widget>[
              for (final GroupAvailability availability
                  in GroupAvailability.values)
                PillChip(
                  label: availability.label,
                  selected: widget.filter.availability == availability,
                  onTap: () => widget.onChanged(
                    widget.filter.copyWith(availability: availability),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('الترتيب', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xxs),
          PillRow(
            children: <Widget>[
              for (final GroupSort sort in GroupSort.values)
                PillChip(
                  label: sort.label,
                  selected: widget.filter.sort == sort,
                  onTap: () =>
                      widget.onChanged(widget.filter.copyWith(sort: sort)),
                ),
            ],
          ),
          if (widget.filter.isActive) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => widget.onChanged(widget.filter.cleared()),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: Text(
                  'تفريغ الفلاتر (${widget.filter.activeCount})',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
