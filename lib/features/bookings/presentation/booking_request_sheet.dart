import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/booking_rules.dart';
import 'package:teacher_student_app/features/chat/presentation/chat_launcher.dart';
import 'package:teacher_student_app/features/bookings/widgets/slot_picker_sheet.dart';

/// ورقة «طلب حجز» للطالب (P10).
///
/// تُعيد `true` إذا أُنشئ الطلب فعلًا، حتى يُحدّث المستدعي ما يعرضه.
/// (P24) تُعيد طلب الحجز المُنشأ (لا `bool`) حتى يفتح المستدعي محادثة الحجز
/// مباشرة، فلا يبقى الطالب في شاشة المدرس بعد إرسال الطلب بلا خيط تواصل.
Future<BookingRequest?> showBookingRequestSheet(
  BuildContext context, {
  required TeacherProfile teacher,
}) {
  return showModalBottomSheet<BookingRequest>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) => _BookingRequestSheet(teacher: teacher),
  );
}

class _BookingRequestSheet extends StatefulWidget {
  const _BookingRequestSheet({required this.teacher});

  final TeacherProfile teacher;

  @override
  State<_BookingRequestSheet> createState() => _BookingRequestSheetState();
}

class _BookingRequestSheetState extends State<_BookingRequestSheet> {
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _note = TextEditingController();

  int _duration = 60;
  DateTime? _slot;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _subject.text = '${widget.teacher.subject} — ${widget.teacher.stage}';
  }

  @override
  void dispose() {
    _subject.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickSlot() async {
    final DateTime? picked = await showSlotPickerSheet(
      context,
      durationMinutes: _duration,
      initial: _slot,
    );
    if (picked != null && mounted) {
      setState(() => _slot = picked);
    }
  }

  Future<void> _submit() async {
    final DateTime? slot = _slot;
    if (slot == null) {
      AppSnackBar.show(
        context,
        'اختر موعد الحصة أولًا.',
        type: AppMessageType.warning,
      );
      return;
    }

    // (P26) تحقّق محلي قبل النداء: خطأ حقل فارغ يظهر فورًا بدل رحلة إلى
    // الخادم ثم رسالة خطأ عامة. الرسالة عبر SnackBar لا حوارًا يحجب الشاشة.
    if (_subject.text.trim().isEmpty) {
      AppSnackBar.show(
        context,
        'اكتب مادة الحصة أولًا.',
        type: AppMessageType.warning,
      );
      return;
    }

    final SessionController session = SessionScope.read(context);
    final String? blockReason = BookingRules.slotBlockReason(
      startsAt: slot,
      durationMinutes: _duration,
      now: DateTime.now(),
    );
    if (blockReason != null) {
      AppSnackBar.show(context, blockReason, type: AppMessageType.error);
      return;
    }

    setState(() => _busy = true);
    try {
      final BookingRequest created = await AppServicesScope.of(
        context,
      ).bookings.createRequest(
        teacherId: widget.teacher.id,
        teacherName: widget.teacher.displayName,
        studentId: CurrentStudent.idOf(session),
        studentName: CurrentStudent.nameOf(session),
        subject: _subject.text.trim(),
        startsAt: slot,
        durationMinutes: _duration,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) {
        return;
      }
      // (P28) خيط المحادثة يُنشأ الآن لا عند أول ضغطة «مراسلة»: فيراه المدرس
      // في قائمته لحظة وصول الطلب.
      await ensureThreadForBooking(
        services: AppServicesScope.of(context),
        booking: created,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(created);
      AppSnackBar.show(
        context,
        'أُرسل طلبك لموعد ${BookingRules.slotLabel(created)}. '
        'سيصلك قرار المدرس.',
        type: AppMessageType.success,
      );
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
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.pageGutter,
        AppSpacing.md,
        AppSpacing.pageGutter,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('طلب حجز مع ${widget.teacher.displayName}',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(
                labelText: 'مادة الحصة',
                isDense: true,
              ),
              maxLength: 80,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text('مدة الحصة', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xxs),
            PillRow(
              children: <Widget>[
                for (final int duration in BookingRules.durationOptions)
                  PillChip(
                    label: BookingRules.durationLabel(duration),
                    selected: duration == _duration,
                    onTap: () => setState(() {
                      _duration = duration;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _pickSlot,
              icon: const Icon(Icons.event_available_outlined, size: 18),
              label: Text(
                _slot == null
                    ? 'اختر اليوم والساعة'
                    : '${BookingRules.dateLabel(_slot!)} — '
                          '${BookingRules.timeLabel(_slot!)}',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'ملاحظة للمدرس (اختياري)',
                isDense: true,
              ),
              maxLength: BookingRules.noteMax,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('إرسال الطلب'),
            ),
            const SizedBox(height: AppSpacing.xs),
            const InfoNote(
              text:
                  'الطلب لا يصبح مؤكدًا إلا بموافقة المدرس، ولا يمكن أن يوافق '
                  'على موعد متقاطع مع حصة مؤكدة عنده. الإلغاء مجاني حتى 12 ساعة '
                  'قبل الموعد.',
            ),
          ],
        ),
      ),
    );
  }
}
