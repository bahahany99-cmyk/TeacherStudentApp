import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// شريط حالة الملف التعريفي — **مضغوط** (P28).
///
/// ## ما تغيّر ولماذا
///
/// في السابق كانت هذه بطاقةً تملأ نصف الرئيسية: أيقونة دائرية كبيرة، عنوان،
/// فقرة من ثلاثة أسطر، ثم زرّان بعرض الشاشة. النتيجة أن **حالة** الملف — وهي
/// معلومة من سطر واحد — كانت تسيطر على الصفحة، ولا يبقى للمدرس مكان لمعرفة
/// ما يحتاج متابعته اليوم.
///
/// الشكل الجديد **صفّ واحد** (56–72dp):
/// `[أيقونة حالة] [العنوان + سطر توضيحي] [شارة الحالة] [سهم]`، والضغط عليه
/// يفتح الملف، وأيقونة قلم صغيرة تفتح التعديل. الحالات الاستثنائية (مسودة أو
/// مرفوض) تضيف سطرًا واحدًا فقط (سبب الرفض) ولا تتحوّل إلى بطاقة.
///
/// المفاتيح والنصوص التي تعتمدها الاختبارات محفوظة كما هي.
class TeacherProfileStatusCard extends StatelessWidget {
  const TeacherProfileStatusCard({super.key, required this.teacherId});

  /// معرّف صاحب الجلسة (`uid` الحقيقي، أو معرّف المعاينة في جلسة تجريبية).
  final String teacherId;

  @override
  Widget build(BuildContext context) {
    return AsyncView<TeacherProfile?>(
      load: () => AppServicesScope.of(context).teachers.findMine(teacherId),
      // `null` = لا ملف ⇒ `AsyncView` يعرض `emptyBuilder` (لا `builder`).
      emptyBuilder: (BuildContext context) => const _NoProfileCard(),
      builder: (BuildContext context, TeacherProfile? profile) {
        if (profile == null) {
          return const _NoProfileCard();
        }
        return _StatusRow(profile: profile);
      },
    );
  }
}

/// بلا ملف: دعوة إنشاء واضحة لكن **مضغوطة** (سطر + زر صغير).
class _NoProfileCard extends StatelessWidget {
  const _NoProfileCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      key: const Key('teacher-onboarding-card'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _StatusIcon(
            icon: Icons.badge_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ملفك التعريفي بانتظارك',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'أضف المادة والمرحلة ونبذة قصيرة، وسيظهر ملفك للطلاب بعد '
                  'اعتماد الإدارة.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                FilledButton(
                  key: const Key('teacher-create-profile'),
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(RoutePaths.editTeacherProfile),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    textStyle: theme.textTheme.labelMedium,
                  ),
                  child: const Text('إنشاء ملف تعريفي'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ملف قائم: صف واحد يتغيّر لونه وشارته بحسب الحالة الحقيقية.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.profile});

  final TeacherProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _StatusCopy copy = _StatusCopy.of(profile);
    final bool rejected = profile.status == TeacherProfileStatus.rejected;
    final String? note = (profile.reviewNote ?? '').trim().isEmpty
        ? null
        : profile.reviewNote!.trim();

    return AppCard(
      key: Key('teacher-status-card-${profile.status.wireValue}'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: () =>
          Navigator.of(context).pushNamed(RoutePaths.myTeacherProfile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _StatusIcon(icon: copy.icon, color: copy.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  copy.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              StatusChip(label: copy.chip, color: copy.accent),
              const SizedBox(width: AppSpacing.xxs),
              // تعديل فوري بلا استهلاك مساحة: أيقونة واحدة داخل هدف لمس 40dp.
              IconButton(
                key: const Key('teacher-status-edit'),
                tooltip: 'تعديل الملف',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed(RoutePaths.editTeacherProfile),
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          // سطر واحد فقط يشرح الحالة. لا فقرة، ولا أزرار بعرض الشاشة.
          const SizedBox(height: AppSpacing.xxs),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 44),
            child: Text(
              copy.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // سبب الرفض كما كتبه المراجع: معلومة يملكها المدرس، لا رمز داخلي.
          if (rejected && note != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Container(
              margin: const EdgeInsetsDirectional.only(start: 44),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: AppColors.statusRejected.withAlpha(16),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                'ملاحظة المراجع: $note',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.statusRejected,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// أيقونة الحالة في مربع 36dp ملوّن (لا دائرة 40dp بلا معنى).
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
      ),
      child: Icon(icon, size: 19, color: color),
    );
  }
}

/// نصوص وألوان كل حالة في مكان واحد.
///
/// الفصل مقصود: إضافة حالة جديدة مستقبلًا تعني سطرًا هنا لا بحثًا في الشاشة عن
/// النصوص، ويبقى من السهل مراجعة أن كل حالة تُقال بلغة بشرية.
class _StatusCopy {
  const _StatusCopy({
    required this.title,
    required this.message,
    required this.chip,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String message;
  final String chip;
  final IconData icon;
  final Color accent;

  static _StatusCopy of(TeacherProfile profile) {
    switch (profile.status) {
      case TeacherProfileStatus.draft:
        return const _StatusCopy(
          title: 'أكمل ملفك وأرسله للمراجعة',
          message:
              'ملفك محفوظ كمسودة ولا يراه الطلاب بعد. أضف ما ينقصه ثم احفظ '
              'لإرساله إلى مراجعة الإدارة.',
          chip: 'مسودة',
          icon: Icons.edit_note_outlined,
          accent: AppColors.statusPending,
        );
      case TeacherProfileStatus.pendingReview:
        return const _StatusCopy(
          title: 'ملفك قيد المراجعة',
          message:
              'استلمنا ملفك ويراجعه فريق التوثيق. لا تحتاج إلى أي خطوة الآن — '
              'سنُشعرك عند صدور القرار.',
          chip: 'قيد المراجعة',
          icon: Icons.hourglass_bottom_outlined,
          accent: AppColors.statusPending,
        );
      case TeacherProfileStatus.verified:
        return const _StatusCopy(
          title: 'ملفك موثّق ويظهر للطلاب',
          message:
              'يمكن للطلاب الآن العثور عليك وطلب الانضمام إلى مجموعاتك وحجز '
              'الحصص.',
          chip: 'موثّق',
          icon: Icons.verified_outlined,
          accent: AppColors.statusAccepted,
        );
      case TeacherProfileStatus.rejected:
        return const _StatusCopy(
          title: 'ملفك يحتاج تعديلًا',
          message: 'لم يُعتمد الملف في صورته الحالية. راجع الملاحظة، عدّل ما '
              'يلزم ثم احفظ لإعادة الإرسال.',
          chip: 'يحتاج تعديلًا',
          icon: Icons.report_gmailerrorred_outlined,
          accent: AppColors.statusRejected,
        );
    }
  }
}
