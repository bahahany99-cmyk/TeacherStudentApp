import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/group_waitlist_entry.dart';
import 'package:teacher_student_app/data/models/member_move.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/validation/move_rules.dart';

const String _teacherId = DemoData.demoTeacherId;
const String _studentId = 'student-1';

StudyGroup _group({required String id, required int seatsTotal, String title = ''}) {
  return StudyGroup(
    id: id,
    teacherId: _teacherId,
    teacherName: 'أ. سارة',
    title: title.isEmpty ? 'مجموعة $id' : title,
    subject: 'الرياضيات',
    stage: 'الثانوية العامة',
    seatsTotal: seatsTotal,
    seatsTaken: 0,
    meetingMode: GroupMeetingMode.center,
  );
}

/// مستودع بمجموعتين للمدرس نفسه، والعضو مقبول عبر مسار الانضمام الحقيقي —
/// وهذا يترك **طلب انضمام بحالة `accepted`** في المجموعة المصدر، وهو بالضبط
/// السجل الذي يجب أن يختفي بعد النقل (وإلا صار «مقبولًا» في مجموعة لا ينتمي
/// إليها).
Future<DemoGroupRepository> _build({
  int sourceSeats = 6,
  int targetSeats = 5,
  int targetTaken = 0,
}) async {
  final DemoGroupRepository repo = DemoGroupRepository(
    source: <StudyGroup>[
      _group(id: 'a', seatsTotal: sourceSeats, title: 'المجموعة أ'),
      _group(id: 'b', seatsTotal: targetSeats, title: 'المجموعة ب'),
    ],
  );

  if (targetTaken > 0) {
    // نملأ الهدف بأعضاء حقيقيين حتى تكون المقاعد متسقة مع الأعضاء.
    for (int i = 1; i <= targetTaken; i++) {
      final GroupJoinRequest winner = await repo.requestToJoin(
        group: (await repo.findById('b'))!,
        studentId: 'filled-$i',
        studentName: 'عضو $i',
      );
      await repo.decideJoinRequest(
        request: winner,
        teacherId: _teacherId,
        approve: true,
      );
    }
  }

  final GroupJoinRequest request = await repo.requestToJoin(
    group: (await repo.findById('a'))!,
    studentId: _studentId,
    studentName: 'طالب 1',
  );
  await repo.decideJoinRequest(
    request: request,
    teacherId: _teacherId,
    approve: true,
  );
  return repo;
}

Future<MemberMove> _move(
  DemoGroupRepository repo, {
  String from = 'a',
  String to = 'b',
}) {
  return repo.moveMember(
    memberId: _studentId,
    fromGroupId: from,
    toGroupId: to,
    teacherId: _teacherId,
  );
}

void main() {
  group('تنظيف صفوف الانضمام عند النقل (A-73)', () {
    test('طلب الانضمام المقبول في المجموعة المصدر يُحذف', () async {
      final DemoGroupRepository repo = await _build();
      expect(
        (await repo.findMyRequest(groupId: 'a', studentId: _studentId))!.status,
        JoinRequestStatus.accepted,
        reason: 'قبول الطلب يترك سجلًا مقبولًا قبل النقل',
      );

      final MemberMove move = await _move(repo);

      expect(move.clearedSourceRecords, 1);
      expect(
        await repo.findMyRequest(groupId: 'a', studentId: _studentId),
        isNull,
      );
      expect(
        await repo.listRequestsForGroup('a', teacherId: _teacherId),
        isEmpty,
      );
      // ولا «حالة شبح» في شاشة المدرس.
      expect(
        (await repo.listMembers('a')).any(
          (GroupMember m) => m.id == _studentId,
        ),
        isFalse,
      );
    });

    test('طلب معلّق في المجموعة الهدف يصبح مقبولًا في المعاملة', () async {
      final DemoGroupRepository repo = await _build();
      await repo.requestToJoin(
        group: (await repo.findById('b'))!,
        studentId: _studentId,
        studentName: 'طالب 1',
      );
      expect(
        (await repo.findMyRequest(groupId: 'b', studentId: _studentId))!.status,
        JoinRequestStatus.pending,
      );

      final MemberMove move = await _move(repo);

      final GroupJoinRequest? resolved = await repo.findMyRequest(
        groupId: 'b',
        studentId: _studentId,
      );
      expect(resolved, isNotNull);
      expect(resolved!.status, JoinRequestStatus.accepted);
      expect(resolved.decidedBy, _teacherId);
      expect(resolved.decidedAt, isNotNull);
      expect(move.acceptedJoinRequest, isTrue);
      expect(move.summary, contains('مقبول'));
      // الطلب المعلّق لم يبقَ في صندوق المدرس.
      expect(
        (await repo.listRequestsForGroup('b', teacherId: _teacherId))
            .where((GroupJoinRequest r) => r.isPending),
        isEmpty,
      );
    });

    test('صف الانتظار في المجموعة الهدف يصبح «تم قبوله»', () async {
      // الهدف مكتمل 3/3 ⇒ الطالب يدخل قائمة الانتظار مشروعة.
      final DemoGroupRepository repo = await _build(targetSeats: 3, targetTaken: 3);
      await repo.joinWaitlist(
        group: (await repo.findById('b'))!,
        studentId: _studentId,
        studentName: 'طالب 1',
      );
      expect(
        (await repo.findMyWaitlistEntry(
          groupId: 'b',
          studentId: _studentId,
        ))!.status,
        WaitlistStatus.waiting,
      );

      // رفع السعة يفتح مقعدًا، ثم النقل.
      await repo.updateGroupCapacity(
        groupId: 'b',
        teacherId: _teacherId,
        seatsTotal: 4,
      );
      final MemberMove move = await _move(repo);

      final GroupWaitlistEntry? entry = await repo.findMyWaitlistEntry(
        groupId: 'b',
        studentId: _studentId,
      );
      expect(entry!.status, WaitlistStatus.promoted);
      expect(entry.decidedBy, _teacherId);
      expect(move.promotedWaitlist, isTrue);
      // لم يبقَ منتظر في القائمة المعلّقة.
      expect(
        (await repo.listWaitlist('b', teacherId: _teacherId))
            .where((GroupWaitlistEntry e) => e.isWaiting),
        isEmpty,
      );
    });

    test('السجلات المغلقة تبقى، وصفوف مجموعة ثالثة لا تُمسّ', () async {
      // ثلاث مجموعات من البداية: النقل بين a وb يجب ألّا يلمس صفوف c.
      final DemoGroupRepository fresh = DemoGroupRepository(
        source: <StudyGroup>[
          _group(id: 'a', seatsTotal: 6, title: 'المجموعة أ'),
          _group(id: 'b', seatsTotal: 5, title: 'المجموعة ب'),
          _group(id: 'c', seatsTotal: 5, title: 'المجموعة ج'),
        ],
      );
      final GroupJoinRequest mine = await fresh.requestToJoin(
        group: (await fresh.findById('a'))!,
        studentId: _studentId,
        studentName: 'طالب 1',
      );
      await fresh.decideJoinRequest(
        request: mine,
        teacherId: _teacherId,
        approve: true,
      );
      final GroupJoinRequest other = await fresh.requestToJoin(
        group: (await fresh.findById('c'))!,
        studentId: _studentId,
        studentName: 'طالب 1',
      );
      await fresh.decideJoinRequest(
        request: other,
        teacherId: _teacherId,
        approve: false,
      );

      await _move(fresh);

      final GroupJoinRequest? unaffected = await fresh.findMyRequest(
        groupId: 'c',
        studentId: _studentId,
      );
      expect(unaffected, isNotNull);
      expect(unaffected!.status, JoinRequestStatus.rejected);
    });

    test('النقل الفاشل لا ينظّف شيئًا (ذرّية كاملة)', () async {
      final DemoGroupRepository repo = await _build(
        targetSeats: 3,
        targetTaken: 3,
      );

      await expectLater(_move(repo), throwsA(isA<AppException>()));

      final GroupJoinRequest? source = await repo.findMyRequest(
        groupId: 'a',
        studentId: _studentId,
      );
      expect(source!.status, JoinRequestStatus.accepted);
      expect(
        (await repo.listMembers('a')).length,
        1,
      );
      expect((await repo.findById('b'))!.seatsTaken, 3);
    });

    test('العضو المنقول يحمل أثر النقل (من أين ومتى)', () async {
      final DemoGroupRepository repo = await _build();
      final MemberMove move = await _move(repo);

      final GroupMember member = (await repo.listMembers('b')).first;
      expect(member.wasMoved, isTrue);
      expect(member.movedFromGroupTitle, 'المجموعة أ');
      expect(member.joinedAt, move.member.joinedAt,
          reason: 'تاريخ الانضمام الأصلي لا يتغيّر بالنقل');
    });

    test('النقل ذهابًا وإيابًا ينظّف كل اتجاه على حدة', () async {
      final DemoGroupRepository repo = await _build();

      await _move(repo);
      // في الهدف صار للطالب طلب مقبول (من التحويل أو من العضوية الجديدة).
      expect(
        await repo.findMyRequest(groupId: 'a', studentId: _studentId),
        isNull,
      );

      final MemberMove back = await _move(repo, from: 'b', to: 'a');
      // لا صف لطالب في b أصلًا (العضوية هناك أُنشئت بالنقل لا بطلب)، فلا حذف.
      expect(back.clearedSourceRecords, 0);
      expect(
        await repo.findMyRequest(groupId: 'b', studentId: _studentId),
        isNull,
      );
      expect(
        (await repo.listMembers('a')).any(
          (GroupMember m) => m.id == _studentId,
        ),
        isTrue,
      );
      expect(
        (await repo.listMembers('b')).any(
          (GroupMember m) => m.id == _studentId,
        ),
        isFalse,
      );
      expect(
        (await repo.findById('b'))!.seatsTaken,
        0,
        reason: 'المقعد تحرّر في المجموعة التي خرج منها العضو',
      );
    });

    test('الملخّص يذكر ما نُظّف بالعربية (لا شيء يحدث بصمت)', () async {
      final DemoGroupRepository repo = await _build();
      final MemberMove move = await _move(repo);

      expect(move.acceptedJoinRequest, isFalse);
      expect(move.promotedWaitlist, isFalse);
      expect(move.summary, contains('حُذف 1 سجل قديم'));
      expect(MoveRules.targetFullMessage, contains('مكتملة'));
    });
  });
}
