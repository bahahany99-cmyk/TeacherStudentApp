import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';

/// صورة اختارها المستخدم من معرض جهازه.
class PickedImage {
  const PickedImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;

  /// نوع الصورة ('image/jpeg' أو 'image/png') — يحدّده المختار من الامتداد.
  final String mimeType;
}

/// اختيار صورة من الجهاز (P22).
///
/// **لماذا عقد منفصل عن الحزمة؟** لأن `image_picker` تحتاج منصّة حقيقية:
/// استدعاؤها في اختبار ويدجت يفشل بلا قناة أصلية. الشاشات تعتمد على هذا
/// العقد، والاختبارات تحقن تنفيذًا وهميًا يعيد بايتات جاهزة — فمسار «رفع
/// الصورة» كله (تحقق، ضغط، رفع، تحديث الحالة) قابل للاختبار بلا هاتف.
///
/// الصورة تُصغَّر وتُضغط **عند الاختيار** (`maxWidth`/`imageQuality`) فلا
/// نرفع صور كاميرا خام. القيود مكرّرة في `AvatarLimits` وفي `firestore.rules`.
abstract interface class ImagePickerGateway {
  /// يعيد الصورة المختارة، أو `null` إن ألغى المستخدم الاختيار.
  ///
  /// إلغاء المستخدم **ليس خطأ**: لا رسالة فشل، ولا تغيير للحالة.
  ///
  /// (P24) [preset] يحدّد أبعاد الضغط المطلوبة من المنصّة: صورة الحساب تُعرض
  /// مصغّرة (512px)، وصورة المحادثة تُفتح بملء الشاشة مع تكبير (1024px).
  /// الضغط يحدث **قبل** القراءة، فلا تمرّ صورة كاميرا خام إلى الشبكة أبدًا.
  Future<PickedImage?> pickFromGallery({
    ImagePickPreset preset = ImagePickPreset.avatar,
  });
}

/// غرض الاختيار — يحمل الأبعاد والجودة المطلوبتين من منتقي النظام (P24).
///
/// القيم هنا هي «طلب»ٌ للمنصّة، وليست ضمانًا: بعض الأجهزة تتجاهل `imageQuality`
/// فتُعيد صورة أكبر. لذلك يبقى التحقق من الحجم النهائي في
/// [ChatImageLimits.maxBase64Length] وفي `firestore.rules` بعد الترميز.
enum ImagePickPreset {
  /// صورة حساب: تُعرض دائمًا في دائرة صغيرة.
  avatar(
    maxDimension: AvatarLimits.pickMaxDimension,
    quality: AvatarLimits.pickQuality,
  ),

  /// صورة محادثة: تُعرض بملء الشاشة، فتحتاج تفاصيل أكثر من صورة الحساب —
  /// لكن تبقى مقيّدة بسقف base64 (≈300KB) وبعمر خمسة أيام.
  chat(maxDimension: 1024, quality: 70);

  const ImagePickPreset({required this.maxDimension, required this.quality});

  /// أقصى عرض/ارتفاع يطلبه المنتقي من المنصّة.
  final int maxDimension;

  /// جودة ضغط JPEG المطلوبة (0–100).
  final int quality;
}

/// التنفيذ الحقيقي عبر `image_picker` (المعرض فقط).
///
/// **المعرض لا الكاميرا**: لا نطلب إذن الكاميرا في التطبيق، ولا نضيف مسارًا
/// يحتاج تصريحًا إضافيًا بلا حاجة.
class PlatformImagePickerGateway implements ImagePickerGateway {
  PlatformImagePickerGateway({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedImage?> pickFromGallery({
    ImagePickPreset preset = ImagePickPreset.avatar,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: preset.maxDimension.toDouble(),
        maxHeight: preset.maxDimension.toDouble(),
        imageQuality: preset.quality,
        requestFullMetadata: false,
      );
      if (file == null) {
        return null;
      }

      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }

      // النوع من الامتداد لا من محتوى الملف: `mimeType` من المنصّة قد تأتي
      // `image/jpg` أو فارغة، والقواعد تقبل قيمتين محددتين فقط.
      final String name = file.name.toLowerCase();
      final String mimeType = name.endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      return PickedImage(bytes: bytes, mimeType: mimeType);
    } on PlatformException catch (error) {
      throw AppException(
        AppErrorKind.permission,
        debugMessage: 'image picker failed: ${error.code}',
        overrideTitle: 'تعذّر فتح الصور',
        overrideMessage:
            'لم نتمكن من الوصول إلى صور الجهاز. تحقّق من الإذن في إعدادات '
            'الهاتف ثم أعد المحاولة.',
      );
    } on MissingPluginException {
      // منصّة لا تدعم المنتقي (مثل تشغيل بلا بناء أصلي): رسالة مفهومة.
      throw const AppException(
        AppErrorKind.unavailable,
        debugMessage: 'image_picker plugin not registered',
        overrideTitle: 'غير متاح على هذا الجهاز',
        overrideMessage: 'اختيار الصور غير متاح في هذه النسخة من التطبيق.',
      );
    }
  }
}

/// تنفيذ لا يفتح شيئًا — للحاويات التي لا تحتاج اختيار صور (اختبارات قديمة،
/// أو منصّة بلا منتقي). يفشل برسالة عربية واضحة بدل نجاح صامت.
class UnavailableImagePickerGateway implements ImagePickerGateway {
  const UnavailableImagePickerGateway();

  @override
  Future<PickedImage?> pickFromGallery({
    ImagePickPreset preset = ImagePickPreset.avatar,
  }) {
    throw const AppException(
      AppErrorKind.unavailable,
      debugMessage: 'image picker gateway not configured',
      overrideTitle: 'غير متاح على هذا الجهاز',
      overrideMessage: 'اختيار الصور غير متاح في هذه النسخة من التطبيق.',
    );
  }
}
