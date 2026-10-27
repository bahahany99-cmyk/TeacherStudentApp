import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/models/group_waitlist_entry.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/validation/waitlist_rules.dart';

StudyGroup _group({
  int seatsTotal = 10,
  int seatsTaken = 10,
  bool isActive = true,
  String teacherId = 'teacher-1',
}) {
  return StudyGroup(
    id: 'g1',
    teacherId: teacherId,
    teacherName: 'أ. سارة',
    title: 'التفاضل',
    subject: 'الرياضيات',
    stage: 'الثانوية العامة',
    seatsTotal: seatsTotal,
    seatsTaken: seatsTaken,
    meetingMode: GroupMeetingMode.center,
    isActive: isActive,
  );
}

GroupWaitlistEntry _entry({
  String studentId = 'student-1',
  String studentName = 'طالب',
  WaitlistStatus status = WaitlistStatus.waiting,
  DateTime? addedAt,
  DateTime? decidedAt,
}) {
  return GroupWaitlistEntry(
    id: GroupWaitlistEntry.idFor(groupId: 'g1', studentId: studentId),
    groupId: 'g1',
    groupTitle: 'التفاضل',
    teacherId: 'teacher-1',
    studentId: studentId,
    studentName: studentName,
    status: status,
    addedAt: addedAt ?? DateTime(2026, 10, 1),
    decidedAt: decidedAt,
  );
}

void main() {
  group('WaitlistRules — من يدخل القائمة', () {
    test('المجموعة المكتملة تقبل الانتظار', () {
      expect(
        WaitlistRules.canJoin(group: _group(), viewerId: 'student-1'),
        isTrue,
      );
    });

    test('المجموعة التي بها مقعد لا تحتاج طابورًا', () {
      final String? reason = WaitlistRules.joinBlockReason(
        group: _group(seatsTaken: 7),
        viewerId: 'student-1',
      );

      expect(reason, contains('مقعد متاح'));
    });

    test('الموقوفة والمدرس ومن هو في القائمة مرفوضون', () {
      expect(
        WaitlistRules.joinBlockReason(
          group: _group(isActive: false),
          viewerId: 'student-1',
        ),
        contains('موقوفة'),
      );
      expect(
        WaitlistRules.joinBlockReason(
          group: _group(),
          viewerId: 'teacher-1',
        ),
        contains('صاحب المجموعة'),
      );
      expect(
        WaitlistRules.joinBlockReason(
          group: _group(),
          viewerId: 'student-1',
          existingStatus: WaitlistStatus.waiting,
        ),
        contains('بالفعل'),
      );
    });

    test('من قُبل سابقًا لا يعود للطابور، ومن غادر يستطيع العودة', () {
      expect(
        WaitlistRules.joinBlockReason(
          group: _group(),
          viewerId: 'student-1',
          existingStatus: WaitlistStatus.promoted,
        ),
        contains('تم قبولك'),
      );
      expect(
        WaitlistRules.joinBlockReason(
          group: _group(),
          viewerId: 'student-1',
          existingStatus: WaitlistStatus.left,
        ),
        isNull,
      );
    });
  });

  group('WaitlistRules — القبول', () {
    test('مقعد متاح + صف منتظر = قبول ممكن', () {
      expect(
        WaitlistRules.canPromote(
          group: _group(seatsTaken: 9),
          entry: _entry(),
        ),
        isTrue,
      );
    });

    test('لا قبول بلا مقعد، ولا لمجموعة موقوفة، ولا لصف منتهٍ', () {
      expect(
        WaitlistRules.promoteBlockReason(group: _group(), entry: _entry()),
        contains('لا مقعد'),
      );
      expect(
        WaitlistRules.promoteBlockReason(
          group: _group(seatsTaken: 9, isActive: false),
          entry: _entry(),
        ),
        contains('موقوفة'),
      );
      expect(
        WaitlistRules.promoteBlockReason(
          group: _group(seatsTaken: 9),
          entry: _entry(status: WaitlistStatus.left),
        ),
        contains('لم يعد'),
      );
    });
  });

  group('WaitlistRules — الترتيب والموضع', () {
    final List<GroupWaitlistEntry> entries = <GroupWaitlistEntry>[
      _entry(
        studentId: 'third',
        addedAt: DateTime(2026, 10, 5),
      ),
      _entry(
        studentId: 'first',
        addedAt: DateTime(2026, 10, 1),
      ),
      _entry(
        studentId: 'done',
        status: WaitlistStatus.promoted,
        addedAt: DateTime(2026, 9, 20),
        decidedAt: DateTime(2026, 10, 10),
      ),
      _entry(
        studentId: 'second',
        addedAt: DateTime(2026, 10, 3),
      ),
    ];

    test('المنتظرون أولًا بالأقدم، ثم المنتهون بالأحدث', () {
      expect(
        WaitlistRules.ordered(entries).map((GroupWaitlistEntry e) => e.studentId),
        <String>['first', 'third', 'second', 'done'],
      );
    });

    test('الموضع يبدأ من 1 ويخص المنتظرين فقط', () {
      expect(
        WaitlistRules.positionOf(entries, _entry(studentId: 'first').id),
        1,
      );
      expect(
        WaitlistRules.positionOf(entries, _entry(studentId: 'third').id),
        2,
      );
      expect(
        WaitlistRules.positionOf(entries, _entry(studentId: 'done').id),
        isNull,
      );
      expect(WaitlistRules.positionOf(entries, 'مجهول'), isNull);
    });

    test('waitingOnly يستبعد المنتهين ويحفظ الترتيب', () {
      final List<GroupWaitlistEntry> waiting = WaitlistRules.waitingOnly(entries);

      expect(waiting, hasLength(3));
      expect(waiting.every((GroupWaitlistEntry e) => e.isWaiting), isTrue);
      expect(waiting.first.studentId, 'first');
    });

    test('ملخص الطابور يذكر المقعد المتاح', () {
      expect(
        WaitlistRules.summaryLine(waiting: 0, seatsAvailable: 0),
        contains('فارغة'),
      );
      expect(
        WaitlistRules.summaryLine(waiting: 1, seatsAvailable: 0),
        'طالب واحد في قائمة الانتظار',
      );
      expect(
        WaitlistRules.summaryLine(waiting: 3, seatsAvailable: 1),
        contains('مقعد متاح'),
      );
    });

    test('لا قبول تلقائي بلا دوال خادم', () {
      expect(WaitlistRules.hasAutomaticPromotion, isFalse);
    });
  });

  group('WaitlistRules — التحقق والنموذج', () {
    test('الحقول الصحيحة تُقبل', () {
      expect(
        WaitlistRules.validateEntry(
          groupId: 'g1',
          groupTitle: 'التفاضل',
          studentId: 'student-1',
          studentName: 'طالب',
        ).isValid,
        isTrue,
      );
    });

    test('العنوان القصير أو الاسم الفارغ مرفوضان', () {
      expect(
        WaitlistRules.validateEntry(
          groupId: 'g1',
          groupTitle: 'أب',
          studentId: 's1',
          studentName: 'طالب',
        ).problems.first.field,
        'groupTitle',
      );
      expect(
        WaitlistRules.validateEntry(
          groupId: 'g1',
          groupTitle: 'التفاضل',
          studentId: 's1',
          studentName: '   ',
        ).isValid,
        isFalse,
      );
    });

    test('اسم أطول من 80 حرفًا مرفوض، وغياب التاريخ مرفوض', () {
      expect(
        WaitlistRules.validateEntry(
          groupId: 'g1',
          groupTitle: 'التفاضل',
          studentId: 's1',
          studentName: 'ا' * 81,
        ).problems.first.field,
        'studentName',
      );
      expect(
        WaitlistRules.validateEntry(
          groupId: 'g1',
          groupTitle: 'التفاضل',
          studentId: 's1',
          studentName: 'طالب',
          hasAddedAt: false,
        ).problems.first.field,
        'addedAt',
      );
    });

    test('خريطة الإنشاء تحمل الحقول المسموح بها فقط', () {
      final Map<String, Object?> map = buildWaitlistEntry(
        group: _group(),
        studentId: 'student-1',
        studentName: 'طالب',
      ).toCreateMap();

      expect(map.keys.toSet(), <String>{
        'groupId',
        'groupTitle',
        'teacherId',
        'studentId',
        'studentName',
        'status',
        'addedAt',
      });
      expect(map['status'], 'waiting');
      expect(map.containsKey('decidedBy'), isFalse);
    });

    test('الحالة تُقرأ بتسامح والقيم النصية ثابتة', () {
      expect(WaitlistStatus.parse('promoted'), WaitlistStatus.promoted);
      expect(WaitlistStatus.parse('left'), WaitlistStatus.left);
      expect(WaitlistStatus.parse('أي شيء'), WaitlistStatus.waiting);
      expect(WaitlistStatus.parse(null), WaitlistStatus.waiting);
      expect(WaitlistStatus.waiting.name, 'waiting');
      expect(WaitlistStatus.promoted.name, 'promoted');
      expect(WaitlistStatus.left.name, 'left');
    });
  });
}
