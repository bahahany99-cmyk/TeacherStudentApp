import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// (P20) أصول أيقونة التطبيق.
///
/// **لماذا اختبار على ملفات ثنائية؟** لأن أيقونة خاطئة أو مفقودة لا تُكتشف
/// بترجمة ناجحة ولا باختبار واجهة: `flutter_launcher_icons` يُشغَّل في CI قبل
/// البناء، ولو كان أحد الملفات بمقاس خطأ أو بلا قناة شفافية، فإما يفشل التوليد
/// برسالة غامضة أو — الأسوأ — تُقصّ العلامة على جهاز المستخدم.
///
/// ⚠️ **فخّ مقيس:** فك ترميز صورة عبر `dart:ui` داخل `testWidgets` **لا يكتمل**
/// إلا داخل `tester.runAsync`. الـbinding الاختباري يستبدل الزمن الافتراضي
/// (fake async)، فلا تصل نتيجة محرّك الصور أبدًا ويُعلَّق الاختبار حتى مهلة CI
/// بدل أن يفشل برسالة — حدث فعلًا (تشغيل ظلّ 20+ دقيقة بلا نتيجة). لذلك كل
/// قراءة بكسل تمرّ عبر `_load` التي تستخدم `runAsync`.
const String _iconDir = 'assets/icon/';

typedef IconPixels = ({int width, int height, Uint8List pixels});

Future<IconPixels> _load(WidgetTester tester, String name) async {
  final IconPixels? result = await tester.runAsync(() async {
    final Uint8List bytes = await File('$_iconDir$name').readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    final IconPixels loaded = (
      width: image.width,
      height: image.height,
      pixels: data!.buffer.asUint8List(),
    );
    image.dispose();
    codec.dispose();
    return loaded;
  });

  return result!;
}

int _alphaAt(Uint8List pixels, int width, int x, int y) =>
    pixels[(y * width + x) * 4 + 3];

void main() {
  const List<String> files = <String>[
    'app_icon.png',
    'app_icon_foreground.png',
    'app_icon_background.png',
    'app_icon_monochrome.png',
  ];

  group('أصول الأيقونة موجودة وبالمقاس الصحيح', () {
    test('الملفات الأربعة موجودة', () {
      for (final String name in files) {
        expect(
          File('$_iconDir$name').existsSync(),
          isTrue,
          reason: '$_iconDir$name مفقود — لن يستطيع flutter_launcher_icons '
              'توليد أيقونة صحيحة',
        );
      }
    });

    testWidgets('كل ملفات الأيقونة 1024×1024 ومربّعة', (
      WidgetTester tester,
    ) async {
      for (final String name in files) {
        final IconPixels icon = await _load(tester, name);
        expect(icon.width, 1024, reason: '$name عرضه غير متوقع');
        expect(icon.height, 1024, reason: '$name ارتفاعه غير متوقع');
      }
    });
  });

  group('الطبقة الأمامية (Foreground) صالحة لقناع أندرويد', () {
    testWidgets('الزوايا شفافة والقلب معتم — العلامة منفصلة عن الخلفية', (
      WidgetTester tester,
    ) async {
      final IconPixels icon = await _load(tester, 'app_icon_foreground.png');
      final int size = icon.width;
      const int margin = 8;

      for (final (int x, int y) in <(int, int)>[
        (margin, margin),
        (size - margin, margin),
        (margin, size - margin),
        (size - margin, size - margin),
      ]) {
        expect(
          _alphaAt(icon.pixels, size, x, y),
          0,
          reason: 'الزاوية ($x,$y) غير شفافة: طبقة الخلفية لم تُفصل عن العلامة',
        );
      }

      // العلامة موسَّطة: مربّع 80×80 في القلب يحمل بكسلات معتمة كثيرة. لا نفحص
      // البكسل المركزي وحده لأن فراغًا بين صفحتي الكتاب قد يقع عنده بالضبط.
      int opaque = 0;
      const int half = 40;
      final int center = size ~/ 2;
      for (int y = center - half; y < center + half; y++) {
        for (int x = center - half; x < center + half; x++) {
          if (_alphaAt(icon.pixels, size, x, y) > 200) {
            opaque++;
          }
        }
      }
      expect(
        opaque / (half * 2 * half * 2),
        greaterThan(0.15),
        reason: 'العلامة غير موسَّطة: $opaque بكسل معتم فقط في قلب اللوحة',
      );
    });

    testWidgets('العلامة داخل المنطقة الآمنة فلا يقطعها القناع', (
      WidgetTester tester,
    ) async {
      final IconPixels icon = await _load(tester, 'app_icon_foreground.png');
      final int size = icon.width;

      // طبقة الأيقونة التكيّفية 108dp، والماسك 72dp، والدائرة **المضمونة** 66dp.
      // أي: 66/216 من العرض نصف قطرًا ⇒ 313px من 1024. ما يخرج عنها قد يقطعه
      // قناع صغير (قطرة/دائرة ضيّقة) على بعض الأجهزة.
      final double safeRadius = size * (66 / 216);
      final double center = size / 2;

      int outside = 0;
      for (int y = 0; y < size; y += 4) {
        for (int x = 0; x < size; x += 4) {
          if (_alphaAt(icon.pixels, size, x, y) < 8) {
            continue;
          }
          final double dx = x - center;
          final double dy = y - center;
          if ((dx * dx + dy * dy) > safeRadius * safeRadius) {
            outside++;
          }
        }
      }

      expect(
        outside,
        0,
        reason: 'العلامة تمتد خارج المنطقة الآمنة ($outside بكسل) — ستُقطع '
            'على أقنعة أندرويد الصغيرة',
      );
    });
  });

  group('طبقات أندرويد الأخرى', () {
    testWidgets('الخلفية تدرّج لا لون مسطّح', (WidgetTester tester) async {
      final IconPixels icon = await _load(tester, 'app_icon_background.png');
      final int size = icon.width;

      int minLuma = 255;
      int maxLuma = 0;
      for (int y = 0; y < size; y += 16) {
        for (int x = 0; x < size; x += 16) {
          final int offset = (y * size + x) * 4;
          final int luma =
              (icon.pixels[offset] +
                  icon.pixels[offset + 1] +
                  icon.pixels[offset + 2]) ~/
              3;
          if (luma < minLuma) {
            minLuma = luma;
          }
          if (luma > maxLuma) {
            maxLuma = luma;
          }
        }
      }

      // تدرّج الهوية يمتد من كحلي غامق إلى وردي فاتح: فرق واضح في السطوع.
      expect(
        maxLuma - minLuma,
        greaterThan(25),
        reason: 'الخلفية مسطّحة (فرق السطوع $maxLuma-$minLuma) — التدرّج فُقد',
      );
    });

    testWidgets('الأحاديّة (Monochrome) ظلّية بيضاء بقناع شفاف للعلامة', (
      WidgetTester tester,
    ) async {
      final IconPixels icon = await _load(tester, 'app_icon_monochrome.png');
      final int size = icon.width;

      // الزاوية شفافة، والقلب أبيض صريح: هذا ما تتوقعه «أيقونات النظام».
      expect(_alphaAt(icon.pixels, size, 8, 8), 0);

      int whiteOpaque = 0;
      final int center = size ~/ 2;
      for (int y = center - 40; y < center + 40; y++) {
        for (int x = center - 40; x < center + 40; x++) {
          final int offset = (y * size + x) * 4;
          if (_alphaAt(icon.pixels, size, x, y) > 200 &&
              icon.pixels[offset] == 255 &&
              icon.pixels[offset + 1] == 255 &&
              icon.pixels[offset + 2] == 255) {
            whiteOpaque++;
          }
        }
      }
      expect(whiteOpaque, greaterThan(500));
    });
  });
}
