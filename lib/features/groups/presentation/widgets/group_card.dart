import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/study_group.dart';

/// بطاقة عرض مجموعة دراسية.
///
/// زر "طلب انضمام" غير مفعّل الآن: طلبات الانضمام والتحقق من السعة يُنفَّذان
/// في المرحلة 8، والتحقق النهائي على الخادم.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.group, this.onJoinTap});

  final StudyGroup group;
  final VoidCallback? onJoinTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: AppSpacing.listGap,
      child: AppCard(
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
                  label: group.isFull ? 'مكتملة' : 'متاحة',
                  color: group.isFull
                      ? AppColors.statusRejected
                      : AppColors.statusAccepted,
                ),
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
            Row(
              children: <Widget>[
                Icon(
                  Icons.groups_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  '${group.seatsTaken} / ${group.seatsTotal} مقعد',
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.videocam_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  group.meetingMode.label,
                  style: theme.textTheme.labelSmall,
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
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onJoinTap,
                child: const Text('طلب الانضمام'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
