import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/data/models/content_report.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// ملخّص اللوحة: ما ينتظر قرارًا الآن.
class AdminOverview {
  const AdminOverview({
    required this.queue,
    required this.reports,
    required this.verifiedCount,
    required this.totalProfiles,
  });

  final List<TeacherProfile> queue;
  final List<ContentReport> reports;
  final int verifiedCount;
  final int totalProfiles;
}

/// «لوحة الإدارة» (P14): مدخل واحد لطابور التوثيق والمراجعة.
///
/// الأرقام تُقرأ من المستودع لا من عدّاد محلي، فلا تختلف عمّا تراه الشاشات.
/// ولا شيء هنا يمنح صلاحية: كل كتابة تفحصها القواعد بالادعاء الإداري.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  /// يُزاد بعد كل عودة من شاشة فرعية لتُقرأ الأرقام من جديد.
  int _revision = 0;

  Future<AdminOverview> _load() async {
    // نقرأ الحاوية قبل أي `await` (قاعدة `use_build_context_synchronously`).
    final AppServices services = AppServicesScope.of(context);
    final List<TeacherProfile> queue = await services.admin
        .listVerificationQueue();
    final List<ContentReport> reports = await services.admin.listOpenReports();
    final List<TeacherProfile> all = await services.admin.listAllProfiles();
    return AdminOverview(
      queue: queue,
      reports: reports,
      verifiedCount: all
          .where(
            (TeacherProfile profile) =>
                profile.status == TeacherProfileStatus.verified,
          )
          .length,
      totalProfiles: all.length,
    );
  }

  Future<void> _open(String route) async {
    await Navigator.of(context).pushNamed(route);
    if (!mounted) {
      return;
    }
    setState(() => _revision++);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('لوحة الإدارة')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const DemoBanner(),
                  Text(
                    'قرارات التوثيق والمراجعة تُفرض في قواعد Firestore '
                    'بالادعاء الإداري، فلا تكفي هذه الشاشة لمنح صلاحية.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AsyncView<AdminOverview>(
                    key: ValueKey<int>(_revision),
                    load: _load,
                    builder: (BuildContext context, AdminOverview data) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.hourglass_top_rounded,
                                  label: 'بانتظار التوثيق',
                                  value: '${data.queue.length}',
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.flag_outlined,
                                  label: 'بلاغات مفتوحة',
                                  value: '${data.reports.length}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.verified_outlined,
                                  label: 'ملفات موثّقة',
                                  value: '${data.verifiedCount}',
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.folder_copy_outlined,
                                  label: 'كل الملفات',
                                  value: '${data.totalProfiles}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sectionGap),
                          const SectionHeader(title: 'الأقسام'),
                          AppCard(
                            onTap: () => _open(RoutePaths.adminVerification),
                            child: _EntryRow(
                              icon: Icons.badge_outlined,
                              title: 'طابور التوثيق',
                              subtitle:
                                  '${data.queue.length} ملف بانتظار قرار',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          AppCard(
                            onTap: () => _open(RoutePaths.adminModeration),
                            child: _EntryRow(
                              icon: Icons.reviews_outlined,
                              title: 'المراجعة والبلاغات',
                              subtitle:
                                  '${data.reports.length} بلاغ مفتوح · أحدث '
                                  'التقييمات',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sectionGap),
                          const InfoNote(
                            text: 'الملف غير الموثّق لا يظهر للطلاب ولا يقبل '
                                'حجزًا، والفرض في القواعد لا في الواجهة.',
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

/// خلية رقم كبير فوق تسمية صغيرة.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// صف مدخل قسم: أيقونة + عنوان + سطر توضيحي + سهم.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleMedium),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_left_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}
