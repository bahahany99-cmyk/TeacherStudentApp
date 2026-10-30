import 'dart:io';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';

import 'package:teacher_student_app/app/shell/app_shell.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/app_background.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';

import '../helpers/test_app.dart';

/// اختبارات «النسخة 3» من النظام البصري: Edge-to-Edge، البطاقات البيضاء
/// العائمة، واختفاء الكتل المشبعة.
///
/// (P21) مجموعة «شريحة وضع الزائر» حُذفت مع الويدجت نفسه: لا شريحة تطوير في
/// واجهة الإنتاج، فلا شيء يُقاس.
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

  group('بطاقات بيضاء عائمة', () {
    testWidgets('البطاقة بيضاء بحواف البطاقة المعتمدة وظلين بالضبط', (
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
      // (P26) نصف قطر البطاقة صار 20 — نتبع الرمز لا رقمًا مكرّرًا هنا.
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppSpacing.radiusCard),
      );
      expect(decoration.boxShadow, AppShadows.card);
      expect(decoration.boxShadow!.length, 2);

      final Border border = decoration.border! as Border;
      expect(border.top.width, 1.2);
      expect(border.top.color.a, closeTo(0.8, 0.01));
    });
  });

  group('الهوية 5 — نيلي درسلي', () {
    test('الهوية نيلية (أزرق مسيطر) والخلفية باردة لا وردية', () {
      final Color seed = AppColors.seed;
      // أزرق صريح: القناة الزرقاء هي الأقوى بوضوح.
      expect(seed.b, greaterThan(seed.r));
      expect(seed.b, greaterThan(seed.g));
      // تباين كافٍ للنص على الأبيض (≥ 4.5:1).
      expect(_contrastOnWhite(seed), greaterThanOrEqualTo(4.5));

      // الخلفية باردة هادئة، لا بيضاء مسطّحة ولا وردية.
      final Color background = AppColors.lightBackground;
      expect(background, isNot(Colors.white));
      expect(background.b, greaterThanOrEqualTo(background.r));
    });

    test('الحالات الدلالية متمايزة وقابلة للقراءة', () {
      final List<Color> statuses = <Color>[
        AppColors.statusAccepted,
        AppColors.statusPending,
        AppColors.statusRejected,
        AppColors.statusNeutral,
        AppColors.statusInfo,
      ];
      // لا لونان متطابقان: كل حالة تُقرأ بلونها.
      expect(statuses.toSet().length, statuses.length);
      for (final Color status in statuses) {
        expect(
          _contrastOnWhite(status),
          greaterThanOrEqualTo(4.5),
          reason: 'الحالة $status غير مقروءة على الأبيض',
        );
      }
      // «مقبول» أخضر (الثقة) و«مرفوض» أحمر — إشارة صريحة لا رمادية.
      expect(
        AppColors.statusAccepted.g,
        greaterThan(AppColors.statusAccepted.r),
      );
      expect(
        AppColors.statusRejected.r,
        greaterThan(AppColors.statusRejected.g),
      );
    });

    test('النصوص الأساسية فوق حد التباين المقروء', () {
      expect(_contrastOnWhite(AppColors.textPrimary), greaterThanOrEqualTo(7));
      expect(_contrastOnWhite(AppColors.textSecondary), greaterThanOrEqualTo(4.5));
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

    testWidgets('(P28) صف حالة الملف على سطر واحد بلا فيض', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('واجهة المدرس'));
      expect(find.byType(AppShell), findsOneWidget);

      // (P28) البطاقة الضخمة أُلغيت: صف واحد يحمل العنوان وشارة الحالة وأيقونة
      // تعديل. الاختبار يحرس الحدّ الأعلى للارتفاع كي لا تعود البطاقة.
      final Finder onboarding = find.byKey(
        const Key('teacher-onboarding-card'),
      );
      final Finder status = find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppCard &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'teacher-status-card-',
            ),
      );
      expect(
        onboarding.evaluate().isNotEmpty || status.evaluate().isNotEmpty,
        isTrue,
        reason: 'لا صفّ حالة ملف على الرئيسية',
      );
      final Finder shown = onboarding.evaluate().isNotEmpty ? onboarding : status;
      expect(tester.getSize(shown.first).height, lessThanOrEqualTo(160));
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
    test('التدرّج ينتهي بخلفية الصفحة المعتمة (لا تسرّب تحته)', () {
      final LinearGradient page = AppGradients.page;

      expect(page.begin, Alignment.topCenter);
      expect(page.colors.first, AppColors.blushTop);
      expect(
        page.colors.last,
        AppColors.lightBackground,
        reason: '(P28) الشريط ينتهي بلون خلفية الصفحة: البطاقات البيضاء '
            'تحتاج خلفية مختلفة عنها لتبدو أسطحًا لا صفحة واحدة مسطّحة',
      );
      expect(page.colors.last.a, 1.0, reason: 'الخلفية معتمة لا شفافة');
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


/// تباين لون على خلفية بيضاء وفق WCAG: (1.05) / (L + 0.05).
///
/// `Color.r/g/b` في هذه النسخة من Flutter قيم كسرية 0..1، فالحساب مباشر بلا
/// تحويل.
double _contrastOnWhite(Color color) {
  double linear(double channel) => channel <= 0.03928
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

  final double luminance =
      0.2126 * linear(color.r) +
      0.7152 * linear(color.g) +
      0.0722 * linear(color.b);
  return 1.05 / (luminance + 0.05);
}
