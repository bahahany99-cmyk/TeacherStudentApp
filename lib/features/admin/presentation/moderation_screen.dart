import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/data/models/content_report.dart';
import 'package:teacher_student_app/data/models/teacher_review.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// بيانات شاشة المراجعة: البلاغات المفتوحة + أحدث التقييمات.
class ModerationData {
  const ModerationData({required this.reports, required this.reviews});

  final List<ContentReport> reports;
  final List<TeacherReview> reviews;
}

/// «المراجعة والبلاغات» (P14): حسم البلاغات وحذف المحتوى المخالف.
///
/// **حدود مقصودة:** الحذف متاح للتقييمات فقط — لأنها المحتوى الوحيد الذي
/// يملك مستودع الإدارة فيه تفويضًا صريحًا (`deleteReview`). بلاغ عن مدرس أو
/// مجموعة يُحسم بالاستبعاد/الحسم مع ملاحظة، ولا يُحذف المستند من هنا.
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  int _revision = 0;

  /// منع نقرتين على البلاغ نفسه أثناء الكتابة.
  final Set<String> _busy = <String>{};

  Future<void> _resolve(
    ContentReport report, {
    required ReportResolution resolution,
    required String message,
    String? note,
    bool deleteReview = false,
  }) async {
    if (_busy.contains(report.id)) {
      return;
    }
    setState(() => _busy.add(report.id));
    final AppServices services = AppServicesScope.of(context);
    try {
      if (deleteReview) {
        await services.admin.deleteReview(report.targetId);
      }
      await services.admin.resolveReport(
        reportId: report.id,
        resolution: resolution,
        note: note,
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, message, type: AppMessageType.success);
      setState(() => _revision++);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        toAppException(error).message,
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busy.remove(report.id));
      }
    }
  }

  Future<void> _deleteReview(TeacherReview review) async {
    if (_busy.contains(review.bookingId)) {
      return;
    }
    setState(() => _busy.add(review.bookingId));
    final AppServices services = AppServicesScope.of(context);
    try {
      await services.admin.deleteReview(review.bookingId);
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        'حُذف التقييم وأُغلق البلاغ المرتبط به إن وُجد.',
        type: AppMessageType.success,
      );
      setState(() => _revision++);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        toAppException(error).message,
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busy.remove(review.bookingId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('المراجعة والبلاغات')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const DemoBanner(),
                  AsyncView<ModerationData>(
                    key: ValueKey<int>(_revision),
                    load: () async {
                      final AppServices services = AppServicesScope.of(context);
                      final List<ContentReport> reports = await services.admin
                          .listOpenReports();
                      final List<TeacherReview> reviews = await services.admin
                          .listRecentReviews(limit: 30);
                      return ModerationData(reports: reports, reviews: reviews);
                    },
                    builder: (BuildContext context, ModerationData data) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const SectionHeader(
                            title: 'البلاغات المفتوحة',
                            subtitle: 'الأحدث أولًا',
                          ),
                          if (data.reports.isEmpty)
                            const EmptyState(
                              icon: Icons.flag_outlined,
                              title: 'لا بلاغات مفتوحة',
                              message: 'ستظهر هنا بلاغات الطلاب عن المحتوى '
                                  'المخالف.',
                            )
                          else
                            for (final ContentReport report in data.reports)
                              _ReportCard(
                                report: report,
                                busy: _busy.contains(report.id),
                                onDeleteContent: () => _resolve(
                                  report,
                                  resolution: ReportResolution.resolved,
                                  message:
                                      'حُذف المحتوى وأُغلق البلاغ.',
                                  note: 'حُذف المحتوى المخالف بقرار إداري.',
                                  deleteReview: true,
                                ),
                                onDismiss: () => _resolve(
                                  report,
                                  resolution: ReportResolution.dismissed,
                                  message: 'استُبعد البلاغ.',
                                  note: 'استُبعد بعد المراجعة.',
                                ),
                              ),
                          const SizedBox(height: AppSpacing.sectionGap),
                          const SectionHeader(
                            title: 'أحدث التقييمات',
                            subtitle: 'حذف التقييم يسحب أثره من المتوسط',
                          ),
                          if (data.reviews.isEmpty)
                            const EmptyState(
                              icon: Icons.star_border_rounded,
                              title: 'لا تقييمات بعد',
                            )
                          else
                            for (final TeacherReview review in data.reviews)
                              _ReviewCard(
                                review: review,
                                busy: _busy.contains(review.bookingId),
                                onDelete: () => _deleteReview(review),
                              ),
                          const SizedBox(height: AppSpacing.sectionGap),
                          const InfoNote(
                            text: 'حذف التقييم وإنقاص المتوسط يحدثان في '
                                'معاملة واحدة، والقواعد تمنع زيادة المتوسط '
                                'بحذف تقييم.',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة بلاغ: الهدف والسبب وزرّا الحسم.
class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.busy,
    required this.onDeleteContent,
    required this.onDismiss,
  });

  final ContentReport report;
  final bool busy;
  final VoidCallback onDeleteContent;
  final VoidCallback onDismiss;

  /// الحذف متاح لتقييم فقط (انظر توثيق الشاشة).
  bool get _canDeleteContent => report.targetType == ReportTargetType.review;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: AppSpacing.listGap,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'السبب: ${report.reason}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${report.targetType.label} · ${report.targetLabel}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (report.details != null && report.details!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                report.details!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                if (_canDeleteContent)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onDeleteContent,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('حذف المحتوى'),
                    ),
                  )
                else
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onDismiss,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('حسم البلاغ'),
                    ),
                  ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onDismiss,
                    child: const Text('استبعاد البلاغ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة تقييم: النجوم والنص + زر الحذف.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.busy,
    required this.onDelete,
  });

  final TeacherReview review;
  final bool busy;
  final VoidCallback onDelete;

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
                const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  '${review.rating}/5',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  review.teacherId,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                review.comment!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('حذف التقييم'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
