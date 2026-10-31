import 'dart:typed_data';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/models/chat_image.dart';

/// عقد صور المحادثة المؤقتة (P24).
///
/// **لماذا عقد مستقل؟** لأن الصور أثقل ما في المحادثة، ولأن الشاشات لا يجب أن
/// تعرف Firestore ولا التخزين. العقد صغير بقصد: رفع، قراءة، وحذف المنتهي.
///
/// **الانتهاء ليس تجميليًا:** كل صورة تحمل `expiresAt` (خمسة أيام)، والقواعد
/// ترفض قراءتها بعد ذلك. والحذف يحدث عند أول وصول للمستند بعد انتهائه
/// ([findById] تحذفه)، فيتحرر التخزين تدريجيًا بلا دالة سحابية ولا استعلام
/// مجموعات (قواعد Firestore لا تسمح باستعلام يعيد مستندات لم تُقرأ بعد).
abstract interface class ChatImageRepository {
  /// يرفع صورة إلى محادثة ويعيدها بموعد انتهائها.
  ///
  /// يرفض ما تجاوز [ChatImageLimits.maxBase64Length] أو كان بنوع غير مسموح —
  /// والقواعد ترفضه أيضًا، فلا يعتمد الأمان على هذه الطبقة.
  Future<ChatImage> upload({
    required String chatId,
    required String senderId,
    required Uint8List bytes,
    required String mimeType,
  });

  /// صورة واحدة، أو `null` إن لم توجد أو انتهت صلاحيتها.
  ///
  /// عند الانتهاء تُحذف من المصدر في نفس النداء (تنظيف تدريجي)، ويُعاد `null`
  /// فتظهر الرسالة «انتهت مدة الصورة» بدل مربع مكسور.
  Future<ChatImage?> findById({
    required String chatId,
    required String imageId,
  });

  /// حذف صورة انتهت صلاحيتها. لا يحذف صورة سارية (القواعد تمنع ذلك أيضًا).
  Future<void> deleteExpired({
    required String chatId,
    required String imageId,
  });
}

/// تنفيذ فارغ: لا رفع، ولا قراءة.
///
/// يخدم الحاويات المصغّرة في الاختبارات القديمة. الرفع يفشل برسالة عربية
/// صريحة بدل نجاح صامت يوهم المستخدم أن صورته أُرسلت.
class EmptyChatImageRepository implements ChatImageRepository {
  const EmptyChatImageRepository();

  @override
  Future<ChatImage> upload({
    required String chatId,
    required String senderId,
    required Uint8List bytes,
    required String mimeType,
  }) {
    throw const AppException(
      AppErrorKind.unavailable,
      debugMessage: 'chat image repository not configured',
      overrideTitle: 'الصور غير متاحة الآن',
      overrideMessage: 'تعذّر إرسال الصورة. أعد المحاولة بعد قليل.',
    );
  }

  @override
  Future<ChatImage?> findById({
    required String chatId,
    required String imageId,
  }) async => null;

  @override
  Future<void> deleteExpired({
    required String chatId,
    required String imageId,
  }) async {}
}
