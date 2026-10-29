import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// (P20) أصول أيقونة التطبيق.
///
/// **لماذا اختبار على ملفات ثنائية؟** لأن أيقونة خاطئة أو مفقودة لا تُكتشف
/// بترجمة ناجحة ولا باختبار واجهة: `flutter_launcher_icons` يُشغَّل في CI قبل
/// البناء، ولو كان أحد الملفات مربّعًا بغير المتوقع أو بلا قناة شفافية، فإما
/// يفشل التوليد برسالة غامضة أو — الأسوأ — تُقصّ العلامة على جهاز المستخدم.
/// هذا الملف يقيس الخصائص الأربع التي يعتمد عليها التوليد.
const String _iconDir = 'assets/icon/';

Future<({int width, int height, ui.Image image})> _decode(String name) async {
  final Uint8List bytes = await File('$_iconDir$name').readAsBytes();
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ui.Image image = frame.image;
  addTearDown(image.dispose);
  return (width: image.width, height: image.height, image: image);
}

/// بكسلات RGBA لصورة كاملة (ترتيب القنوات: R,G,B,A لكل بكسل).
Future<Uint8List> _pixels(ui.Image image) async {
  final ByteData? data = await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  return data!.buffer.asUint8List();
}

int _alphaAt(Uint8List pixels, int width, int x, int y) =>
    pixels[(y * width + x) * 4 + 3];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('أصول الأيقونة موجودة وبالمقاس الصحيح', () {
    const List<String> files = <String>[
      'app_icon.png',
      'app_icon_foreground.png',
      'app_icon_background.png',
      'app_icon_monochrome.png',
    ];

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
        final ({int width, int height, ui.Image image}) decoded =
            await _decode(name);
        expect(decoded.width, 1024, reason: '$name عرضه غير متوقع');
        expect(decoded.height, 1024, reason: '$name ارتفاعه غير متوقع');
      }
    });
  });

  group('الطبقة الأمامية (Foreground) صالحة لقناع أندرويد', () {
    testWidgets('الزوايا شفافة والوسط معتم — أي أن العلامة منفصلة عن الخلفية', (
      WidgetTester tester,
    ) async {
      final ({int width, int height, ui.Image image}) decoded = await _decode(
        'app_icon_foreground.png',
      );
      final Uint8List pixels = await _pixels(decoded.image);
      const int size = 1024;
      const int margin = 8;

      for (final (int x, int y) in <(int, int)>[
        (margin, margin),
        (size - margin, margin),
        (margin, size - margin),
        (size - margin, size - margin),
      ]) {
        expect(
          _alphaAt(pixels, decoded.width, x, y),
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
          if (_alphaAt(pixels, decoded.width, x, y) > 200) {
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

    testWidgets('العلامة داخل المنطقة الآمنة (66%) فلا يقطعها القناع', (
      WidgetTester tester,
    ) async {
      final ({int width, int height, ui.Image image}) decoded = await _decode(
        'app_icon_foreground.png',
      );
      final Uint8List pixels = await _pixels(decoded.image);
      final int width = decoded.width;

      // طبقة الأيقونة التكيّفية 108dp، والماسك 72dp، والدائرة **المضمونة** 66dp.
      // أي: 66/216 من العرض نصف قطرًا ⇒ 313px من 1024. ما يخرج عنها قد يقطعه
      // قناع صغير (قطرة/دائرة ضيّقة) على بعض الأجهزة.
      final double safeRadius = width * (66 / 216);
      final double center = width / 2;

      int outside = 0;
      for (int y = 0; y < width; y += 4) {
        for (int x = 0; x < width; x += 4) {
          if (_alphaAt(pixels, width, x, y) < 8) {
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
    testWidgets('الخلفية تدرّج لا لون مسطّح (الصورة ليست بكسل واحد مكرّر)', (
      WidgetTester tester,
    ) async {
      final ({int width, int height, ui.Image image}) decoded = await _decode(
        'app_icon_background.png',
      );
      final Uint8List pixels = await _pixels(decoded.image);
      final int width = decoded.width;

      int minLuma = 255;
      int maxLuma = 0;
      for (int y = 0; y < decoded.height; y += 16) {
        for (int x = 0; x < width; x += 16) {
          final int offset = (y * width + x) * 4;
          final int luma =
              (pixels[offset] + pixels[offset + 1] + pixels[offset + 2]) ~/ 3;
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
      final ({int width, int height, ui.Image image}) decoded = await _decode(
        'app_icon_monochrome.png',
      );
      final Uint8List pixels = await _pixels(decoded.image);
      final int width = decoded.width;

      // الزاوية شفافة، والمركز أبيض صريح: هذا ما تتوقعه «أيقونات النظام».
      expect(_alphaAt(pixels, width, 8, 8), 0);
      final int center = ((width ~/ 2) * width + (width ~/ 2)) * 4;
      expect(pixels[center], 255);
      expect(pixels[center + 1], 255);
      expect(pixels[center + 2], 255);
    });
  });
}
