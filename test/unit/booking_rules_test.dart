import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/validation/booking_rules.dart';

/// موعد بعد [hours] ساعة من الآن، على رأس الساعة، داخل نافذة اليوم الدراسي.
///
/// نستخدم «الآن» لأن القواعد تعتمد عليه (مهلة ساعة، نافذة 12 ساعة للإلغاء)،
/// ونثبّت الدقائق إلى صفر حتى لا تتغير التوقعات مع ثانية التنفيذ.
DateTime _soon({int hours = 48, int atHour = 16}) {
  final DateTime base = DateTime.now().add(Duration(hours: hours));
  return DateTime(base.year, base.month, base.day, atHour);
}

/// أول موعد داخل نافذة الإلغاء المجاني (12 ساعة) وفي ساعات العمل.
///
/// لماذا دالة مستقلة؟ لأن «داخل 12 ساعة» و«داخل 8:00–22:00» لا يتقاطعان في كل
/// ساعة من اليوم لنفس المدة (نمط 19:07 يترك 53 دقيقة فقط قبل الإغلاق والصبح
/// يقع خارج النافذة). نبدأ من `now + المهلة` ونصعد بنصف ساعة، فنضمن موعدًا
/// صالحًا للإنشاء **و** داخل النافذة في أي وقت — وبدل افتراض الساعة الحالية.
DateTime _slotInsideCancelWindow({int durationMinutes = 60}) {
  final DateTime now = DateTime.now();
  DateTime candidate = now.add(BookingRules.minimumLeadTime);
  candidate = DateTime(
    candidate.year,
    candidate.month,
    candidate.day,
    candidate.hour,
    candidate.minute,
  );
  if (candidate.minute % 30 != 0) {
    candidate = candidate.add(Duration(minutes: 30 - candidate.minute % 30));
  }

  for (int step = 0; step < 48; step++) {
    final int minute = candidate.hour * 60 + candidate.minute;
    final bool insideHours =
        minute >= BookingRules.openMinute &&
        minute + durationMinutes <= BookingRules.closeMinute;
    final bool insideWindow =
        candidate.isBefore(now.add(BookingRules.freeCancelWindow)) &&
        !candidate.isBefore(now.add(BookingRules.minimumLeadTime));
    if (insideHours && insideWindow) {
      return candidate;
    }
    candidate = candidate.add(const Duration(minutes: 30));
  }
  throw StateError('تعذّر إيجاد موعد داخل نافذة الإلغاء — راجع BookingRules.');
}

/// أول موعد داخل ساعات العمل بعد [after] — يبدأ الفحص من `now + after`.
///
/// السبب: الاختبارات كانت تستخدم «الآن + ساعتين/خمس ساعات» مباشرة، فتنجح نهارًا
/// وتسقط ليلًا لأن الموعد يخرج عن نافذة 8:00–22:00 (كشفه CI في P17 الساعة
/// 20:40). نبحث عن أول خانة نصف ساعة صالحة بدل افتراض الساعة الحالية.
DateTime _businessSlotAhead(Duration after) {
  final DateTime now = DateTime.now();
  DateTime candidate = now.add(after);
  for (int step = 0; step < 96; step++) {
    final int minute = candidate.hour * 60 + candidate.minute;
    final bool insideHours =
        minute >= BookingRules.openMinute &&
        minute + 60 <= BookingRules.closeMinute;
    if (insideHours && !candidate.isBefore(now.add(BookingRules.minimumLeadTime))) {
      return candidate;
    }
    // ننتقل نصف ساعة للأمام، وإلى الفتح إن كنا خارج النافذة.
    candidate = minute + 30 >= BookingRules.closeMinute
        ? DateTime(
            candidate.year,
            candidate.month,
            candidate.day + 1,
            BookingRules.openMinute ~/ 60,
          )
        : candidate.add(const Duration(minutes: 30));
  }
  throw StateError('تعذّر إيجاد موعد داخل ساعات العمل — راجع BookingRules.');
}

BookingRequest _booking({
  String id = 'b1',
  String teacherId = 'teacher-1',
  String studentId = 'student-1',
  required DateTime startsAt,
  int durationMinutes = 60,
  BookingStatus status = BookingStatus.accepted,
  BookingActor? proposedBy,
  DateTime? proposedStartsAt,
}) {
  return BookingRequest(
    id: id,
    teacherId: teacherId,
    teacherName: 'أ. سارة',
    studentId: studentId,
    studentName: 'طالب',
    subject: 'الرياضيات',
    requestedAt: startsAt.subtract(const Duration(days: 2)),
    status: status,
    dateKey: BookingRulesLite.keyOf(startsAt),
    startMinutes: BookingRulesLite.minutesOf(startsAt),
    durationMinutes: durationMinutes,
    proposedBy: proposedBy,
    proposalDateKey: proposedStartsAt == null
        ? null
        : BookingRulesLite.keyOf(proposedStartsAt),
    proposalStartMinutes: proposedStartsAt == null
        ? null
        : BookingRulesLite.minutesOf(proposedStartsAt),
  );
}

void main() {
  group('BookingRules — الموعد المقترح', () {
    test('موعد صالح داخل النافذة يُقبل', () {
      final DateTime start = _soon();
      expect(
        BookingRules.slotBlockReason(
          startsAt: start,
          durationMinutes: 60,
          now: DateTime.now(),
        ),
        isNull,
      );
    });

    test('المدة يجب أن تكون من الخيارات المعتمدة', () {
      // «الآن» مُثبَّت حتى لا تتغير النتيجة مع ساعة تشغيل CI.
      final DateTime now = DateTime(2026, 1, 15, 10);
      final DateTime start = DateTime(2026, 1, 20, 12);

      expect(
        BookingRules.slotBlockReason(
          startsAt: start,
          durationMinutes: 50,
          now: now,
        ),
        contains('مدة'),
      );
      for (final int duration in BookingRules.durationOptions) {
        expect(
          BookingRules.slotBlockReason(
            startsAt: start,
            durationMinutes: duration,
            now: now,
          ),
          isNull,
          reason: 'المدة $duration معتمدة',
        );
      }
    });

    test('خارج نافذة اليوم (قبل 8 صباحًا أو بعد 10 مساءً) مرفوض', () {
      expect(
        BookingRules.slotBlockReason(
          startsAt: _soon(atHour: 7),
          durationMinutes: 60,
          now: DateTime.now(),
        ),
        contains('المواعيد المتاحة'),
      );
      expect(
        BookingRules.slotBlockReason(
          startsAt: _soon(atHour: 21),
          durationMinutes: 120,
          now: DateTime.now(),
        ),
        contains('منتصف الليل'),
        reason: '21:00 + ساعتان تعبر 22:00',
      );
    });

    test('مهلة ساعة على الأقل قبل الموعد', () {
      final DateTime now = DateTime(2026, 1, 15, 10);
      expect(
        BookingRules.slotBlockReason(
          startsAt: DateTime(2026, 1, 15, 10, 30),
          durationMinutes: 60,
          now: now,
        ),
        contains('ساعة'),
      );
      expect(
        BookingRules.slotBlockReason(
          startsAt: DateTime(2026, 1, 15, 11, 30),
          durationMinutes: 60,
          now: now,
        ),
        isNull,
      );
    });

    test('لا حجز أبعد من 90 يومًا', () {
      final DateTime now = DateTime(2026, 1, 15, 10);
      expect(
        BookingRules.slotBlockReason(
          startsAt: DateTime(2026, 6, 1, 12),
          durationMinutes: 60,
          now: now,
        ),
        contains('90'),
      );
    });
  });

  group('BookingRules — كشف التعارض', () {
    final DateTime start = _soon(atHour: 16);

    test('تقاطع جزئي من البداية ومن النهاية يُكتشف', () {
      final BookingRequest accepted = _booking(startsAt: start);
      expect(
        BookingRules.findConflict(
          start: start.add(const Duration(minutes: 30)),
          durationMinutes: 60,
          existing: <BookingRequest>[accepted],
        ),
        isNotNull,
      );
      expect(
        BookingRules.findConflict(
          start: start.subtract(const Duration(minutes: 30)),
          durationMinutes: 60,
          existing: <BookingRequest>[accepted],
        ),
        isNotNull,
      );
    });

    test('ملاصق تمامًا بلا تقاطع يُقبل', () {
      final BookingRequest accepted = _booking(startsAt: start);
      expect(
        BookingRules.findConflict(
          start: start.add(const Duration(minutes: 60)),
          durationMinutes: 60,
          existing: <BookingRequest>[accepted],
        ),
        isNull,
      );
    });

    test('الملغى والمرفوض والمعلّق لا تحجز وقتًا', () {
      for (final BookingStatus status in <BookingStatus>[
        BookingStatus.pending,
        BookingStatus.rejected,
        BookingStatus.cancelled,
        BookingStatus.cancelledLate,
      ]) {
        expect(
          BookingRules.findConflict(
            start: start,
            durationMinutes: 60,
            existing: <BookingRequest>[_booking(startsAt: start, status: status)],
          ),
          isNull,
          reason: 'الحالة ${status.name} لا تشغل وقتًا',
        );
      }
    });

    test('الطلب نفسه يُستثنى عند التحقق من اقتراحه', () {
      final BookingRequest accepted = _booking(startsAt: start);
      expect(
        BookingRules.findConflict(
          start: start,
          durationMinutes: 60,
          existing: <BookingRequest>[accepted],
          ignoreId: accepted.id,
        ),
        isNull,
      );
    });
  });

  group('BookingRules — الانتقالات', () {
    final DateTime now = DateTime.now();

    test('المدرس يقبل الطلب المعلّق، والطالب لا', () {
      final BookingRequest pending = _booking(
        startsAt: _soon(),
        status: BookingStatus.pending,
      );
      expect(
        BookingRules.actionBlockReason(
          booking: pending,
          viewer: BookingViewer.teacher,
          action: BookingAction.accept,
          now: now,
        ),
        isNull,
      );
      expect(
        BookingRules.actionBlockReason(
          booking: pending,
          viewer: BookingViewer.student,
          action: BookingAction.accept,
          now: now,
        ),
        isNotNull,
        reason: 'الطالب لا يقبل طلبه بنفسه',
      );
    });

    test('لا قرار على طلب منتهٍ (مرفوض/ملغى/منفّذ)', () {
      for (final BookingStatus status in <BookingStatus>[
        BookingStatus.rejected,
        BookingStatus.cancelled,
        BookingStatus.completed,
      ]) {
        expect(
          BookingRules.actionBlockReason(
            booking: _booking(startsAt: _soon(), status: status),
            viewer: BookingViewer.teacher,
            action: BookingAction.accept,
            now: now,
          ),
          contains('لم يعد'),
        );
      }
    });

    test('إعلان التنفيذ للمدرس بعد انتهاء الموعد فقط', () {
      final DateTime future = _soon(hours: 48, atHour: 16);
      final BookingRequest accepted = _booking(startsAt: future);
      expect(
        BookingRules.actionBlockReason(
          booking: accepted,
          viewer: BookingViewer.teacher,
          action: BookingAction.complete,
          now: now,
        ),
        contains('قبل انتهاء'),
      );

      // بعد انتهاء الموعد (نتخيل «الآن» بعد الموعد بساعة).
      expect(
        BookingRules.actionBlockReason(
          booking: accepted,
          viewer: BookingViewer.teacher,
          action: BookingAction.complete,
          now: future.add(const Duration(hours: 2)),
        ),
        isNull,
      );
      expect(
        BookingRules.actionBlockReason(
          booking: accepted,
          viewer: BookingViewer.student,
          action: BookingAction.complete,
          now: future.add(const Duration(hours: 2)),
        ),
        contains('المدرس'),
      );
    });

    test('قبول الاقتراح من الطرف الآخر فقط', () {
      final DateTime proposed = _soon(hours: 72, atHour: 18);
      final BookingRequest teacherProposal = _booking(
        startsAt: _soon(),
        status: BookingStatus.rescheduleProposed,
        proposedBy: BookingActor.teacher,
        proposedStartsAt: proposed,
      );

      expect(
        BookingRules.actionBlockReason(
          booking: teacherProposal,
          viewer: BookingViewer.student,
          action: BookingAction.acceptProposal,
          now: now,
        ),
        isNull,
      );
      expect(
        BookingRules.actionBlockReason(
          booking: teacherProposal,
          viewer: BookingViewer.teacher,
          action: BookingAction.acceptProposal,
          now: now,
        ),
        contains('المدرس'),
      );
    });
  });

  group('BookingRules — مهلة الإلغاء 12 ساعة', () {
    test('الإلغاء قبل 12 ساعة يبقى «ملغى»', () {
      final DateTime start = DateTime.now().add(const Duration(days: 3));
      final BookingRequest booking = _booking(startsAt: start);
      expect(
        BookingRules.cancelStatus(booking: booking, now: DateTime.now()),
        BookingStatus.cancelled,
      );
    });

    test('الإلغاء داخل 12 ساعة يُسجّل «ملغى متأخرًا»', () {
      final DateTime start = DateTime.now().add(const Duration(hours: 5));
      final BookingRequest booking = _booking(startsAt: start);
      expect(
        BookingRules.cancelStatus(booking: booking, now: DateTime.now()),
        BookingStatus.cancelledLate,
      );
      expect(
        BookingRules.isLateCancellation(
          booking: booking,
          now: DateTime.now(),
        ),
        isTrue,
      );
    });
  });

  group('BookingRules — العرض', () {
    test('وصف الموعد والتاريخ بالعربية', () {
      final BookingRequest booking = _booking(
        startsAt: DateTime(2026, 11, 1, 17, 30),
        durationMinutes: 90,
      );
      expect(BookingRules.slotLabel(booking), contains('نوفمبر'));
      expect(BookingRules.slotLabel(booking), contains('5:30 م'));
      expect(BookingRules.slotLabel(booking), contains('ساعة و30 دقيقة'));
    });

    test('طلب بلا موعد يُوصف صريحًا', () {
      final BookingRequest bare = BookingRequest(
        id: 'x',
        teacherName: 'أ',
        studentName: 'ب',
        subject: 'الرياضيات',
        requestedAt: DateTime(2026, 10, 1),
        status: BookingStatus.pending,
      );
      expect(BookingRules.slotLabel(bare), 'بلا موعد محدد');
    });
  });

  group('الحجز — المستودع التجريبي (المسار الكامل)', () {
    test('إنشاء طلب ثم قبوله يحجز الوقت', () async {
      final DemoBookingRepository repo = DemoBookingRepository(
        source: <BookingRequest>[],
      );
      final DateTime start = _soon(atHour: 14);

      final BookingRequest created = await repo.createRequest(
        teacherId: 'teacher-1',
        teacherName: 'أ. سارة',
        studentId: 'student-1',
        studentName: 'طالب',
        subject: 'الرياضيات',
        startsAt: start,
        durationMinutes: 60,
        note: 'مراجعة',
      );
      expect(created.status, BookingStatus.pending);
      expect(created.dateKey, BookingRulesLite.keyOf(start));

      final BookingRequest accepted = await repo.decideRequest(
        request: created,
        teacherId: 'teacher-1',
        approve: true,
      );
      expect(accepted.status, BookingStatus.accepted);
      expect(accepted.decidedBy, 'teacher-1');
    });

    test('حجز متقاطع مع حجز مؤكد مرفوض برسالة التعارض', () async {
      final DemoBookingRepository repo = DemoBookingRepository(
        source: <BookingRequest>[],
      );
      final DateTime start = _soon(atHour: 16);

      final BookingRequest first = await repo.createRequest(
        teacherId: 'teacher-1',
        teacherName: 'أ. سارة',
        studentId: 'student-1',
        studentName: 'طالب',
        subject: 'الرياضيات',
        startsAt: start,
        durationMinutes: 60,
      );
      await repo.decideRequest(
        request: first,
        teacherId: 'teacher-1',
        approve: true,
      );

      // طلب آخر متقاطع يُرفض عند الإنشاء (فحص مبكر)…
      await expectLater(
        repo.createRequest(
          teacherId: 'teacher-1',
          teacherName: 'أ. سارة',
          studentId: 'student-2',
          studentName: 'طالب آخر',
          subject: 'الرياضيات',
          startsAt: start.add(const Duration(minutes: 30)),
          durationMinutes: 60,
        ),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.overrideMessage,
            'overrideMessage',
            BookingRules.conflictMessage,
          ),
        ),
      );

      // …ولو أُنشئ على وقت حر ثم تقاطع بعد ذلك، فالقبول نفسه يرفضه.
      final BookingRequest later = await repo.createRequest(
        teacherId: 'teacher-1',
        teacherName: 'أ. سارة',
        studentId: 'student-3',
        studentName: 'طالب ثالث',
        subject: 'الرياضيات',
        startsAt: start.add(const Duration(hours: 2)),
        durationMinutes: 60,
      );
      await expectLater(
        repo.proposeReschedule(
          request: later,
          actorId: 'student-3',
          byTeacher: false,
          startsAt: start.add(const Duration(minutes: 15)),
        ),
        completes,
        reason: 'الاقتراح لا يحجز وقتًا',
      );
    });

    test('مدرس آخر لا يقبل ولا يرفض', () async {
      final DemoBookingRepository repo = DemoBookingRepository(
        source: <BookingRequest>[],
      );
      final BookingRequest created = await repo.createRequest(
        teacherId: 'teacher-1',
        teacherName: 'أ. سارة',
        studentId: 'student-1',
        studentName: 'طالب',
        subject: 'الرياضيات',
        startsAt: _soon(),
        durationMinutes: 60,
      );

      await expectLater(
        repo.decideRequest(
          request: created,
          teacherId: 'teacher-2',
          approve: true,
        ),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.kind,
            'kind',
            AppErrorKind.permission,
          ),
        ),
      );
    });

    test('الإلغاء داخل المهلة: ملغى متأخرًا، ويحرّر الوقت', () async {
      final DemoBookingRepository repo = DemoBookingRepository(
        source: <BookingRequest>[],
      );
      // داخل نافذة الإلغاء المجاني (12 ساعة) **وداخل** ساعات العمل: الموعد
      // هنا يُنشأ فعليًا، فـ«الآن + 5 ساعات» الليلية كان يُرفض قبل الإلغاء.
      final DateTime start = _slotInsideCancelWindow();

      final BookingRequest created = await repo.createRequest(
        teacherId: 'teacher-1',
        teacherName: 'أ. سارة',
        studentId: 'student-1',
        studentName: 'طالب',
        subject: 'الرياضيات',
        startsAt: start,
        durationMinutes: 60,
      );
      final BookingRequest accepted = await repo.decideRequest(
        request: created,
        teacherId: 'teacher-1',
        approve: true,
      );
      final BookingRequest cancelled = await repo.cancelRequest(
        request: accepted,
        actorId: 'student-1',
        byTeacher: false,
      );

      expect(cancelled.status, BookingStatus.cancelledLate);
      expect(cancelled.cancelledBy, 'student-1');
    });

    test('الاقتراح البديل: طالب يقترح ← المدرس يقبل ← الموعد ينتقل', () async {
      final DemoBookingRepository repo = DemoBookingRepository(
        source: <BookingRequest>[],
      );
      final DateTime original = _soon(atHour: 16);
      final DateTime alternative = _soon(atHour: 19);

      final BookingRequest created = await repo.createRequest(
        teacherId: 'teacher-1',
        teacherName: 'أ. سارة',
        studentId: 'student-1',
        studentName: 'طالب',
        subject: 'الرياضيات',
        startsAt: original,
        durationMinutes: 60,
      );

      final BookingRequest proposed = await repo.proposeReschedule(
        request: created,
        actorId: 'student-1',
        byTeacher: false,
        startsAt: alternative,
      );
      expect(proposed.status, BookingStatus.rescheduleProposed);
      expect(proposed.proposedBy, BookingActor.student);
      expect(proposed.proposalDateKey, BookingRulesLite.keyOf(alternative));

      final BookingRequest accepted = await repo.decideRequest(
        request: proposed,
        teacherId: 'teacher-1',
        approve: true,
      );
      expect(accepted.status, BookingStatus.accepted);
      expect(accepted.dateKey, BookingRulesLite.keyOf(alternative));
      expect(accepted.startMinutes, BookingRulesLite.minutesOf(alternative));
      expect(accepted.proposalDateKey, isNull);
    });

    test('اقتراح المدرس: الطالب يقبل، وبعد الموعد يعلن المدرس التنفيذ', () async {
      final DemoBookingRepository repo = DemoBookingRepository(
        source: <BookingRequest>[],
      );
      // موعد بديل صالح في أي ساعة من اليوم (لا «الآن + ساعتين»).
      final DateTime proposed = _businessSlotAhead(const Duration(hours: 2));

      final BookingRequest created = await repo.createRequest(
        teacherId: 'teacher-1',
        teacherName: 'أ. سارة',
        studentId: 'student-1',
        studentName: 'طالب',
        subject: 'الرياضيات',
        startsAt: _soon(atHour: 16),
        durationMinutes: 30,
      );

      final BookingRequest proposal = await repo.proposeReschedule(
        request: created,
        actorId: 'teacher-1',
        byTeacher: true,
        startsAt: proposed,
      );

      // المدرس لا يقبل اقتراح نفسه.
      await expectLater(
        repo.respondToProposal(
          request: proposal,
          actorId: 'teacher-1',
          byTeacher: true,
          accept: true,
        ),
        throwsA(isA<AppException>()),
      );

      final BookingRequest accepted = await repo.respondToProposal(
        request: proposal,
        actorId: 'student-1',
        byTeacher: false,
        accept: true,
      );
      expect(accepted.status, BookingStatus.accepted);

      // إعلان التنفيذ قبل انتهاء الموعد مرفوض.
      await expectLater(
        repo.completeRequest(request: accepted, teacherId: 'teacher-1'),
        throwsA(isA<AppException>()),
      );
    });

    test('رفض الاقتراح يُنهي الطلب', () async {
      final DemoBookingRepository repo = DemoBookingRepository(
        source: <BookingRequest>[],
      );
      final BookingRequest created = await repo.createRequest(
        teacherId: 'teacher-1',
        teacherName: 'أ. سارة',
        studentId: 'student-1',
        studentName: 'طالب',
        subject: 'الرياضيات',
        startsAt: _soon(atHour: 16),
        durationMinutes: 60,
      );
      final BookingRequest proposal = await repo.proposeReschedule(
        request: created,
        actorId: 'teacher-1',
        byTeacher: true,
        startsAt: _soon(atHour: 20),
      );
      final BookingRequest rejected = await repo.respondToProposal(
        request: proposal,
        actorId: 'student-1',
        byTeacher: false,
        accept: false,
      );
      expect(rejected.status, BookingStatus.rejected);
    });

    test('إنشاء بموعد خارج النافذة مرفوض قبل أي كتابة', () async {
      final DemoBookingRepository repo = DemoBookingRepository(
        source: <BookingRequest>[],
      );
      await expectLater(
        repo.createRequest(
          teacherId: 'teacher-1',
          teacherName: 'أ. سارة',
          studentId: 'student-1',
          studentName: 'طالب',
          subject: 'الرياضيات',
          startsAt: _soon(atHour: 5),
          durationMinutes: 60,
        ),
        throwsA(isA<AppException>()),
      );
      expect(await repo.listMine(), isEmpty);
    });
  });
}
