import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/shell/app_shell.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/app_background.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';

import '../helpers/test_app.dart';

/// اختبارات «النسخة 3» من النظام البصري (2026-10-27): Edge-to-Edge، الشريحة
/// الدقيقة لوضع الزائر، البطاقات البيضاء العائمة، واختفاء الكتل المشبعة.
void main() {
  group('Edge-to-Edge', () {
    test('خلفية الـScaffold شفافة لتمرّ خلفية النافذة المتدرّجة', () {
      expect(AppTheme.light.scaffoldBackgroundColor, Colors.transparent);
      expect(AppTheme.dark.scaffoldBackgroundColor, Colors.transparent);
    });

    test('شريط الحالة والمحتوى خلفه: أيقونات داكنة وخلفية شفافة', () {
      final SystemUiOverlayStyle? style = AppTheme
          .light
          .appBarTheme
          .systemOverlayStyle;

      expect(style, isNotNull);
      expect(style!.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarColor, Colors.transparent);
    });
  });

  group('شريحة وضع الزائر الدقيقة', () {
    testWidgets('سطر واحد وارتفاع صغير (ليست صندوقًا تحذيريًا)', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Padding(
              padding: AppSpacing.pagePadding,
              child: DemoBanner(),
            ),
          ),
        ),
      );

      // نقيس الشريحة نفسها (لا الهامش السفلي حولها).
      final Size size = tester.getSize(
        find
            .descendant(
              of: find.byType(DemoBanner),
              matching: find.byType(Container),
            )
            .first,
      );
      // الارتفاع السابق كان نحو 60+ مع أيقونة وسطرين؛ الآن سطر واحد دقيق.
      expect(size.height, lessThan(34));

      final Text text = tester.widget<Text>(
        find.text('وضع الزائر · بيانات تجريبية'),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('قارئ الشاشة يسمع النص الكامل لا المختصر', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Padding(
              padding: AppSpacing.pagePadding,
              child: DemoBanner(),
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(
          'وضع الزائر: بيانات تجريبية محلية بلا حساب ولا اتصال بخادم.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('بطاقات بيضاء عائمة', () {
    testWidgets('البطاقة بيضاء بحواف 24 وحدّ أبيض وظلين بالضبط', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: SizedBox(width: 280, child: AppCard(child: Text('بطاقة'))),
            ),
          ),
        ),
      );

      final Container container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration decoration = container.decoration! as BoxDecoration;

      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, BorderRadius.circular(24));
      expect(decoration.boxShadow, AppShadows.card);
      expect(decoration.boxShadow!.length, 2);

      final Border border = decoration.border! as Border;
      expect(border.top.width, 1.2);
      expect(border.top.color.a, closeTo(0.8, 0.01));
    });
  });

  group('لوحة v4 — وردي فاخر بلا أخضر', () {
    test('الهوية وردية والغسيل وردي/لافندر', () {
      // اللون الأساسي وردي عميق (قناة حمراء أعلى من الخضراء والزرقاء).
      final Color seed = AppColors.seed;
      expect(seed.r, greaterThan(seed.g));
      expect(seed.b, greaterThan(seed.g));

      // لا بقايا نعناع/أخضر في خلفيات الغسيل.
      for (final Color wash in <Color>[
        AppColors.washRose,
        AppColors.washLilac,
        AppColors.washPeach,
      ]) {
        // دافئة/وردية: الأحمر هو القناة الأقوى أو مساوٍ للأخضر.
        expect(wash.r, greaterThanOrEqualTo(wash.g));
      }
    });

    test('الحالات الدلالية خالية من الأخضر', () {
      // القاعدة: الأخضر ليس القناة الأقوى (لا لون «أخضر» أو «نعناعي»)، وهو
      // تحقّق أعم من مقارنة الأحمر فقط لأن الأزرق الرمادي مقبول.
      for (final Color status in <Color>[
        AppColors.statusAccepted,
        AppColors.statusPending,
        AppColors.statusRejected,
        AppColors.statusNeutral,
      ]) {
        final double maxOther = status.r > status.b ? status.r : status.b;
        expect(
          status.g,
          lessThanOrEqualTo(maxOther),
          reason: 'اللون $status أخضر مسيطر',
        );
      }
    });

    test('لا لون أخضر هوية قديم في أي مكان من الشجرة', () {
      // 0E7C66 كان لون الهوية القديم؛ نتأكد أنه لم يبقَ في أي مصدر.
      final Directory lib = Directory('lib');
      final RegExp oldGreen = RegExp(r'0x[Ff]{2}0E7C66|0x[Ff]{2}0A5D4C');
      final List<String> offenders = <String>[];
      for (final FileSystemEntity entity in lib.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          if (oldGreen.hasMatch(entity.readAsStringSync())) {
            offenders.add(entity.path);
          }
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('لا كتل لونية مشبعة', () {
    test('بطاقة «لمعة» شديدة الخفة: لا لون الهوية المشبع داخلها', () {
      expect(AppGradients.glow.colors.contains(AppColors.heroFrom), isFalse);
      expect(AppGradients.glow.colors.contains(AppColors.heroTo), isFalse);
      // التدرّج المشبع محصور في الشعار فقط.
      expect(AppGradients.hero.colors, <Color>[
        AppColors.heroFrom,
        AppColors.heroTo,
      ]);
    });
  });

  group('الشاشات على هاتف 360×720', () {
    testWidgets('واجهة الطالب تبني بلا فيض ولا كتلة مشبعة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // الدخول كزائر (طالب) من شاشة الدخول.
      await tapVisible(tester, find.text('واجهة الطالب'));
      expect(find.byType(AppShell), findsOneWidget);

      // لا AppCard بتدرّج الهوية المشبع في أي مكان.
      final Iterable<AppCard> cards = tester.widgetList<AppCard>(
        find.byType(AppCard),
      );
      expect(
        cards.any((AppCard c) => c.gradient == AppGradients.hero),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('أزرار البطاقة التمهيدية للمدرس في سطر واحد بلا فيض', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('واجهة المدرس'));
      expect(find.byType(AppShell), findsOneWidget);

      // النصان ظاهران كاملين (بلا التفاف إلى سطرين) — سبب العطل المرصود.
      final Finder profile = find.text('ملفي التعريفي');
      final Finder addGroup = find.text('إضافة مجموعة');
      expect(profile, findsWidgets);
      expect(addGroup, findsWidgets);

      final Text profileText = tester.widget<Text>(profile.first);
      expect(profileText.maxLines, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('صف الفلاتر في شاشة المدرسين يمرّر أفقيًا بلا التفاف', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('واجهة الطالب'));
      await tapVisible(tester, find.text('المدرسون'));

      expect(find.byType(PillRow), findsWidgets);
      expect(find.byType(PillChip), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('لوحة v4.2 — صفحة بيضاء وشريط بلاش علوي فقط', () {
    test('التدرّج ينتهي بأبيض صريح معتم (لا تسرّب تحته)', () {
      final LinearGradient page = AppGradients.page;

      expect(page.begin, Alignment.topCenter);
      expect(page.colors.first, AppColors.blushTop);
      expect(
        page.colors.last,
        Colors.white,
        reason: 'حافة الشريط السفلية يجب أن تكون بيضاء معتمة',
      );
      expect(page.colors.last.a, 1.0, reason: 'الأبيض معتم لا شفاف');
      expect(page.stops!.last, 1.0);
      // لا لافندر ولا أي غسيل أسفل الشريط.
      expect(page.colors.contains(AppColors.washLilac), isFalse);
    });

    test('شريط البلاش ≤ 20% من الشاشة وسقفه 200 نقطة', () {
      expect(AppBackground.blushHeightFactor, lessThanOrEqualTo(0.2));

      // على هاتف 720dp: 144dp شريط، و576dp (80%) أبيض صريح.
      final double phone = AppBackground.blushHeightFor(720);
      expect(phone, closeTo(144, 0.01));
      expect(phone / 720, lessThanOrEqualTo(0.2));

      // على شاشة طويلة لا يتضخّم الشريط بلا حد.
      expect(
        AppBackground.blushHeightFor(2000),
        lessThanOrEqualTo(AppBackground.blushMaxHeight),
      );
    });

    testWidgets('الخلفية: أبيض صريح + شريط أعلى الشاشة فقط', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const AppBackground(
            child: Scaffold(body: Center(child: Text('محتوى'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1) الطبقة السفلية بيضاء صريحة.
      final ColoredBox base = tester.widget<ColoredBox>(
        find.byKey(AppBackground.baseKey),
      );
      expect(base.color, Colors.white);

      // 2) الشريط محصور في الأعلى بارتفاع محسوب، ولا يغطّي منتصف الشاشة.
      final Finder band = find.byKey(AppBackground.blushBandKey);
      expect(band, findsOneWidget);

      final Size bandSize = tester.getSize(band);
      final double screenHeight = tester.view.physicalSize.height /
          tester.view.devicePixelRatio;
      expect(
        bandSize.height / screenHeight,
        lessThanOrEqualTo(0.205),
        reason: 'الشريط يجب ألا يتجاوز 20% من الشاشة',
      );
      expect(tester.getTopLeft(band).dy, 0);
      // المنتصف (حيث البطاقات) خارج الشريط ⇒ أبيض.
      expect(
        tester.getBottomLeft(band).dy,
        lessThan(screenHeight * 0.5),
      );
    });

    test('البلاش داخل «النقطة الحلوة»: لا باهت ولا صارخ', () {
      final HSLColor blush = HSLColor.fromColor(AppColors.blushTop);

      // فاتح جدًا (L عالٍ) لكنه ليس أبيض مغبَّشًا: تشبّع كافٍ ليكون مرئيًا.
      expect(blush.lightness, greaterThanOrEqualTo(0.85));
      expect(blush.lightness, lessThanOrEqualTo(0.97));
      expect(blush.saturation, greaterThanOrEqualTo(0.35));
      expect(blush.saturation, lessThanOrEqualTo(0.75));
      // قناة حمراء أعلى من الخضراء والزرقاء ⇒ وردي دافئ لا أخضر ولا رمادي.
      expect(AppColors.blushTop.r, greaterThan(AppColors.blushTop.g));
      expect(AppColors.blushTop.b, greaterThan(AppColors.blushTop.g));
    });

    test('النص داكن بتباين حادّ على الأبيض', () {
      final double white = Colors.white.computeLuminance();

      double contrast(Color color) {
        final double lum = color.computeLuminance();
        final double lighter = lum > white ? lum : white;
        final double darker = lum > white ? white : lum;
        return (lighter + 0.05) / (darker + 0.05);
      }

      // WCAG AAA للمتون العادية هو 7:1؛ ونطلب أكثر لأن النص «حادّ».
      expect(contrast(AppColors.textPrimary), greaterThanOrEqualTo(15));
      expect(contrast(AppColors.textSecondary), greaterThanOrEqualTo(6));
      expect(AppTheme.light.colorScheme.onSurface, AppColors.textPrimary);
      expect(AppTheme.light.colorScheme.surface, Colors.white);
    });

    test('لا لون أخضر في أي هكس داخل lib (القناة الخضراء ليست الأعلى)', () {
      // فحص شامل بدل مطاردة ألوان بعينها: أي هكس في الشجرة تكون فيه G أكبر
      // من R وB يفشل — وهذا يغطي «أخضر»، «نعناعي»، «ليموني»، «زيتوني».
      final RegExp hex = RegExp(r'0x[Ff][Ff]([0-9A-Fa-f]{6})');
      final List<String> offenders = <String>[];

      for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        for (final RegExpMatch match in hex.allMatches(entity.readAsStringSync())) {
          final String digits = match.group(1)!;
          final int r = int.parse(digits.substring(0, 2), radix: 16);
          final int g = int.parse(digits.substring(2, 4), radix: 16);
          final int b = int.parse(digits.substring(4, 6), radix: 16);
          if (g > r && g > b) {
            offenders.add('${entity.path}: 0x$digits');
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('، '));
    });
  });
}
