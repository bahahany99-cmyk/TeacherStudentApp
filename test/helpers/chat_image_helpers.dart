import 'dart:typed_data';

import 'package:teacher_student_app/data/services/chat_image_saver.dart';

/// حافظ صور اصطناعي (P24): يسجّل ما طُلب حفظه بلا منصّة.
///
/// يُحقن في [AppServices] للاختبار، فلا يلمس الاختبار `gal` ولا قناة أصلية.
class FakeChatImageSaver implements ChatImageSaver {
  FakeChatImageSaver({this.error});

  /// خطأ يُرمى بدل الحفظ (لمسار رفض الإذن / امتلاء التخزين).
  final Object? error;

  /// ما حُفظ فعلًا — يتحقق منه الاختبار.
  final List<SavedChatImage> saved = <SavedChatImage>[];

  int get calls => saved.length;

  @override
  Future<void> saveToGallery({
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
  }) async {
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    saved.add(
      SavedChatImage(bytes: bytes, mimeType: mimeType, fileName: fileName),
    );
  }
}

/// صورة نُزّلت في الاختبار.
class SavedChatImage {
  const SavedChatImage({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileName;
}
