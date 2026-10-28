import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/validation/direct_chat_rules.dart';

/// اختبارات قواعد المحادثة المباشرة (P11) — **دوال نقية، بلا شبكة**.
///
/// كل حالة هنا تقابل شرطًا في `firestore.rules`؛ الهدف إثبات أن الواجهة تعرض
/// نفس الحدّ الذي يفرضه الخادم بدل أن تسمح ثم تُرفض.
DirectChat _chat({
  DirectChatOrigin origin = DirectChatOrigin.booking,
  String studentId = 'student-1',
  String teacherId = 'teacher-1',
  DateTime? lastMessageAt,
  String? lastSenderId,
  DateTime? studentLastReadAt,
  DateTime? teacherLastReadAt,
  String? bookingId = 'booking-1',
}) {
  return DirectChat(
    id: DirectChat.idFor(teacherId: teacherId, studentId: studentId),
    teacherId: teacherId,
    teacherName: 'أ. سارة الخطيب',
    studentId: studentId,
    studentName: 'طالب تجريبي',
    origin: origin,
    bookingId: origin == DirectChatOrigin.booking ? bookingId : null,
    createdAt: DateTime(2026, 10, 20, 9),
    lastMessageAt: lastMessageAt,
    lastSenderId: lastSenderId,
    studentLastReadAt: studentLastReadAt,
    teacherLastReadAt: teacherLastReadAt,
  );
}

void main() {
  group('معرّف المحادثة', () {
    test('مشتق من الطرفين ولا يعتمد على ترتيبهما', () {
      expect(
        DirectChat.idFor(teacherId: 'teacher-1', studentId: 'student-1'),
        'teacher-1_student-1',
      );
    });

    test('الطرفان فقط يُعتبران ضمن المحادثة', () {
      final DirectChat chat = _chat();
      expect(chat.involves('teacher-1'), isTrue);
      expect(chat.involves('student-1'), isTrue);
      expect(chat.involves('stranger-9'), isFalse);
      expect(chat.involves(null), isFalse);
      expect(chat.involves(''), isFalse);
    });

    test('عرض الطرف الآخر يتبع دور القارئ', () {
      final DirectChat chat = _chat();
      expect(chat.partnerNameFor('teacher-1'), 'طالب تجريبي');
      expect(chat.partnerNameFor('student-1'), 'أ. سارة الخطيب');
      expect(chat.partnerIdFor('teacher-1'), 'student-1');
      expect(chat.partnerIdFor('student-1'), 'teacher-1');
    });
  });

  group('خصوصية المدرس (A-78)', () {
    test('القيمة الافتراضية متشدّدة', () {
      expect(DirectChatRules.defaultAllowDirectMessages, isFalse);
    });

    test('الاستفسار مسموح فقط عند تفعيل الخيار', () {
      expect(
        DirectChatRules.startBlockedReason(
          viewerId: 'student-1',
          hasBooking: false,
          isGroupMember: false,
          allowDirectMessages: false,
        ),
        isNotNull,
      );
      expect(
        DirectChatRules.startBlockedReason(
          viewerId: 'student-1',
          hasBooking: false,
          isGroupMember: false,
          allowDirectMessages: true,
        ),
        isNull,
      );
    });

    test('الحجز القائم أو العضوية يتجاوزان إغلاق الخيار', () {
      expect(
        DirectChatRules.startBlockedReason(
          viewerId: 'student-1',
          hasBooking: true,
          isGroupMember: false,
          allowDirectMessages: false,
        ),
        isNull,
      );
      expect(
        DirectChatRules.startBlockedReason(
          viewerId: 'student-1',
          hasBooking: false,
          isGroupMember: true,
          allowDirectMessages: false,
        ),
        isNull,
      );
    });

    test('غير المسجّل لا يبدأ محادثة', () {
      expect(
        DirectChatRules.startBlockedReason(
          viewerId: null,
          hasBooking: true,
          isGroupMember: true,
          allowDirectMessages: true,
        ),
        isNotNull,
      );
    });

    test('الأصل المختار يفضّل الحجز ثم المجموعة', () {
      expect(
        DirectChatRules.originFor(hasBooking: true, isGroupMember: true),
        DirectChatOrigin.booking,
      );
      expect(
        DirectChatRules.originFor(hasBooking: false, isGroupMember: true),
        DirectChatOrigin.group,
      );
      expect(
        DirectChatRules.originFor(hasBooking: false, isGroupMember: false),
        DirectChatOrigin.inquiry,
      );
    });
  });

  group('منع الإرسال', () {
    test('المحادثة المفتوحة تسمح للطرفين', () {
      final DirectChat chat = _chat();
      expect(
        DirectChatRules.sendBlockedReason(
          chat: chat,
          viewerId: 'student-1',
          allowDirectMessages: false,
        ),
        isNull,
      );
      // خيط الحجز لا يعتمد على خيار الاستفسار.
      expect(
        DirectChatRules.sendBlockedReason(
          chat: chat,
          viewerId: 'teacher-1',
          allowDirectMessages: false,
        ),
        isNull,
      );
    });

    test('الغريب ممنوع من الإرسال والقراءة', () {
      final DirectChat chat = _chat();
      expect(
        DirectChatRules.sendBlockedReason(
          chat: chat,
          viewerId: 'stranger-9',
          allowDirectMessages: true,
        ),
        isNotNull,
      );
      expect(DirectChatRules.canView(chat: chat, viewerId: 'stranger-9'), false);
    });

    test('رفض الحجز يوقف الإرسال', () {
      final DirectChat chat = _chat();
      expect(
        DirectChatRules.sendBlockedReason(
          chat: chat,
          viewerId: 'student-1',
          allowDirectMessages: true,
          bookingRejected: true,
        ),
        isNotNull,
      );
    });

    test('إيقاف الاستفسار يمنع الإرسال في خيط الاستفسار وحده', () {
      final DirectChat inquiry = _chat(origin: DirectChatOrigin.inquiry);
      expect(
        DirectChatRules.sendBlockedReason(
          chat: inquiry,
          viewerId: 'student-1',
          allowDirectMessages: false,
        ),
        isNotNull,
      );
      expect(
        DirectChatRules.sendBlockedReason(
          chat: inquiry,
          viewerId: 'student-1',
          allowDirectMessages: true,
        ),
        isNull,
      );
      // العضوية لا تتأثر بالخيار.
      final DirectChat group = _chat(origin: DirectChatOrigin.group);
      expect(
        DirectChatRules.sendBlockedReason(
          chat: group,
          viewerId: 'student-1',
          allowDirectMessages: false,
        ),
        isNull,
      );
    });
  });

  group('المقروء', () {
    test('رسالة الطرف الآخر غير المقروءة تُعلَّم جديدة', () {
      final DirectChat chat = _chat(
        lastMessageAt: DateTime(2026, 10, 20, 12),
        lastSenderId: 'teacher-1',
      );
      expect(chat.hasUnreadFor('student-1'), isTrue);
      expect(chat.hasUnreadFor('teacher-1'), isFalse);
    });

    test('قراءة أحدث من الرسالة تُلغي الإشعار', () {
      final DirectChat chat = _chat(
        lastMessageAt: DateTime(2026, 10, 20, 12),
        lastSenderId: 'teacher-1',
        studentLastReadAt: DateTime(2026, 10, 20, 12, 5),
      );
      expect(chat.hasUnreadFor('student-1'), isFalse);
    });

    test('قراءة أقدم من الرسالة لا تُلغيها', () {
      final DirectChat chat = _chat(
        lastMessageAt: DateTime(2026, 10, 20, 12),
        lastSenderId: 'teacher-1',
        studentLastReadAt: DateTime(2026, 10, 20, 11, 59),
      );
      expect(chat.hasUnreadFor('student-1'), isTrue);
    });

    test('الغريب لا يرى أي غير مقروء', () {
      final DirectChat chat = _chat(
        lastMessageAt: DateTime(2026, 10, 20, 12),
        lastSenderId: 'teacher-1',
      );
      expect(chat.hasUnreadFor('stranger-9'), isFalse);
    });

    test('«مقروء» تظهر على رسالتي حين قرأها الطرف الآخر', () {
      final DirectChat chat = _chat(
        teacherLastReadAt: DateTime(2026, 10, 20, 12, 30),
      );
      final DirectChatMessage mine = DirectChatMessage(
        id: 'm1',
        chatId: chat.id,
        senderId: 'student-1',
        senderName: 'طالب',
        senderRole: UserRole.student,
        text: 'مرحبًا',
        sentAt: DateTime(2026, 10, 20, 12),
      );
      expect(
        mine.isReadByPartner(
          chat.partnerLastReadAtFor('student-1'),
          'student-1',
        ),
        isTrue,
      );
      expect(
        mine.isReadByPartner(
          chat.partnerLastReadAtFor('teacher-1'),
          'teacher-1',
        ),
        isFalse,
      );
    });
  });

  group('العرض العربي', () {
    test('تسميات الأصل', () {
      expect(DirectChatOrigin.booking.label, 'مرتبطة بحجز');
      expect(DirectChatOrigin.group.label, 'عضو مجموعة');
      expect(DirectChatOrigin.inquiry.label, 'استفسار قبل الحجز');
      expect(DirectChatOrigin.parse('group'), DirectChatOrigin.group);
      expect(DirectChatOrigin.parse('غير معروف'), DirectChatOrigin.inquiry);
    });

    test('الوقت بنظام 12 ساعة', () {
      expect(DirectChatRules.timeLabel(DateTime(2026, 10, 20, 9, 5)), '9:05 ص');
      expect(
        DirectChatRules.timeLabel(DateTime(2026, 10, 20, 21, 30)),
        '9:30 م',
      );
      expect(
        DirectChatRules.timeLabel(DateTime(2026, 10, 20, 12, 0)),
        '12:00 م',
      );
      expect(DirectChatRules.timeLabel(DateTime(2026, 10, 20, 0, 7)), '12:07 ص');
    });

    test('فاصل اليوم', () {
      final DateTime now = DateTime(2026, 10, 28, 15);
      expect(
        DirectChatRules.dayLabel(DateTime(2026, 10, 28, 9), now: now),
        'اليوم',
      );
      expect(
        DirectChatRules.dayLabel(DateTime(2026, 10, 27, 9), now: now),
        'أمس',
      );
      expect(
        DirectChatRules.dayLabel(DateTime(2026, 10, 20, 9), now: now),
        '20/10/2026',
      );
    });

    test('الفواصل تظهر عند تغيّر اليوم فقط', () {
      DirectChatMessage at(int day, String id) => DirectChatMessage(
        id: id,
        chatId: 'chat',
        senderId: 's',
        senderName: 'طالب',
        senderRole: UserRole.student,
        text: 'نص',
        sentAt: DateTime(2026, 10, day, 10),
      );
      final List<DirectChatMessage> messages = <DirectChatMessage>[
        at(20, 'a'),
        at(20, 'b'),
        at(21, 'c'),
      ];
      expect(DirectChatRules.startsNewDay(messages, 0), isTrue);
      expect(DirectChatRules.startsNewDay(messages, 1), isFalse);
      expect(DirectChatRules.startsNewDay(messages, 2), isTrue);
    });

    test('تنظيف النص يوحّد المسافات', () {
      expect(DirectChatRules.normalize('  مرحبًا   بك '), 'مرحبًا بك');
      expect(DirectChatRules.normalize(null), '');
    });
  });
}
