import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/study_group.dart';

StudyGroup _group({
  String id = 'g1',
  String teacherId = 'teacher-1',
  int seatsTotal = 12,
  int seatsTaken = 9,
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
    isActive: isActive,
  );
}

/// ينفّذ القرار ويرجع `true` إن نجح بدل رمي الاستثناء (لمقارنة النتائج).
Future<bool> _tryAccept(
  DemoGroupRepository repo,
  GroupJoinRequest request, {
  String teacherId = 'teacher-1',
}) async {
  try {
    await repo.decideJoinRequest(
      request: request,
      teacherId: teacherId,
      approve: true,
    );
    return true;
  } on AppException {
    return false;
  }
}

void main() {
  group('الوضع التجريبي — طلبات الانضمام (P8)', () {
    test('الطلب يُنشأ معلّقًا ويُقرأ للطالب وللمدرس', () async {
      final DemoGroupRepository repo = DemoGroupRepository(
        source: <StudyGroup>[_group()],
      );
      final StudyGroup group = (await repo.findById('g1'))!;

      final GroupJoinRequest request = await repo.requestToJoin(
        group: group,
        studentId: 's1',
        studentName: 'طالب أول',
      );

      expect(request.status, JoinRequestStatus.pending);
      expect(request.id, 'g1_s1');
      expect((await repo.findMyRequest(groupId: 'g1', studentId: 's1'))?.id, request.id);
      expect(await repo.listRequestsForGroup('g1'), hasLength(1));
      expect(await repo.listMyRequests('s1'), hasLength(1));
    });

    test('طلب ثانٍ معلّق لنفس الطالب مرفوض', () async {
      final DemoGroupRepository repo = DemoGroupRepository(
        source: <StudyGroup>[_group()],
      );
      final StudyGroup group = (await repo.findById('g1'))!;

      await repo.requestToJoin(group: group, studentId: 's1', studentName: 'طالب');
      await expectLater(
        repo.requestToJoin(group: group, studentId: 's1', studentName: 'طالب'),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.overrideMessage,
            'overrideMessage',
            contains('قيد المراجعة'),
          ),
        ),
      );
    });

    test('القبول يزيد المقعد مرة واحدة وينشئ عضوية', () async {
      final DemoGroupRepository repo = DemoGroupRepository(
        source: <StudyGroup>[_group(seatsTaken: 9)],
      );
      final StudyGroup group = (await repo.findById('g1'))!;
      final GroupJoinRequest request = await repo.requestToJoin(
        group: group,
        studentId: 's1',
        studentName: 'طالب أول',
      );

      final GroupJoinRequest accepted = await repo.decideJoinRequest(
        request: request,
        teacherId: 'teacher-1',
        approve: true,
      );

      expect(accepted.status, JoinRequestStatus.accepted);
      final StudyGroup updated = (await repo.findById('g1'))!;
      expect(updated.seatsTaken, 10);
      expect(updated.seatsTotal, 12);

      // مجموعات الاختبار ليست من بيانات العرض، فلا أعضاء وهميين مولَّدين؛
      // المهم أن العضو المقبول أُضيف مرة واحدة.
      final members = await repo.listMembers('g1');
      expect(members.where((m) => m.id == 's1'), hasLength(1));
      expect(members.first.name, 'طالب أول');
    });

    test('غير المالك لا يقبل، والطلب المرفوض لا يُقبل', () async {
      final DemoGroupRepository repo = DemoGroupRepository(
        source: <StudyGroup>[_group()],
      );
      final StudyGroup group = (await repo.findById('g1'))!;
      final GroupJoinRequest request = await repo.requestToJoin(
        group: group,
        studentId: 's1',
        studentName: 'طالب',
      );

      await expectLater(
        repo.decideJoinRequest(
          request: request,
          teacherId: 'teacher-2',
          approve: true,
        ),
        throwsA(isA<AppException>()),
      );

      await repo.decideJoinRequest(
        request: request,
        teacherId: 'teacher-1',
        approve: false,
      );
      await expectLater(
        repo.decideJoinRequest(
          request: request,
          teacherId: 'teacher-1',
          approve: true,
        ),
        throwsA(isA<AppException>()),
      );
      expect((await repo.findById('g1'))!.seatsTaken, 9);
    });

    test('الطلب بعد الرفض يعود معلّقًا ويُحجز مقعد واحد فقط', () async {
      final DemoGroupRepository repo = DemoGroupRepository(
        source: <StudyGroup>[_group()],
      );
      final StudyGroup group = (await repo.findById('g1'))!;
      final GroupJoinRequest first = await repo.requestToJoin(
        group: group,
        studentId: 's1',
        studentName: 'طالب',
      );
      await repo.decideJoinRequest(
        request: first,
        teacherId: 'teacher-1',
        approve: false,
      );

      final GroupJoinRequest second = await repo.requestToJoin(
        group: group,
        studentId: 's1',
        studentName: 'طالب',
      );
      expect(second.isPending, isTrue);
      await repo.decideJoinRequest(
        request: second,
        teacherId: 'teacher-1',
        approve: true,
      );

      expect((await repo.findById('g1'))!.seatsTaken, 10);
      expect(await repo.listRequestsForGroup('g1'), hasLength(1));
    });

    test('إلغاء الطالب لطلبه يعمل، ولطلب مقبول لا', () async {
      final DemoGroupRepository repo = DemoGroupRepository(
        source: <StudyGroup>[_group()],
      );
      final StudyGroup group = (await repo.findById('g1'))!;
      final GroupJoinRequest request = await repo.requestToJoin(
        group: group,
        studentId: 's1',
        studentName: 'طالب',
      );

      final GroupJoinRequest cancelled = await repo.cancelJoinRequest(
        request: request,
        studentId: 's1',
      );
      expect(cancelled.status, JoinRequestStatus.cancelled);

      await expectLater(
        repo.cancelJoinRequest(request: cancelled, studentId: 's2'),
        throwsA(isA<AppException>()),
      );
    });

    test('آخر مقعد: طلبان متزامنان لا يحصلان على المقعد معًا', () async {
      // السعة 12 والمشغول 11 ⇒ مقعد واحد. الطلبان يُرسلان قبل أي قرار، ثم
      // يُنفَّذ القبولان «في اللحظة نفسها» عبر Future.wait.
      final DemoGroupRepository repo = DemoGroupRepository(
        source: <StudyGroup>[_group(seatsTaken: 11)],
      );
      final StudyGroup group = (await repo.findById('g1'))!;

      await repo.requestToJoin(group: group, studentId: 's1', studentName: 'أ');
      await repo.requestToJoin(group: group, studentId: 's2', studentName: 'ب');

      final List<GroupJoinRequest> pending = await repo.listRequestsForGroup('g1');
      expect(pending, hasLength(2));

      final List<bool> results = await Future.wait<bool>(<Future<bool>>[
        _tryAccept(repo, pending[0]),
        _tryAccept(repo, pending[1]),
      ]);

      expect(
        results.where((bool ok) => ok).length,
        1,
        reason: 'قبول واحد فقط يجوز على المقعد الأخير',
      );
      expect(
        (await repo.findById('g1'))!.seatsTaken,
        12,
        reason: 'لا يُحجز المقعد مرتين',
      );
      // عضو واحد فقط أُضيف: المقعد الأخير لم يُحجز مرتين.
      expect(await repo.listMembers('g1'), hasLength(1));
    });

    test('المجموعة المكتملة أو الموقوفة ترفض الطلب', () async {
      for (final StudyGroup group in <StudyGroup>[
        _group(seatsTaken: 12),
        _group(isActive: false),
      ]) {
        final DemoGroupRepository repo = DemoGroupRepository(
          source: <StudyGroup>[group],
        );
        await expectLater(
          repo.requestToJoin(
            group: group,
            studentId: 's1',
            studentName: 'طالب',
          ),
          throwsA(isA<AppException>()),
        );
        expect(await repo.listRequestsForGroup(group.id), isEmpty);
      }
    });
  });
}
