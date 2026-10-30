import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/chat_image.dart';
import 'package:teacher_student_app/data/services/chat_image_repository.dart';

/// اختبارات صور المحادثة المؤقتة (P24، البند 4).
///
/// ثلاثة أشياء تُثبت هنا:
/// 1. **الانتهاء** بعد خمسة أيام (وحساب المتبقي بالعربية).
/// 2. **الرفض** لما يتجاوز سقف base64 أو نوعًا غير مسموح — قبل أي كتابة.
/// 3. **الحذف** بعد الانتهاء فقط: صورة سارية لا يحذفها أحد.
///
/// القواعد تفرض الشيء نفسه على الخادم؛ هذه الطبقة تعطي الرسالة العربية
/// وتُبقي المستخدم بعيدًا عن خطأ صلاحيات متأخر.
void main() {
  group('ChatImageLimits', () {
    test('العمر خمسة أيام والسقف 400 ألف حرف', () {
      expect(ChatImageLimits.lifetime, const Duration(days: 5));
      expect(ChatImageLimits.maxBase64Length, 400000);
      expect(ChatImageLimits.mimeTypes, <String>['image/jpeg', 'image/png']);
    });

    test('التسمية العربية للعمر', () {
      expect(ChatImage.lifetimeLabel(), '5 أيام');
    });
  });

  group('ChatImage', () {
    final DateTime now = DateTime(2026, 10, 30, 12);

    ChatImage imageAt(DateTime createdAt) => ChatImage(
      id: 'img-1',
      chatId: 'chat-1',
      senderId: 'student-1',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      mimeType: 'image/png',
      createdAt: createdAt,
      expiresAt: createdAt.add(ChatImageLimits.lifetime),
    );

    test('صورة جديدة ليست منتهية', () {
      expect(imageAt(now).isExpired(now: now), isFalse);
    });

    test('تنتهي بعد خمسة أيام بالضبط', () {
      final ChatImage image = imageAt(now);
      expect(
        image.isExpired(now: now.add(const Duration(days: 5))),
        isTrue,
        reason: 'عند موعد الانتهاء نفسه تصبح غير متاحة',
      );
    });

    test('هامش التسامح يمنع «انتهت» كاذبة قبل الموعد', () {
      final ChatImage image = imageAt(now);
      final DateTime justBefore = now.add(
        ChatImageLimits.lifetime - const Duration(minutes: 1),
      );
      expect(image.isExpired(now: justBefore), isFalse);
    });

    test('المتبقي لا يصير سالبًا', () {
      final ChatImage image = imageAt(now);
      expect(
        image.remaining(now: now.add(const Duration(days: 9))),
        Duration.zero,
      );
      expect(image.remaining(now: now).inDays, 5);
    });

    test('المتبقي بصيغة عربية مقروءة', () {
      expect(ChatImage.remainingLabel(const Duration(days: 3)), '3 أيام');
      expect(ChatImage.remainingLabel(const Duration(days: 1)), 'يوم واحد');
      expect(ChatImage.remainingLabel(const Duration(hours: 5)), '5 ساعة');
      expect(ChatImage.remainingLabel(const Duration(minutes: 20)), '20 دقيقة');
    });

    test('خريطة الكتابة تحمل المفاتيح الستة فقط', () {
      final Map<String, Object?> data = imageAt(now).toCreateMap();
      expect(data.keys.toSet(), <String>{
        'chatId',
        'senderId',
        'imageBase64',
        'mimeType',
        'createdAt',
        'expiresAt',
      });
      expect(data['chatId'], 'chat-1');
      expect(data['senderId'], 'student-1');
    });

    test('المعرّف فريد داخل المحادثة', () {
      final String a = ChatImage.newId(now, senderId: 's1');
      final String b = ChatImage.newId(
        now.add(const Duration(microseconds: 1)),
        senderId: 's1',
      );
      expect(a, isNot(b));
    });
  });

  group('DemoChatImageRepository', () {
    DateTime clock = DateTime(2026, 10, 30, 12);
    DemoChatImageRepository repo() =>
        DemoChatImageRepository(now: () => clock);

    Uint8List payload([int size = 256]) =>
        Uint8List.fromList(List<int>.filled(size, 7));

    test('الرفع يعيد صورة تنتهي بعد خمسة أيام', () async {
      final ChatImage image = await repo().upload(
        chatId: 'chat-1',
        senderId: 'student-1',
        bytes: payload(),
        mimeType: 'image/png',
      );
      expect(image.expiresAt, clock.add(ChatImageLimits.lifetime));
      expect(image.chatId, 'chat-1');
    });

    test('القراءة قبل الانتهاء تنجح', () async {
      final DemoChatImageRepository repository = repo();
      final ChatImage image = await repository.upload(
        chatId: 'chat-1',
        senderId: 'student-1',
        bytes: payload(),
        mimeType: 'image/png',
      );
      clock = clock.add(const Duration(days: 4));
      final ChatImage? found = await repository.findById(
        chatId: 'chat-1',
        imageId: image.id,
      );
      expect(found, isNotNull);
      expect(found!.bytes.length, 256);
    });

    test('القراءة بعد الانتهاء تعيد null وتحذف المستند', () async {
      final DemoChatImageRepository repository = repo();
      final ChatImage image = await repository.upload(
        chatId: 'chat-1',
        senderId: 'student-1',
        bytes: payload(),
        mimeType: 'image/png',
      );
      clock = clock.add(const Duration(days: 6));
      expect(
        await repository.findById(chatId: 'chat-1', imageId: image.id),
        isNull,
      );
      // بعد الحذف التلقائي: لا شيء لتحذفه لاحقًا.
      clock = clock.add(const Duration(days: 1));
      expect(
        await repository.findById(chatId: 'chat-1', imageId: image.id),
        isNull,
      );
    });

    test('النوع غير المسموح يُرفض برسالة عربية', () async {
      await expectLater(
        repo().upload(
          chatId: 'chat-1',
          senderId: 'student-1',
          bytes: payload(),
          mimeType: 'image/gif',
        ),
        throwsA(
          isA<AppException>().having(
            (AppException error) => error.message,
            'message',
            contains('JPG'),
          ),
        ),
      );
    });

    test('الصورة الأكبر من السقف تُرفض قبل أي كتابة', () async {
      // 400,000 حرف base64 ≈ 300KB بايت.
      final Uint8List tooBig = payload(310000);
      await expectLater(
        repo().upload(
          chatId: 'chat-1',
          senderId: 'student-1',
          bytes: tooBig,
          mimeType: 'image/jpeg',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('حذف صورة سارية ممنوع، وحذف المنتهية مسموح', () async {
      final DemoChatImageRepository repository = repo();
      final ChatImage image = await repository.upload(
        chatId: 'chat-1',
        senderId: 'student-1',
        bytes: payload(),
        mimeType: 'image/png',
      );

      await expectLater(
        repository.deleteExpired(chatId: 'chat-1', imageId: image.id),
        throwsA(isA<AppException>()),
        reason: 'صورة سارية لا يمسحها العميل — كما تفرضه القواعد',
      );

      clock = clock.add(const Duration(days: 6));
      await repository.deleteExpired(chatId: 'chat-1', imageId: image.id);
      expect(
        await repository.findById(chatId: 'chat-1', imageId: image.id),
        isNull,
      );
    });

    test('التنفيذ الفارغ يفشل بوضوح ولا يوهم بالنجاح', () async {
      const EmptyChatImageRepository empty = EmptyChatImageRepository();
      await expectLater(
        empty.upload(
          chatId: 'chat-1',
          senderId: 'student-1',
          bytes: payload(),
          mimeType: 'image/png',
        ),
        throwsA(isA<AppException>()),
      );
      expect(
        await empty.findById(chatId: 'chat-1', imageId: 'x'),
        isNull,
      );
    });
  });
}
