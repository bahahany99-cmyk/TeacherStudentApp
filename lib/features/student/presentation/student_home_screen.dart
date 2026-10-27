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
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_card.dart';

/// الصفحة الرئيسية لواجهة الطالب.
///
/// عرض فقط: لا بحث حقيقي، ولا حجز، ولا قراءة من Firestore.
class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name =
        SessionScope.of(context).user?.displayName ?? 'طالب';

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const DemoBanner(),
              // بطاقة ترحيب بتدرّج الهوية (v2): السطح المشبع الوحيد في الصفحة.
              AppCard(
                gradient: AppGradients.hero,
                borderColor: Colors.white24,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'أهلًا $name',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ابحث عن مدرس مناسب أو تابع مجموعاتك وحجوزاتك.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withAlpha(215),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                enabled: false,
                decoration: const InputDecoration(
                  hintText: 'ابحث باسم المدرس أو المادة (غير مفعّل في هذه المرحلة)',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('اختصارات', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        _ShortcutChip(
                          icon: Icons.person_search_outlined,
                          label: 'ابحث عن مدرس',
                          onTap: () => ShellScope.read(context).goTo(AppTab.teachers),
                        ),
                        _ShortcutChip(
                          icon: Icons.groups_outlined,
                          label: 'المجموعات الدراسية',
                          onTap: () => ShellScope.read(context).goTo(AppTab.groups),
                        ),
                        _ShortcutChip(
                          icon: Icons.event_note_outlined,
                          label: 'حجوزاتي',
                          onTap: () => ShellScope.read(context).goTo(AppTab.bookings),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionHeader(
                title: 'مدرسون مميزون',
                subtitle: 'قسم مستقل عن نتائج البحث العادي',
                actionLabel: 'عرض الكل',
                onActionTap: () =>
                    ShellScope.read(context).goTo(AppTab.teachers),
              ),
              AsyncView<List<TeacherProfile>>(
                load: () => AppServicesScope.of(context).teachers.listFeatured(),
                builder: (BuildContext context, List<TeacherProfile> teachers) {
                  if (teachers.isEmpty) {
                    return const EmptyState(
                      icon: Icons.workspace_premium_outlined,
                      title: 'لا يوجد مدرسون مميزون حاليًا',
                    );
                  }
                  return Column(
                    children: teachers
                        .map(
                          (TeacherProfile t) => TeacherCard(
                            teacher: t,
                            onTap: () => Navigator.of(context).pushNamed(
                              RoutePaths.teacherProfile,
                              arguments: t.id,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader(title: 'حجوزاتي القادمة'),
              AsyncView<List<BookingRequest>>(
                load: () => AppServicesScope.of(context).bookings.listMine(),
                builder: (BuildContext context, List<BookingRequest> bookings) {
                  final List<BookingRequest> pending = bookings
                      .where((BookingRequest b) => b.waitingForTeacher)
                      .take(2)
                      .toList(growable: false);
                  if (pending.isEmpty) {
                    return const EmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'لا توجد حجوزات قيد الانتظار',
                      message: 'سيظهر هنا أي طلب حجز بانتظار موافقة المدرس.',
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
                                  Icon(
                                    Icons.schedule_outlined,
                                    color: AppColors.statusPending,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          b.teacherName,
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
                                  Text(
                                    b.status.label,
                                    style: theme.textTheme.labelSmall?.copyWith(
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
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }
}

/// اختصار في الرئيسية ينقل إلى قسم آخر داخل الهيكل (بلا تكرار لمنطق التنقل).
class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelSmall,
      onPressed: onTap,
    );
  }
}
