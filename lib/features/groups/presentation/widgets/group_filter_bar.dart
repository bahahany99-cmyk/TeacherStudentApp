import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/data/models/group_filter.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/group_filter_sheet.dart';

/// شريط فلاتر الاستكشاف — **مضغوط**: بحث + شريط أفقي واحد (P24).
///
/// ما تغيّر ولماذا:
/// - كان الشريط خمسة صفوف مكدّسة (المادة، المرحلة، طريقة الحضور، المقاعد،
///   الترتيب) داخل بطاقة واحدة، فيأكل ارتفاع الشاشة قبل أول نتيجة. صار:
///   ① حقل بحث، ② زر «فلترة» (بعدد الفلاتر النشطة) يفتح [GroupFilterSheet]
///   حيث كل ما ليس مادة، ③ شريط أفقي واحد للمواد (الفعل الأكثر استخدامًا)
///   يُمرَّر أفقيًا بدل أن ينزل سطرًا لكل ثلاث حبات.
/// - **لا فلتر يُطبَّق بالنيّة:** كل نقرة هنا تُعيد الفلتر عبر [onChanged]،
///   والورقة تُطبّق مرة واحدة عند «عرض النتائج».
///
/// المكوّن عرض فقط: يستقبل الفلتر الحالي ويعيد الجديد، فلا يعرف مستودعًا.
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

  /// مفتاح زر «فلترة» — يستخدمه الاختبار للوصول إلى الفعل بلا نص.
  static const Key filterButtonKey = Key('group-filter-open');

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

  Future<void> _openAdvanced() async {
    final GroupFilter? next = await showGroupFilterSheet(
      context,
      filter: widget.filter,
      stageOptions: widget.stageOptions,
    );
    if (next != null && next != widget.filter) {
      widget.onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasActiveAdvanced = widget.filter.activeCount > 0;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onChanged: (String value) =>
                      widget.onChanged(widget.filter.copyWith(query: value)),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالمادة أو المدرس أو المرحلة',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    suffixIcon: widget.filter.query.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            onPressed: () {
                              _query.clear();
                              widget.onChanged(
                                widget.filter.copyWith(query: ''),
                              );
                            },
                            icon: const Icon(Icons.close, size: 18),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // زر واحد للفلاتر المتقدمة: أيقونة + شارة عدد، بلا نص طويل يزاحم
              // حقل البحث على 360dp.
              Semantics(
                button: true,
                label: hasActiveAdvanced
                    ? 'فلترة متقدمة، ${widget.filter.activeCount} فلتر نشط'
                    : 'فلترة متقدمة',
                child: Material(
                  color: hasActiveAdvanced
                      ? theme.colorScheme.primary.withAlpha(22)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: InkWell(
                    key: GroupFilterBar.filterButtonKey,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    onTap: _openAdvanced,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs + 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.tune,
                            size: 18,
                            color: hasActiveAdvanced
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          if (hasActiveAdvanced) ...<Widget>[
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              '${widget.filter.activeCount}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // شريط أفقي واحد: «الكل» + المواد. التمرير الأفقي بدل التكديس
          // العمودي هو جوهر هذا التعديل.
          PillRow(
            children: <Widget>[
              if (widget.filter.isActive)
                PillChip(
                  label: 'تفريغ الفلاتر (${widget.filter.activeCount})',
                  icon: Icons.filter_alt_off_outlined,
                  dense: true,
                  onTap: () => widget.onChanged(widget.filter.cleared()),
                ),
              PillChip(
                label: 'الكل',
                dense: true,
                selected: widget.filter.subject == null,
                onTap: () =>
                    widget.onChanged(widget.filter.copyWith(subject: null)),
              ),
              for (final String subject in widget.subjectOptions)
                PillChip(
                  label: subject,
                  dense: true,
                  selected: widget.filter.subject == subject,
                  onTap: () => widget.onChanged(
                    widget.filter.copyWith(
                      subject: widget.filter.subject == subject ? null : subject,
                    ),
                  ),
                ),
              // ملخّص ما اختير في الورقة (مرحلة/حضور/مقاعد) كنص واحد مضغوط،
              // لا كصفوف إضافية.
              if (_advancedSummary(widget.filter) != null)
                PillChip(
                  label: _advancedSummary(widget.filter)!,
                  icon: Icons.filter_alt_outlined,
                  dense: true,
                  selected: true,
                  onTap: _openAdvanced,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              widget.resultLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// سطر واحد يصف فلاتر الورقة النشطة (بدون البحث والمادة، فلهما حبّاتهما).
  static String? _advancedSummary(GroupFilter filter) {
    final List<String> parts = <String>[];
    if (filter.stage != null) {
      parts.add('مرحلة: ${filter.stage}');
    }
    if (filter.meetingMode != null) {
      parts.add(filter.meetingMode!.label);
    }
    if (filter.availability != GroupAvailability.any) {
      parts.add(filter.availability.label);
    }
    if (filter.sort != GroupSort.recommended) {
      parts.add(filter.sort.label);
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
