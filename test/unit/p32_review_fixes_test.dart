import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/group_message.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/validation/chat_read_marker.dart';
import 'package:teacher_student_app/data/validation/group_unread_rules.dart';

/// اختبارات إصلاحين من مراجعة P32:
///
/// * **إصلاح 1:** عدّ غير المقروء في محادثة المجموعة — الفرق بين عددين
///   يحسبهما الخادم، لا قراءة 10 رسائل ثم استبعاد رسائلي على العميل.
/// * **إصلاح 3:** إعادة محاولة تعليم إشعارات المحادثة بعد فشلها، دون تكرار
///   الكتابة في كل بناء.
///
/// الاختبارات هنا على **المنطق النقي** وعلى **الوضع التجريبي** (نفس العقود
/// ونفس الصيغة). أما تنفيذ Firestore نفسه فتُغطّيه اختبارات المحاكي في
/// `tool/rules_tests/tests/p32_firestore_queries.test.mjs`.

GroupMessage _message({
  required String id,
  required String senderId,
  required DateTime sentAt,
  String groupId = 'g1',
}) {
  return GroupMessage(
    id: id,
    groupId: groupId,
    senderId: senderId,
    senderName: senderId,
    senderRole: UserRole.student,
    text: 'رسالة $id',
    sentAt: sentAt,
  );
}

void main() {
  group('إصلاح 1 — العدّاد لا يُخفي رسائل غير مقروءة بسبب سقف القراءة', () {
    test('10 رسائل لي ثم رسالة واحدة من غيري ⇒ 1، وليس صفرًا', () {
      // هذا هو السيناريو الذي كان يُظهر «0»: السقف القديم (10) يُستهلك برسائلي
      // قبل الوصول إلى رسالة العضو الآخر.
      expect(
        GroupUnreadRules.unreadFromCounts(
          totalAfterRead: 11,
          ownAfterRead: 10,
        ),
        1,
      );
      expect(GroupUnreadRules.badgeLabel(1), '1');
    });

    test('رسائل العضو نفسه لا تُحتسب', () {
      expect(
        GroupUnreadRules.unreadFromCounts(
          totalAfterRead: 10,
          ownAfterRead: 10,
        ),
        0,
        reason: 'كل ما بعد آخر قراءة كتبه العضو نفسه',
      );
      expect(GroupUnreadRules.badgeLabel(0), isNull);
    });

    test('عدد الآخرين كاملًا يُعرض، والسقف للعرض فقط (9+)', () {
      expect(
        GroupUnreadRules.unreadFromCounts(
          totalAfterRead: 15,
          ownAfterRead: 0,
        ),
        15,
      );
      expect(GroupUnreadRules.badgeLabel(15), '9+');
    });

    test('لا يصبح الفرق سالبًا لو تغيّرت البيانات بين العدّين', () {
      expect(
        GroupUnreadRules.unreadFromCounts(
          totalAfterRead: 3,
          ownAfterRead: 5,
        ),
        0,
      );
    });

    test('الوضع التجريبي: 10 رسائل لي بعد القراءة ثم رسالة من زميل ⇒ 1', () async {
      // الوضع التجريبي لا يملك ساعة قابلة للحقن، فنجعل رسائل الحالة **بعد**
      // لحظة التعليم: التعليم يضع `lastReadAt = الآن`، والرسائل أبعد منه.
      final DateTime after = DateTime.now().add(const Duration(minutes: 1));
      final List<GroupMessage> source = <GroupMessage>[
        for (int i = 0; i < 10; i++)
          _message(
            id: 'mine-$i',
            senderId: 'student-1',
            sentAt: after.add(Duration(seconds: i)),
          ),
        _message(
          id: 'other-1',
          senderId: 'teacher-1',
          sentAt: after.add(const Duration(seconds: 30)),
        ),
      ];
      final DemoMessageRepository messages = DemoMessageRepository(
        source: source,
      );

      await messages.markRead(groupId: 'g1', memberId: 'student-1');
      expect(
        await messages.lastReadAt(groupId: 'g1', memberId: 'student-1'),
        isNotNull,
      );

      final int unread = await messages.unreadCount(
        groupId: 'g1',
        memberId: 'student-1',
      );
      expect(unread, 1, reason: 'رسالة الزميل وحدها، لا صفر');
      expect(GroupUnreadRules.badgeLabel(unread), '1');

      // زميل لم يقرأ شيئًا: كل رسائلي العشر ورسالة الزميل غير مقروءة عنده.
      expect(
        await messages.unreadCount(groupId: 'g1', memberId: 'student-2'),
        11,
      );
    });

    test('رسائلي لا تُحتسب، وقراءة المجموعة تحدّث علامتي وحدها', () async {
      final DateTime after = DateTime.now().add(const Duration(minutes: 1));
      final DemoMessageRepository messages = DemoMessageRepository(
        source: <GroupMessage>[
          _message(id: 'mine-1', senderId: 'student-1', sentAt: after),
          _message(
            id: 'other-1',
            senderId: 'teacher-1',
            sentAt: after.add(const Duration(minutes: 1)),
          ),
          _message(
            id: 'other-2',
            senderId: 'teacher-1',
            sentAt: after.add(const Duration(minutes: 2)),
          ),
        ],
      );

      // قبل أي قراءة: رسالتان للطرف الآخر، ورسالتي أنا لا تُحتسب.
      expect(
        await messages.unreadCount(groupId: 'g1', memberId: 'student-1'),
        2,
      );

      await messages.markRead(groupId: 'g1', memberId: 'student-1');

      expect(
        await messages.unreadCount(groupId: 'g1', memberId: 'student-1'),
        0,
      );
      // علامة الزميل لم تُمسّ.
      expect(
        await messages.lastReadAt(groupId: 'g1', memberId: 'student-2'),
        isNull,
      );
      expect(
        await messages.unreadCount(groupId: 'g1', memberId: 'student-2'),
        2,
      );
    });
  });

  group('إصلاح 3 — إعادة محاولة تعليم إشعارات المحادثة', () {
    const Duration retryDelay = Duration(seconds: 5);
    final DateTime t0 = DateTime(2026, 11, 4, 12);

    test('المحادثة تنجح، والإشعارات تفشل أول مرة، ثم تُعاد المحاولة وتنجح', () async {
      final ChatReadMarker marker = ChatReadMarker(retryDelay: retryDelay);
      int chatCalls = 0;
      int notifyAttempts = 0;
      int notifySuccesses = 0;
      int notifyFailuresLeft = 1;

      Future<void> markChat() async => chatCalls++;
      Future<void> clearNotifications() async {
        notifyAttempts++;
        if (notifyFailuresLeft > 0) {
          notifyFailuresLeft--;
          throw const AppException.network(debugMessage: 'شبكة متعثرة');
        }
        notifySuccesses++;
      }

      // 1) فتح المحادثة: النجاح في المحادثة والفشل في الإشعارات.
      final bool pendingAfterFirst = await marker.run(
        chatId: 'c1',
        chatUnread: true,
        now: t0,
        markChat: markChat,
        clearNotifications: clearNotifications,
      );
      expect(chatCalls, 1, reason: 'تعليم المحادثة نُفّذ');
      expect(notifyAttempts, 1);
      expect(notifySuccesses, 0, reason: 'الإشعارات لم تُعلَّم فعلًا');
      expect(pendingAfterFirst, isTrue, reason: 'الحالة غير مكتملة');

      // 2) داخل فترة التهدئة: لا كتابة متكررة في إعادات البناء.
      final DateTime duringCooldown = t0.add(const Duration(seconds: 2));
      expect(
        marker.shouldAttempt(
          chatId: 'c1',
          chatUnread: false,
          now: duringCooldown,
        ),
        isFalse,
      );
      await marker.run(
        chatId: 'c1',
        chatUnread: false,
        now: duringCooldown,
        markChat: markChat,
        clearNotifications: clearNotifications,
      );
      expect(notifyAttempts, 1, reason: 'لا محاولة داخل التهدئة');
      expect(chatCalls, 1, reason: 'المحادثة لا تُعلَّم مرتين');

      // 3) بعد التهدئة: محاولة جديدة تنجح.
      final DateTime afterCooldown = t0.add(retryDelay);
      expect(
        marker.shouldAttempt(
          chatId: 'c1',
          chatUnread: false,
          now: afterCooldown,
        ),
        isTrue,
      );
      final bool pendingAfterRetry = await marker.run(
        chatId: 'c1',
        chatUnread: false,
        now: afterCooldown,
        markChat: markChat,
        clearNotifications: clearNotifications,
      );
      expect(notifyAttempts, 2, reason: 'محاولة ثانية فعلية');
      expect(notifySuccesses, 1, reason: 'الإشعارات عُلِّمت في المحاولة الثانية');
      expect(pendingAfterRetry, isFalse);
      expect(chatCalls, 1);

      // 4) بعد اكتمال الحالتين: لا محاولات ولا كتابات أخرى.
      expect(
        marker.shouldAttempt(
          chatId: 'c1',
          chatUnread: false,
          now: afterCooldown.add(const Duration(minutes: 3)),
        ),
        isFalse,
      );
      expect(
        marker.isPending(chatId: 'c1', chatUnread: false),
        isFalse,
      );
    });

    test('فشل تعليم المحادثة لا يُعلَّم، وتُعاد المحاولة', () async {
      final ChatReadMarker marker = ChatReadMarker(retryDelay: retryDelay);
      int chatFailuresLeft = 1;
      int chatSuccesses = 0;
      int notifySuccesses = 0;

      await marker.run(
        chatId: 'c2',
        chatUnread: true,
        now: t0,
        markChat: () async {
          if (chatFailuresLeft > 0) {
            chatFailuresLeft--;
            throw const AppException.network();
          }
          chatSuccesses++;
        },
        clearNotifications: () async => notifySuccesses++,
      );
      expect(chatSuccesses, 0);
      expect(
        notifySuccesses,
        0,
        reason: 'الإشعارات لا تُعلَّم قبل نجاح تعليم المحادثة',
      );

      await marker.run(
        chatId: 'c2',
        chatUnread: true,
        now: t0.add(retryDelay),
        markChat: () async => chatSuccesses++,
        clearNotifications: () async => notifySuccesses++,
      );
      expect(chatSuccesses, 1);
      expect(notifySuccesses, 1);
      expect(marker.isPending(chatId: 'c2', chatUnread: true), isFalse);
    });

    test('محادثة مقروءة سلفًا: إفراغ الإشعارات فقط، بلا كتابة على المحادثة', () async {
      final ChatReadMarker marker = ChatReadMarker(retryDelay: retryDelay);
      int chatCalls = 0;
      int notifySuccesses = 0;

      final bool pending = await marker.run(
        chatId: 'c3',
        chatUnread: false,
        now: t0,
        markChat: () async => chatCalls++,
        clearNotifications: () async => notifySuccesses++,
      );

      expect(chatCalls, 0, reason: 'لا شيء يُعلَّم في المحادثة');
      expect(notifySuccesses, 1);
      expect(pending, isFalse);
    });
  });
}
