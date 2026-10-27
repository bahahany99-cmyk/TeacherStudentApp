import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/detail_row.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// تفاصيل طلب حجز.
///
/// عرض فقط: لا موافقة، ولا رفض، ولا إلغاء — كلها تحتاج كتابة على الخادم
/// (Phase 8). نعرض الحالة كما هي، دون وعود بخطوات غير منفّذة.
class BookingDetailsScreen extends StatelessWidget {
  const BookingDetailsScreen({super.key, required this.bookingId});

  final String bookingId;

  Color _statusColor(BookingStatus status) {
    return switch (status) {
      BookingStatus.pending => AppColors.statusPending,
      BookingStatus.accepted => AppColors.statusAccepted,
      BookingStatus.rejected => AppColors.statusRejected,
      BookingStatus.cancelled => AppColors.statusNeutral,
      BookingStatus.completed => AppColors.statusAccepted,
    };
  }

  String _formatDateTime(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} — $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SessionController session = SessionScope.of(context);
    final bool isTeacherView = session.role == UserRole.teacher;

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الطلب')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: AsyncView<BookingRequest?>(
                load: () =>
                    AppServicesScope.of(context).bookings.findById(bookingId),
                emptyBuilder: (BuildContext context) => const EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'الطلب غير موجود',
                  message:
                      'ربما حُذف الطلب، أو أنه ليس من طلباتك (الوصول محصور '
                      'بصاحب الطلب والطرف الآخر).',
                ),
                builder: (BuildContext context, BookingRequest? booking) {
                  if (booking == null) {
                    return const EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: 'الطلب غير موجود',
                    );
                  }

                  return Column(
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
                                    isTeacherView
                                        ? booking.studentName
                                        : booking.teacherName,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                StatusChip(
                                  label: booking.status.label,
                                  color: _statusColor(booking.status),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              isTeacherView
                                  ? 'طالب طلب حصة'
                                  : 'المدرس صاحب الطلب',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            DetailRow(
                              icon: Icons.menu_book_outlined,
                              label: 'المادة',
                              value: booking.subject,
                            ),
                            DetailRow(
                              icon: Icons.schedule_outlined,
                              label: 'تاريخ الطلب',
                              value: _formatDateTime(booking.requestedAt),
                            ),
                            DetailRow(
                              icon: Icons.tag,
                              label: 'رقم الطلب',
                              value: booking.id,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const SectionHeader(
                        title: 'ملاحظة الطالب',
                        subtitle: 'نص كتبه الطالب مع الطلب إن وُجد',
                      ),
                      AppCard(
                        child: Text(
                          booking.note ?? 'لا توجد ملاحظة مرفقة بهذا الطلب.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const InfoNote(
                        text:
                            'الموافقة والرفض والإلغاء غير مفعّلة في هذه المرحلة؛ '
                            'تُنفَّذ على الخادم مع قسم الحجوزات (Phase 8)، ولا '
                            'يمكن للطالب تغيير حالة الطلب بنفسه (C-08).',
                      ),
                      const SizedBox(height: AppSpacing.lg),
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
