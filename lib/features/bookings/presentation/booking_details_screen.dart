import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
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
import 'package:teacher_student_app/data/services/booking_repository.dart';
import 'package:teacher_student_app/data/validation/booking_rules.dart';
import 'package:teacher_student_app/features/chat/presentation/chat_launcher.dart';
import 'package:teacher_student_app/features/bookings/widgets/slot_picker_sheet.dart';

/// تفاصيل طلب حجز + إجراءات الطرفين (P10).
///
/// **من يفعل ماذا؟** (A-75)
/// - المدرس: قبول/رفض الطلب المعلّق، اقتراح وقت بديل، إعلان التنفيذ، الإلغاء.
/// - الطالب: إلغاء طلبه، اقتراح وقت بديل، قبول اقتراح المدرس أو رفضه.
///
/// كل زر يُعرض فقط عندما يكون مسموحًا في الحالة الحالية، ويُفسَّر المنع بنص
/// عربي بدل زر معطّل بلا سبب.
class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  int _revision = 0;
  bool _busy = false;

  void _reload() => setState(() => _revision++);

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

  /// المُعرّف الفعلي للمستخدم الحالي — يختلف عن `CurrentTeacher.idOf` في وضع
  /// الزائر (A-56)، ولذلك نقرأ `session.user` مباشرة عند الحاجة للتحقق.
  String _viewerId(SessionController session, BookingRequest booking) {
    if (session.role == UserRole.teacher) {
      return CurrentTeacher.idOf(session);
    }
    return booking.studentId ?? '';
  }

  /// ينفّذ إجراءً واحدًا بنفس معالجة الأخطاء في كل الأزرار.
  Future<void> _run(
    Future<BookingRequest> Function(BookingRepository repo) action, {
    required String success,
  }) async {
    final BookingRepository repo = AppServicesScope.of(context).bookings;
    setState(() => _busy = true);
    try {
      await action(repo);
      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, success, type: AppMessageType.success);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        error.overrideMessage ?? error.message,
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) {
        _busy = false;
        _reload();
      }
    }
  }

  Future<void> _cancel(BookingRequest booking, bool byTeacher) async {
    final bool late = BookingRules.isLateCancellation(
      booking: booking,
      now: DateTime.now(),
    );
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('إلغاء الموعد'),
        content: Text(
          late
              ? 'الموعد خلال أقل من ${BookingRules.freeCancelWindow.inHours} '
                    'ساعة؛ سيُسجَّل الإلغاء «متأخرًا». هل تريد المتابعة؟'
              : 'سيُلغى الموعد ويُبلَّغ الطرف الآخر. هل تريد المتابعة؟',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('إلغاء الموعد'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _run(
      (BookingRepository repo) => repo.cancelRequest(
        request: booking,
        actorId: _viewerId(SessionScope.read(context), booking),
        byTeacher: byTeacher,
      ),
      success: late ? 'أُلغي الموعد (متأخرًا).' : 'أُلغي الموعد.',
    );
  }

  Future<void> _propose(BookingRequest booking, bool byTeacher) async {
    final DateTime? slot = await showSlotPickerSheet(
      context,
      durationMinutes: booking.durationMinutes ?? 60,
      initial: booking.startsAt,
    );
    if (slot == null || !mounted) {
      return;
    }
    await _run(
      (BookingRepository repo) => repo.proposeReschedule(
        request: booking,
        actorId: _viewerId(SessionScope.read(context), booking),
        byTeacher: byTeacher,
        startsAt: slot,
      ),
      success: 'أُرسل الوقت البديل للطرف الآخر.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SessionController session = SessionScope.of(context);
    final bool isTeacherView = session.role == UserRole.teacher;
    final BookingViewer viewer = isTeacherView
        ? BookingViewer.teacher
        : BookingViewer.student;

    return Scaffold(
      // شفاف لعرض تدرّج الخلفية العالمي (نسخة 3).
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('تفاصيل الطلب')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: AsyncView<BookingRequest?>(
                key: ValueKey<int>(_revision),
                load: () =>
                    AppServicesScope.of(context).bookings.findById(
                      widget.bookingId,
                    ),
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
                                // `Flexible` يمنع فيضًا بكسر من البكسل على
                                // الشاشات الضيقة عندما يطول اسم الحالة.
                                Flexible(
                                  child: StatusChip(
                                    label: booking.status.label,
                                    color: _statusColor(booking.status),
                                  ),
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
                              icon: Icons.event_outlined,
                              label: 'موعد الحصة',
                              value: BookingRules.slotLabel(booking),
                            ),
                            if (booking.status.isReschedule)
                              DetailRow(
                                icon: Icons.swap_horiz,
                                label: 'الوقت البديل',
                                value:
                                    '${BookingRules.proposalLabel(booking)} '
                                    '(اقتراح ${booking.proposedBy?.label ?? ''})',
                              ),
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
                      SectionHeader(
                        title: 'الإجراءات',
                        subtitle: isTeacherView
                            ? 'القرار لك: قبول، رفض، أو وقت بديل'
                            : 'يمكنك الإلغاء أو اقتراح وقت بديل',
                      ),
                      _actions(booking, viewer, isTeacherView),
                      const SizedBox(height: AppSpacing.xs),
                      // المحادثة المباشرة (P11): أصلها هذا الحجز نفسه، فتُفتح
                      // بلا شرط خصوصية إضافي — العلاقة قائمة بالفعل.
                      ChatActionButton(
                        label: 'محادثة بخصوص الطلب',
                        icon: Icons.forum_outlined,
                        onPressed: (BuildContext context) =>
                            openChatForBooking(context, booking),
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
                            'لا يصبح الحجز مؤكدًا إلا بموافقة المدرس، ولا يقبل '
                            'موعدًا متقاطعًا مع حصة مؤكدة. الإلغاء داخل 12 ساعة '
                            'قبل الموعد يُسجّل «متأخرًا».',
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

  Widget _actions(
    BookingRequest booking,
    BookingViewer viewer,
    bool isTeacherView,
  ) {
    final DateTime now = DateTime.now();
    final List<Widget> buttons = <Widget>[];

    String? blocked(BookingAction action) => BookingRules.actionBlockReason(
      booking: booking,
      viewer: viewer,
      action: action,
      now: now,
    );

    final bool canComplete = blocked(BookingAction.complete) == null;
    final bool canCancel = blocked(BookingAction.cancel) == null;
    final bool canPropose =
        blocked(BookingAction.proposeReschedule) == null && !booking.status.isReschedule;
    final bool canAcceptProposal =
        blocked(BookingAction.acceptProposal) == null;
    final bool canDecide =
        isTeacherView &&
        (booking.status.isPending ||
            (booking.status.isReschedule &&
                booking.proposedBy == BookingActor.student));

    if (canDecide) {
      buttons.add(
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(
                  (BookingRepository repo) => repo.decideRequest(
                    request: booking,
                    teacherId: _viewerId(SessionScope.read(context), booking),
                    approve: true,
                  ),
                  success: 'قُبل الطلب وأُضيف إلى جدولك.',
                ),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('قبول الطلب'),
        ),
      );
      buttons.add(
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _run(
                  (BookingRepository repo) => repo.decideRequest(
                    request: booking,
                    teacherId: _viewerId(SessionScope.read(context), booking),
                    approve: false,
                  ),
                  success: 'رُفض الطلب.',
                ),
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: const Text('رفض'),
        ),
      );
    }

    if (canAcceptProposal) {
      buttons.add(
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(
                  (BookingRepository repo) => repo.respondToProposal(
                    request: booking,
                    actorId: _viewerId(SessionScope.read(context), booking),
                    byTeacher: isTeacherView,
                    accept: true,
                  ),
                  success: 'قُبل الوقت البديل وأصبح الموعد مؤكدًا.',
                ),
          icon: const Icon(Icons.event_available_outlined, size: 18),
          label: const Text('قبول الوقت البديل'),
        ),
      );
      buttons.add(
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _run(
                  (BookingRepository repo) => repo.respondToProposal(
                    request: booking,
                    actorId: _viewerId(SessionScope.read(context), booking),
                    byTeacher: isTeacherView,
                    accept: false,
                  ),
                  success: 'رُفض الوقت البديل وأُغلق الطلب.',
                ),
          icon: const Icon(Icons.block_outlined, size: 18),
          label: const Text('رفض الوقت البديل'),
        ),
      );
    }

    if (canPropose) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _propose(booking, isTeacherView),
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: const Text('اقتراح وقت بديل'),
        ),
      );
    }

    if (canComplete) {
      buttons.add(
        FilledButton.tonalIcon(
          onPressed: _busy
              ? null
              : () => _run(
                  (BookingRepository repo) => repo.completeRequest(
                    request: booking,
                    teacherId: _viewerId(SessionScope.read(context), booking),
                  ),
                  success: 'أُعلن تنفيذ الحصة.',
                ),
          icon: const Icon(Icons.task_alt_outlined, size: 18),
          label: const Text('إعلان التنفيذ'),
        ),
      );
    }

    if (canCancel) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _cancel(booking, isTeacherView),
          icon: const Icon(Icons.event_busy_outlined, size: 18),
          label: const Text('إلغاء الموعد'),
        ),
      );
    }

    if (buttons.isEmpty) {
      return const InfoNote(
        text: 'لا إجراء متاح لهذا الطلب الآن؛ حالته نهائية أو ينتظر الطرف الآخر.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final Widget button in buttons)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
            child: SizedBox(width: double.infinity, child: button),
          ),
      ],
    );
  }
}
