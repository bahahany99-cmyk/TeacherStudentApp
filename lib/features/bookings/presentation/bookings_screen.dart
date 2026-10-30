import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/shell/app_tab.dart';
import 'package:teacher_student_app/app/shell/shell_controller.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
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
  Future<void> _openDetails(String bookingId) {
    // (P25) لا حاجة لإعادة قراءة عند العودة: القائمة تُدفع حيًّا من
    // `bookings.watchMine()`، فأي قرار داخل التفاصيل يظهر هنا فور كتابته.
    return Navigator.of(
      context,
    ).pushNamed(RoutePaths.bookingDetails, arguments: bookingId);
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
              SectionHeader(
                title: isTeacher ? 'طلبات واردة' : 'طلباتي',
                subtitle: isTeacher
                    ? 'افتح الطلب للقبول أو الرفض أو اقتراح وقت بديل'
                    : 'كل طلب يظل بانتظار موافقة المدرس حتى يردّ عليه',
              ),
              // (P25) **البند 7:** قائمة حيّة بدل قراءة عند البناء. قبل ذلك
              // كان قبول المدرس يكتب الحالة في الخادم بينما شاشة الطالب تعرض
              // اللقطة القديمة (فراغ) حتى يعيد فتحها. الآن الطلب المقبول يظهر
              // ويُحدَّث فورًا عبر `watchMine`.
              StreamBuilder<List<BookingRequest>>(
                stream: AppServicesScope.of(context).bookings.watchMine(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<BookingRequest>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return const EmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'تعذّر تحميل الحجوزات',
                      message: 'تحقّق من الاتصال ثم أعد فتح الصفحة.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final List<BookingRequest> bookings = snapshot.data!;
                  if (bookings.isEmpty) {
                    // (P26) حالة الفراغ تحمل مخرجًا لا نصًّا: الطالب يُوجَّه
                    // إلى استعراض المدرسين، والمدرس إلى مجموعاته. زر لا يعمل
                    // أسوأ من لا زر، لذلك يُخفى خارج الهيكل (اختبار منفرد).
                    final ShellController? shell = ShellScope.readOrNull(
                      context,
                    );
                    return EmptyState(
                      icon: isTeacher
                          ? Icons.inbox_outlined
                          : Icons.event_available_outlined,
                      title: 'لا توجد طلبات بعد',
                      message: isTeacher
                          ? 'حين يطلب طالب حصة ستظهر طلباته هنا مباشرة.'
                          : 'اطلب حصة من صفحة المدرس، وسيظهر الطلب هنا بحالته.',
                      primaryActionLabel: shell == null
                          ? null
                          : (isTeacher
                                ? 'إدارة مجموعاتي'
                                : 'استكشف المدرسين الآن'),
                      onPrimaryAction: shell == null
                          ? null
                          : () => shell.goTo(
                              isTeacher ? AppTab.groups : AppTab.teachers,
                            ),
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
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }
}
