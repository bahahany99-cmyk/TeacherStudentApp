import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';

/// حفظ صورة المحادثة في معرض الجهاز (P24).
///
/// **لماذا عقد منفصل؟** لأن الحفظ يحتاج قناة أصلية (إذن تخزين + كتابة في
/// المعرض)، واستدعاؤها في اختبار ويدجت يفشل بلا منصّة. العارض يعتمد على هذا
/// العقد، والاختبارات تحقن تنفيذًا وهميًا يسجّل ما حُفظ — فيبقى زر «تنزيل»
/// قابلًا للاختبار بلا هاتف.
///
/// **لماذا لا نخزّن في مجلد التطبيق؟** لأن المستخدم يريد الصورة في معرضه حيث
/// يراها بعد إغلاق التطبيق، لا في مسار داخلي لا يصل إليه.
abstract interface class ChatImageSaver {
  /// يحفظ [bytes] في معرض الصور باسم [fileName] (بلا امتداد).
  ///
  /// يرمي [AppException] برسالة عربية واضحة عند رفض الإذن أو امتلاء التخزين؛
  /// النجاح الصامت حين لا تُحفظ الصورة أسوأ من رسالة صريحة.
  Future<void> saveToGallery({
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
  });
}

/// التنفيذ الحقيقي عبر `gal` (أندرويد/iOS).
class PlatformChatImageSaver implements ChatImageSaver {
  const PlatformChatImageSaver();

  @override
  Future<void> saveToGallery({
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw const AppException(
        AppErrorKind.invalidInput,
        debugMessage: 'empty image bytes',
        overrideTitle: 'الصورة غير متاحة',
        overrideMessage: 'تعذّر تنزيل الصورة. أعد المحاولة بعد قليل.',
      );
    }

    try {
      // الإذن يُطلب مرة واحدة عند أول تنزيل فقط؛ بعدها يصبح الحفظ مباشرًا.
      if (!await Gal.hasAccess()) {
        final bool granted = await Gal.requestAccess();
        if (!granted) {
          throw const AppException(
            AppErrorKind.permission,
            debugMessage: 'gallery access denied',
            overrideTitle: 'الإذن مطلوب',
            overrideMessage:
                'للتنزيل نحتاج إذن الوصول إلى صور الجهاز. يمكنك منحه من '
                'إعدادات الهاتف ثم إعادة المحاولة.',
          );
        }
      }
      await Gal.putImageBytes(bytes, name: fileName);
    } on GalException catch (error) {
      // رسالة عربية بحسب نوع الفشل — بلا رموز تقنية ولا تفاصيل داخلية.
      final String message = switch (error.type.name) {
        'accessDenied' =>
          'لم يُمنح إذن الوصول إلى صور الجهاز. يمكنك منحه من إعدادات '
              'الهاتف ثم إعادة المحاولة.',
        'notEnoughSpace' => 'لا توجد مساحة كافية في الهاتف لحفظ الصورة.',
        'notSupportedFormat' =>
          'صيغة الصورة غير مدعومة في معرض هذا الجهاز.',
        _ => 'تعذّر حفظ الصورة في المعرض. أعد المحاولة بعد قليل.',
      };
      throw AppException(
        error.type == GalExceptionType.accessDenied
            ? AppErrorKind.permission
            : AppErrorKind.unavailable,
        debugMessage: 'gallery save failed: ${error.type.name}',
        overrideTitle: error.type == GalExceptionType.accessDenied
            ? 'الإذن مطلوب'
            : 'تعذّر التنزيل',
        overrideMessage: message,
      );
    } on MissingPluginException {
      throw const AppException(
        AppErrorKind.unavailable,
        debugMessage: 'gal plugin not registered',
        overrideTitle: 'غير متاح على هذا الجهاز',
        overrideMessage: 'تنزيل الصور غير متاح في هذه النسخة من التطبيق.',
      );
    }
  }
}

/// تنفيذ لا يحفظ شيئًا — للحاويات التي لا تحتاج تنزيلًا (اختبارات قديمة).
///
/// يفشل برسالة عربية صريحة بدل نجاح صامت يوهم المستخدم أن الصورة حُفظت.
class UnavailableChatImageSaver implements ChatImageSaver {
  const UnavailableChatImageSaver();

  @override
  Future<void> saveToGallery({
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
  }) {
    throw const AppException(
      AppErrorKind.unavailable,
      debugMessage: 'chat image saver not configured',
      overrideTitle: 'غير متاح على هذا الجهاز',
      overrideMessage: 'تنزيل الصور غير متاح في هذه النسخة من التطبيق.',
    );
  }
}
