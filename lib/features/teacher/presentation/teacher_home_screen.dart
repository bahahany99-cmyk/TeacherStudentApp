import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/app_tab.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/group_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';

/// الصفحة الرئيسية لواجهة المدرس.
///
/// عرض فقط: حالة الملف تجريبية، ولا توجد إجراءات موافقة فعلية.
class TeacherHomeScreen extends StatelessWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = SessionScope.of(context).user?.displayName ?? 'مدرس';

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const DemoBanner(),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'ملفك التعريفي',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const Flexible(
                          child: StatusChip(
                            label: 'قيد المراجعة',
                            color: AppColors.statusPending,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'أهلًا $name، ملفك بانتظار مراجعة الإدارة. لن يظهر للطلاب '
                      'ولا يمكن استقبال حجوزات قبل الاعتماد (C-06).',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showComingSoon(context),
                            child: const Text('تعديل الملف'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showComingSoon(context),
                            child: const Text('إضافة مجموعة'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionHeader(
                title: 'طلبات بانتظار موافقتك',
                subtitle: 'الموافقة والرفض سيُنفَّذان على الخادم في مرحلة لاحقة',
                actionLabel: 'كل الطلبات',
                onActionTap: () =>
                    ShellScope.read(context).goTo(AppTab.bookings),
              ),
              AsyncView<List<BookingRequest>>(
                load: () => AppServicesScope.of(context).bookings.listMine(),
                builder: (BuildContext context, List<BookingRequest> bookings) {
                  final List<BookingRequest> pending = bookings
                      .where((BookingRequest b) => b.waitingForTeacher)
                      .toList(growable: false);
                  if (pending.isEmpty) {
                    return const EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'لا توجد طلبات جديدة',
                    );
                  }
                  return Column(
                    children: pending
                        .map(
                          (BookingRequest b) => Padding(
                            padding: AppSpacing.listGap,
                            child: AppCard(
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          b.studentName,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        Text(
                                          b.subject,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Flexible(
                                    child: StatusChip(
                                      label: 'بانتظار المراجعة',
                                      color: AppColors.statusPending,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              SectionHeader(
                title: 'مجموعاتي',
                actionLabel: 'إدارة المجموعات',
                onActionTap: () =>
                    ShellScope.read(context).goTo(AppTab.groups),
              ),
              AsyncView<List<StudyGroup>>(
                load: () => AppServicesScope.of(
                  context,
                ).groups.listForTeacher(DemoData.demoTeacherId),
                builder: (BuildContext context, List<StudyGroup> groups) {
                  if (groups.isEmpty) {
                    return const EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'لم تُنشئ مجموعات بعد',
                      message: 'إنشاء المجموعات وإدارة الأعضاء في مرحلة لاحقة.',
                    );
                  }
                  return Column(
                    children: groups
                        .map(
                          (StudyGroup g) => GroupCard(
                            group: g,
                            onJoinTap: () => _showComingSoon(context),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'العملات المالية غير مدعومة داخل التطبيق؛ الاتفاق على '
                        'السعر والدفع يتم بينك وبين الطالب خارج التطبيق (C-15).',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
    );
  }

  void _showComingSoon(BuildContext context) {
    AppSnackBar.show(context, AppStrings.comingSoon);
  }
}
