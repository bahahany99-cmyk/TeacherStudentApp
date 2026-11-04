import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/data/services/image_picker_gateway.dart';
import 'package:teacher_student_app/features/profile/presentation/avatar_crop_geometry.dart';

/// تصدير المربع المختار من الصورة إلى JPEG جاهز للرفع (P31).
///
/// ## لماذا لا نعيد استخدام بايتات المختار كما هي؟
/// لأن المطلوب **قصّ فعلي**: ما يراه المستخدم داخل الإطار هو ما يُحفظ. القصّ
/// يتم في `dart:ui` (نفس المحرّك الذي رسم المعاينة) ثم يُرمَّز JPEG بـ`image`
/// لأن `dart:ui` لا يُخرج إلا PNG (وصورة PNG بـ512px تتجاوز سقف الحمولة).
///
/// ## لماذا بهذا الترتيب (دقة ← ضغط ← تصغير)؟
/// 1. الرسم بدقة `outputPx` (512) وبـ`FilterQuality.high` فلا تُفقد التفاصيل.
/// 2. ترميز JPEG بجودة عالية أولًا؛ إن تجاوز السقف نهبط درجات الجودة.
/// 3. إن لم يكفِ، نصغّر الأبعاد — آخر حلّ يحفظ الميزة بدل رفض الصورة.
///
/// النِّسب محفوظة دائمًا: الإخراج مربّع، والصورة تُرسم بنفس مقياس المعاينة بلا
/// أي تمدّد غير متماثل (لا `BoxFit.fill` على مستطيل).
abstract final class AvatarCropEncoder {
  /// دقة الإخراج: 512px تكفي لعرض 96dp على شاشة 3× بكثافة كاملة.
  static const int outputPx = 512;

  /// سلّم الجودة — الأول هو المعتمد في الحالة الطبيعية.
  static const List<int> qualityLadder = <int>[86, 72, 60];

  /// أبعاد بديلة تُجرَّب إن بقي الحجم أكبر من السقف.
  static const List<int> sizeLadder = <int>[512, 384, 256];

  /// يبني صورة القصّ النهائية.
  ///
  /// [image] الصورة المفكوكة، [cropSide] ضلع الإطار بالشاشة، [zoom] و[pan]
  /// حالة المعاينة نفسها. يعيد `null` إن تعذّر التصدير (صورة غير صالحة).
  static Future<PickedImage?> encode({
    required ui.Image image,
    required double cropSide,
    required double zoom,
    required ui.Offset pan,
  }) async {
    final ui.Image? rendered = await _render(
      image: image,
      cropSide: cropSide,
      zoom: zoom,
      pan: pan,
      outputPx: outputPx,
    );
    if (rendered == null) {
      return null;
    }

    final ByteData? raw = await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    rendered.dispose();
    if (raw == null) {
      return null;
    }

    // `rawRgba` = 4 قنوات بالترتيب RGBA؛ `image` 4.x يقرأ `ByteBuffer` مباشرة.
    img.Image source = img.Image.fromBytes(
      width: outputPx,
      height: outputPx,
      bytes: raw.buffer,
      numChannels: 4,
    );

    for (final int size in sizeLadder) {
      if (size != outputPx) {
        // التصغير بنسبة متساوية ⇒ لا تشويه.
        source = img.copyResize(source, width: size, height: size);
      }
      for (final int quality in qualityLadder) {
        final Uint8List jpeg = img.encodeJpg(source, quality: quality);
        if (jpeg.length * 4 ~/ 3 <= AvatarLimits.maxBase64Length) {
          return PickedImage(bytes: jpeg, mimeType: 'image/jpeg');
        }
      }
    }

    throw const AppException(
      AppErrorKind.invalidInput,
      debugMessage: 'cropped avatar exceeds base64 cap at all ladder steps',
      overrideTitle: 'الصورة كبيرة',
      overrideMessage: 'تعذّر ضغط الصورة. جرّب صورة أخرى أو أعد المحاولة.',
    );
  }

  /// يرسم داخل المربّع فقط، بنفس مقياس المعاينة.
  static Future<ui.Image?> _render({
    required ui.Image image,
    required double cropSide,
    required double zoom,
    required ui.Offset pan,
    required int outputPx,
  }) async {
    if (cropSide <= 0) {
      return null;
    }
    final double k = outputPx / cropSide;
    final double scale =
        CropMath.coverScale(
          imageSize: ui.Size(image.width.toDouble(), image.height.toDouble()),
          cropSide: cropSide,
        ) *
        CropMath.clampZoom(zoom);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.scale(k, k);
    // مركز الصورة على الشاشة (نفس ما رسمته المعاينة) ثم القياس حول المركز.
    canvas.translate(cropSide / 2 + pan.dx, cropSide / 2 + pan.dy);
    canvas.scale(scale, scale);
    canvas.drawImage(
      image,
      ui.Offset(-image.width / 2, -image.height / 2),
      ui.Paint()
        ..filterQuality = ui.FilterQuality.high
        ..isAntiAlias = true,
    );
    final ui.Picture picture = recorder.endRecording();
    try {
      return await picture.toImage(outputPx, outputPx);
    } finally {
      picture.dispose();
    }
  }
}
