import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/validation/featured_rules.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_showcase_card.dart';

/// مفتاحا مبدّل «أونلاين / أوفلاين» — تثبتهما الاختبارات.
const Key featuredSegmentOnlineKey = Key('featured-segment-online');
const Key featuredSegmentOfflineKey = Key('featured-segment-offline');

/// قسم «المدرسون المميزون» في الرئيسية (P25): مبدّل شرائح + شريط بطاقات.
///
/// **لماذا مبدّل لا صفّان؟** المطلوب عشر بطاقات، وصفّان من خمس أفقية يأكلان
/// نصف الشاشة الأولى فيُدفن «مجموعاتي» أسفلها. المبدّل يعرض خمسًا في مساحة
/// واحدة، ويُظهر العدد المتاح في الشريحة الأخرى («أوفلاين 3») فيعرف الطالب
/// بلا ضغطة عمياء أن هناك محتوى آخر.
///
/// القائمة تأتي من [FeaturedRules.selectWeekly] في الأعلى (حكمة القواعد في
/// `lib/data` وليس في الودجة) — هذه الودجة عرض محض.
class FeaturedTeachersStrip extends StatefulWidget {
  const FeaturedTeachersStrip({
    super.key,
    required this.selection,
    required this.onTeacherTap,
    required this.onViewAll,
  });

  final FeaturedSelection selection;
  final ValueChanged<TeacherProfile> onTeacherTap;

  /// «عرض الكل» → شاشة المميزين الكاملة.
  final VoidCallback onViewAll;

  @override
  State<FeaturedTeachersStrip> createState() => _FeaturedTeachersStripState();
}

class _FeaturedTeachersStripState extends State<FeaturedTeachersStrip> {
  /// إن كان الاختيار الافتراضي (أونلاين) فارغًا بينما الحضوري متاح، نبدأ
  /// بالحضوري: شاشة أولى فارغة أسوأ من شاشة تبدأ بالشريحة الممتلئة. لا نغيّر
  /// اختيار المستخدم بعدها.
  late bool _online = _resolveInitial();

  bool _resolveInitial() {
    if (widget.selection.online.isNotEmpty) {
      return true;
    }
    return widget.selection.offline.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final List<TeacherProfile> visible = _online
        ? widget.selection.online
        : widget.selection.offline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _SegmentedToggle(
                onlineSelected: _online,
                onlineCount: widget.selection.online.length,
                offlineCount: widget.selection.offline.length,
                onChanged: (bool online) => setState(() => _online = online),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            TextButton(
              onPressed: widget.onViewAll,
              child: const Text('عرض الكل'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: TeacherShowcaseCard.height,
          child: visible.isEmpty
              ? const SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'لا يوجد مدرسون في هذه الشريحة الآن',
                    message:
                        'جرّب الشريحة الأخرى، أو ابحث عن مدرس بالمادة والمرحلة.',
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: visible.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(width: AppSpacing.xs),
                  itemBuilder: (BuildContext context, int index) {
                    final TeacherProfile teacher = visible[index];
                    return TeacherShowcaseCard(
                      key: ValueKey<String>(teacher.id),
                      teacher: teacher,
                      onTap: () => widget.onTeacherTap(teacher),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// مبدّل شريحتين بحبة واحدة منزلقة — لا زرّان منفصلان.
class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({
    required this.onlineSelected,
    required this.onlineCount,
    required this.offlineCount,
    required this.onChanged,
  });

  final bool onlineSelected;
  final int onlineCount;
  final int offlineCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(140),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _Segment(
              key: featuredSegmentOnlineKey,
              label: 'مدرسون أونلاين',
              count: onlineCount,
              selected: onlineSelected,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _Segment(
              key: featuredSegmentOfflineKey,
              label: 'مدرسون أوفلاين',
              count: offlineCount,
              selected: !onlineSelected,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color foreground = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        // شفافية اللمس: الحبة بكاملها قابلة للضغط، لا النص وحده.
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (count > 0) ...<Widget>[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground.withAlpha(selected ? 220 : 160),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
