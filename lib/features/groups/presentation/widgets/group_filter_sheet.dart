import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/data/models/group_filter.dart';
import 'package:teacher_student_app/data/models/study_group.dart';

/// ورقة «فلترة متقدمة» لاستكشاف المجموعات (P24).
///
/// **لماذا ورقة لا صفوف شرائح مكدّسة؟** الشاشة كانت تعرض خمسة صفوف من الشرائح
/// (مادة، مرحلة، حضور، مقاعد، ترتيب) فوق النتائج، فتستهلك نصف الهاتف قبل أول
/// بطاقة. هنا يبقى في الشاشة بحثٌ وشريط أفقي واحد للمواد، وكل ما عدا ذلك
/// ينتقل إلى ورقة تُفتح عند الطلب.
///
/// **الصيغة:** الورقة لا تُطبّق على كل نقرة. المستخدم يكوّم اختياراته ثم يضغط
/// «عرض النتائج»، فلا تُعاد قراءة القائمة خمس مرات أثناء التعديل. و«تفريغ»
/// يعيد الفلتر إلى حالة محايدة (مع الحفاظ على الترتيب) بلا إغلاق الورقة.
class GroupFilterSheet extends StatefulWidget {
  const GroupFilterSheet({
    super.key,
    required this.filter,
    required this.stageOptions,
  });

  /// الفلتر الحالي — نقطة البداية للمسوّدة المحلية.
  final GroupFilter filter;

  /// المراحل المشتقة من البيانات المعروضة (لا قائمة نظرية).
  final List<String> stageOptions;

  /// مفتاح زر التطبيق — يستخدمه الاختبار للوصول إلى الفعل بلا نص.
  static const Key applyKey = Key('group-filter-apply');
  static const Key resetKey = Key('group-filter-reset');

  @override
  State<GroupFilterSheet> createState() => _GroupFilterSheetState();
}

class _GroupFilterSheetState extends State<GroupFilterSheet> {
  late GroupFilter _draft = widget.filter;

  void _update(GroupFilter next) {
    setState(() => _draft = next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
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
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'فلترة متقدمة',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_draft.isActive)
                  PillChip(
                    label: '${_draft.activeCount} فلتر',
                    dense: true,
                    icon: Icons.filter_alt_outlined,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (widget.stageOptions.isNotEmpty) ...<Widget>[
                      const SectionHeader(title: 'المرحلة'),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          for (final String stage in widget.stageOptions)
                            PillChip(
                              label: stage,
                              selected: _draft.stage == stage,
                              onTap: () => _update(
                                _draft.copyWith(
                                  stage: _draft.stage == stage ? null : stage,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    const SectionHeader(title: 'طريقة الحضور'),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        for (final GroupMeetingMode mode
                            in GroupMeetingMode.values)
                          PillChip(
                            label: mode.label,
                            selected: _draft.meetingMode == mode,
                            onTap: () => _update(
                              _draft.copyWith(
                                meetingMode: _draft.meetingMode == mode
                                    ? null
                                    : mode,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const SectionHeader(title: 'المقاعد'),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        for (final GroupAvailability availability
                            in GroupAvailability.values)
                          PillChip(
                            label: availability.label,
                            selected: _draft.availability == availability,
                            onTap: () => _update(
                              _draft.copyWith(availability: availability),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const SectionHeader(title: 'الترتيب'),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        for (final GroupSort sort in GroupSort.values)
                          PillChip(
                            label: sort.label,
                            selected: _draft.sort == sort,
                            onTap: () =>
                                _update(_draft.copyWith(sort: sort)),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    key: GroupFilterSheet.resetKey,
                    onPressed: _draft.isActive
                        ? () => _update(_draft.cleared())
                        : null,
                    child: const Text('تفريغ'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: GroupFilterSheet.applyKey,
                    onPressed: () => Navigator.of(context).pop(_draft),
                    child: const Text('عرض النتائج'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// يفتح ورقة الفلترة ويعيد الفلتر الجديد، أو `null` إن أُغلقت بلا تطبيق.
Future<GroupFilter?> showGroupFilterSheet(
  BuildContext context, {
  required GroupFilter filter,
  required List<String> stageOptions,
}) {
  return showModalBottomSheet<GroupFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (BuildContext sheetContext) => GroupFilterSheet(
      filter: filter,
      stageOptions: stageOptions,
    ),
  );
}
