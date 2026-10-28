import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/booking_rules.dart';

/// صفحة الحجوزات (P10).
///
/// قائمة طلبات الطرف الحالي، وكل صف يفتح شاشة التفاصيل حيث تُنفَّذ الإجراءات
/// (قبول/رفض/اقتراح وقت بديل/إلغاء/إعلان تنفيذ). بعد العودة من التفاصيل نُعيد
/// القراءة، لأن الحالة قد تغيّرت هناك.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key, required this.viewerRole});

  final UserRole viewerRole;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  /// مفتاح إعادة القراءة بعد أي تغيير يعود من شاشة التفاصيل.
  int _revision = 0;

  Future<void> _openDetails(String bookingId) async {
    await Navigator.of(context).pushNamed(
      RoutePaths.bookingDetails,
      arguments: bookingId,
    );
    if (mounted) {
      setState(() => _revision++);
    }
  }

  Color _statusColor(BookingStatus status) {
    return switch (status) {
      BookingStatus.pending => AppColors.statusPending,
      BookingStatus.accepted => AppColors.statusAccepted,
      BookingStatus.rejected => AppColors.statusRejected,
      BookingStatus.cancelled => AppColors.statusNeutral,
      BookingStatus.cancelledLate => AppColors.statusRejected,
      BookingStatus.rescheduleProposed => AppColors.statusPending,
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
    final bool isTeacher = widget.viewerRole == UserRole.teacher;

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
                    ? 'افتح الطلب للقبول أو الرفض أو اقتراح وقت بديل'
                    : 'كل طلب يظل بانتظار موافقة المدرس (C-08)',
              ),
              AsyncView<List<BookingRequest>>(
                key: ValueKey<int>(_revision),
                load: () => AppServicesScope.of(context).bookings.listMine(),
                builder: (BuildContext context, List<BookingRequest> bookings) {
                  if (bookings.isEmpty) {
                    return const EmptyState(
                      icon: Icons.event_note_outlined,
                      title: 'لا توجد طلبات بعد',
                      message:
                          'اطلب حصة من صفحة المدرس، وسيظهر الطلب هنا بحالته.',
                    );
                  }
                  return Column(
                    children: <Widget>[
                      for (final BookingRequest booking in bookings)
                        Padding(
                          padding: AppSpacing.listGap,
                          child: AppCard(
                            onTap: () => _openDetails(booking.id),
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
                                    Flexible(
                                      child: StatusChip(
                                        label: booking.status.label,
                                        color: _statusColor(booking.status),
                                      ),
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
                                      Icons.event_outlined,
                                      size: 14,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Flexible(
                                      child: Text(
                                        booking.hasSchedule
                                            ? BookingRules.slotLabel(booking)
                                            : _formatDateTime(
                                                booking.requestedAt,
                                              ),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                'المحادثة المرتبطة بالحجز تُنفَّذ في المرحلة التالية (P11)، '
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
