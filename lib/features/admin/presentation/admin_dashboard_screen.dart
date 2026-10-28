import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/data/models/content_report.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// أرقام لوحة الإدارة — تُقرأ مرة واحدة عند فتح الشاشة.
class _AdminOverview {
  const _AdminOverview({
    required this.queue,
    required this.reports,
    required this.verified,
  });

  final List<TeacherProfile> queue;
  final List<ContentReport> reports;
  final int verified;
}

/// «لوحة الإدارة» (P14): مدخل واحد لطابور التوثيق والمراجعة.
///
/// **لماذا شاشة أرقام لا جدول؟** لأن عمل المسؤول في هذا التطبيق قرارَان لا
/// أكثر: توثيق ملف، وحسم بلاغ. الأرقام تجيب «هل يوجد ما ينتظرني؟» قبل فتح
/// أي قائمة، وكل بطاقة تقود إلى الشاشة المتخصصة.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDemo = SessionScope.of(context).isDemoSession;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('لوحة الإدارة')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (isDemo) const DemoBanner(),
                  const SizedBox(height: AppSpacing.sm),
                  AsyncView<_AdminOverview>(
                    load: () async {
                      final List<TeacherProfile> queue = await AppServicesScope.of(
                        context,
                      ).admin.listVerificationQueue();
                      final List<ContentReport> reports =
                          await AppServicesScope.of(
                            context,
                          ).admin.listOpenReports();
                      final List<TeacherProfile> all = await AppServicesScope.of(
                        context,
                      ).admin.listAllProfiles();
                      return _AdminOverview(
                        queue: queue,
                        reports: reports,
                        verified: all
                            .where(
                              (TeacherProfile profile) =>
                                  profile.status ==
                                  TeacherProfileStatus.verified,
                            )
                            .length,
                      );
                    },
                    builder:
                        (BuildContext context, _AdminOverview overview) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _OverviewTile(
                                icon: Icons.verified_user_outlined,
                                title: 'طابور التوثيق',
                                value: '${overview.queue.length}',
                                caption: overview.queue.isEmpty
                                    ? 'لا ملفات بانتظار قرار'
                                    : 'ملف بانتظار قرار',
                                accent: theme.colorScheme.primary,
                                onTap: () => Navigator.of(
                                  context,
                                ).pushNamed(RoutePaths.adminVerification),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _OverviewTile(
                                icon: Icons.flag_outlined,
                                title: 'البلاغات المفتوحة',
                                value: '${overview.reports.length}',
                                caption: overview.reports.isEmpty
                                    ? 'لا بلاغات تحتاج مراجعة'
                                    : 'بلاغ بانتظار حسم',
                                accent: AppColors.demoForeground,
                                onTap: () => Navigator.of(
                                  context,
                                ).pushNamed(RoutePaths.adminModeration),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _OverviewTile(
                                icon: Icons.school_outlined,
                                title: 'المدرسون الموثّقون',
                                value: '${overview.verified}',
                                caption: 'يظهرون في بحث الطلاب',
                                accent: theme.colorScheme.secondary,
                                onTap: () => Navigator.of(
                                  context,
                                ).pushNamed(RoutePaths.adminVerification),
                              ),
                            ],
                          );
                        },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const SectionHeader(title: 'كيف تُفرض الصلاحية؟'),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        InfoNote(
                          text:
                              'كل قرار في هذه اللوحة (توثيق، رفض، حسم بلاغ، '
                              'حذف تقييم) يُفحص في قواعد Firestore بشرط '
                              'الادعاء الإداري على الخادم. إخفاء الشاشة هنا '
                              'لتجربة أنظف فقط، وليس حماية.',
                          icon: Icons.shield_outlined,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'الملف غير الموثّق لا يظهر في البحث ولا يستطيع قبول '
                          'حجز أو طلب انضمام — القواعد تقرأ حالته من مستنده '
                          'لحظة الكتابة، فلا تنفع إعادة تسمية الحالة في الواجهة.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
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

/// بطاقة رقم واحد + عنوان + شرح، تنقل إلى الشاشة المتخصصة.
class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String caption;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: AppSpacing.avatarSm / 2,
            backgroundColor: accent.withAlpha(28),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  caption,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          StatusChip(label: value, color: accent),
        ],
      ),
    );
  }
}
