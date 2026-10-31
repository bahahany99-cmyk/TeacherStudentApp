import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/core/widgets/user_avatar_view.dart';
import 'package:teacher_student_app/data/models/study_group.dart';

/// بطاقة عرض مجموعة دراسية.
///
/// (P24) **هوية المدرس صارت رأس البطاقة** لا سطرًا نصيًا: صورة المدرس (أو
/// صورته الافتراضية الحتمية) + اسمه + شارة التوثيق، ثم عنوان المجموعة. السبب
/// أن الطالب يختار مدرسًا قبل أن يختار مجموعة؛ وكان الاسم مدفونًا في سطر
/// «الاسم • المادة • المرحلة» بلا صورة ولا علامة توثيق.
///
/// - `teacherVerified`: `true` ⇒ شارة توثيق، `false` ⇒ لا شارة، `null` ⇒
///   «غير معروف» فلا ندّعي شيئًا. القيمة تأتي من شاشة الاستكشاف التي تقرأ
///   ملفات المدرسين مرة واحدة لكل قائمة.
/// - `onTap`: يفتح تفاصيل المجموعة.
/// - `onJoinTap`: زر طلب الانضمام. **لا يظهر** إذا لم يُمرَّر، لأن واجهة المدرس
///   لا تطلب الانضمام لمجموعته.
/// - `onEditTap`: زر تعديل (P7) — للمالك فقط. إخفاؤه ليس حماية؛ القواعد هي.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.group,
    this.onTap,
    this.onJoinTap,
    this.onEditTap,
    this.onMembersTap,
    this.onRequestsTap,
    this.favoriteAction,
    this.teacherVerified,
    this.onTeacherTap,
  });

  final StudyGroup group;
  final VoidCallback? onTap;
  final VoidCallback? onJoinTap;
  final VoidCallback? onEditTap;

  /// مداخل المدرس السريعة (P28): الأعضاء وطلبات الانضمام — كان الوصول إليهما
  /// يمرّ عبر «تفاصيل المجموعة» ثم صفّين، فيضيع الطالب المنتظر خلف ضغطتين.
  final VoidCallback? onMembersTap;
  final VoidCallback? onRequestsTap;

  /// زر المفضلة (P13) — يُمرَّر من واجهة الطالب فقط.
  final Widget? favoriteAction;

  /// هل ملف صاحب المجموعة موثّق؟ (`null` = لا نعرف، فلا شارة.)
  final bool? teacherVerified;

  /// فتح ملف المدرس من البطاقة (اختياري).
  final VoidCallback? onTeacherTap;

  /// مفتاح شارة التوثيق — يثبته اختبار البطاقة بلا الاعتماد على نص.
  static const Key teacherBadgeKey = Key('group-card-teacher-verified');

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
            // ── رأس البطاقة: المدرس أولًا ──────────────────────────────────
            Row(
              children: <Widget>[
                _TeacherIdentity(
                  group: group,
                  verified: teacherVerified,
                  onTap: onTeacherTap,
                ),
                const SizedBox(width: AppSpacing.xs),
                if (favoriteAction != null) favoriteAction!,
                if (onEditTap != null)
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
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                PillChip(
                  dense: true,
                  icon: Icons.menu_book_outlined,
                  label: group.subject,
                ),
                PillChip(
                  dense: true,
                  icon: Icons.school_outlined,
                  label: group.stage,
                ),
                PillChip(
                  dense: true,
                  icon: Icons.groups_outlined,
                  // (P28) «المتاح» هو ما يهم الطالب والمدرس؛ النسبة الكاملة
                  // تُبقى في التفاصيل. لا فرق بين استعلامين: كلاهما يقرأ
                  // `seatsTaken/seatsTotal` من مستند المجموعة نفسه.
                  label: group.isFull
                      ? 'مكتملة ($group.seatsTotal)'
                      : 'متاح ${group.seatsAvailable} من ${group.seatsTotal}',
                  color: group.isFull
                      ? AppColors.statusRejected
                      : AppColors.statusAccepted,
                ),
                PillChip(
                  dense: true,
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
            if (onMembersTap != null || onRequestsTap != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  if (onRequestsTap != null)
                    Expanded(
                      child: TextButton.icon(
                        key: const Key('group-card-requests'),
                        onPressed: onRequestsTap,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          textStyle: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: const Icon(Icons.inbox_outlined, size: 16),
                        label: const Text('طلبات الانضمام'),
                      ),
                    ),
                  if (onMembersTap != null)
                    Expanded(
                      child: TextButton.icon(
                        key: const Key('group-card-members'),
                        onPressed: onMembersTap,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          textStyle: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: const Icon(Icons.people_outline, size: 16),
                        label: const Text('الأعضاء'),
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

/// صورة المدرس واسمه وشارة توثيقه — الصف الذي يجعل البطاقة «بشخص».
class _TeacherIdentity extends StatelessWidget {
  const _TeacherIdentity({
    required this.group,
    required this.verified,
    required this.onTap,
  });

  final StudyGroup group;
  final bool? verified;
  final VoidCallback? onTap;

  /// حرفان من اسم المدرس: نتجاوز لقب «أ.» الشائع قبل الاسم.
  String get _initials {
    String name = group.teacherName.trim();
    for (final String prefix in <String>['أ.', 'أ', 'د.', 'م.']) {
      if (name.startsWith(prefix)) {
        name = name.substring(prefix.length).trim();
        break;
      }
    }
    if (name.isEmpty) {
      return '؟';
    }
    final List<String> words = name.split(RegExp(r'\s+'));
    final String first = words.first;
    final String second = words.length > 1 ? words[1] : '';
    final String two = '$first${second.isEmpty ? '' : ' ${second[0]}'}';
    return two.length <= 2 ? two : two.substring(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget avatar = UserAvatarLoader(
      userId: group.teacherId,
      initials: _initials,
      size: AppSpacing.avatarSm,
      semanticLabel: 'صورة ${group.teacherName}',
    );

    final Widget nameRow = Row(
      children: <Widget>[
        Flexible(
          child: Text(
            group.teacherName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (verified == true) ...<Widget>[
          const SizedBox(width: AppSpacing.xxs),
          Icon(
            Icons.verified_rounded,
            key: GroupCard.teacherBadgeKey,
            size: 16,
            color: theme.colorScheme.primary,
            semanticLabel: 'ملف موثّق',
          ),
        ],
      ],
    );

    final Widget body = Row(
      children: <Widget>[
        avatar,
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              nameRow,
              const SizedBox(height: 2),
              Text(
                verified == true ? 'مدرس موثّق' : 'مدرس',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap == null) {
      return Expanded(child: body);
    }
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: body,
      ),
    );
  }
}
