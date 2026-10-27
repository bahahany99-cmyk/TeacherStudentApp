import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/app_tab.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/teacher_groups_section.dart';

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
              // بطاقة تمهيدية «لمعة» بدل الكتلة الخضراء المشبعة (نسخة 3).
              // نص داكن على سطح فاتح: تباين أعلى وأهدأ بصريًا من الأبيض على
              // الأخضر، وأقرب إلى المرجع المعتمد.
              AppCard(
                gradient: AppGradients.glow,
                borderColor: AppBorders.onTint,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'ملفك التعريفي',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const StatusChip(
                          label: 'حساب تجريبي',
                          color: AppColors.demoForeground,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'أهلًا $name، هذه معاينة محلية بلا Firebase. حالة اعتماد '
                      'ملفك تأتي من الخادم، والملف لا يظهر للطلاب قبل الاعتماد '
                      '(C-06).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.75,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // زرّان بشكل «حبة دواء» في صف واحد: حشوة أفقية صغيرة +
                    // سطر واحد إجباري، فلا يلتف النص على سطرين كما كان يحدث
                    // على الشاشات الضيقة.
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pushNamed(
                              RoutePaths.myTeacherProfile,
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
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
                            ).pushNamed<bool>(RoutePaths.groupForm),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                              ),
                              textStyle: theme.textTheme.labelMedium,
                            ),
                            child: const Text(
                              'إضافة مجموعة',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
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
                              onTap: () => Navigator.of(context).pushNamed(
                                RoutePaths.bookingDetails,
                                arguments: b.id,
                              ),
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
              const SizedBox(height: AppSpacing.sectionGap),
              const TeacherGroupsSection(
                maxItems: 3,
                headerActionLabel: 'إدارة المجموعات',
                // الزر داخل القسم؛ ولا نكرّره هنا.
                showCreateButton: true,
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
}
