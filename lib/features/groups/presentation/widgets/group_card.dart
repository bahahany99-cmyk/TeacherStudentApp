import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/data/models/study_group.dart';

/// بطاقة عرض مجموعة دراسية.
///
/// - `onTap`: يفتح تفاصيل المجموعة.
/// - `onJoinTap`: زر طلب الانضمام. **لا يظهر** إذا لم يُمرَّر، لأن واجهة المدرس
///   لا تطلب الانضمام لمجموعته. الزر نفسه غير منفّذ بعد (المرحلة 8).
/// - `onEditTap`: زر تعديل (P7) — يظهر لصاحب المجموعة فقط، ويُمرَّر من الواجهة
///   التي تعرف الدور. إخفاؤه ليس حماية؛ القواعد تمنع أي تعديل من غير المالك.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.group,
    this.onTap,
    this.onJoinTap,
    this.onEditTap,
    this.favoriteAction,
  });

  final StudyGroup group;
  final VoidCallback? onTap;
  final VoidCallback? onJoinTap;
  final VoidCallback? onEditTap;

  /// زر المفضلة (P13) — يُمرَّر من واجهة الطالب فقط، فلا نضع منطق أدوار هنا.
  final Widget? favoriteAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: AppSpacing.listGap,
      child: AppCard(
        onTap: onTap,
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
                PillBadge(
                  label: group.isActive
                      ? (group.isFull ? 'مكتملة' : 'متاحة')
                      : 'موقوفة',
                  icon: group.isActive
                      ? (group.isFull
                            ? Icons.lock_outline
                            : Icons.check_circle_outline)
                      : Icons.visibility_off_outlined,
                  color: !group.isActive
                      ? AppColors.statusNeutral
                      : (group.isFull
                            ? AppColors.statusRejected
                            : AppColors.statusAccepted),
                ),
                if (favoriteAction != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.xxs),
                  favoriteAction!,
                ],
                if (onEditTap != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.xxs),
                  IconButton(
                    onPressed: onEditTap,
                    tooltip: 'تعديل المجموعة',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.primary.withAlpha(18),
                      minimumSize: const Size(34, 34),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${group.teacherName} • ${group.subject} • ${group.stage}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                PillChip(
                  dense: true,
                  icon: Icons.groups_outlined,
                  label: '${group.seatsTaken} / ${group.seatsTotal} مقعد',
                  color: group.isFull
                      ? AppColors.statusRejected
                      : AppColors.statusAccepted,
                ),
                PillChip(
                  dense: true,
                  icon: Icons.videocam_outlined,
                  label: group.meetingMode.label,
                ),
                PillChip(
                  dense: true,
                  icon: Icons.school_outlined,
                  label: group.stage,
                ),
              ],
            ),
            if (group.scheduleNote != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      group.scheduleNote!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (onJoinTap != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onJoinTap,
                  child: const Text('طلب الانضمام'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
