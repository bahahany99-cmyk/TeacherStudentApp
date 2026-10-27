import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// بطاقة عرض ملف مدرس — على نمط المرجع البصري المعتمد (نسخة 2).
///
/// التكوين:
/// 1. وسم «مدرس مميز» أعلى البطاقة (إن وُجد) + أيقونة مفضلة (للعرض فقط).
/// 2. صورة رمزية + الاسم + علامة التحقق + سطر تعريفي مختصر.
/// 3. صف إحصاءات من ثلاث خلايا: السعر / التقييم / عدد المراجعات.
///
/// لا تحتوي أي زر حجز فعلي في هذه المرحلة (الحجز مؤجل للمرحلة 8).
class TeacherCard extends StatelessWidget {
  const TeacherCard({super.key, required this.teacher, this.onTap});

  final TeacherProfile teacher;
  final VoidCallback? onTap;

  /// سعر مختصر للعرض في خلية الإحصاء (بدون كلمة «سعر استرشادي»).
  ///
  /// الشاشة التفصيلية تعرض النص الكامل كما هو؛ هنا نحتاج قيمة قصيرة تناسب
  /// خلية واحدة، فلا نجعلها تلتف على سطرين.
  String get _priceValue {
    final String? hint = teacher.priceHint;
    if (hint == null) {
      return '—';
    }
    final int slash = hint.indexOf('/');
    final String head = slash == -1 ? hint : hint.substring(0, slash);
    return head.replaceAll('سعر استرشادي:', '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: AppSpacing.listGap,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (teacher.isFeatured)
                  const PillBadge(
                    label: 'مدرس مميز',
                    icon: Icons.workspace_premium_outlined,
                    color: AppColors.accent,
                  )
                else
                  PillChip(
                    label: teacher.stage,
                    dense: true,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                const Spacer(),
                Icon(
                  Icons.favorite_border,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: AppSpacing.avatarSm / 2 + 4,
                  backgroundColor: theme.colorScheme.primary.withAlpha(26),
                  child: Text(
                    teacher.initials,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              teacher.displayName,
                              style: theme.textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${teacher.subject} • ${teacher.area}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              teacher.bio,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(color: theme.colorScheme.outlineVariant, height: 1),
            const SizedBox(height: AppSpacing.sm),
            // صف الإحصاءات: ثلاث خلايا متساوية كما في المرجع.
            Row(
              children: <Widget>[
                _StatCell(
                  value: _priceValue,
                  label: 'الحصة',
                  emphasis: true,
                ),
                _StatDivider(color: theme.colorScheme.outlineVariant),
                _StatCell(
                  value: teacher.reviewsCount == 0
                      ? '—'
                      : teacher.rating.toStringAsFixed(1),
                  label: 'التقييم',
                  icon: teacher.reviewsCount == 0 ? null : Icons.star_rounded,
                ),
                _StatDivider(color: theme.colorScheme.outlineVariant),
                _StatCell(
                  value: teacher.reviewsCount == 0
                      ? 'جديد'
                      : '${teacher.reviewsCount}',
                  label: 'مراجعة',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// خلية إحصاء: قيمة كبيرة فوق تسمية صغيرة.
class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    this.icon,
    this.emphasis = false,
  });

  final String value;
  final String label;
  final IconData? icon;

  /// القيمة الأساسية (السعر) تُعرض بلون الهوية.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: AppColors.accent),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: emphasis
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// فاصل رأسي رقيق بين خلايا الإحصاء.
class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      color: color.withAlpha(140),
    );
  }
}
