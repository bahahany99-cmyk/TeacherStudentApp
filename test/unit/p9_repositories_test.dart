import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/group_message.dart';
import 'package:teacher_student_app/data/models/group_session.dart';
import 'package:teacher_student_app/data/models/user_role.dart';

SessionDraft _draft({
  String title = 'حلّ تدريبات',
  GroupWeekday weekday = GroupWeekday.monday,
  int start = 18 * 60,
  int duration = 60,
}) {
  return SessionDraft(
    title: title,
    weekday: weekday,
    startMinutes: start,
    durationMinutes: duration,
  );
}

void main() {
  group('الجدول التجريبي (P9)', () {
    test('يعيد مواعيد المجموعة مرتّبة فقط', () async {
      final DemoScheduleRepository schedules = DemoScheduleRepository();
      final List<GroupSession> sessions = await schedules.listForGroup(
        'demo-group-1',
      );

      expect(sessions, hasLength(DemoData.sessions.length));
      expect(
        sessions.every((GroupSession s) => s.groupId == 'demo-group-1'),
        isTrue,
      );
      expect(
        sessions.first.weekday.index,
        lessThanOrEqualTo(sessions.last.weekday.index),
      );
      expect(await schedules.listForGroup('ليس-موجودًا'), isEmpty);
    });

    test('المالك يضيف موعدًا، ويظهر فورًا في القائمة', () async {
      final DemoScheduleRepository schedules = DemoScheduleRepository();
      final GroupSession created = await schedules.createSession(
        groupId: 'demo-group-1',
        teacherId: 'teacher-1',
        draft: _draft(),
      );

      expect(created.title, 'حلّ تدريبات');
      expect(created.isCancelled, isFalse);
      final List<GroupSession> all = await schedules.listForGroup(
        'demo-group-1',
      );
      expect(all.any((GroupSession s) => s.id == created.id), isTrue);
    });

    test('تداخل مع موعد قائم مرفوض برسالة عربية', () async {
      final DemoScheduleRepository schedules = DemoScheduleRepository();

      await expectLater(
        // الموعد الأول في بيانات العرض: السبت 17:00 لمدة 90 دقيقة.
        schedules.createSession(
          groupId: 'demo-group-1',
          teacherId: 'teacher-1',
          draft: _draft(
            weekday: GroupWeekday.saturday,
            start: 17 * 60 + 30,
          ),
        ),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.overrideMessage,
            'overrideMessage',
            contains('يتعارض'),
          ),
        ),
      );
    });

    test('عبر منتصف الليل مرفوض', () async {
      final DemoScheduleRepository schedules = DemoScheduleRepository();

      await expectLater(
        schedules.createSession(
          groupId: 'demo-group-1',
          teacherId: 'teacher-1',
          draft: _draft(start: 23 * 60 + 30, duration: 60),
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('تعديل موعد: يغيّر الحقول، ويحفظ المالك والمجموعة', () async {
      final DemoScheduleRepository schedules = DemoScheduleRepository();
      final GroupSession session = (await schedules.listForGroup(
        'demo-group-1',
      )).first;

      final GroupSession updated = await schedules.updateSession(
        session: session,
        teacherId: 'teacher-1',
        draft: SessionDraft.fromSession(session).copyWith(
          title: 'عنوان محدّث',
          startMinutes: 20 * 60,
        ),
      );

      expect(updated.title, 'عنوان محدّث');
      expect(updated.startMinutes, 20 * 60);
      expect(updated.groupId, session.groupId);
      expect(updated.teacherId, session.teacherId);
    });

    test('غير المالك لا يعدّل ولا يلغي', () async {
      final DemoScheduleRepository schedules = DemoScheduleRepository();
      final GroupSession session = (await schedules.listForGroup(
        'demo-group-1',
      )).first;

      await expectLater(
        schedules.updateSession(
          session: session,
          teacherId: 'teacher-2',
          draft: SessionDraft.fromSession(session),
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        schedules.setCancelled(
          session: session,
          teacherId: 'teacher-2',
          isCancelled: true,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('الإلغاء يُبقي الموعد في القائمة بوسمه، ويعود بالتفعيل', () async {
      final DemoScheduleRepository schedules = DemoScheduleRepository();
      final GroupSession session = (await schedules.listForGroup(
        'demo-group-1',
      )).first;

      final GroupSession cancelled = await schedules.setCancelled(
        session: session,
        teacherId: 'teacher-1',
        isCancelled: true,
      );
      expect(cancelled.isCancelled, isTrue);
      expect(
        (await schedules.listForGroup('demo-group-1')).length,
        DemoData.sessions.length,
      );

      final GroupSession restored = await schedules.setCancelled(
        session: cancelled,
        teacherId: 'teacher-1',
        isCancelled: false,
      );
      expect(restored.isCancelled, isFalse);
    });
  });

  group('المحادثة التجريبية (P9)', () {
    test('رسالة العرض موجودة وتُقرأ لمجموعتها فقط', () async {
      final DemoMessageRepository messages = DemoMessageRepository();

      final List<GroupMessage> mine = await messages.listForGroup('demo-group-1');
      expect(mine, hasLength(DemoData.messages.length));
      expect(mine.first.senderRole, UserRole.teacher);
      expect(await messages.listForGroup('demo-group-2'), isEmpty);
    });

    test('الإرسال يضيف رسالة مرتّبة في النهاية', () async {
      final DemoMessageRepository messages = DemoMessageRepository();

      final GroupMessage sent = await messages.sendMessage(
        groupId: 'demo-group-1',
        senderId: 'demo-student',
        senderName: 'طالب تجريبي',
        senderRole: UserRole.student,
        text: '  شكرًا يا أستاذ   ',
      );

      expect(sent.text, 'شكرًا يا أستاذ');
      final List<GroupMessage> all = await messages.listForGroup(
        'demo-group-1',
      );
      expect(all.last.id, sent.id);
      expect(all.last.isMine('demo-student'), isTrue);
      expect(all.last.isMine('someone-else'), isFalse);
    });

    test('الرسالة الفارغة أو الطويلة مرفوضة', () async {
      final DemoMessageRepository messages = DemoMessageRepository();

      await expectLater(
        messages.sendMessage(
          groupId: 'demo-group-1',
          senderId: 'demo-student',
          senderName: 'طالب',
          senderRole: UserRole.student,
          text: '   ',
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        messages.sendMessage(
          groupId: 'demo-group-1',
          senderId: 'demo-student',
          senderName: 'طالب',
          senderRole: UserRole.student,
          text: 'ا' * 501,
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('العضوية (P9)', () {
    test('الطالب ليس عضوًا قبل قبول طلبه، ويصبح عضوًا بعد القبول', () async {
      final DemoGroupRepository groups = DemoGroupRepository();
      final group = (await groups.findById('demo-group-1'))!;

      expect(
        await groups.isMember(groupId: group.id, userId: 'demo-student'),
        isFalse,
      );

      final request = await groups.requestToJoin(
        group: group,
        studentId: 'demo-student',
        studentName: 'طالب تجريبي',
      );
      await groups.decideJoinRequest(
        request: request,
        teacherId: group.teacherId,
        approve: true,
      );

      expect(
        await groups.isMember(groupId: group.id, userId: 'demo-student'),
        isTrue,
      );
    });
  });
}
