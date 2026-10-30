import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// بطاقة حالة الملف التعريفي — **من حالة الملف الحقيقية لا من نص مكتوب** (P21).
///
/// ## المشكلة التي حُلّت
///
/// كانت الرئيسية تعرض نصًا ثابتًا لا علاقة له بحساب صاحبه:
/// «هذه معاينة محلية بلا Firebase… حالة اعتماد ملفك (C-06)» مع وسم
/// «حساب تجريبي». النتيجة: مدرس **موثّق فعليًا** يقرأ أنه في معاينة، ومدرس بلا
/// ملف يُخبَر برمز سياسة داخلية بدل أن يُطلب منه إنشاء ملفه.
///
/// ## السلوك الآن
///
/// تقرأ `teacherProfiles/{uid}` من المستودع (نفس مصدر بقية الشاشات) وتعرض:
///
/// | الحالة | ما يراه المدرس |
/// |---|---|
/// | بلا ملف | «أنشئ ملفك التعريفي» + زر إجراء — دعوة واضحة لا رسالة تقنية |
/// | `draft` | «أكمل ملفك وأرسله للمراجعة» + زر تعديل |
/// | `pendingReview` | «ملفك قيد المراجعة» + ما المتوقع ومتى |
/// | `verified` | «ملفك موثّق ويظهر للطلاب» + زر الملف |
/// | `rejected` | «ملفك يحتاج تعديلًا» + سبب الإدارة كما كتبه المراجع |
///
/// **لماذا نُخفي النص التقني بدل حذفه فقط؟** لأن الحالة نفسها معلومة يحتاجها
/// المدرس: بدونها سيكرّر المحاولة بلا معرفة ما ينتظره. الحل ليس «بلا رسالة»
/// بل «رسالة إنسانية مبنية على الحالة».
///
/// أي خطأ في القراءة يعرض حالة خطأ عربية قابلة لإعادة المحاولة (عبر
/// [AsyncView])، لا رسالة تقنية ولا بيانات بديلة ملفّقة.
class TeacherProfileStatusCard extends StatelessWidget {
  const TeacherProfileStatusCard({super.key, required this.teacherId});

  /// معرّف صاحب الجلسة (`uid` الحقيقي، أو معرّف المعاينة في جلسة تجريبية).
  final String teacherId;

  @override
  Widget build(BuildContext context) {
    return AsyncView<TeacherProfile?>(
      load: () => AppServicesScope.of(context).teachers.findMine(teacherId),
      // `null` = لا ملف ⇒ `AsyncView` يعرض `emptyBuilder` (لا `builder`).
      // لذلك دعوة الإنشاء تُمرَّر هنا، لا كحالة داخل `builder`.
      emptyBuilder: (BuildContext context) => const _NoProfileCard(),
      builder: (BuildContext context, TeacherProfile? profile) {
        if (profile == null) {
          return const _NoProfileCard();
        }
        return _StatusCard(profile: profile);
      },
    );
  }
}

/// بلا ملف: دعوة إنشاء واضحة (onboarding) لا رسالة تقنية.
class _NoProfileCard extends StatelessWidget {
  const _NoProfileCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      key: const Key('teacher-onboarding-card'),
      gradient: AppGradients.glow,
      borderColor: AppBorders.onTint,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.badge_outlined, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'ملفك التعريفي بانتظارك',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'أضف المادة والمرحلة والمنطقة ونبذة قصيرة عن طريقة شرحك، وسيظهر '
            'ملفك للطلاب بعد أن تعتمده الإدارة.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.75,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('teacher-create-profile'),
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(RoutePaths.editTeacherProfile),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            child: const Text('إنشاء ملف تعريفي'),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'يستغرق دقيقتين، ويمكنك تعديله في أي وقت.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// ملف قائم: الشكل والنبرة يتغيّران بحسب حالته الحقيقية.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.profile});

  final TeacherProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _StatusCopy copy = _StatusCopy.of(profile);

    return AppCard(
      key: Key('teacher-status-card-${profile.status.wireValue}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundColor: copy.accent.withAlpha(28),
                child: Icon(copy.icon, size: 20, color: copy.accent),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  copy.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            copy.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.75,
            ),
          ),
          // سبب الرفض كما كتبه المراجع: معلومة يملكها المدرس، لا رمز داخلي.
          if (profile.status == TeacherProfileStatus.rejected &&
              (profile.reviewNote ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.statusRejected.withAlpha(18),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                'ملاحظة المراجع: ${profile.reviewNote!.trim()}',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(RoutePaths.myTeacherProfile),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    textStyle: theme.textTheme.labelMedium,
                  ),
                  child: const Text(
                    'ملفي التعريفي',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(RoutePaths.editTeacherProfile),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    textStyle: theme.textTheme.labelMedium,
                  ),
                  child: const Text(
                    'تعديل',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
    required this.icon,
    required this.accent,
  });

  final String title;
  final String message;
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
          icon: Icons.edit_note_outlined,
          accent: AppColors.statusPending,
        );
      case TeacherProfileStatus.pendingReview:
        return const _StatusCopy(
          title: 'ملفك قيد المراجعة',
          message:
              'استلمنا ملفك ويراجعه فريق التوثيق. لا تحتاج إلى أي خطوة الآن — '
              'سنُشعرك عند صدور القرار، ويمكنك تعديل بياناتك في أي وقت.',
          icon: Icons.hourglass_bottom_outlined,
          accent: AppColors.statusPending,
        );
      case TeacherProfileStatus.verified:
        return const _StatusCopy(
          title: 'ملفك موثّق ويظهر للطلاب',
          message:
              'يمكن للطلاب الآن العثور عليك وطلب الانضمام إلى مجموعاتك '
              'وحجز الحصص. حافظ على تحديث بياناتك ومواعيدك.',
          icon: Icons.verified_outlined,
          accent: AppColors.statusAccepted,
        );
      case TeacherProfileStatus.rejected:
        return const _StatusCopy(
          title: 'ملفك يحتاج تعديلًا',
          message:
              'لم يُعتمد الملف في صورته الحالية. راجع الملاحظة أدناه، عدّل ما '
              'يلزم، ثم احفظ لإعادة إرساله إلى المراجعة.',
          icon: Icons.report_gmailerrorred_outlined,
          accent: AppColors.statusRejected,
        );
    }
  }
}
