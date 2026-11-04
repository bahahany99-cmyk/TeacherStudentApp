import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// شريط «مدرسون مميزون» في الرئيسية (P15).
///
/// **لماذا أفقي؟** لأن التمييز قسم تسويقي قصير (٣–٦ بطاقات) لا نتيجة بحث؛
/// القائمة العمودية الطويلة تدفع بقية الرئيسية إلى أسفل. التمرير الأفقي يبقي
/// القسم في شاشة واحدة ويُظهر أن هناك المزيد (بطاقة مقتطعة على الحافة).
///
/// الترتيب والقصر على الموثّقين يأتيان من المستودع
/// (`TeacherDiscoveryRules.featured`)، فالودجت عرض فقط.
class FeaturedTeachersCarousel extends StatelessWidget {
  const FeaturedTeachersCarousel({
    super.key,
    required this.teachers,
    this.onTeacherTap,
  });

  final List<TeacherProfile> teachers;

  /// فتح ملف المدرس. الافتراضي: التنقل بالمسار المعروف.
  final ValueChanged<TeacherProfile>? onTeacherTap;

  /// ارتفاع البطاقة — ثابت لأن `ListView` الأفقي يحتاج قيدًا في المحور الآخر.
  static const double cardHeight = 210;

  static const double cardWidth = 232;

  @override
  Widget build(BuildContext context) {
    if (teachers.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // RTL: البداية على اليمين تلقائيًا لأن الاتجاه موروث.
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
        itemCount: teachers.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: AppSpacing.xs),
        itemBuilder: (BuildContext context, int index) {
          final TeacherProfile teacher = teachers[index];
          return SizedBox(
            width: cardWidth,
            child: _FeaturedTeacherCard(
              teacher: teacher,
              onTap: () {
                final ValueChanged<TeacherProfile>? tap = onTeacherTap;
                if (tap != null) {
                  tap(teacher);
                  return;
                }
                Navigator.of(context).pushNamed(
                  RoutePaths.teacherProfile,
                  arguments: teacher.id,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// بطاقة مدرس مميز: وسم + اسم + طريقة التقديم + المكان + تقييم.
class _FeaturedTeacherCard extends StatelessWidget {
  const _FeaturedTeacherCard({required this.teacher, required this.onTap});

  final TeacherProfile teacher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const PillBadge(
            label: 'مدرس مميز',
            icon: Icons.workspace_premium_outlined,
            color: AppColors.accent,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: AppSpacing.avatarSm / 2,
                backgroundColor: theme.colorScheme.primary.withAlpha(26),
                child: Text(
                  teacher.initials,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      teacher.displayName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      teacher.subject,
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
          // طريقة التقديم والمكان: أهم معلومة قرار للطالب قبل فتح الملف.
          Row(
            children: <Widget>[
              Icon(
                teacher.isOnline
                    ? Icons.public_rounded
                    : Icons.place_outlined,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  '${teacher.deliveryLabel} · ${teacher.locationLabel}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              if (teacher.reviewsCount > 0) ...<Widget>[
                const Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 2),
                Text(
                  teacher.rating.toStringAsFixed(1),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else
                Text(
                  'جديد',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              if (teacher.priceHint != null)
                Flexible(
                  child: Text(
                    teacher.priceHint!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
