import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/content_report.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/admin/presentation/widgets/verification_actions.dart';

/// أرقام لوحة الإدارة — تُقرأ مرة واحدة عند فتح الشاشة.
class _AdminOverview {
  const _AdminOverview({
    required this.queue,
    required this.reports,
    required this.verified,
    required this.featured,
  });

  final List<TeacherProfile> queue;
  final List<ContentReport> reports;
  final int verified;

  /// كم ملفًا معروضًا في شريط «مدرسون مميزون» الآن (P15).
  final int featured;
}

/// «لوحة الإدارة» (P14): مدخل واحد لطابور التوثيق والمراجعة.
///
/// **لماذا شاشة أرقام لا جدول؟** لأن عمل المسؤول في هذا التطبيق قرارَان لا
/// أكثر: توثيق ملف، وحسم بلاغ. الأرقام تجيب «هل يوجد ما ينتظرني؟» قبل فتح
/// أي قائمة، وكل بطاقة تقود إلى الشاشة المتخصصة.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  /// يُزاد بعد كل قرار ليُعيد `AsyncView` القراءة من المصدر (الطابور والأرقام).
  int _revision = 0;

  Future<void> _approve(TeacherProfile profile) async {
    final bool done = await approveTeacherProfile(context, profile);
    if (done && mounted) {
      setState(() => _revision++);
    }
  }

  Future<void> _reject(TeacherProfile profile) async {
    final bool done = await rejectTeacherProfile(context, profile);
    if (done && mounted) {
      setState(() => _revision++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

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
                  // (P18) التحقق من الجلسة داخل `DemoBanner` نفسه.
                  const DemoBanner(),
                  const SizedBox(height: AppSpacing.sm),
                  AsyncView<_AdminOverview>(
                    // (P19) مفتاح المراجعة: بعد أي قرار يُعاد القراءة، فيظهر
                    // الملف التالي في القائمة العددية فورًا بدل رقم قديم.
                    key: ValueKey<int>(_revision),
                    load: () async {
                      // نقرأ الخدمات مرة واحدة **قبل** أي `await`: لا نستخدم
                      // `BuildContext` بعد فجوة غير متزامنة.
                      final AppServices services = AppServicesScope.of(context);
                      final List<TeacherProfile> queue =
                          await services.admin.listVerificationQueue();
                      final List<ContentReport> reports =
                          await services.admin.listOpenReports();
                      final List<TeacherProfile> all =
                          await services.admin.listAllProfiles();
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
                        featured: all
                            .where(
                              (TeacherProfile profile) =>
                                  profile.isFeatured &&
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
                              const SizedBox(height: AppSpacing.sm),
                              // (P15) التمييز قرار إداري مستقل عن التوثيق.
                              _OverviewTile(
                                icon: Icons.workspace_premium_outlined,
                                title: 'المدرسون المميزون',
                                value: '${overview.featured}',
                                caption: overview.featured == 0
                                    ? 'لا أحد في شريط الرئيسية'
                                    : 'يظهرون في شريط الرئيسية',
                                accent: AppColors.accent,
                                onTap: () => Navigator.of(
                                  context,
                                ).pushNamed(RoutePaths.adminFeatured),
                              ),
                              // (P19) قائمة المعلّقين مع قرار مباشر: المسؤول
                              // يوثّق من اللوحة بنقرة واحدة بلا فتح شاشة أخرى،
                              // والرفض يفتح سببًا مكتوبًا (لا رفض صامت).
                              const SizedBox(height: AppSpacing.md),
                              _PendingTeachersSection(
                                overview: overview,
                                onApprove: _approve,
                                onReject: _reject,
                                onOpenQueue: () => Navigator.of(
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
                        const InfoNote(
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

/// قائمة سريعة للملفات المنتظرة قرارًا، مع إجراء مباشر لكل ملف (P19).
///
/// **لماذا هنا وفي «طابور التوثيق» معًا؟** لأن مسار المسؤول اليومي هو: افتح
/// اللوحة ← «هل يوجد ما ينتظرني؟» ← قرّر. إجباره على فتح شاشة ثانية لكل ملف
/// يضيف خطوة بلا فائدة. القرار نفسه ليس مكررًا منطقيًا: كلاهما يستدعي
/// `approveTeacherProfile` / `rejectTeacherProfile` المشتركتين.
///
/// نعرض أول ثلاثة ملفات فقط: القائمة الكاملة (مع كل التفاصيل) في شاشة الطابور،
/// فلا تتحوّل اللوحة إلى جدول طويل.
class _PendingTeachersSection extends StatelessWidget {
  const _PendingTeachersSection({
    required this.overview,
    required this.onApprove,
    required this.onReject,
    required this.onOpenQueue,
  });

  final _AdminOverview overview;
  final ValueChanged<TeacherProfile> onApprove;
  final ValueChanged<TeacherProfile> onReject;
  final VoidCallback onOpenQueue;

  /// أقصى عدد ملفات معروضة في اللوحة.
  static const int _visibleLimit = 3;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TeacherProfile> queue = overview.queue;

    if (queue.isEmpty) {
      return const EmptyState(
        icon: Icons.task_alt,
        title: 'لا ملفات بانتظار التوثيق',
        message: 'كل من أرسل ملفه رُوجع. سيظهر هنا أي ملف جديد فورًا.',
      );
    }

    final List<TeacherProfile> visible = queue
        .take(_visibleLimit)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader(
          title: 'بانتظار التوثيق',
          subtitle: 'التوثيق يفتح الملف للطلاب فورًا',
          icon: Icons.verified_user_outlined,
        ),
        for (final TeacherProfile profile in visible) ...<Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    StatusChip(
                      label: profile.status.label,
                      color: AppColors.demoForeground,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${profile.subject} • ${profile.stage} • ${profile.locationLabel}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        key: Key('dashboard-approve-${profile.id}'),
                        onPressed: () => onApprove(profile),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('توثيق'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: Key('dashboard-reject-${profile.id}'),
                        onPressed: () => onReject(profile),
                        icon: const Icon(Icons.block_outlined, size: 18),
                        label: const Text('رفض'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (queue.length > visible.length)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('dashboard-open-queue'),
              onPressed: onOpenQueue,
              icon: const Icon(Icons.list_alt_outlined, size: 18),
              label: Text('عرض كل الطابور (${queue.length})'),
            ),
          ),
      ],
    );
  }
}
