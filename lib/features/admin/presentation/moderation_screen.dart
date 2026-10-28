import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/content_report.dart';
import 'package:teacher_student_app/data/models/teacher_review.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// ما تحتاجه شاشة المراجعة في قراءة واحدة.
class _ModerationData {
  const _ModerationData({required this.reports, required this.reviews});

  final List<ContentReport> reports;
  final List<TeacherReview> reviews;
}

/// «المراجعة» (P14): البلاغات المفتوحة وأحدث التقييمات.
///
/// **لماذا قائمتان؟** لأن البلاغ يصل من المستخدمين (ويحتاج ردًّا)، بينما
/// المسؤول قد يرى محتوى مخالفًا بنفسه قبل أن يُبلَّغ عنه. القرار على التقييم
/// واحد في الحالتين: حذف إداري يُنقص المجموع في نفس الكتابة (A-90).
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  int _revision = 0;

  AppServices get _services => AppServicesScope.of(context);

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) {
        return;
      }
      setState(() => _revision++);
      AppSnackBar.show(context, success, type: AppMessageType.success);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        toAppException(error).message,
        type: AppMessageType.error,
      );
    }
  }

  /// حذف تقييم مخالف ثم إغلاق البلاغ الذي أشار إليه — بالترتيب نفسه.
  Future<void> _removeReportedReview(ContentReport report) async {
    await _run(() async {
      await _services.admin.deleteReview(report.targetId);
      await _services.admin.resolveReport(
        reportId: report.id,
        resolution: ReportResolution.resolved,
        note: 'حُذف التقييم المخالف.',
      );
    }, 'حُذف التقييم وأُغلق البلاغ.');
  }

  Future<void> _removeReview(TeacherReview review) async {
    await _run(
      () => _services.admin.deleteReview(review.bookingId),
      'حُذف التقييم، وتحدّث متوسط المدرس.',
    );
  }

  Future<void> _resolve(ContentReport report) async {
    await _run(
      () => _services.admin.resolveReport(
        reportId: report.id,
        resolution: ReportResolution.dismissed,
        note: 'لا يوجد مخالفة بعد المراجعة.',
      ),
      'استُبعد البلاغ بلا إجراء على المحتوى.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('المراجعة والبلاغات')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: AsyncView<_ModerationData>(
                key: ValueKey<int>(_revision),
                load: () async {
                  final List<ContentReport> reports =
                      await _services.admin.listOpenReports();
                  final List<TeacherReview> reviews =
                      await _services.admin.listRecentReviews();
                  return _ModerationData(reports: reports, reviews: reviews);
                },
                builder:
                    (BuildContext context, _ModerationData data) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          const InfoNote(
                            text:
                                'حذف تقييم إجراء نهائي: القواعد تمنع تعديله أو '
                                'حذفه من التطبيق، وتنقص مجموع تقييمات المدرس في '
                                'نفس الكتابة الذرّية.',
                          ),
                          const SectionHeader(
                            title: 'البلاغات المفتوحة',
                            subtitle: 'الأحدث أولًا',
                          ),
                          if (data.reports.isEmpty)
                            const EmptyState(
                              icon: Icons.flag_outlined,
                              title: 'لا بلاغات مفتوحة',
                              message: 'كل ما وصل روجع وحُسم.',
                            )
                          else
                            for (final ContentReport report
                                in data.reports) ...<Widget>[
                              _ReportCard(
                                report: report,
                                onRemoveContent:
                                    report.targetType ==
                                        ReportTargetType.review
                                    ? () => _removeReportedReview(report)
                                    : null,
                                onDismiss: () => _resolve(report),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                          const SectionHeader(
                            title: 'أحدث التقييمات',
                            subtitle: 'مراجعة مباشرة قبل ورود بلاغ',
                          ),
                          if (data.reviews.isEmpty)
                            const EmptyState(
                              icon: Icons.rate_review_outlined,
                              title: 'لا تقييمات بعد',
                            )
                          else
                            for (final TeacherReview review
                                in data.reviews) ...<Widget>[
                              _ReviewCard(
                                review: review,
                                onRemove: () => _removeReview(review),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                          const SizedBox(height: AppSpacing.md),
                        ],
                      );
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة بلاغ واحد + قراره.
class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onDismiss,
    this.onRemoveContent,
  });

  final ContentReport report;
  final VoidCallback onDismiss;

  /// `null` حين لا يكون الهدف تقييمًا (لا يوجد حذف له في هذه المرحلة).
  final VoidCallback? onRemoveContent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  report.targetLabel ??
                      '${report.targetType.label} #${report.targetId}',
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              StatusChip(
                label: report.targetType.label,
                color: AppColors.demoForeground,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'السبب: ${report.reason ?? 'غير محدد'}',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
          ),
          if (report.details != null && report.details!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              report.details!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            'من: ${report.reporterId ?? 'مستخدم'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            children: <Widget>[
              if (onRemoveContent != null)
                FilledButton.icon(
                  onPressed: onRemoveContent,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('حذف المحتوى'),
                ),
              OutlinedButton.icon(
                onPressed: onDismiss,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('استبعاد البلاغ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// بطاقة تقييم في قائمة المراجعة.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onRemove});

  final TeacherReview review;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String comment = review.comment ?? '';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(width: AppSpacing.xs),
              StatusChip(
                label: '${review.rating} من 5',
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'المدرس: ${review.teacherId}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (comment.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(comment, style: theme.textTheme.bodySmall?.copyWith(height: 1.6)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('حذف التقييم'),
            ),
          ),
        ],
      ),
    );
  }
}
