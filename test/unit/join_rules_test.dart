import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/validation/join_rules.dart';

StudyGroup _group({
  String id = 'g1',
  String teacherId = 'teacher-1',
  int seatsTotal = 12,
  int seatsTaken = 0,
  bool isActive = true,
}) {
  return StudyGroup(
    id: id,
    teacherId: teacherId,
    teacherName: 'أ. سارة',
    title: 'التفاضل',
    subject: 'الرياضيات',
    stage: 'الثانوية العامة',
    seatsTotal: seatsTotal,
    seatsTaken: seatsTaken,
    meetingMode: GroupMeetingMode.center,
    scheduleNote: 'السبت 5 م',
    isActive: isActive,
  );
}

GroupJoinRequest _request({
  String groupId = 'g1',
  String studentId = 'student-1',
  JoinRequestStatus status = JoinRequestStatus.pending,
}) {
  return GroupJoinRequest(
    id: GroupJoinRequest.idFor(groupId: groupId, studentId: studentId),
    groupId: groupId,
    groupTitle: 'التفاضل',
    teacherId: 'teacher-1',
    studentId: studentId,
    studentName: 'طالب',
    status: status,
    requestedAt: DateTime(2026, 10, 27),
  );
}

void main() {
  group('JoinRules — من يستطيع إرسال طلب', () {
    test('الطالب يستطيع الطلب في مجموعة منشورة بها مقعد', () {
      final StudyGroup group = _group(seatsTaken: 3);

      expect(JoinRules.requestBlockReason(group: group, viewerId: 'student-1'), isNull);
      expect(
        JoinRules.canRequestJoin(group: group, viewerId: 'student-1'),
        isTrue,
      );
    });

    test('المجموعة الموقوفة أو المكتملة تمنع الطلب برسالة عربية', () {
      final String? stopped = JoinRules.requestBlockReason(
        group: _group(isActive: false),
        viewerId: 'student-1',
      );
      final String? full = JoinRules.requestBlockReason(
        group: _group(seatsTaken: 12),
        viewerId: 'student-1',
      );

      expect(stopped, contains('موقوفة'));
      expect(full, contains('مكتملة'));
    });

    test('لا طلب ثانٍ لصاحب المجموعة ولا لطلب معلّق أو مقبول', () {
      expect(
        JoinRules.requestBlockReason(
          group: _group(),
          viewerId: 'teacher-1',
        ),
        contains('صاحب المجموعة'),
      );
      expect(
        JoinRules.requestBlockReason(
          group: _group(),
          viewerId: 'student-1',
          existingStatus: JoinRequestStatus.pending,
        ),
        contains('قيد المراجعة'),
      );
      expect(
        JoinRules.requestBlockReason(
          group: _group(),
          viewerId: 'student-1',
          existingStatus: JoinRequestStatus.accepted,
        ),
        contains('عضو'),
      );
    });

    test('بعد الرفض أو الإلغاء يمكن إعادة المحاولة', () {
      for (final JoinRequestStatus status in <JoinRequestStatus>[
        JoinRequestStatus.rejected,
        JoinRequestStatus.cancelled,
      ]) {
        expect(status.allowsRetry, isTrue);
        expect(
          JoinRules.requestBlockReason(
            group: _group(seatsTaken: 2),
            viewerId: 'student-1',
            existingStatus: status,
          ),
          isNull,
        );
      }
    });
  });

  group('JoinRules — القبول والسعة', () {
    test('القبول ممكن لطلب معلّق في مجموعة بها مقعد', () {
      expect(
        JoinRules.canAccept(group: _group(seatsTaken: 11), request: _request()),
        isTrue,
      );
    });

    test('امتلاء المجموعة يمنع القبول حتى لو كان الطلب معلّقًا', () {
      final String? reason = JoinRules.acceptBlockReason(
        group: _group(seatsTaken: 12),
        request: _request(),
      );

      expect(reason, contains('امتلأت'));
      expect(
        JoinRules.canAccept(
          group: _group(seatsTaken: 12),
          request: _request(),
        ),
        isFalse,
      );
    });

    test('طلب مقبول أو مرفوض لا يُقبل مرة أخرى', () {
      expect(
        JoinRules.acceptBlockReason(
          group: _group(seatsTaken: 0),
          request: _request(status: JoinRequestStatus.accepted),
        ),
        contains('لم يعد'),
      );
    });

    test('المجموعة الموقوفة لا تُقبل طلباتها', () {
      expect(
        JoinRules.acceptBlockReason(
          group: _group(isActive: false, seatsTaken: 1),
          request: _request(),
        ),
        contains('موقوفة'),
      );
    });

    test('الزيادة مقعد واحد بالضبط', () {
      expect(JoinRules.seatsAfterAccept(0), 1);
      expect(JoinRules.seatsAfterAccept(11), 12);
    });
  });

  group('JoinRules — المعرّف والتحقق', () {
    test('معرّف الطلب حتمي: مجموعة + طالب', () {
      expect(
        GroupJoinRequest.idFor(groupId: 'g1', studentId: 's1'),
        'g1_s1',
      );
      // طالبان مختلفان أو مجموعتان مختلفتان ⇒ مستندان مختلفان دائمًا.
      expect(
        GroupJoinRequest.idFor(groupId: 'g1', studentId: 's1'),
        isNot(GroupJoinRequest.idFor(groupId: 'g1', studentId: 's2')),
      );
      expect(
        GroupJoinRequest.idFor(groupId: 'g1', studentId: 's1'),
        isNot(GroupJoinRequest.idFor(groupId: 'g2', studentId: 's1')),
      );
    });

    test('خريطة الإنشاء لا تحمل قرارًا مسبقًا', () {
      final Map<String, Object?> map = _request().toCreateMap();

      expect(map['status'], 'pending');
      expect(map['teacherId'], 'teacher-1');
      expect(map.containsKey('decidedAt'), isFalse);
      expect(map.containsKey('decidedBy'), isFalse);
    });

    test('التحقق يرفض عنوانًا قصيرًا واسمًا فارغًا', () {
      expect(
        JoinRules.validateRequest(
          groupTitle: 'أب',
          studentName: 'طالب',
          studentId: 's1',
          groupId: 'g1',
        ).isValid,
        isFalse,
      );
      expect(
        JoinRules.validateRequest(
          groupTitle: 'التفاضل',
          studentName: '   ',
          studentId: 's1',
          groupId: 'g1',
        ).isValid,
        isFalse,
      );
      expect(
        JoinRules.validateRequest(
          groupTitle: 'التفاضل',
          studentName: 'طالب',
          studentId: 's1',
          groupId: 'g1',
        ).isValid,
        isTrue,
      );
    });
  });

  // (P24) البند 2: تهدئة الإلغاء — إغلاق حلقة «أرسل ⇒ ألغِ ⇒ أرسل».
  group('JoinRules — تهدئة الإلغاء', () {
    final DateTime now = DateTime(2026, 10, 30, 12);

    test('الثوابت: 5 دقائق تهدئة، وسقف 30 دقيقة، وأرضية 4 للخادم', () {
      expect(JoinRules.cancelCooldown, const Duration(minutes: 5));
      expect(JoinRules.maxCooldown, const Duration(minutes: 30));
      expect(JoinRules.cooldownFloor, const Duration(minutes: 4));
      expect(
        JoinRules.cooldownFloor,
        lessThan(JoinRules.cancelCooldown),
        reason: 'الأرضية أقل من المدة لتمتص فرق ساعة الجهاز',
      );
    });

    test('بلا موعد تهدئة لا يوجد منع', () {
      expect(JoinRules.cooldownRemaining(), isNull);
      expect(JoinRules.cooldownBlockReason(now: now), isNull);
    });

    test('التهديد السارية تمنع الطلب برسالة تذكر المدة', () {
      final DateTime until = now.add(const Duration(minutes: 3));
      final String? reason = JoinRules.requestBlockReason(
        group: _group(),
        viewerId: 'student-1',
        existingStatus: JoinRequestStatus.cancelled,
        cooldownUntil: until,
        now: now,
      );

      expect(reason, isNotNull);
      expect(reason, contains('ألغيت طلبك'));
      expect(
        JoinRules.canRequestJoin(
          group: _group(),
          viewerId: 'student-1',
          cooldownUntil: until,
          now: now,
        ),
        isFalse,
      );
    });

    test('بعد انقضاء التهدئة يعود الطلب متاحًا', () {
      final DateTime until = now.add(const Duration(minutes: 5));
      final DateTime later = until.add(const Duration(seconds: 1));

      expect(
        JoinRules.requestBlockReason(
          group: _group(),
          viewerId: 'student-1',
          existingStatus: JoinRequestStatus.cancelled,
          cooldownUntil: until,
          now: later,
        ),
        isNull,
      );
      expect(JoinRules.cooldownRemaining(cooldownUntil: until, now: later), isNull);
    });

    test('التهديد لا تتجاوز الحالات الأخرى أولوية: الإيقاف والاكتمال أولًا', () {
      final DateTime until = now.add(const Duration(minutes: 3));

      expect(
        JoinRules.requestBlockReason(
          group: _group(isActive: false),
          viewerId: 'student-1',
          cooldownUntil: until,
          now: now,
        ),
        contains('موقوفة'),
      );
      expect(
        JoinRules.requestBlockReason(
          group: _group(seatsTaken: 12),
          viewerId: 'student-1',
          cooldownUntil: until,
          now: now,
        ),
        contains('مكتملة'),
      );
      expect(
        JoinRules.requestBlockReason(
          group: _group(),
          viewerId: 'student-1',
          existingStatus: JoinRequestStatus.pending,
          cooldownUntil: until,
          now: now,
        ),
        contains('قيد المراجعة'),
      );
    });

    test('نص المدة عربي سليم', () {
      expect(JoinRules.describeCooldown(const Duration(seconds: 40)), '40 ثانية');
      expect(JoinRules.describeCooldown(const Duration(minutes: 1)), 'دقيقة واحدة');
      expect(JoinRules.describeCooldown(const Duration(minutes: 2)), 'دقيقتين');
      expect(JoinRules.describeCooldown(const Duration(minutes: 5)), '5 دقائق');
      expect(JoinRules.describeCooldown(const Duration(minutes: 20)), '20 دقيقة');
    });

    test('الطلب الملغى يحمل موعد تهدئة عند الإلغاء ويُقرأ منه', () {
      final GroupJoinRequest cancelled = _request(
        status: JoinRequestStatus.cancelled,
      ).copyWith(cooldownUntil: now.add(JoinRules.cancelCooldown));

      expect(cancelled.cooldownUntil, isNotNull);
      // الإلغاء يكتب الوضع والموعد فقط — لا تُمسّ حقول أخرى.
      final Map<String, Object?> map = cancelled.cancelMap(
        cooldownUntil: now.add(JoinRules.cancelCooldown),
      );
      expect(map['status'], 'cancelled');
      expect(map['cooldownUntil'], now.add(JoinRules.cancelCooldown));
      expect(map.keys.toSet(), <String>{'status', 'cooldownUntil'});
    });
  });
}
