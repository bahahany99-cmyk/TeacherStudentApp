import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/chat_image.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/image_picker_gateway.dart';
import 'package:teacher_student_app/features/chat/presentation/direct_chat_screen.dart';
import 'package:teacher_student_app/features/chat/presentation/widgets/chat_image_thumbnail.dart';
import 'package:teacher_student_app/features/chat/presentation/widgets/chat_image_viewer.dart';

import '../helpers/avatar_helpers.dart';
import '../helpers/chat_image_helpers.dart';
import '../helpers/test_app.dart';

const String _teacherId = 'demo-teacher-1';
final String _chatId = DirectChat.idFor(
  teacherId: _teacherId,
  studentId: DemoData.demoStudentId,
);

/// حزمة تجريبية بصور محادثة حقيقية في الذاكرة (لا Firestore ولا منصّة).
class _Harness {
  _Harness({
    PickedImage? picked,
    FakeChatImageSaver? saver,
    DateTime Function()? clock,
    List<DirectChatMessage>? messages,
  }) : picker = FakeImagePickerGateway(result: picked),
       saver = saver ?? FakeChatImageSaver(),
       _messages = messages {
    chatImages = DemoChatImageRepository(now: clock ?? DateTime.now);
    services = _build();
  }

  final FakeImagePickerGateway picker;
  final FakeChatImageSaver saver;
  final List<DirectChatMessage>? _messages;
  late final DemoChatImageRepository chatImages;
  late final AppServices services;

  AppServices _build() {
    final DemoNotificationRepository notifications = DemoNotificationRepository();
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
        messages: _messages,
        findBooking: bookings.findById,
        isMember: groups.isMember,
        notifications: notifications,
      ),
      notifications: notifications,
      schedules: DemoScheduleRepository(),
      messages: DemoMessageRepository(),
      reviews: DemoReviewRepository(),
      favorites: DemoFavoriteRepository(),
      imagePicker: picker,
      chatImages: chatImages,
      imageSaver: saver,
    );
  }
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

/// يرسل صورة من زر المرفق (نفس مسار المستخدم).
Future<void> _sendImage(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('chat-image-pick')));
  await tester.pumpAndSettle();
}

void main() {
  group('صور المحادثة (P24) — الإرسال والعرض', () {
    testWidgets('زر المرفق يرفع صورة ويرسل رسالة تحمل imageId', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness(
        picked: PickedImage(bytes: tinyPngBytes(), mimeType: 'image/png'),
      );

      await tester.pumpWidget(_host(harness.services));
      await tester.pumpAndSettle();

      await _sendImage(tester);

      // الصورة طُلبت بأبعاد المحادثة (1024) لا بأبعاد صورة الحساب (512).
      expect(harness.picker.pickCalls, 1);
      expect(harness.picker.lastPreset, ImagePickPreset.chat);
      expect(ChatImageLimits.lifetime.inDays, 5);

      // المصغّر ظهر، والملخّص في صندوق المحادثات لم يبقَ فارغًا.
      expect(
        find.byKey(ChatImageThumbnail.thumbnailKey),
        findsOneWidget,
      );
      final DirectChat chat = (await harness.services.chats.findById(
        _chatId,
      ))!;
      expect(chat.lastMessageText, '📷 صورة');
      expect(tester.takeException(), isNull);
    });

    testWidgets('إلغاء الاختيار لا يرسل شيئًا ولا يعرض خطأ', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness(picked: null);

      await tester.pumpWidget(_host(harness.services));
      await tester.pumpAndSettle();

      final String? before = (await harness.services.chats.findById(
        _chatId,
      ))!.lastMessageText;

      await _sendImage(tester);

      expect(harness.picker.pickCalls, 1);
      expect(find.byKey(ChatImageThumbnail.thumbnailKey), findsNothing);
      final DirectChat chat = (await harness.services.chats.findById(
        _chatId,
      ))!;
      expect(chat.lastMessageText, before);
    });

    testWidgets('شارة التحذير صغيرة وتكشف التفصيل عند اللمس', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness(
        picked: PickedImage(bytes: tinyPngBytes(), mimeType: 'image/png'),
      );

      await tester.pumpWidget(_host(harness.services));
      await tester.pumpAndSettle();
      await _sendImage(tester);

      // لا نص تحذير ثقيل داخل المحادثة — الشارة وحدها.
      expect(find.textContaining('تُحذف صور المحادثة تلقائيًا'), findsNothing);

      await tester.tap(find.byKey(ChatImageThumbnail.badgeKey));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('تُحذف صور المحادثة تلقائيًا بعد 5 أيام'),
        findsOneWidget,
      );
    });

    testWidgets('صورة انتهت صلاحيتها تظهر «انتهت مدة الصورة» لا مربعًا مكسورًا', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      // الساعة قابلة للتحريك: نرفع الصورة عند T ثم نقرأها عند T+6 أيام.
      DateTime clock = DateTime(2026, 10, 30, 12);
      final _Harness harness = _Harness(
        clock: () => clock,
        messages: <DirectChatMessage>[
          DirectChatMessage(
            id: 'm-image',
            chatId: _chatId,
            senderId: DemoData.demoStudentId,
            senderName: 'طالب تجريبي',
            senderRole: UserRole.student,
            text: '',
            sentAt: clock,
            imageId: 'gone-image',
          ),
        ],
      );

      await harness.chatImages.upload(
        chatId: _chatId,
        senderId: DemoData.demoStudentId,
        bytes: tinyPngBytes(),
        mimeType: 'image/png',
      );
      clock = clock.add(const Duration(days: 6));

      await tester.pumpWidget(_host(harness.services));
      await tester.pumpAndSettle();

      expect(find.byKey(ChatImageThumbnail.missingKey), findsOneWidget);
      expect(find.text('انتهت مدة الصورة'), findsOneWidget);
      expect(find.byKey(ChatImageThumbnail.thumbnailKey), findsNothing);
    });
  });

  group('عارض الصورة (P24) — تكبير وتنزيل', () {
    testWidgets('النقر على المصغّر يفتح العارض بملء الشاشة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness(
        picked: PickedImage(bytes: tinyPngBytes(), mimeType: 'image/png'),
      );

      await tester.pumpWidget(_host(harness.services));
      await tester.pumpAndSettle();
      await _sendImage(tester);

      await tester.tap(find.byKey(ChatImageThumbnail.thumbnailKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ChatImageViewer.viewerKey), findsOneWidget);
      expect(find.byKey(ChatImageViewer.zoomInKey), findsOneWidget);
      expect(find.byKey(ChatImageViewer.zoomOutKey), findsOneWidget);
      expect(find.byKey(ChatImageViewer.downloadKey), findsOneWidget);
      // التفصيل يظهر هنا فقط — سطر واحد، لا لافتة.
      expect(find.textContaining('تُحذف بعد'), findsOneWidget);
    });

    testWidgets('زرّا التكبير يعملان بلا استثناء', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness(
        picked: PickedImage(bytes: tinyPngBytes(), mimeType: 'image/png'),
      );

      await tester.pumpWidget(_host(harness.services));
      await tester.pumpAndSettle();
      await _sendImage(tester);
      await tester.tap(find.byKey(ChatImageThumbnail.thumbnailKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ChatImageViewer.zoomInKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ChatImageViewer.zoomInKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ChatImageViewer.zoomOutKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // بعد التصغير الكامل لا يتجاوز المقياس حدّه الأدنى.
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('زر التنزيل يحفظ الصورة فعلًا ويؤكد', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness(
        picked: PickedImage(bytes: tinyPngBytes(), mimeType: 'image/png'),
      );

      await tester.pumpWidget(_host(harness.services));
      await tester.pumpAndSettle();
      await _sendImage(tester);
      await tester.tap(find.byKey(ChatImageThumbnail.thumbnailKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ChatImageViewer.downloadKey));
      await tester.pumpAndSettle();

      expect(harness.saver.calls, 1);
      expect(harness.saver.saved.single.mimeType, 'image/png');
      expect(harness.saver.saved.single.fileName, startsWith('chat-image-'));
      expect(find.text('حُفظت الصورة في معرض الجهاز.'), findsOneWidget);
    });

    testWidgets('فشل التنزيل يعرض سببه بدل صمت', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness(
        picked: PickedImage(bytes: tinyPngBytes(), mimeType: 'image/png'),
        saver: FakeChatImageSaver(
          error: const AppException(
            AppErrorKind.permission,
            overrideMessage: 'الإذن مرفوض في الاختبار.',
          ),
        ),
      );

      await tester.pumpWidget(_host(harness.services));
      await tester.pumpAndSettle();
      await _sendImage(tester);
      await tester.tap(find.byKey(ChatImageThumbnail.thumbnailKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ChatImageViewer.downloadKey));
      await tester.pumpAndSettle();

      expect(harness.saver.calls, 0);
      expect(find.text('الإذن مرفوض في الاختبار.'), findsOneWidget);
    });
  });
}
