import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/core/widgets/user_avatar_view.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// بطاقة مدرس «عرض»: صورة + توثيق + اسم + مواد + مراحل + تقييم + سعر + عنوان.
///
/// (P25) **لماذا بطاقة موحّدة؟** لأن المدرس يظهر في ثلاثة أماكن (شريط الرئيسية،
/// صفحة «المميزون»، نتائج البحث الشامل) وكان كل مكان يرسم بطاقة مختلفة بمعلومات
/// مختلفة — فيرى الطالب السعر في مكان والمراجعات في آخر. هنا **مجموعة واحدة**
/// من المعلومات في كل الأماكن:
///
/// | المعلومة | لماذا |
/// |---|---|
/// | الصورة والتوثيق | أول ما يحكم به الطالب على المدرس |
/// | الاسم | الهوية |
/// | المادة والمرحلة | «هل يدرّس صفي؟» |
/// | التقييم وعدد المراجعات | خبرة الآخرين، والعدد يمنع تقييمًا من مراجعة واحدة |
/// | السعر | قرار مالي قبل أي ضغطة |
/// | العنوان | **للحضوري فقط** — الطالب يحتاج يعرف إن كان قريبًا |
///
/// البطاقة عرض فقط: لا تقرأ من الشبكة إلا الصورة (عبر محمّل الصور المخزَّن).
class TeacherShowcaseCard extends StatelessWidget {
  const TeacherShowcaseCard({
    super.key,
    required this.teacher,
    required this.onTap,
    this.compact = true,
  });

  final TeacherProfile teacher;
  final VoidCallback onTap;

  /// `true` = بطاقة أفقية في شريط (عرض ثابت)، `false` = صف كامل العرض.
  final bool compact;

  /// عرض بطاقة الشريط — ثابت لأن `ListView` الأفقي يحتاج قيدًا.
  static const double width = 238;

  /// ارتفاع الشريط: يكفي كل المعلومات بلا حشو.
  static const double height = 200;

  /// مفتاح شارة التوثيق — تثبته الاختبارات.
  static const Key verifiedBadgeKey = Key('teacher-card-verified');

  /// مفتاح عنوان الحضور في البطاقة.
  static const Key locationKey = Key('teacher-card-location');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            UserAvatarLoader(
              userId: teacher.id,
              initials: teacher.initials,
              size: AppSpacing.avatarSm,
              semanticLabel: 'صورة ${teacher.displayName}',
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          teacher.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (teacher.status ==
                          TeacherProfileStatus.verified) ...<Widget>[
                        const SizedBox(width: 4),
                        const Icon(
                          key: verifiedBadgeKey,
                          Icons.verified_rounded,
                          size: 15,
                          color: AppColors.statusAccepted,
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      if (teacher.reviewsCount > 0) ...<Widget>[
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          teacher.rating.toStringAsFixed(1),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            '(${teacher.reviewsCount})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ] else
                        Text(
                          'مدرس جديد',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // المادة والمرحلة — «هل يدرّس صفي؟»
        Wrap(
          spacing: AppSpacing.xxs,
          runSpacing: AppSpacing.xxs,
          children: <Widget>[
            PillChip(
              dense: true,
              icon: Icons.menu_book_outlined,
              label: teacher.subject,
            ),
            PillChip(
              dense: true,
              icon: Icons.school_outlined,
              label: teacher.stage,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // المكان: **للحضوري فقط** — درس أونلاين لا عنوان له يُعرض.
        if (!teacher.isOnline)
          Row(
            key: locationKey,
            children: <Widget>[
              const Icon(
                Icons.place_outlined,
                size: 14,
                color: AppColors.statusRejected,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  teacher.locationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            children: <Widget>[
              const Icon(
                Icons.public_rounded,
                size: 14,
                color: AppColors.statusAccepted,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                'حصص عن بُعد',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        // **لا Spacer هنا:** البطاقة تُستخدم أيضًا داخل قائمة عمودية (نتائج
        // البحث وصفحة «عرض الكل») حيث الارتفاع غير محدود، و`Spacer` في تلك
        // الحالة يرمي استثناءً في وقت العرض. الفاصل الثابت يعطي المسافة نفسها
        // في الحالتين.
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            if (teacher.priceHint != null)
              Flexible(
                child: Text(
                  teacher.priceHint!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const Spacer(),
            if (teacher.isFeatured)
              const PillBadge(
                label: 'مميز',
                icon: Icons.workspace_premium_outlined,
                color: AppColors.accent,
              )
            else
              Icon(
                Icons.chevron_left,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ],
    );

    final Widget card = AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: content,
    );

    return compact ? SizedBox(width: width, child: card) : card;
  }
}
