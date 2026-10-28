import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/data/models/teacher_rating.dart';
import 'package:teacher_student_app/data/models/teacher_review.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// قسم «التقييمات» في ملف المدرس (P13).
///
/// يقرأ مصدرين من نفس المستودع:
/// - [TeacherRating]: مجموع + عدد (المتوسط يُحسب للعرض)، ويُبثّ حيًّا.
/// - التقييمات نفسها: قائمة الأحدث أولًا.
///
/// لا يوجد هنا تقييم من العميل: أي طالب يرى «قيّم الحصة» من حجزه المنفّذ فقط،
/// والأهلية مفروضة في المستودع والقواعد.
class TeacherReviewsSection extends StatefulWidget {
  const TeacherReviewsSection({super.key, required this.teacherId});

  final String teacherId;

  @override
  State<TeacherReviewsSection> createState() => _TeacherReviewsSectionState();
}

class _TeacherReviewsSectionState extends State<TeacherReviewsSection> {
  Stream<TeacherRating>? _ratings;
  Stream<List<TeacherReview>>? _reviews;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ratings != null) {
      return;
    }
    // ننشئ التدفّقين مرة واحدة: إنشاؤهما في `build` يعيد الاشتراك عند كل بناء.
    final AppServices services = AppServicesScope.of(context);
    _ratings = services.reviews.watchRating(widget.teacherId);
    _reviews = services.reviews.watchForTeacher(widget.teacherId);
  }

  /// يعيد الاشتراك في التدفّقين بعد انقطاعهما (زر «إعادة المحاولة»).
  ///
  /// التدفّق المُنهى بالخطأ لا يُعاد تشغيله تلقائيًا؛ إنشاء تدفّق جديد هو
  /// الطريقة الوحيدة لمعرفة أن الشبكة عادت.
  void _resubscribe() {
    final AppServices services = AppServicesScope.of(context);
    setState(() {
      _ratings = services.reviews.watchRating(widget.teacherId);
      _reviews = services.reviews.watchForTeacher(widget.teacherId);
    });
  }

  String _dateLabel(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StreamBuilder<TeacherRating>(
          stream: _ratings,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<TeacherRating> snapshot,
              ) {
                if (snapshot.hasError) {
                  return _StreamErrorCard(
                    error: snapshot.error!,
                    onRetry: _resubscribe,
                  );
                }
                final TeacherRating rating =
                    snapshot.data ?? TeacherRating.empty(widget.teacherId);
                if (rating.isEmpty) {
                  return const SizedBox.shrink();
                }
                return AppCard(
                  child: Row(
                    children: <Widget>[
                      Text(
                        rating.average.toStringAsFixed(1),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // النص داخل Expanded: العرض 360dp لا يحتمل صفًا غير
                      // مرن مع أرقام عربية ونجوم.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                for (
                                  int star = 1;
                                  star <= TeacherRating.maxStars;
                                  star++
                                )
                                  Icon(
                                    star <= rating.average.round()
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 16,
                                    color: const Color(0xFFB26A00),
                                  ),
                              ],
                            ),
                            Text(
                              rating.averageLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
        ),
        StreamBuilder<List<TeacherReview>>(
          stream: _reviews,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<TeacherReview>> snapshot,
              ) {
                if (snapshot.hasError) {
                  // (P16) «لا توجد تقييمات» و«تعذّر تحميل التقييمات» ليسا
                  // الشيء نفسه: الأول حكم على المدرس، والثاني حكم على الشبكة.
                  return _StreamErrorCard(
                    error: snapshot.error!,
                    onRetry: _resubscribe,
                  );
                }
                final List<TeacherReview> reviews =
                    snapshot.data ?? const <TeacherReview>[];
                if (reviews.isEmpty) {
                  return const EmptyState(
                    icon: Icons.reviews_outlined,
                    title: 'لا توجد تقييمات بعد',
                    message:
                        'يظهر هنا تقييم الطلاب بعد حصص منفّذة. التقييم لا يُكتب '
                        'إلا لمن حضر حصة فعلية مع هذا المدرس.',
                  );
                }
                return Column(
                  children: <Widget>[
                    for (final TeacherReview review in reviews)
                      Padding(
                        padding: AppSpacing.listGap,
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      review.studentName,
                                      style: theme.textTheme.titleSmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    children: <Widget>[
                                      for (
                                        int star = 1;
                                        star <= TeacherRating.maxStars;
                                        star++
                                      )
                                        Icon(
                                          star <= review.rating
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
                                          size: 14,
                                          color: star <= review.rating
                                              ? const Color(0xFFB26A00)
                                              : AppColors.textMuted,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              if (review.hasComment)
                                Text(
                                  review.comment!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.6,
                                  ),
                                ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                _dateLabel(review.createdAt),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
        ),
      ],
    );
  }
}

/// بطاقة خطأ لتدفّق منقطع داخل قسم التقييمات.
///
/// صغيرة عن قصد: القسم جزء من ملف المدرس، فلا يصحّ أن يغطّي انقطاع التقييمات
/// الملف كله. تحمل الزر الذي يعيد الاشتراك.
class _StreamErrorCard extends StatelessWidget {
  const _StreamErrorCard({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppException failure = toAppException(error);
    final ThemeData theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(failure.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            failure.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      ),
    );
  }
}
