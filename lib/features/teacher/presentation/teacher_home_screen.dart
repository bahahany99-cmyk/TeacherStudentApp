import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/app_tab.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/teacher_groups_section.dart';
import 'package:teacher_student_app/features/teacher/presentation/widgets/teacher_profile_status_card.dart';

/// الصفحة الرئيسية لواجهة المدرس.
///
/// (P21) بطاقة أعلى الصفحة تقرأ **ملف صاحب الجلسة الحقيقي** وتعرض حالته
/// الحقيقية (بلا ملف / مسودة / قيد المراجعة / موثّق / مرفوض مع سبب الإدارة).
/// لا نص ثابت ولا إشارة إلى بيئة التطوير.
class TeacherHomeScreen extends StatelessWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SessionController session = SessionScope.of(context);
    // نفس المعرّف الذي تكتبه بقية الشاشات (uid الحقيقي أو معرّف المعاينة).
    final String teacherId = CurrentTeacher.idOf(session);

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // (P21) بطاقة الحالة تُبنى من `teacherProfiles/{uid}` الحقيقي:
              // بلا ملف ⇒ دعوة إنشاء، وقيد المراجعة ⇒ انتظار، ومرفوض ⇒ السبب.
              // لا نص ثابت ولا رموز سياسات داخلية في واجهة المستخدم.
              TeacherProfileStatusCard(teacherId: teacherId),
              const SizedBox(height: AppSpacing.sectionGap),
              SectionHeader(
                title: 'طلبات بانتظار موافقتك',
                subtitle: 'راجع الطلب ثم اقبله أو ارفضه من التفاصيل',
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
              // (P23) زر واحد فقط للإنشاء. العنوان كان يحمل سابقًا «إدارة
              // المجموعات» بينما يفتح نموذج **الإنشاء** — نصّ يخالف فعله.
              const TeacherGroupsSection(maxItems: 3),
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
                        'الدفع يتم بينك وبين الطالب خارج التطبيق. السعر في '
                        'ملفك استرشادي، والتطبيق لا يحتفظ بأي مبالغ.',
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
