import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/features/profile/presentation/avatar_crop_geometry.dart';

/// (P31) حساب القصّ: التغطية، حدود التكبير، ومنع الفراغ داخل الإطار.
///
/// هذا الاختبار هو الحارس الحقيقي لشاشة القصّ: أي خطأ في هذه الدوال يظهر عند
/// المستخدم كحافة سوداء داخل دائرته أو كصورة مشوّهة — ولا يظهر في أي تحليل.
void main() {
  group('(P31) CropMath', () {
    test('التغطية تجعل أصغر بُعد يساوي الإطار', () {
      const Size landscape = Size(1200, 800);
      final double cover = CropMath.coverScale(
        imageSize: landscape,
        cropSide: 300,
      );
      expect(landscape.height * cover, closeTo(300, 0.001));
      expect(landscape.width * cover, greaterThan(300));
    });

    test('التغطية على صورة عمودية تعتمد العرض', () {
      const Size portrait = Size(600, 1600);
      final double cover = CropMath.coverScale(
        imageSize: portrait,
        cropSide: 240,
      );
      expect(portrait.width * cover, closeTo(240, 0.001));
      expect(portrait.height * cover, greaterThan(240));
    });

    test('التكبير محدود بين 1 و4', () {
      expect(CropMath.clampZoom(0.2), CropMath.minZoom);
      expect(CropMath.clampZoom(9), CropMath.maxZoom);
      expect(CropMath.clampZoom(double.nan), CropMath.minZoom);
      expect(CropMath.clampZoom(2.5), 2.5);
    });

    test('الأبعاد المعروضة = الصورة × (تغطية × تكبير) بلا تشويه', () {
      const Size imageSize = Size(1000, 500);
      final Size one = CropMath.displayedSize(
        imageSize: imageSize,
        cropSide: 200,
        zoom: 1,
      );
      final Size two = CropMath.displayedSize(
        imageSize: imageSize,
        cropSide: 200,
        zoom: 2,
      );
      // النسبة الأصلية محفوظة في كل الحالات.
      expect(one.width / one.height, closeTo(2, 0.0001));
      expect(two.width / two.height, closeTo(2, 0.0001));
      expect(two.width, closeTo(one.width * 2, 0.001));
      expect(two.height, closeTo(one.height * 2, 0.001));
    });

    test('الإزاحة محدودة فلا يظهر فراغ داخل الإطار', () {
      const Size displayed = Size(400, 200);
      // أفقيًا: 100 نقطة متاحة على كل جانب، رأسيًا لا شيء.
      final Offset clamped = CropMath.clampPan(
        const Offset(1000, 1000),
        displayed: displayed,
        cropSide: 200,
      );
      expect(clamped.dx, closeTo(100, 0.001));
      expect(clamped.dy, 0, reason: 'لا هامش رأسي في صورة تغطّي الإطار بالضبط');
    });

    test('صورة أصغر من الإطار لا تُزيح (التغطية تكبّرها أولًا)', () {
      final Size displayed = CropMath.displayedSize(
        imageSize: const Size(40, 40),
        cropSide: 200,
        zoom: 1,
      );
      expect(displayed.width, closeTo(200, 0.001));
      expect(
        CropMath.clampPan(const Offset(50, -50), displayed: displayed, cropSide: 200),
        Offset.zero,
      );
    });

    test('أبعاد صفرية لا تُنتج NaN', () {
      expect(
        CropMath.coverScale(imageSize: Size.zero, cropSide: 200),
        1,
      );
      expect(
        CropMath.displayedSize(
          imageSize: Size.zero,
          cropSide: 200,
          zoom: 1,
        ),
        Size.zero,
      );
    });
  });
}
