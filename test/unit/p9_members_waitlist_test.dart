import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/group_filter.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/group_waitlist_entry.dart';
import 'package:teacher_student_app/data/models/study_group.dart';

/// مجموعة مكتملة (6 من 6) لصاحب الجلسة التجريبية.
const String _fullGroupId = 'demo-group-5';
const String _teacherId = DemoData.demoTeacherId;

void main() {
  group('إدارة الأعضاء (P9)', () {
    test('إزالة عضو تحرّر مقعدًا واحدًا وتنقص القائمة', () async {
      final DemoGroupRepository groups = DemoGroupRepository();
      final StudyGroup before = (await groups.findById('demo-group-1'))!;
      final List<GroupMember> members = await groups.listMembers(before.id);

      final StudyGroup after = await groups.removeMember(
        groupId: before.id,
        memberId: members.first.id,
        teacherId: _teacherId,
      );

      expect(after.seatsTaken, before.seatsTaken - 1);
      final List<GroupMember> remaining = await groups.listMembers(before.id);
      expect(remaining, hasLength(members.length - 1));
      expect(
        remaining.any((GroupMember m) => m.id == members.first.id),
        isFalse,
      );
    });

    test('عضو مقبول بالقبول يُزال من القائمة أيضًا', () async {
      final DemoGroupRepository groups = DemoGroupRepository();
      final StudyGroup group = (await groups.findById('demo-group-1'))!;
      final request = await groups.requestToJoin(
        group: group,
        studentId: 'demo-student',
        studentName: 'طالب تجريبي',
      );
      await groups.decideJoinRequest(
        request: request,
        teacherId: _teacherId,
        approve: true,
      );

      expect(
        await groups.isMember(groupId: group.id, userId: 'demo-student'),
        isTrue,
      );
      await groups.removeMember(
        groupId: group.id,
        memberId: 'demo-student',
        teacherId: _teacherId,
      );

      expect(
        await groups.isMember(groupId: group.id, userId: 'demo-student'),
        isFalse,
      );
      expect(
        (await groups.findById(group.id))!.seatsTaken,
        group.seatsTaken + 1 - 1,
      );
    });

    test('غير المالك لا يزيل عضوًا', () async {
      final DemoGroupRepository groups = DemoGroupRepository();
      final StudyGroup group = (await groups.findById('demo-group-1'))!;
      final List<GroupMember> members = await groups.listMembers(group.id);

      await expectLater(
        groups.removeMember(
          groupId: group.id,
          memberId: members.first.id,
          teacherId: 'teacher-2',
        ),
        throwsA(isA<AppException>()),
      );
      expect(
        (await groups.findById(group.id))!.seatsTaken,
        group.seatsTaken,
        reason: 'لا تغيير بعد محاولة مرفوضة',
      );
    });

    test('عضو غير موجود يُرفض، والمقعد لا يصبح سالبًا', () async {
      final DemoGroupRepository groups = DemoGroupRepository();

      await expectLater(
        groups.removeMember(
          groupId: 'demo-group-1',
          memberId: 'مجهول',
          teacherId: _teacherId,
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('قائمة الانتظار (P9)', () {
    test('بيانات العرض تحمل منتظرين لمجموعة مكتملة فقط', () async {
      final DemoGroupRepository groups = DemoGroupRepository();
      final List<GroupWaitlistEntry> entries = await groups.listWaitlist(
        _fullGroupId,
        teacherId: _teacherId,
      );

      expect(entries, hasLength(DemoData.waitlist.length));
      expect(entries.every((GroupWaitlistEntry e) => e.isWaiting), isTrue);
      expect(entries.first.addedAt.isBefore(entries.last.addedAt), isTrue);
      expect(await groups.listWaitlist('demo-group-1'), isEmpty);
    });

    test('طالب ينضم لمجموعة مكتملة، ثم يغادر، ثم يعود', () async {
      final DemoGroupRepository groups = DemoGroupRepository();
      final StudyGroup group = (await groups.findById(_fullGroupId))!;

      final GroupWaitlistEntry entry = await groups.joinWaitlist(
        group: group,
        studentId: 'student-x',
        studentName: 'طالب جديد',
      );
      expect(entry.status, WaitlistStatus.waiting);
      expect(
        (await groups.findMyWaitlistEntry(
          groupId: group.id,
          studentId: 'student-x',
        ))!
            .id,
        entry.id,
      );

      final GroupWaitlistEntry left = await groups.leaveWaitlist(
        entry: entry,
        studentId: 'student-x',
      );
      expect(left.status, WaitlistStatus.left);
      expect(left.decidedBy, 'student-x');

      final GroupWaitlistEntry again = await groups.joinWaitlist(
        group: group,
        studentId: 'student-x',
        studentName: 'طالب جديد',
      );
      expect(again.isWaiting, isTrue);
      expect(again.id, entry.id, reason: 'معرّف حتمي: صف واحد لكل طالب');
    });

    test('مجموعة بها مقعد لا تقبل طابورًا', () async {
      final DemoGroupRepository groups = DemoGroupRepository();
      final StudyGroup group = (await groups.findById('demo-group-1'))!;

      await expectLater(
        groups.joinWaitlist(
          group: group,
          studentId: 'student-x',
          studentName: 'طالب',
        ),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.overrideMessage,
            'overrideMessage',
            contains('مقعد متاح'),
          ),
        ),
      );
    });

    test('الانضمام مرتين مرفوض، والمغادرة من غير صاحبه مرفوضة', () async {
      final DemoGroupRepository groups = DemoGroupRepository();
      final StudyGroup group = (await groups.findById(_fullGroupId))!;
      final GroupWaitlistEntry entry = await groups.joinWaitlist(
        group: group,
        studentId: 'student-x',
        studentName: 'طالب',
      );

      await expectLater(
        groups.joinWaitlist(
          group: group,
          studentId: 'student-x',
          studentName: 'طالب',
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        groups.leaveWaitlist(entry: entry, studentId: 'someone-else'),
        throwsA(isA<AppException>()),
      );
    });

    test('قبول منتظر بلا مقعد مرفوض', () async {
      final DemoGroupRepository groups = DemoGroupRepository();
      final GroupWaitlistEntry entry =
          (await groups.listWaitlist(_fullGroupId, teacherId: _teacherId)).first;

      await expectLater(
        groups.promoteFromWaitlist(entry: entry, teacherId: _teacherId),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.overrideMessage,
            'overrideMessage',
            contains('لا مقعد'),
          ),
        ),
      );
    });

    test('قبول المنتظر بعد تحرر مقعد: يزيد المقعد ويُنشئ عضوية', () async {
      final DemoGroupRepository groups = DemoGroupRepository();
      final List<GroupWaitlistEntry> queue = await groups.listWaitlist(
        _fullGroupId,
        teacherId: _teacherId,
      );
      final GroupWaitlistEntry first = queue.first;

      // تحرير مقعد بإزالة عضو — هذه هي الحلقة الكاملة للطابور.
      final StudyGroup group = (await groups.findById(_fullGroupId))!;
      final List<GroupMember> members = await groups.listMembers(_fullGroupId);
      await groups.removeMember(
        groupId: _fullGroupId,
        memberId: members.first.id,
        teacherId: _teacherId,
      );
      expect(
        (await groups.findById(_fullGroupId))!.seatsAvailable,
        1,
        reason: 'مقعد واحد متاح بعد الإزالة',
      );

      final GroupWaitlistEntry promoted = await groups.promoteFromWaitlist(
        entry: first,
        teacherId: _teacherId,
      );

      expect(promoted.status, WaitlistStatus.promoted);
      expect(promoted.decidedBy, _teacherId);
      expect(
        (await groups.findById(_fullGroupId))!.seatsTaken,
        group.seatsTaken,
        reason: 'إزالة + قبول = نفس العدد',
      );
      expect(
        await groups.isMember(
          groupId: _fullGroupId,
          userId: first.studentId,
        ),
        isTrue,
      );
      expect(
        (await groups.listMembers(_fullGroupId)).any(
          (GroupMember m) => m.id == first.studentId,
        ),
        isTrue,
      );

      // لا يُقبل المنتظر نفسه مرتين.
      await expectLater(
        groups.promoteFromWaitlist(entry: promoted, teacherId: _teacherId),
        throwsA(isA<AppException>()),
      );
    });

    test('غير المالك لا يقبل منتظرًا', () async {
      final DemoGroupRepository groups = DemoGroupRepository();
      final GroupWaitlistEntry entry =
          (await groups.listWaitlist(_fullGroupId, teacherId: _teacherId)).first;

      await expectLater(
        groups.promoteFromWaitlist(entry: entry, teacherId: 'teacher-2'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('استكشاف المجموعات (P9) — المستودع التجريبي', () {
    test('البحث يفلتر ويحفظ الإجمالي', () async {
      final DemoGroupRepository groups = DemoGroupRepository();
      final GroupSearchResult all = await groups.searchDiscoverable(
        GroupFilter.empty,
      );
      final GroupSearchResult math = await groups.searchDiscoverable(
        const GroupFilter(subject: 'الرياضيات'),
      );

      expect(all.total, all.groups.length);
      expect(math.groups.every((StudyGroup g) => g.subject == 'الرياضيات'), isTrue);
      expect(math.total, all.total);
    });

    test('فلتر المكتملة يعيد مجموعة العرض المكتملة', () async {
      final DemoGroupRepository groups = DemoGroupRepository();
      final GroupSearchResult full = await groups.searchDiscoverable(
        const GroupFilter(availability: GroupAvailability.full),
      );

      expect(full.groups.every((StudyGroup g) => g.isFull), isTrue);
      expect(
        full.groups.any((StudyGroup g) => g.id == _fullGroupId),
        isTrue,
      );
    });

    test('إيقاف مجموعة يخفيها من الاستكشاف', () async {
      final DemoGroupRepository groups = DemoGroupRepository();
      final StudyGroup group = (await groups.findById('demo-group-1'))!;

      await groups.updateGroup(
        groupId: group.id,
        teacherId: _teacherId,
        draft: GroupDraft.fromGroup(group),
        isActive: false,
      );

      final GroupSearchResult result = await groups.searchDiscoverable(
        const GroupFilter(query: 'التفاضل'),
      );
      expect(
        result.groups.any((StudyGroup g) => g.id == group.id),
        isFalse,
      );
    });
  });
}
