import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/study_group.dart';

/// بطاقة عرض مجموعة دراسية.
///
/// - `onTap`: يفتح تفاصيل المجموعة.
/// - `onJoinTap`: زر طلب الانضمام. **لا يظهر** إذا لم يُمرَّر، لأن واجهة المدرس
///   لا تطلب الانضمام لمجموعته. الزر نفسه غير منفّذ بعد (المرحلة 8).
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.group, this.onTap, this.onJoinTap});

  final StudyGroup group;
  final VoidCallback? onTap;
  final VoidCallback? onJoinTap;

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
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xxs,
              children: <Widget>[
                _IconLabel(
                  icon: Icons.groups_outlined,
                  label: '${group.seatsTaken} / ${group.seatsTotal} مقعد',
                ),
                _IconLabel(
                  icon: Icons.videocam_outlined,
                  label: group.meetingMode.label,
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

/// أيقونة مع نص قصير في صف لا يتجاوز عرض الشاشة (بدل Row قد يفيض).
class _IconLabel extends StatelessWidget {
  const _IconLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.labelSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
