import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/utils/arabic_text.dart';
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
    this.subjectOptions = const <String>[],
  });

  /// الفلتر الحالي — نقطة البداية للمسوّدة المحلية.
  final GroupFilter filter;

  /// المراحل المشتقة من البيانات المعروضة (لا قائمة نظرية).
  final List<String> stageOptions;

  /// (P25) المواد **المشتقة من مستندات المجموعات المنشورة** — استعلام
  /// `listSubjects()` على كل المجموعات النشطة، لا قائمة مكتوبة في الكود.
  /// لذلك تظهر مادة كتبها مدرس بنفسه («علوم متكاملة») بلا تعديل برمجي.
  final List<String> subjectOptions;

  /// مفتاح حقل البحث عن مادة — تثبته الاختبارات.
  static const Key subjectSearchKey = Key('group-filter-subject-search');

  /// مفتاح زر التطبيق — يستخدمه الاختبار للوصول إلى الفعل بلا نص.
  static const Key applyKey = Key('group-filter-apply');
  static const Key resetKey = Key('group-filter-reset');

  @override
  State<GroupFilterSheet> createState() => _GroupFilterSheetState();
}

class _GroupFilterSheetState extends State<GroupFilterSheet> {
  late GroupFilter _draft = widget.filter;

  /// نص البحث داخل قائمة المواد (لا يفلتر النتائج بذاته).
  final TextEditingController _subjectQuery = TextEditingController();

  @override
  void dispose() {
    _subjectQuery.dispose();
    super.dispose();
  }

  void _update(GroupFilter next) {
    setState(() => _draft = next);
  }

  /// المواد المعروضة بعد البحث داخل القائمة — مطابقة عربية مُطبَّعة (الهمزات
  /// والتاء المربوطة تُوحَّد) حتى لا تخفي «فيزياء» عند كتابة «فيزياء» بلا همزة.
  List<String> get _visibleSubjects {
    final String needle = ArabicText.normalize(_subjectQuery.text);
    final List<String> all = widget.subjectOptions;
    if (needle.isEmpty) {
      return all;
    }
    return all
        .where(
          (String subject) => ArabicText.normalize(subject).contains(needle),
        )
        .toList(growable: false);
  }

  /// هل النص المكتوب مادة غير موجودة في القائمة؟ (مثال: مادة جديدة كتبها
  /// مدرس بعد آخر تحديث للقائمة) — نعرض خيار «البحث بها» حتى لا يُحبَس
  /// المستخدم.
  String? get _customSubject {
    final String typed = _subjectQuery.text.trim();
    if (typed.isEmpty) {
      return null;
    }
    final bool exists = widget.subjectOptions.any(
      (String subject) =>
          ArabicText.normalize(subject) == ArabicText.normalize(typed),
    );
    return exists ? null : typed;
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
                    const SectionHeader(title: 'المادة'),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      key: GroupFilterSheet.subjectSearchKey,
                      controller: _subjectQuery,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'ابحث عن مادة…',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _subjectQuery.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'مسح',
                                onPressed: () {
                                  _subjectQuery.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close, size: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // قائمة المواد تحت الحقل — لا قائمة منسدلة منبثقة: الشريحة
                    // تُضغط مباشرة، والقائمة تُمرَّر مع الورقة نفسها.
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        PillChip(
                          label: 'كل المواد',
                          selected: _draft.subject == null,
                          onTap: () => _update(_draft.copyWith(subject: null)),
                        ),
                        for (final String subject in _visibleSubjects)
                          PillChip(
                            label: subject,
                            selected: _draft.subject == subject,
                            onTap: () => _update(
                              _draft.copyWith(
                                subject: _draft.subject == subject
                                    ? null
                                    : subject,
                              ),
                            ),
                          ),
                        if (_customSubject != null)
                          PillChip(
                            label: 'بحث بـ«$_customSubject»',
                            icon: Icons.add_rounded,
                            selected: _draft.subject == _customSubject,
                            onTap: () => _update(
                              _draft.copyWith(subject: _customSubject),
                            ),
                          ),
                      ],
                    ),
                    if (widget.subjectOptions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          'لم تُسجَّل مواد بعد — اكتب اسم المادة للبحث بها.',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
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
  List<String> subjectOptions = const <String>[],
}) {
  return showModalBottomSheet<GroupFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (BuildContext sheetContext) => GroupFilterSheet(
      filter: filter,
      stageOptions: stageOptions,
      subjectOptions: subjectOptions,
    ),
  );
}
