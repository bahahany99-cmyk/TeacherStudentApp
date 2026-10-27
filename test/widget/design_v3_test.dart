import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/shell/app_shell.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
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
        expect(wash.g, lessThanOrEqualTo(wash.r));
      }
    });

    test('الحالات الدلالية خالية من الأخضر', () {
      for (final Color status in <Color>[
        AppColors.statusAccepted,
        AppColors.statusPending,
        AppColors.statusRejected,
        AppColors.statusNeutral,
      ]) {
        expect(
          status.g,
          lessThanOrEqualTo(status.r),
          reason: 'اللون $status ليس أخضر مسيطرًا',
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
}
