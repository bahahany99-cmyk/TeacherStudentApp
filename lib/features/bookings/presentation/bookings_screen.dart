import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// صفحة الحجوزات.
///
/// في المرحلة 2: عرض فقط. لا إنشاء طلب، ولا موافقة/رفض، ولا محادثة.
/// تنفيذ هذه الإجراءات وربطها بالخادم في المرحلة 8.
class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key, required this.viewerRole});

  final UserRole viewerRole;

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
    final bool isTeacher = viewerRole == UserRole.teacher;

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const DemoBanner(),
              SectionHeader(
                title: isTeacher ? 'طلبات واردة' : 'طلباتي',
                subtitle: isTeacher
                    ? 'الموافقة/الرفض غير مفعّلة في هذه المرحلة'
                    : 'كل طلب يظل بانتظار موافقة المدرس (C-08)',
              ),
              AsyncView<List<BookingRequest>>(
                future: AppServicesScope.of(context).bookings.listMine(),
                builder: (BuildContext context, List<BookingRequest> bookings) {
                  if (bookings.isEmpty) {
                    return const EmptyState(
                      icon: Icons.event_note_outlined,
                      title: 'لا توجد طلبات بعد',
                      message:
                          'إنشاء طلبات الحجز وربطها بالخادم في مرحلة لاحقة.',
                    );
                  }
                  return Column(
                    children: <Widget>[
                      for (final BookingRequest booking in bookings)
                        Padding(
                          padding: AppSpacing.listGap,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusLg,
                              ),
                              border: Border.all(
                                color: theme.colorScheme.outline,
                                width: 0.7,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        isTeacher
                                            ? booking.studentName
                                            : booking.teacherName,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ),
                                    StatusChip(
                                      label: booking.status.label,
                                      color: _statusColor(booking.status),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  booking.subject,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.schedule_outlined,
                                      size: 14,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Text(
                                      _formatDateTime(booking.requestedAt),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                                if (booking.note != null) ...<Widget>[
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    booking.note!,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'المحادثات النصية المرتبطة بالحجز تُنفَّذ في مرحلة لاحقة، '
                'مقيدة بعضوية الطلب على الخادم.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
