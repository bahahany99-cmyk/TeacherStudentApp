import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// بطاقة عرض ملف مدرس.
///
/// لا تحتوي أي زر حجز فعلي في هذه المرحلة (الحجز مؤجل للمرحلة 8).
class TeacherCard extends StatelessWidget {
  const TeacherCard({super.key, required this.teacher, this.onTap});

  final TeacherProfile teacher;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: AppSpacing.listGap,
      child: AppCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: AppSpacing.avatarSm / 2,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                teacher.initials,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
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
                      Expanded(
                        child: Text(
                          teacher.displayName,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (teacher.isFeatured)
                        Icon(
                          Icons.workspace_premium_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${teacher.subject} • ${teacher.stage}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Expanded(
                        child: Text(
                          teacher.area,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Color(0xFFE8A33D),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Flexible(
                        child: Text(
                          teacher.reviewsCount == 0
                              ? 'لا توجد تقييمات بعد'
                              : '${teacher.rating.toStringAsFixed(1)} '
                                    '(${teacher.reviewsCount} تقييم)',
                          style: theme.textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      if (teacher.priceHint != null)
                        Flexible(
                          child: Text(
                            teacher.priceHint!,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
