import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/chat_read_marker.dart';
import 'package:teacher_student_app/features/chat/presentation/direct_chat_screen.dart';

import '../helpers/test_app.dart';

/// إصلاح 3 على مستوى الواجهة: فتح المحادثة يعلّم رسائلها، وفشل تعليم
/// **إشعاراتها** لا يُفقد المحاولة — تُعاد تلقائيًا بعد [ChatReadMarker.retryDelay]
/// فيصبح الجرس صحيحًا دون إغلاق الشاشة وإعادة فتحها.

const String _studentId = 'demo-student';
const String _teacherId = 'demo-teacher-1';
final String _chatId = DirectChat.idFor(
  teacherId: _teacherId,
  studentId: _studentId,
);

/// مستودع إشعارات تجريبي يفشل **أول** نداء لتعليم إشعارات المحادثة فقط
/// (شبكة متعثرة)، ثم ينجح. بقية السلوك هو سلوك المستودع التجريبي نفسه.
class _FlakyNotificationRepository extends DemoNotificationRepository {
  _FlakyNotificationRepository({required super.source});

  int attempts = 0;
  int failuresLeft = 1;

  @override
  Future<int> markChatMessagesRead({
    required String recipientId,
    required String chatId,
  }) async {
    attempts++;
    if (failuresLeft > 0) {
      failuresLeft--;
      throw const AppException.network(debugMessage: 'شبكة متعثرة (اختبار)');
    }
    return super.markChatMessagesRead(
      recipientId: recipientId,
      chatId: chatId,
    );
  }
}

DirectChat _chat() {
  return DirectChat(
    id: _chatId,
    teacherId: _teacherId,
    teacherName: 'أ. سارة الخطيب',
    studentId: _studentId,
    studentName: 'طالب',
    origin: DirectChatOrigin.inquiry,
    createdAt: DateTime(2026, 11, 1, 9),
    lastMessageAt: DateTime(2026, 11, 4, 9),
    lastMessageText: 'تذكير بالواجب',
    lastSenderId: _teacherId,
  );
}

AppNotification _notification() {
  return AppNotification(
    id: 'dm-1',
    recipientId: _studentId,
    type: NotificationType.directMessage,
    actorId: _teacherId,
    actorName: 'أ. سارة الخطيب',
    targetId: _chatId,
    title: 'رسالة من أ. سارة الخطيب',
    createdAt: DateTime(2026, 11, 4, 9),
  );
}

DirectChatMessage _message() {
  return DirectChatMessage(
    id: 'm1',
    chatId: _chatId,
    senderId: _teacherId,
    senderName: 'أ. سارة الخطيب',
    senderRole: UserRole.teacher,
    text: 'تذكير بالواجب',
    sentAt: DateTime(2026, 11, 4, 9),
  );
}

AppServices _services(_FlakyNotificationRepository notifications) {
  final DemoBookingRepository bookings = DemoBookingRepository(
    notifications: notifications,
  );
  final DemoGroupRepository groups = DemoGroupRepository(
    notifications: notifications,
  );
  return AppServices(
    admin: DemoAdminRepository(),
    auth: const DemoAuthService(),
    teachers: DemoTeacherRepository(),
    groups: groups,
    bookings: bookings,
    chats: DemoDirectChatRepository(
      source: <DirectChat>[_chat()],
      messages: <DirectChatMessage>[_message()],
      settings: <String, bool>{_teacherId: true},
      findBooking: bookings.findById,
      isMember: groups.isMember,
      notifications: notifications,
    ),
    notifications: notifications,
    schedules: DemoScheduleRepository(),
    messages: DemoMessageRepository(),
    reviews: DemoReviewRepository(),
    favorites: DemoFavoriteRepository(),
  );
}

Widget _host(AppServices services) {
  final SessionController session = SessionController(services.auth)
    ..startDemoSession(UserRole.student);
  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          theme: AppTheme.light,
          home: DirectChatScreen(chatId: _chatId),
        ),
      ),
    ),
  );
}

int _unreadCount(List<AppNotification> items) =>
    items.where((AppNotification item) => !item.isRead).length;

void main() {
  testWidgets('فشل تعليم الإشعارات يُعاد بعد التهدئة فيصبح الجرس صحيحًا', (
    WidgetTester tester,
  ) async {
    usePhoneSurface(tester);
    final _FlakyNotificationRepository notifications =
        _FlakyNotificationRepository(source: <AppNotification>[_notification()]);
    final AppServices services = _services(notifications);

    await tester.pumpWidget(_host(services));
    await tester.pumpAndSettle();

    // 1) المحادثة عُلِّمت مقروءة، و2) تعليم الإشعارات فشل أول مرة.
    expect(notifications.attempts, 1, reason: 'محاولة واحدة فقط، لا حلقة');
    expect(
      _unreadCount(await notifications.listMine(_studentId)),
      1,
      reason: 'الإشعار لم يُعلَّم لأنه فشل',
    );

    // 3) إعادة بناء متكررة داخل التهدئة لا تكتب شيئًا.
    await tester.pump(const Duration(seconds: 1));
    expect(notifications.attempts, 1);

    // 4) بعد انقضاء التهدئة تُعاد المحاولة تلقائيًا وتنجح.
    await tester.pump(ChatReadMarker().retryDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(notifications.attempts, greaterThanOrEqualTo(2));
    expect(
      _unreadCount(await notifications.listMine(_studentId)),
      0,
      reason: 'الجرس صار يطابق الواقع دون إغلاق الشاشة',
    );

    // 5) بعد النجاح لا كتابات أخرى.
    final int attemptsAfterSuccess = notifications.attempts;
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(notifications.attempts, attemptsAfterSuccess);
  });
}
