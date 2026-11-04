import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_message.dart';
import 'package:teacher_student_app/data/models/notification_page.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/validation/group_unread_rules.dart';
import 'package:teacher_student_app/data/validation/notification_rules.dart';

/// اختبارات P32 — السلوك الحقيقي للطبقة التجريبية (نفس عقود Firestore).
///
/// **لماذا الوضع التجريبي؟** لأن التواريخ والأحداث فيه حقيقية والتأثير واحد:
/// ما يُختبر هنا هو منطق التطبيق (من يُشعَر، ومتى، وبكم إشعار)، لا Firebase.
/// أما **الأمان** (من يحق له الكتابة) فتُثبته اختبارات المحاذي في
/// `tool/rules_tests` على القواعد نفسها.

AppNotification _notification({
  required String id,
  required String recipientId,
  required String targetId,
  required DateTime createdAt,
  NotificationType type = NotificationType.directMessage,
  DateTime? readAt,
}) {
  return AppNotification(
    id: id,
    recipientId: recipientId,
    type: type,
    actorId: 'other',
    actorName: 'طرف آخر',
    targetId: targetId,
    title: 'إشعار $id',
    createdAt: createdAt,
    readAt: readAt,
  );
}

Future<BookingRequest> _createPending(
  DemoBookingRepository bookings, {
  DateTime? startsAt,
}) {
  final DateTime base = startsAt ?? DateTime.now().add(const Duration(days: 4));
  final DateTime slot = DateTime(base.year, base.month, base.day, 18);
  return bookings.createRequest(
    teacherId: 'demo-teacher-1',
    teacherName: 'أ. سارة الخطيب',
    studentId: 'demo-student',
    studentName: 'طالب تجريبي',
    subject: 'الرياضيات',
    startsAt: slot,
    durationMinutes: 60,
  );
}

void main() {
  group('P32 — نصوص الأنواع الجديدة', () {
    test('إلغاء الحجز: العنوان يسمّي من ألغى، والنص يوضّح الموعد', () {
      expect(
        NotificationRules.titleFor(
          type: NotificationType.bookingCancelled,
          actorName: 'طالب تجريبي',
        ),
        contains('طالب تجريبي'),
      );
      expect(
        NotificationRules.bodyFor(
          type: NotificationType.bookingCancelled,
          actorName: 'طالب تجريبي',
          slotLabel: 'السبت ٦ م',
        ),
        contains('السبت ٦ م'),
      );
    });

    test('قرار الإدارة: نص واضح لكل قرار، وسبب الرفض مذكور ومقصوص', () {
      expect(
        NotificationRules.bodyFor(
          type: NotificationType.teacherApproved,
          actorName: 'إدارة المنصة',
        ),
        isNotEmpty,
      );
      final String withReason = NotificationRules.bodyFor(
        type: NotificationType.teacherRejected,
        actorName: 'إدارة المنصة',
        subject: 'بيانات التواصل داخل النبذة',
      );
      expect(withReason, contains('بيانات التواصل داخل النبذة'));

      // سبب طويل لا يجعل النص يتجاوز حدّ القاعدة (200).
      final String long = NotificationRules.bodyFor(
        type: NotificationType.teacherRejected,
        actorName: 'إدارة المنصة',
        subject: 'ط' * 200,
      );
      expect(long.length, lessThanOrEqualTo(NotificationRules.bodyMax));
    });

    test('كل نوع جديد له وجهة صحيحة', () {
      expect(
        NotificationType.bookingCancelled.target,
        NotificationTarget.booking,
      );
      expect(
        NotificationType.teacherApproved.target,
        NotificationTarget.teacherProfile,
      );
      expect(
        NotificationType.teacherRejected.target,
        NotificationTarget.teacherProfile,
      );
    });
  });

  group('P32 — إشعار إلغاء الحجز', () {
    test('إلغاء الطالب يُشعر المدرس مرة واحدة', () async {
      final DemoNotificationRepository notifications =
          DemoNotificationRepository(source: <AppNotification>[]);
      final DemoBookingRepository bookings = DemoBookingRepository(
        notifications: notifications,
        source: <BookingRequest>[],
      );
      final BookingRequest request = await _createPending(bookings);

      await bookings.cancelRequest(
        request: request,
        actorId: 'demo-student',
        byTeacher: false,
      );

      final List<AppNotification> teacherInbox =
          await notifications.listMine('demo-teacher-1');
      final List<AppNotification> cancelled = teacherInbox
          .where(
            (AppNotification n) => n.type == NotificationType.bookingCancelled,
          )
          .toList();
      expect(cancelled.length, 1);
      expect(cancelled.single.targetId, request.id);
      expect(cancelled.single.target, NotificationTarget.booking);
      // لا إشعار للمنشئ نفسه.
      expect(
        (await notifications.listMine('demo-student'))
            .where(
              (AppNotification n) =>
                  n.type == NotificationType.bookingCancelled,
            ),
        isEmpty,
      );
    });

    test('إلغاء المدرس يُشعر الطالب', () async {
      final DemoNotificationRepository notifications =
          DemoNotificationRepository(source: <AppNotification>[]);
      final DemoBookingRepository bookings = DemoBookingRepository(
        notifications: notifications,
        source: <BookingRequest>[],
      );
      final BookingRequest request = await _createPending(bookings);
      final BookingRequest accepted = await bookings.decideRequest(
        request: request,
        teacherId: 'demo-teacher-1',
        approve: true,
      );

      await bookings.cancelRequest(
        request: accepted,
        actorId: 'demo-teacher-1',
        byTeacher: true,
      );

      final List<AppNotification> studentInbox = await notifications.listMine(
        'demo-student',
      );
      final List<AppNotification> cancelled = studentInbox
          .where(
            (AppNotification n) => n.type == NotificationType.bookingCancelled,
          )
          .toList();
      expect(cancelled.length, 1);
      expect(cancelled.single.targetId, request.id);
    });

    test('إلغاء مرفوض لا يُنشئ إشعارًا', () async {
      final DemoNotificationRepository notifications =
          DemoNotificationRepository(source: <AppNotification>[]);
      final DemoBookingRepository bookings = DemoBookingRepository(
        notifications: notifications,
        source: <BookingRequest>[],
      );
      final BookingRequest request = await _createPending(bookings);
      await bookings.cancelRequest(
        request: request,
        actorId: 'demo-student',
        byTeacher: false,
      );

      final int before = (await notifications.listMine('demo-teacher-1')).length;

      // إلغاء ثانٍ: الحالة لم تتغيّر ⇒ يُرفض.
      await expectLater(
        bookings.cancelRequest(
          request: request,
          actorId: 'demo-student',
          byTeacher: false,
        ),
        throwsA(isA<AppException>()),
      );

      final int after = (await notifications.listMine('demo-teacher-1')).length;
      expect(after, before, reason: 'لا إشعار جديد لإلغاء لم يحدث');
    });

    test('المعرّف الحتمي يمنع تكرار الإشعار عند إعادة المحاولة', () async {
      final DemoNotificationRepository notifications =
          DemoNotificationRepository(source: <AppNotification>[]);
      final String key = NotificationRules.cancelNotificationId('booking-9');

      final AppNotification first = await notifications.push(
        type: NotificationType.bookingCancelled,
        recipientId: 'demo-teacher-1',
        actorId: 'demo-student',
        actorName: 'طالب',
        targetId: 'booking-9',
        dedupeId: key,
      );
      final AppNotification second = await notifications.push(
        type: NotificationType.bookingCancelled,
        recipientId: 'demo-teacher-1',
        actorId: 'demo-student',
        actorName: 'طالب',
        targetId: 'booking-9',
        dedupeId: key,
      );

      expect(second.id, first.id);
      expect((await notifications.listMine('demo-teacher-1')).length, 1);
    });
  });

  group('P32 — إشعار قرار التوثيق', () {
    test('الاعتماد يُشعر المدرس، والرفض يُشعره مرة أخرى', () async {
      final DemoNotificationRepository notifications =
          DemoNotificationRepository(source: <AppNotification>[]);
      final List<TeacherProfile> profiles = <TeacherProfile>[
        ...DemoData.teachers,
      ];
      final DemoAdminRepository admin = DemoAdminRepository(
        profiles: profiles,
        notifications: notifications,
      );

      await admin.verifyTeacher('demo-teacher-6-review');
      List<AppNotification> inbox = await notifications.listMine(
        'demo-teacher-6-review',
      );
      expect(inbox.length, 1);
      expect(inbox.single.type, NotificationType.teacherApproved);
      expect(inbox.single.target, NotificationTarget.teacherProfile);

      // قرار الإدارة نفسه مرة أخرى: الحالة لم تتغيّر ⇒ لا إشعار ثانٍ.
      await admin.verifyTeacher('demo-teacher-6-review');
      inbox = await notifications.listMine('demo-teacher-6-review');
      expect(inbox.length, 1);

      // رفض جديد: قرار مختلف يستحق إشعارًا مختلفًا.
      await admin.rejectTeacher(
        teacherId: 'demo-teacher-6-review',
        reason: 'بيانات ناقصة في الملف',
      );
      inbox = await notifications.listMine('demo-teacher-6-review');
      expect(inbox.length, 2);
      expect(
        inbox
            .singleWhere((n) => n.type == NotificationType.teacherRejected)
            .body,
        contains('بيانات ناقصة في الملف'),
      );
    });

    test('تعديل بيانات بلا قرار لا يُنشئ إشعارًا', () async {
      final DemoNotificationRepository notifications =
          DemoNotificationRepository(source: <AppNotification>[]);
      final DemoAdminRepository admin = DemoAdminRepository(
        profiles: <TeacherProfile>[...DemoData.teachers],
        notifications: notifications,
      );

      // لا مسار «تعديل» في مستودع الإدارة سوى القرار؛ نتحقق أن قائمة الطابور
      // وحدها (قراءة) لا تكتب إشعارًا.
      await admin.listVerificationQueue();
      await admin.listAllProfiles();
      expect(await notifications.listMine('demo-teacher-6-review'), isEmpty);
    });
  });

  group('P32 — تعليم إشعارات محادثة واحدة', () {
    test('يُعلّم رسائل المحادثة المعنية فقط، ويترك غيرها', () async {
      final DateTime base = DateTime(2026, 10, 27, 9);
      final DemoNotificationRepository notifications =
          DemoNotificationRepository(
            source: <AppNotification>[
              _notification(
                id: 'chat-a',
                recipientId: 'demo-student',
                targetId: 'chat-a',
                createdAt: base,
              ),
              _notification(
                id: 'chat-a-2',
                recipientId: 'demo-student',
                targetId: 'chat-a',
                createdAt: base.subtract(const Duration(minutes: 1)),
              ),
              _notification(
                id: 'chat-b',
                recipientId: 'demo-student',
                targetId: 'chat-b',
                createdAt: base.subtract(const Duration(minutes: 2)),
              ),
              _notification(
                id: 'booking',
                recipientId: 'demo-student',
                targetId: 'chat-a',
                type: NotificationType.bookingCancelled,
                createdAt: base.subtract(const Duration(minutes: 3)),
              ),
              _notification(
                id: 'other-user',
                recipientId: 'demo-teacher-1',
                targetId: 'chat-a',
                createdAt: base.subtract(const Duration(minutes: 4)),
              ),
            ],
          );

      final int changed = await notifications.markChatMessagesRead(
        recipientId: 'demo-student',
        chatId: 'chat-a',
      );
      expect(changed, 2);

      final List<AppNotification> mine = await notifications.listMine(
        'demo-student',
      );
      expect(
        mine.singleWhere((n) => n.id == 'chat-a').isRead,
        isTrue,
        reason: 'إشعار المحادثة المفتوحة يُعلَّم مقروءًا',
      );
      expect(mine.singleWhere((n) => n.id == 'chat-a-2').isRead, isTrue);
      expect(
        mine.singleWhere((n) => n.id == 'chat-b').isRead,
        isFalse,
        reason: 'محادثة أخرى لا تتأثر',
      );
      expect(
        mine.singleWhere((n) => n.id == 'booking').isRead,
        isFalse,
        reason: 'إشعار حجز لا يُعلَّم مقروءًا بفتح محادثة',
      );
      expect(
        (await notifications.listMine('demo-teacher-1')).single.isRead,
        isFalse,
        reason: 'إشعارات مستخدم آخر لا تُمسّ',
      );

      // نداء ثانٍ: لا شيء غير مقروء ⇒ صفر كتابات.
      expect(
        await notifications.markChatMessagesRead(
          recipientId: 'demo-student',
          chatId: 'chat-a',
        ),
        0,
      );
    });
  });

  group('P32 — تصفّح الإشعارات بالمؤشر', () {
    test('صفحتان بلا فقد ولا تكرار، والعدّاد لا يتأثر', () async {
      final DateTime base = DateTime(2026, 10, 27, 12);
      final List<AppNotification> source = <AppNotification>[
        for (int i = 0; i < 25; i++)
          _notification(
            id: 'n${i.toString().padLeft(2, '0')}',
            recipientId: 'demo-student',
            targetId: 'chat-a',
            createdAt: base.subtract(Duration(minutes: i)),
          ),
      ];
      final DemoNotificationRepository notifications =
          DemoNotificationRepository(source: source);

      final NotificationPage first = await notifications.listPage(
        recipientId: 'demo-student',
        limit: 20,
      );
      expect(first.items.length, 20);
      expect(first.hasMore, isTrue);

      final NotificationPage second = await notifications.listPage(
        recipientId: 'demo-student',
        limit: 20,
        before: first.items.last.createdAt,
        beforeId: first.items.last.id,
      );
      expect(second.items.length, 5);
      expect(second.hasMore, isFalse);

      final List<String> ids = <String>[
        ...first.items.map((AppNotification n) => n.id),
        ...second.items.map((AppNotification n) => n.id),
      ];
      expect(ids.toSet().length, ids.length, reason: 'لا تكرار بين الصفحتين');
      expect(ids.length, 25, reason: 'لا فقد: كل الإشعارات وصلت');
      // الترتيب الزمني الصحيح عبر الصفحتين.
      expect(ids, NotificationRules.newestFirst(source).map((n) => n.id).toList());

      // العدّاد مستقل: قراءة صفحة لم تُعلّم شيئًا مقروءًا.
      expect(await notifications.watchUnreadCount('demo-student').first, 25);
    });

    test('تساوي الوقت لا يُسقط إشعارًا (مؤشر مركّب)', () async {
      final DateTime same = DateTime(2026, 10, 27, 12);
      final List<AppNotification> source = <AppNotification>[
        _notification(
          id: 'a',
          recipientId: 'demo-student',
          targetId: 'c',
          createdAt: same,
        ),
        _notification(
          id: 'b',
          recipientId: 'demo-student',
          targetId: 'c',
          createdAt: same,
        ),
        _notification(
          id: 'c',
          recipientId: 'demo-student',
          targetId: 'c',
          createdAt: same,
        ),
        _notification(
          id: 'd',
          recipientId: 'demo-student',
          targetId: 'c',
          createdAt: same.subtract(const Duration(minutes: 1)),
        ),
      ];
      final DemoNotificationRepository notifications =
          DemoNotificationRepository(source: source);

      final NotificationPage first = await notifications.listPage(
        recipientId: 'demo-student',
        limit: 2,
      );
      final NotificationPage second = await notifications.listPage(
        recipientId: 'demo-student',
        limit: 4,
        before: first.items.last.createdAt,
        beforeId: first.items.last.id,
      );

      final List<String> ids = <String>[
        ...first.items.map((AppNotification n) => n.id),
        ...second.items.map((AppNotification n) => n.id),
      ];
      expect(ids, <String>['a', 'b', 'c', 'd']);
    });
  });

  group('P32 — غير المقروء في محادثة المجموعة', () {
    GroupMessage message({
      required String id,
      required String senderId,
      required DateTime sentAt,
    }) {
      return GroupMessage(
        id: id,
        groupId: 'g1',
        senderId: senderId,
        senderName: senderId,
        senderRole: UserRole.student,
        text: 'رسالة $id',
        sentAt: sentAt,
      );
    }

    test('القواعد النقية: رسائلي ليست غير مقروءة، والغياب يعني الكل', () {
      final DateTime base = DateTime(2026, 10, 27, 12);
      final List<GroupMessage> messages = <GroupMessage>[
        message(id: 'm1', senderId: 'teacher-1', sentAt: base),
        message(
          id: 'm2',
          senderId: 'student-1',
          sentAt: base.add(const Duration(minutes: 1)),
        ),
        message(
          id: 'm3',
          senderId: 'teacher-1',
          sentAt: base.add(const Duration(minutes: 2)),
        ),
      ];

      expect(
        GroupUnreadRules.countUnread(
          messages: messages,
          memberId: 'student-1',
          lastReadAt: null,
        ),
        2,
        reason: 'رسالتا المدرس فقط قبل أي قراءة',
      );
      expect(
        GroupUnreadRules.countUnread(
          messages: messages,
          memberId: 'student-1',
          lastReadAt: base,
        ),
        1,
        reason: 'm3 وحدها بعد علامة القراءة',
      );
      expect(GroupUnreadRules.badgeLabel(0), isNull);
      expect(GroupUnreadRules.badgeLabel(3), '3');
      expect(GroupUnreadRules.badgeLabel(12), '9+');
    });

    test('العدّاد منفصل لكل عضو، والتعليم لا يمسّ زميلًا', () async {
      final DateTime base = DateTime(2026, 10, 27, 12);
      final DemoMessageRepository messages = DemoMessageRepository(
        source: <GroupMessage>[
          message(id: 'm1', senderId: 'teacher-1', sentAt: base),
          message(
            id: 'm2',
            senderId: 'teacher-1',
            sentAt: base.add(const Duration(minutes: 1)),
          ),
        ],
      );

      expect(
        await messages.unreadCount(groupId: 'g1', memberId: 'student-1'),
        2,
      );
      expect(
        await messages.unreadCount(groupId: 'g1', memberId: 'student-2'),
        2,
      );

      // الطالب الأول يفتح المحادثة ⇒ عدّاده صفر، وعدّاد زميله كما هو.
      await messages.markRead(groupId: 'g1', memberId: 'student-1');
      expect(
        await messages.unreadCount(groupId: 'g1', memberId: 'student-1'),
        0,
      );
      expect(
        await messages.unreadCount(groupId: 'g1', memberId: 'student-2'),
        2,
      );

      // رسالة جديدة بعد القراءة تظهر للأول وللثاني (الأول بلا غير مقروء).
      await messages.sendMessage(
        groupId: 'g1',
        senderId: 'teacher-1',
        senderName: 'أ. سارة',
        senderRole: UserRole.teacher,
        text: 'تذكير بالواجب',
      );
      expect(
        await messages.unreadCount(groupId: 'g1', memberId: 'student-1'),
        1,
      );
      expect(
        await messages.unreadCount(groupId: 'g1', memberId: 'student-2'),
        3,
      );

      // عضو آخر تمامًا في مجموعة أخرى لا يتأثر.
      expect(
        await messages.unreadCount(groupId: 'g2', memberId: 'student-1'),
        0,
      );
    });
  });
}
