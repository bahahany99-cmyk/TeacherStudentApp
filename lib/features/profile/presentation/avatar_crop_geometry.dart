import 'dart:math' as math;
import 'dart:ui';

/// حساب القصّ والتحريك (P31) — دوال نقية بلا واجهة ولا صور.
///
/// **لماذا فصلها؟** لأن أهم ما في شاشة القصّ ليس الرسم بل **ألا تخرج الصورة عن
/// الإطار**: لا فراغ أسود في الزوايا، ولا تشويه للنِّسب. هذا حساب يمكن اختباره
/// مباشرة (بلا هاتف ولا محرّك صور) بدل الاعتماد على لقطة شاشة.
///
/// النموذج الرياضي:
/// - الإطار مربّع ثابت طول ضلعه `cropSide` نقطة على الشاشة.
/// - الصورة تُعرض بمقياس `cover` يجعل أصغر بُعد لها يساوي الإطار، مضروبًا في
///   `zoom` (1 = تغطية كاملة، والحد الأقصى 4×).
/// - الإزاحة `pan` هي موضع **مركز الصورة** بالنسبة لمركز الإطار، مقيسة بنقاط
///   الشاشة، ومحدودة بحيث تبقى الحواف مغطّاة.
abstract final class CropMath {
  /// أقل تكبير: تغطية كاملة بلا فراغ (لا تصغير تحت هذا الحد).
  static const double minZoom = 1;

  /// أقصى تكبير: 4× — يكفي لإظهار الوجه بلا فقدان حادّ في الجودة.
  static const double maxZoom = 4;

  /// مقياس «التغطية»: يجعل الصورة تملأ الإطار كاملًا بأصغر بُعد.
  static double coverScale({
    required Size imageSize,
    required double cropSide,
  }) {
    final double smallest = math.min(imageSize.width, imageSize.height);
    if (smallest <= 0 || cropSide <= 0) {
      return 1;
    }
    return cropSide / smallest;
  }

  /// تطبيع التكبير داخل حدوده.
  static double clampZoom(double zoom) {
    if (zoom.isNaN) {
      return minZoom;
    }
    return zoom.clamp(minZoom, maxZoom);
  }

  /// أبعاد الصورة بعد العرض (على الشاشة).
  static Size displayedSize({
    required Size imageSize,
    required double cropSide,
    required double zoom,
  }) {
    final double scale =
        coverScale(imageSize: imageSize, cropSide: cropSide) *
        clampZoom(zoom);
    return Size(imageSize.width * scale, imageSize.height * scale);
  }

  /// حدود الإزاحة بحيث لا يظهر فراغ داخل الإطار.
  static Offset clampPan(
    Offset pan, {
    required Size displayed,
    required double cropSide,
  }) {
    final double maxX = math.max(0, (displayed.width - cropSide) / 2);
    final double maxY = math.max(0, (displayed.height - cropSide) / 2);
    return Offset(
      pan.dx.clamp(-maxX, maxX).toDouble(),
      pan.dy.clamp(-maxY, maxY).toDouble(),
    );
  }
}
