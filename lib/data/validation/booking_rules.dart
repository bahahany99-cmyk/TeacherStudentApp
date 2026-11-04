import 'package:teacher_student_app/data/models/booking_request.dart';

/// من يقوم بالإجراء — التمييز يحكم من يحقّ له الانتقال (A-75).
enum BookingViewer { teacher, student }

/// الأفعال المتاحة على طلب حجز.
enum BookingAction { accept, reject, cancel, complete, proposeReschedule, acceptProposal }

/// قواعد الحجز — دوال نقية بلا Flutter ولا شبكة (A-74/A-75).
///
/// كل نص هنا يُعرض للمستخدم **ويُطبَّق في القواعد** قدر ما تسمح به لغة القواعد؛
/// والتفصيل الدقيق (كشف التعارض) في الطبقة الوسطى داخل معاملة.
abstract final class BookingRules {
  // ── حدود الوقت (G6) ──────────────────────────────────────────────────────

  /// مدد مسموحة بالدقائق — نفس خيارات الجدول الأسبوعي، فيتعلمها المستخدم مرة.
  static const List<int> durationOptions = <int>[30, 45, 60, 90, 120];

  /// نافذة اليوم الدراسي: من 8 صباحًا إلى 10 مساءً (وقت محلي).
  static const int openMinute = 8 * 60;
  static const int closeMinute = 22 * 60;

  /// مهلة الإلغاء المجاني: 12 ساعة قبل الموعد.
  static const Duration freeCancelWindow = Duration(hours: 12);

  /// أقرب موعد مسموح: ساعة واحدة من الآن (يمنع طلب حصة بدأت أو ستبدأ فورًا).
  static const Duration minimumLeadTime = Duration(hours: 1);

  /// أقصى مدى مستقبلي: 90 يومًا (يمنع طلبات بعيدة بلا معنى).
  static const int maxDaysAhead = 90;

  static const int noteMax = 200;

  // ── رسائل مشتركة ─────────────────────────────────────────────────────────

  static const String conflictMessage =
      'يوجد موعد مؤكد للمدرس يتقاطع مع هذا الوقت. اختر وقتًا آخر.';

  /// أقرب وقت مسموح بصيغة عربية (يُستخدم في التلميحات).
  static String leadTimeLabel() => 'بعد ${minimumLeadTime.inHours} ساعة على الأقل';

  // ── التحقق من الموعد المقترح ─────────────────────────────────────────────

  /// سبب رفض موعد مقترح — أو `null` إن كان صالحًا.
  ///
  /// تُستخدم عند إنشاء الطلب وعند اقتراح وقت بديل، فيمرّ الاقتراح من نفس
  /// الفحص الذي يمرّ به الطلب الأول.
  static String? slotBlockReason({
    required DateTime? startsAt,
    required int durationMinutes,
    required DateTime now,
  }) {
    if (startsAt == null) {
      return 'اختر يوم الحصة ووقتها.';
    }
    if (!durationOptions.contains(durationMinutes)) {
      return 'مدة الحصة يجب أن تكون إحدى القيم: '
          '${durationOptions.join(' / ')} دقيقة.';
    }
    final int startMinutes =
        startsAt.hour * 60 + startsAt.minute;
    final int endMinutes = startMinutes + durationMinutes;
    if (startMinutes < openMinute || endMinutes > closeMinute) {
      return 'المواعيد المتاحة بين ${_time(openMinute)} و${_time(closeMinute)}، '
          'ولا تعبر الحصة منتصف الليل.';
    }
    if (startsAt.isBefore(now.add(minimumLeadTime))) {
      return 'لا يمكن طلب موعد يقل عن ${minimumLeadTime.inHours} ساعة من الآن.';
    }
    if (startsAt.isAfter(now.add(const Duration(days: maxDaysAhead)))) {
      return 'لا يمكن الحجز أبعد من $maxDaysAhead يومًا.';
    }
    return null;
  }

  // ── كشف التعارض ──────────────────────────────────────────────────────────

  /// أول حجز **مؤكد** يتقاطع مع الفترة المقترحة، أو `null`.
  ///
  /// [ignoreId] يتيح تجاهل الطلب نفسه عند التحقق من اقتراح بديل له.
  static BookingRequest? findConflict({
    required DateTime start,
    required int durationMinutes,
    required Iterable<BookingRequest> existing,
    String? ignoreId,
  }) {
    final DateTime end = start.add(Duration(minutes: durationMinutes));
    for (final BookingRequest booking in existing) {
      if (!booking.status.holdsSlot) {
        continue;
      }
      if (booking.id == ignoreId) {
        continue;
      }
      if (booking.overlapsWith(start, end)) {
        return booking;
      }
    }
    return null;
  }

  // ── انتقالات الحالة ──────────────────────────────────────────────────────

  /// هل يحقّ لهذا الطرف تنفيذ هذا الفعل الآن؟ يُرجع سبب المنع أو `null`.
  ///
  /// القرار يُقرأ من الحالة **و** من الأدوار: المدرس يقبل/يرفض/يعلن الإكمال،
  /// والطالب يقبل اقتراح إعادة الجدولة، والطرفان يلغيان.
  static String? actionBlockReason({
    required BookingRequest booking,
    required BookingViewer viewer,
    required BookingAction action,
    required DateTime now,
  }) {
    if (booking.status.isTerminal) {
      return 'هذا الطلب لم يعد قابلًا للتعديل.';
    }

    return switch (action) {
      BookingAction.accept => _teacherOnly(
        viewer,
        booking.status.isPending || _studentProposed(booking),
        'لا يمكن قبول هذا الطلب في حالته الحالية.',
      ),
      BookingAction.reject => _teacherOnly(
        viewer,
        booking.status.isPending || _studentProposed(booking),
        'لا يمكن رفض هذا الطلب في حالته الحالية.',
      ),
      BookingAction.cancel => booking.status.canCancel
          ? null
          : 'لا يمكن إلغاء هذا الطلب في حالته الحالية.',
      BookingAction.complete => _completeReason(booking, viewer, now),
      BookingAction.proposeReschedule =>
        booking.status.isPending || booking.status.isAccepted
            ? null
            : 'لا يمكن اقتراح وقت بديل في هذه الحالة.',
      BookingAction.acceptProposal =>
        _teacherProposed(booking)
            ? (viewer == BookingViewer.student
                  ? null
                  : 'الاقتراح من المدرس؛ يقبله الطالب.')
            : (viewer == BookingViewer.teacher
                  ? null
                  : 'لا يوجد اقتراح من المدرس لقبوله.'),
    };
  }

  static String? _teacherOnly(
    BookingViewer viewer,
    bool stateAllowed,
    String fallback,
  ) {
    if (viewer != BookingViewer.teacher) {
      return 'القرار للمدرس صاحب الطلب.';
    }
    return stateAllowed ? null : fallback;
  }

  static String? _completeReason(
    BookingRequest booking,
    BookingViewer viewer,
    DateTime now,
  ) {
    if (viewer != BookingViewer.teacher) {
      return 'إعلان تنفيذ الحصة من المدرس فقط.';
    }
    if (!booking.status.isAccepted) {
      return 'لا يمكن إعلان التنفيذ قبل قبول الطلب.';
    }
    final DateTime? end = booking.endsAt;
    if (end == null) {
      return 'الطلب بلا موعد محدد.';
    }
    if (now.isBefore(end)) {
      return 'لا يمكن إعلان التنفيذ قبل انتهاء موعد الحصة.';
    }
    return null;
  }

  static bool _teacherProposed(BookingRequest booking) =>
      booking.status.isReschedule && booking.proposedBy == BookingActor.teacher;

  static bool _studentProposed(BookingRequest booking) =>
      booking.status.isReschedule && booking.proposedBy == BookingActor.student;

  /// الحالة التي يُكتبها الإلغاء: مبكرًا أم داخل المهلة.
  ///
  /// القرار في الطبقة الوسطى، والقواعد تتحقق من **التصنيف نفسه** مقابل
  /// `request.time` و`startsAt`، فلا يستطيع عميل تصنيف إلغاء متأخر كمبكر.
  static BookingStatus cancelStatus({
    required BookingRequest booking,
    required DateTime now,
  }) {
    final DateTime? start = booking.startsAt;
    if (start == null) {
      return BookingStatus.cancelled;
    }
    return now.isAfter(start.subtract(freeCancelWindow))
        ? BookingStatus.cancelledLate
        : BookingStatus.cancelled;
  }

  /// هل الإلغاء داخل المهلة (أي يُسجّل «ملغى متأخرًا»)؟
  static bool isLateCancellation({
    required BookingRequest booking,
    required DateTime now,
  }) => cancelStatus(booking: booking, now: now) == BookingStatus.cancelledLate;

  // ── العرض ────────────────────────────────────────────────────────────────

  /// «السبت 1 نوفمبر — 5:00 م · 60 دقيقة» أو نص بديل واضح.
  static String slotLabel(BookingRequest booking) {
    final DateTime? start = booking.startsAt;
    if (start == null) {
      return 'بلا موعد محدد';
    }
    final int duration = booking.durationMinutes ?? 60;
    return '${dateLabel(start)} — ${timeLabel(start)} · '
        '${durationLabel(duration)}';
  }

  /// وصف الوقت البديل المقترح.
  static String proposalLabel(BookingRequest booking) {
    final DateTime? start = booking.proposedStartsAt;
    if (start == null) {
      return 'بلا موعد بديل';
    }
    return '${dateLabel(start)} — ${timeLabel(start)}';
  }

  static const List<String> _weekdays = <String>[
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  static const List<String> _months = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static String dateLabel(DateTime value) =>
      '${_weekdays[value.weekday - 1]} ${value.day} ${_months[value.month - 1]}';

  static String timeLabel(DateTime value) {
    final int hour24 = value.hour;
    final int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour12:$minute ${hour24 >= 12 ? 'م' : 'ص'}';
  }

  static String durationLabel(int minutes) {
    if (minutes >= 60 && minutes % 60 == 0) {
      return minutes == 60 ? 'ساعة' : '${minutes ~/ 60} ساعات';
    }
    if (minutes > 60) {
      final int hours = minutes ~/ 60;
      final int rest = minutes % 60;
      return '$hours ساعة و$rest دقيقة';
    }
    return '$minutes دقيقة';
  }

  static String _time(int minutes) {
    final int hour = minutes ~/ 60;
    final int minute = minutes % 60;
    return '$hour:${minute.toString().padLeft(2, '0')}';
  }
}
