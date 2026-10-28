import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/group_waitlist_entry.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/validation/notification_rules.dart';

AppNotification _item({
  required String id,
  required DateTime createdAt,
  DateTime? readAt,
  NotificationType type = NotificationType.directMessage,
  String title = 'إشعار',
}) {
  return AppNotification(
    id: id,
    recipientId: 'student-1',
    type: type,
    actorId: 'teacher-1',
    actorName: 'أ. سارة',
    targetId: 'chat-1',
    title: title,
    createdAt: createdAt,
    readAt: readAt,
  );
}

void main() {
  group('أنواع الإشعار ووجهاتها', () {
    test('كل نوع له اسم متجر ووجهة معروفة', () {
      expect(
        NotificationType.bookingRequested.wireName,
        'bookingRequested',
      );
      expect(
        NotificationType.bookingRequested.target,
        NotificationTarget.booking,
      );
      expect(NotificationType.bookingAccepted.target, NotificationTarget.booking);
      expect(NotificationType.bookingRejected.target, NotificationTarget.booking);
      expect(
        NotificationType.rescheduleProposed.target,
        NotificationTarget.booking,
      );
      expect(NotificationType.directMessage.target, NotificationTarget.chat);
      expect(NotificationType.waitlistPromoted.target, NotificationTarget.group);
    });

    test('التحويل من نص المتجر ذهابًا وإيابًا', () {
      for (final NotificationType type in NotificationType.values) {
        expect(NotificationType.parse(type.wireName), type);
      }
    });

    test('نوع غير معروف لا يُسقط الإشعار', () {
      expect(NotificationType.parse('somethingNew'), isA<NotificationType>());
      expect(NotificationType.parse(null), NotificationType.bookingRequested);
      expect(NotificationTarget.parse('chat'), NotificationTarget.chat);
      expect(NotificationTarget.parse('???'), NotificationTarget.booking);
    });
  });

  group('نصوص الإشعار', () {
    test('العنوان يذكر المُحدِث', () {
      expect(
        NotificationRules.titleFor(
          type: NotificationType.bookingRequested,
          actorName: 'طالب تجريبي',
        ),
        'طلب حجز جديد من طالب تجريبي',
      );
      expect(
        NotificationRules.titleFor(
          type: NotificationType.bookingAccepted,
          actorName: 'أ. سارة',
        ),
        'قبل أ. سارة طلب الحجز',
      );
      // اسم فارغ لا يترك صياغة مكسورة.
      expect(
        NotificationRules.titleFor(
          type: NotificationType.directMessage,
          actorName: '   ',
        ),
        'رسالة جديدة',
      );
    });

    test('النص التفصيلي يذكر المادة أو الموعد', () {
      expect(
        NotificationRules.bodyFor(
          type: NotificationType.bookingRequested,
          actorName: 'طالب',
          subject: 'الرياضيات',
        ),
        contains('الرياضيات'),
      );
      expect(
        NotificationRules.bodyFor(
          type: NotificationType.bookingAccepted,
          actorName: 'أ. سارة',
          slotLabel: 'السبت 6:00 م',
        ),
        contains('السبت 6:00 م'),
      );
    });

    test('التحقق من الطول: عنوان مطلوب وحدود مطابقة للقواعد', () {
      expect(
        NotificationRules.textProblem(title: '  ', actorName: 'طالب'),
        isNotNull,
      );
      expect(
        NotificationRules.textProblem(title: 'ا' * 121, actorName: 'طالب'),
        isNotNull,
      );
      expect(
        NotificationRules.textProblem(title: 'عنوان', actorName: 'طالب', body: 'ب' * 201),
        isNotNull,
      );
      expect(
        NotificationRules.textProblem(
          title: 'عنوان',
          actorName: 'ط' * 81,
        ),
        isNotNull,
      );
      expect(
        NotificationRules.textProblem(
          title: 'عنوان',
          actorName: 'طالب',
          body: 'نص قصير',
        ),
        isNull,
      );
    });

    test('التنظيف يوحّد المسافات', () {
      expect(NotificationRules.normalize('  نص   مكرر '), 'نص مكرر');
      expect(NotificationRules.normalize(null), '');
    });
  });

  group('الترتيب والعدّ', () {
    test('الأحدث أولًا، والترتيب ثابت عند تساوي الوقت', () {
      final List<AppNotification> sorted = NotificationRules.newestFirst(
        <AppNotification>[
          _item(id: 'b', createdAt: DateTime(2026, 10, 20, 10)),
          _item(id: 'a', createdAt: DateTime(2026, 10, 20, 10)),
          _item(id: 'c', createdAt: DateTime(2026, 10, 22, 9)),
        ],
      );
      expect(sorted.map((AppNotification n) => n.id).toList(), <String>['c', 'a', 'b']);
    });

    test('عدّاد غير المقروء يتجاهل المقروء', () {
      final List<AppNotification> items = <AppNotification>[
        _item(id: 'a', createdAt: DateTime(2026, 10, 20)),
        _item(
          id: 'b',
          createdAt: DateTime(2026, 10, 21),
          readAt: DateTime(2026, 10, 21, 1),
        ),
      ];
      expect(NotificationRules.unreadCount(items), 1);
      expect(items[1].isRead, isTrue);
      expect(items[0].isRead, isFalse);
    });

    test('تعليم القراءة يُبقي بقية الحقول كما هي', () {
      final AppNotification item = _item(
        id: 'a',
        createdAt: DateTime(2026, 10, 20),
      );
      final AppNotification read = item.copyWith(readAt: DateTime(2026, 10, 20, 9));
      expect(read.isRead, isTrue);
      expect(read.title, item.title);
      expect(read.targetId, 'chat-1');
      expect(read.type, NotificationType.directMessage);
    });
  });

  group('الوقت النسبي', () {
    final DateTime now = DateTime(2026, 10, 28, 15);

    test('من أقل من دقيقة إلى ساعات', () {
      expect(
        NotificationRules.relativeTime(now.subtract(const Duration(seconds: 20)), now: now),
        'الآن',
      );
      expect(
        NotificationRules.relativeTime(now.subtract(const Duration(minutes: 7)), now: now),
        'قبل 7 دقيقة',
      );
      expect(
        NotificationRules.relativeTime(now.subtract(const Duration(hours: 3)), now: now),
        'قبل 3 ساعة',
      );
    });

    test('أمس وما قبله ثم تاريخ صريح', () {
      expect(
        NotificationRules.relativeTime(DateTime(2026, 10, 27, 22), now: now),
        'أمس',
      );
      expect(
        NotificationRules.relativeTime(DateTime(2026, 10, 25, 10), now: now),
        'قبل 3 أيام',
      );
      expect(
        NotificationRules.relativeTime(DateTime(2026, 9, 30, 10), now: now),
        '30/09/2026',
      );
    });

    test('وقت في المستقبل لا يظهر كرقم سالب', () {
      expect(
        NotificationRules.relativeTime(now.add(const Duration(hours: 2)), now: now),
        'الآن',
      );
    });
  });

  group('الربط مع أفعال التطبيق (P12)', () {
    test('طلب حجز جديد يُنشئ إشعارًا للمدرس', () async {
      final DemoNotificationRepository notifications =
          DemoNotificationRepository(source: <AppNotification>[]);
      final DemoBookingRepository bookings = DemoBookingRepository(
        notifications: notifications,
        source: <BookingRequest>[],
      );

      final DateTime start = DateTime.now().add(const Duration(days: 3));
      final DateTime slot = DateTime(start.year, start.month, start.day, 18);

      await bookings.createRequest(
        teacherId: 'demo-teacher-1',
        teacherName: 'أ. سارة الخطيب',
        studentId: 'demo-student',
        studentName: 'طالب تجريبي',
        subject: 'الرياضيات',
        startsAt: slot,
        durationMinutes: 60,
      );

      final List<AppNotification> teacherInbox = await notifications.listMine(
        'demo-teacher-1',
      );
      expect(teacherInbox.length, 1);
      expect(teacherInbox.single.type, NotificationType.bookingRequested);
      expect(teacherInbox.single.actorId, 'demo-student');
      expect(teacherInbox.single.target, NotificationTarget.booking);
      // ولا شيء للطالب نفسه: لا إشعار لفاعل الفعل.
      expect(await notifications.listMine('demo-student'), isEmpty);
    });

    test('رسالة مباشرة تُنشئ إشعارًا للطرف الآخر', () async {
      final DemoNotificationRepository notifications =
          DemoNotificationRepository(source: <AppNotification>[]);
      final DemoDirectChatRepository chats = DemoDirectChatRepository(
        notifications: notifications,
      );
      final String chatId = DirectChat.idFor(
        teacherId: 'demo-teacher-1',
        studentId: 'demo-student',
      );

      await chats.sendMessage(
        chatId: chatId,
        senderId: 'demo-student',
        senderName: 'طالب تجريبي',
        senderRole: UserRole.student,
        text: 'سؤال سريع',
      );

      final List<AppNotification> teacherInbox = await notifications.listMine(
        'demo-teacher-1',
      );
      expect(teacherInbox.length, 1);
      expect(teacherInbox.single.type, NotificationType.directMessage);
      expect(teacherInbox.single.targetId, chatId);
      expect(teacherInbox.single.target, NotificationTarget.chat);
    });

    test('قبول منتظر يُنشئ إشعار ترقية للطالب', () async {
      final DemoNotificationRepository notifications =
          DemoNotificationRepository(source: <AppNotification>[]);
      final DemoGroupRepository groups = DemoGroupRepository(
        notifications: notifications,
      );

      final List<GroupWaitlistEntry> waiting = await groups.listWaitlist(
        'demo-group-5',
        teacherId: 'demo-teacher-1',
      );
      expect(waiting, isNotEmpty);

      await groups.promoteFromWaitlist(
        entry: waiting.first,
        teacherId: 'demo-teacher-1',
      );

      final List<AppNotification> studentInbox = await notifications.listMine(
        waiting.first.studentId,
      );
      expect(studentInbox.length, 1);
      expect(studentInbox.single.type, NotificationType.waitlistPromoted);
      expect(studentInbox.single.targetId, 'demo-group-5');
    });
  });
}
