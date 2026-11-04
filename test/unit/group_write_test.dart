import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/validation/group_rules.dart';
import 'package:teacher_student_app/data/validation/model_validators.dart';

const String teacherId = 'demo-teacher-1';

GroupDraft draft({
  String title = 'التفاضل والتكامل',
  String subject = 'الرياضيات',
  String stage = 'الثانوية العامة',
  int seats = 12,
  String? scheduleNote = 'السبت 5 م',
  GroupMeetingMode mode = GroupMeetingMode.center,
}) {
  return GroupDraft(
    title: title,
    subject: subject,
    stage: stage,
    seatsTotal: seats,
    scheduleNote: scheduleNote,
    meetingMode: mode,
  );
}

StudyGroup existingGroup({
  int seatsTotal = 12,
  int seatsTaken = 9,
  bool isActive = true,
}) {
  return StudyGroup(
    id: 'g-1',
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

void main() {
  group('قواعد السعة', () {
    test('النطاق 2..40 (حدّ صارم) وأقل قيمة مسموحة تراعي المنضمين', () {
      expect(GroupRules.minSeats, 2);
      expect(GroupRules.maxSeats, 40);
      expect(GroupRules.minAllowedSeats(0), 2);
      expect(GroupRules.minAllowedSeats(1), 2);
      expect(GroupRules.minAllowedSeats(9), 9);
    });

    test('قبول الأعضاء يتوقف على النشر ووجود مقعد', () {
      expect(GroupRules.canAcceptMember(existingGroup()), isTrue);
      expect(
        GroupRules.canAcceptMember(existingGroup(seatsTaken: 12)),
        isFalse,
      );
      expect(
        GroupRules.canAcceptMember(existingGroup(isActive: false)),
        isFalse,
      );
    });

    test('ملخص السعة يوضّح الحالة بالعربية', () {
      expect(GroupRules.capacitySummary(existingGroup()), contains('3'));
      expect(
        GroupRules.capacitySummary(existingGroup(seatsTaken: 12)),
        contains('مكتملة'),
      );
      expect(
        GroupRules.capacitySummary(existingGroup(isActive: false)),
        contains('موقوفة'),
      );
    });

    test('التحقق يرفض تقليل السعة تحت المنضمين', () {
      final ValidationResult result = GroupRules.validateDraft(
        draft(seats: 8),
        seatsTaken: 9,
      );

      expect(result.isValid, isFalse);
      expect(result.problems.single.field, 'seatsTotal');
    });

    test('التحقق يقبل السعة المساوية للمنضمين', () {
      expect(
        GroupRules.validateDraft(draft(seats: 9), seatsTaken: 9).isValid,
        isTrue,
      );
    });
  });

  group('خريطة Firestore', () {
    test('الإنشاء يبدأ بصفر منضمين ونشط، وبالحقول المسموح بها فقط', () {
      final Map<String, Object?> map = draft().toCreateMap(
        teacherId: teacherId,
        teacherName: 'أ. سارة',
      );

      expect(map['seatsTaken'], 0);
      expect(map['isActive'], isTrue);
      expect(map['teacherId'], teacherId);
      expect(map['meetingMode'], 'center');
      expect(
        map.keys,
        containsAll(<String>[
          'teacherId',
          'teacherName',
          'title',
          'subject',
          'stage',
          'seatsTotal',
          'seatsTaken',
          'meetingMode',
          'isActive',
          'scheduleNote',
        ]),
      );
      // لا حقول إدارية أو مؤشرات محسوبة.
      expect(map.containsKey('rating'), isFalse);
      expect(map.containsKey('membersCount'), isFalse);
    });

    test('حذف المسافات الطرفية وإسقاط وصف الموعد الفارغ', () {
      final Map<String, Object?> map = draft(
        title: '  التفاضل  ',
        scheduleNote: '   ',
      ).toCreateMap(teacherId: teacherId, teacherName: 'أ. سارة');

      expect(map['title'], 'التفاضل');
      expect(map.containsKey('scheduleNote'), isFalse);
    });

    test('التحديث لا يمسّ المالك ولا المقاعد المشغولة', () {
      final Map<String, Object?> map = draft(seats: 14).toUpdateMap(
        isActive: false,
      );

      expect(map.containsKey('teacherId'), isFalse);
      expect(map.containsKey('seatsTaken'), isFalse);
      expect(map['seatsTotal'], 14);
      expect(map['isActive'], isFalse);
      // القيمة نصية دائمًا (لا null): القواعد تقرأ المستند **بعد الدمج**،
      // وnull يجعل الحقل بنوع غير نصي فيُرفض التعديل.
      expect(map['scheduleNote'], 'السبت 5 م');

      final Map<String, Object?> cleared = draft(
        scheduleNote: '  ',
      ).toUpdateMap(isActive: true);
      expect(cleared['scheduleNote'], '');
    });
  });

  group('التنفيذ التجريبي (وضع الزائر)', () {
    test('إنشاء مجموعة يضيفها لقائمة المدرس ويجعلها نشطة', () async {
      final DemoGroupRepository repo = DemoGroupRepository();
      final int before = (await repo.listForTeacher(teacherId)).length;

      final StudyGroup created = await repo.createGroup(
        teacherId: teacherId,
        teacherName: 'أ. سارة',
        draft: draft(title: 'مجموعة جديدة'),
      );

      expect(created.seatsTaken, 0);
      expect(created.isActive, isTrue);
      expect((await repo.listForTeacher(teacherId)).length, before + 1);
      expect((await repo.findById(created.id))?.title, 'مجموعة جديدة');
    });

    test('المجموعة الجديدة تظهر في الاستكشاف', () async {
      final DemoGroupRepository repo = DemoGroupRepository();
      final StudyGroup created = await repo.createGroup(
        teacherId: teacherId,
        teacherName: 'أ. سارة',
        draft: draft(title: 'استكشاف'),
      );

      final List<StudyGroup> discoverable = await repo.listDiscoverable();
      expect(
        discoverable.any((StudyGroup g) => g.id == created.id),
        isTrue,
      );
    });

    test('إنشاء بمسودة ناقصة يرفض قبل أي كتابة', () async {
      final DemoGroupRepository repo = DemoGroupRepository();

      await expectLater(
        repo.createGroup(
          teacherId: teacherId,
          teacherName: 'أ. سارة',
          draft: draft(title: '', seats: 1),
        ),
        throwsA(isA<AppException>()),
      );
      // لم تُضف أي مجموعة.
      expect(
        (await repo.listForTeacher(teacherId)).any(
          (StudyGroup g) => g.title.isEmpty,
        ),
        isFalse,
      );
    });

    test('التعديل يحفظ الحقول ويحافظ على المقاعد المشغولة', () async {
      final DemoGroupRepository repo = DemoGroupRepository(
        source: <StudyGroup>[existingGroup()],
      );

      final StudyGroup updated = await repo.updateGroup(
        groupId: 'g-1',
        teacherId: teacherId,
        draft: draft(title: 'التفاضل المتقدم', seats: 20),
        isActive: false,
      );

      expect(updated.title, 'التفاضل المتقدم');
      expect(updated.seatsTotal, 20);
      expect(updated.seatsTaken, 9); // لم تتغير
      expect(updated.isActive, isFalse);
      expect((await repo.listDiscoverable()).length, 0); // موقوفة ⇒ مخفية
      expect((await repo.listForTeacher(teacherId)).length, 1);
    });

    test('التعديل يرفض تقليل السعة تحت المنضمين', () async {
      final DemoGroupRepository repo = DemoGroupRepository(
        source: <StudyGroup>[existingGroup()],
      );

      await expectLater(
        repo.updateGroup(
          groupId: 'g-1',
          teacherId: teacherId,
          draft: draft(seats: 5),
          isActive: true,
        ),
        throwsA(isA<AppException>()),
      );
      // لم يتغيّر شيء.
      expect((await repo.findById('g-1'))?.seatsTotal, 12);
    });

    test('غير المالك لا يعدّل', () async {
      final DemoGroupRepository repo = DemoGroupRepository(
        source: <StudyGroup>[existingGroup()],
      );

      await expectLater(
        repo.updateGroup(
          groupId: 'g-1',
          teacherId: 'teacher-other',
          draft: draft(),
          isActive: true,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('تعديل مجموعة غير موجودة يعيد «غير موجود»', () async {
      final DemoGroupRepository repo = DemoGroupRepository();

      await expectLater(
        repo.updateGroup(
          groupId: 'missing',
          teacherId: teacherId,
          draft: draft(),
          isActive: true,
        ),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.kind,
            'kind',
            AppErrorKind.notFound,
          ),
        ),
      );
    });
  });
}
