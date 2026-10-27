import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/group_waitlist_entry.dart';
import 'package:teacher_student_app/data/models/member_move.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/validation/group_rules.dart';
import 'package:teacher_student_app/data/validation/model_validators.dart';
import 'package:teacher_student_app/data/validation/move_rules.dart';

const String _teacherId = DemoData.demoTeacherId;

StudyGroup _group({
  required String id,
  String teacherId = _teacherId,
  int seatsTotal = 6,
  int seatsTaken = 0,
  bool isActive = true,
  String title = 'مجموعة',
}) {
  return StudyGroup(
    id: id,
    teacherId: teacherId,
    teacherName: 'أ. سارة',
    title: title,
    subject: 'الرياضيات',
    stage: 'الثانوية العامة',
    seatsTotal: seatsTotal,
    seatsTaken: seatsTaken,
    meetingMode: GroupMeetingMode.center,
    isActive: isActive,
  );
}

/// مستودع بمجموعتين للمدرس نفسه، وأعضاؤهما **مقبولون فعليًا** عبر مسار
/// الانضمام الحقيقي (لا عضويّات مزروعة يدويًا)، حتى تكون المقاعد والأعضاء
/// متسقة كما في الإنتاج.
Future<DemoGroupRepository> _build({
  int sourceSeats = 6,
  int sourceMembers = 2,
  int targetSeats = 4,
  int targetTaken = 0,
  bool targetActive = true,
}) async {
  final DemoGroupRepository repo = DemoGroupRepository(
    source: <StudyGroup>[
      _group(id: 'a', seatsTotal: sourceSeats, title: 'المجموعة أ'),
      _group(
        id: 'b',
        seatsTotal: targetSeats,
        seatsTaken: targetTaken,
        isActive: targetActive,
        title: 'المجموعة ب',
      ),
    ],
  );

  for (int i = 1; i <= sourceMembers; i++) {
    final GroupJoinRequest request = await repo.requestToJoin(
      group: (await repo.findById('a'))!,
      studentId: 'student-$i',
      studentName: 'طالب $i',
    );
    await repo.decideJoinRequest(
      request: request,
      teacherId: _teacherId,
      approve: true,
    );
  }
  return repo;
}

void main() {
  group('GroupRules — سعة المجموعة (حدّ صارم 40)', () {
    test('الحد الأقصى 40 والأدنى 2', () {
      expect(GroupRules.maxSeats, 40);
      expect(GroupRules.minSeats, 2);
      expect(ModelLimits.seatsMax, 40);
      expect(GroupRules.canSetCapacity(seatsTotal: 40, seatsTaken: 0), isTrue);
      expect(GroupRules.canSetCapacity(seatsTotal: 41, seatsTaken: 0), isFalse);
      expect(GroupRules.canSetCapacity(seatsTotal: 1, seatsTaken: 0), isFalse);
    });

    test('لا تنزل السعة تحت المنضمين، وتساويهم مسموح', () {
      expect(
        GroupRules.capacityBlockReason(seatsTotal: 8, seatsTaken: 9),
        contains('9'),
      );
      expect(
        GroupRules.capacityBlockReason(seatsTotal: 9, seatsTaken: 9),
        isNull,
      );
    });

    test('رسائل الرفض تذكر الحدّ المخروق', () {
      expect(
        GroupRules.capacityBlockReason(seatsTotal: 41, seatsTaken: 0),
        contains('40'),
      );
      expect(
        GroupRules.capacityBlockReason(seatsTotal: 1, seatsTaken: 0),
        contains('2'),
      );
    });
  });

  group('MoveRules — شروط النقل', () {
    final StudyGroup from = _group(id: 'a', seatsTaken: 2);
    final StudyGroup free = _group(id: 'b', seatsTotal: 6, seatsTaken: 1);
    final StudyGroup full = _group(id: 'c', seatsTotal: 6, seatsTaken: 6);

    test('النقل مسموح إلى مجموعة بها مقعد', () {
      expect(
        MoveRules.canMove(
          from: from,
          to: free,
          sameOwner: true,
          isMember: true,
          targetAlreadyHasMember: false,
        ),
        isTrue,
      );
    });

    test('الهدف المكتمل يُرفض بالنص الحرفي المطلوب', () {
      expect(
        MoveRules.blockReason(
          from: from,
          to: full,
          sameOwner: true,
          isMember: true,
          targetAlreadyHasMember: false,
        ),
        'المجموعة المراد النقل إليها مكتملة السعة.',
      );
      expect(
        MoveRules.targetFullMessage,
        'المجموعة المراد النقل إليها مكتملة السعة.',
      );
    });

    test('مجموعة مدرس آخر، ونفس المجموعة، مرفوضتان', () {
      expect(
        MoveRules.blockReason(
          from: from,
          to: _group(id: 'z', teacherId: 'teacher-2'),
          sameOwner: false,
          isMember: true,
          targetAlreadyHasMember: false,
        ),
        contains('لا تملكها'),
      );
      expect(
        MoveRules.blockReason(
          from: from,
          to: from,
          sameOwner: true,
          isMember: true,
          targetAlreadyHasMember: false,
        ),
        contains('بالفعل'),
      );
    });

    test('عضو غير موجود في المصدر، أو موجود في الهدف، مرفوض', () {
      expect(
        MoveRules.blockReason(
          from: from,
          to: free,
          sameOwner: true,
          isMember: false,
          targetAlreadyHasMember: false,
        ),
        contains('ليس في المجموعة المصدر'),
      );
      expect(
        MoveRules.blockReason(
          from: from,
          to: free,
          sameOwner: true,
          isMember: true,
          targetAlreadyHasMember: true,
        ),
        contains('المجموعة الهدف'),
      );
    });

    test('الهدف الموقوف مرفوض', () {
      expect(
        MoveRules.blockReason(
          from: from,
          to: _group(id: 'p', isActive: false),
          sameOwner: true,
          isMember: true,
          targetAlreadyHasMember: false,
        ),
        contains('موقوفة'),
      );
    });

    test('قائمة الأهداف تستثني المصدر وتشرح تعطيل المكتمل', () {
      final List<StudyGroup> targets = MoveRules.targets(
        from: from,
        ownedGroups: <StudyGroup>[from, free, full],
      );

      expect(targets.map((StudyGroup g) => g.id), <String>['b', 'c']);
      expect(MoveRules.targetBlockReason(free), isNull);
      expect(MoveRules.targetBlockReason(full), MoveRules.targetFullMessage);
    });
  });

  group('النقل — المستودع التجريبي (معاملة محاكاة)', () {
    test('النقل ينقص مقعدًا ويزيد مقعدًا وينقل العضوية', () async {
      final DemoGroupRepository repo = await _build();
      expect((await repo.findById('a'))!.seatsTaken, 2);

      final GroupMember member = (await repo.listMembers('a')).first;
      final MemberMove move = await repo.moveMember(
        memberId: member.id,
        fromGroupId: 'a',
        toGroupId: 'b',
        teacherId: _teacherId,
      );

      expect(move.from.seatsTaken, 1);
      expect(move.to.seatsTaken, 1);
      expect((await repo.findById('a'))!.seatsTaken, 1);
      expect((await repo.findById('b'))!.seatsTaken, 1);
      expect(
        (await repo.listMembers('a')).any((GroupMember m) => m.id == member.id),
        isFalse,
      );
      expect(
        (await repo.listMembers('b')).any((GroupMember m) => m.id == member.id),
        isTrue,
      );
      expect((await repo.listMembers('a')).length, 1);
      expect((await repo.listMembers('b')).length, 1);
      expect(await repo.isMember(groupId: 'b', userId: member.id), isTrue);
    });

    test('الهدف المكتمل: رفض صريح بلا أي كتابة جزئية', () async {
      final DemoGroupRepository repo = await _build(
        targetSeats: 3,
        targetTaken: 3,
      );
      final GroupMember member = (await repo.listMembers('a')).first;

      await expectLater(
        repo.moveMember(
          memberId: member.id,
          fromGroupId: 'a',
          toGroupId: 'b',
          teacherId: _teacherId,
        ),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.overrideMessage,
            'overrideMessage',
            MoveRules.targetFullMessage,
          ),
        ),
      );

      expect((await repo.findById('a'))!.seatsTaken, 2);
      expect((await repo.findById('b'))!.seatsTaken, 3);
      expect(
        (await repo.listMembers('a')).any((GroupMember m) => m.id == member.id),
        isTrue,
      );
    });

    test('مدرس آخر لا ينقل، والعضو المجهول مرفوض', () async {
      final DemoGroupRepository repo = await _build();
      final GroupMember member = (await repo.listMembers('a')).first;

      await expectLater(
        repo.moveMember(
          memberId: member.id,
          fromGroupId: 'a',
          toGroupId: 'b',
          teacherId: 'teacher-2',
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repo.moveMember(
          memberId: 'ghost',
          fromGroupId: 'a',
          toGroupId: 'b',
          teacherId: _teacherId,
        ),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.overrideMessage,
            'overrideMessage',
            contains('ليس في المجموعة المصدر'),
          ),
        ),
      );
      // لا أثر لأي محاولة فاشلة.
      expect((await repo.findById('a'))!.seatsTaken, 2);
      expect((await repo.findById('b'))!.seatsTaken, 0);
    });

    test('الهدف الموقوف لا يستقبل نقلًا', () async {
      final DemoGroupRepository repo = await _build(targetActive: false);
      final GroupMember member = (await repo.listMembers('a')).first;

      await expectLater(
        repo.moveMember(
          memberId: member.id,
          fromGroupId: 'a',
          toGroupId: 'b',
          teacherId: _teacherId,
        ),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.overrideMessage,
            'overrideMessage',
            contains('موقوفة'),
          ),
        ),
      );
    });

    test('مقعد واحد فقط: نقلان متزامنان، واحد ينجح', () async {
      // الهدف 3 مقاعد وفيه مقعدان مشغولان ⇒ مقعد واحد. المصدر فيه عضوان.
      final DemoGroupRepository repo = await _build(
        targetSeats: 3,
        targetTaken: 2,
      );
      final List<GroupMember> members = await repo.listMembers('a');

      final List<Object> results = await Future.wait<Object>(<Future<Object>>[
        repo
            .moveMember(
              memberId: members[0].id,
              fromGroupId: 'a',
              toGroupId: 'b',
              teacherId: _teacherId,
            )
            .then<Object>((MemberMove m) => m)
            .catchError((Object e) => e),
        repo
            .moveMember(
              memberId: members[1].id,
              fromGroupId: 'a',
              toGroupId: 'b',
              teacherId: _teacherId,
            )
            .then<Object>((MemberMove m) => m)
            .catchError((Object e) => e),
      ]);

      expect(results.whereType<MemberMove>().length, 1, reason: 'مقعد واحد فقط');
      expect(results.whereType<AppException>().length, 1);
      expect((await repo.findById('b'))!.seatsTaken, 3);
      expect((await repo.findById('a'))!.seatsTaken, 1);
    });
  });

  group('السعة — المستودع التجريبي', () {
    test('رفع السعة مسموح ولا يمسّ المقاعد المشغولة', () async {
      final DemoGroupRepository repo = await _build();
      final StudyGroup updated = await repo.updateGroupCapacity(
        groupId: 'a',
        teacherId: _teacherId,
        seatsTotal: 40,
      );

      expect(updated.seatsTotal, 40);
      expect(updated.seatsTaken, 2);
      expect((await repo.findById('a'))!.seatsTotal, 40);
      expect((await repo.findById('b'))!.seatsTotal, 4);
    });

    test('تخفيض تحت المنضمين، أو فوق 40، أو تحت 2 مرفوض', () async {
      final DemoGroupRepository repo = await _build();

      await expectLater(
        repo.updateGroupCapacity(
          groupId: 'a',
          teacherId: _teacherId,
          seatsTotal: 1,
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repo.updateGroupCapacity(
          groupId: 'a',
          teacherId: _teacherId,
          seatsTotal: 41,
        ),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.overrideMessage,
            'overrideMessage',
            contains('40'),
          ),
        ),
      );
      // المنضمون 2 ⇒ أي سعة أقل من 2 مرفوضة، والمساواة مسموحة.
      await expectLater(
        repo.updateGroupCapacity(
          groupId: 'a',
          teacherId: _teacherId,
          seatsTotal: 2,
        ),
        completes,
      );
      expect((await repo.findById('a'))!.seatsTotal, 2);
    });

    test('غير المالك لا يعدّل السعة', () async {
      final DemoGroupRepository repo = await _build();

      await expectLater(
        repo.updateGroupCapacity(
          groupId: 'a',
          teacherId: 'teacher-2',
          seatsTotal: 8,
        ),
        throwsA(isA<AppException>()),
      );
      expect((await repo.findById('a'))!.seatsTotal, 6);
    });

    test('رفع سعة مجموعة مكتملة يفتح مقعدًا للمنتظر', () async {
      final DemoGroupRepository repo = DemoGroupRepository();
      final GroupWaitlistEntry entry =
          (await repo.listWaitlist('demo-group-5', teacherId: _teacherId)).first;

      // مكتملة (6 من 6) ⇒ لا قبول.
      await expectLater(
        repo.promoteFromWaitlist(entry: entry, teacherId: _teacherId),
        throwsA(isA<AppException>()),
      );

      final StudyGroup raised = await repo.updateGroupCapacity(
        groupId: 'demo-group-5',
        teacherId: _teacherId,
        seatsTotal: 7,
      );
      expect(raised.seatsAvailable, 1);

      final GroupWaitlistEntry promoted = await repo.promoteFromWaitlist(
        entry: entry,
        teacherId: _teacherId,
      );
      expect(promoted.status, WaitlistStatus.promoted);
      expect((await repo.findById('demo-group-5'))!.seatsTaken, 7);
    });
  });
}
