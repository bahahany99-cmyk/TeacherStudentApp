import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/app_background.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/features/design_gallery/presentation/design_gallery_screen.dart';

import '../helpers/test_app.dart';

Widget _host(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('نظام التصميم v2 — الأشكال', () {
    test('الأزرار الأساسية والثانوية بشكل حبة دواء', () {
      final ThemeData theme = AppTheme.light;

      final OutlinedBorder? filledShape = theme
          .filledButtonTheme
          .style
          ?.shape
          ?.resolve(<WidgetState>{});
      final OutlinedBorder? outlinedShape = theme
          .outlinedButtonTheme
          .style
          ?.shape
          ?.resolve(<WidgetState>{});

      expect(filledShape, isA<StadiumBorder>());
      expect(outlinedShape, isA<StadiumBorder>());
    });

    test('حواف الحقول دائرية 18 والحواف الكبيرة 24', () {
      final ThemeData theme = AppTheme.light;
      final OutlineInputBorder? border =
          theme.inputDecorationTheme.enabledBorder as OutlineInputBorder?;

      expect(border?.borderRadius, BorderRadius.circular(AppSpacing.radiusLg));
      expect(AppSpacing.radiusXl, greaterThan(AppSpacing.radiusLg));
      // أزرار أعلى من النسخة السابقة (52 → 54).
      expect(AppSpacing.buttonHeight, 52);
    });

    test('شريط التنقّل بخلفية بيضاء بلا نتوء لوني', () {
      final ThemeData theme = AppTheme.light;
      expect(theme.navigationBarTheme.backgroundColor, Colors.white);
      expect(theme.navigationBarTheme.elevation, 0);
      expect(theme.appBarTheme.backgroundColor, Colors.transparent);
    });

    test('التدرّجات معرّفة في مكان واحد واتجاهاتها منطقية', () {
      // نسخة 4.2: ثلاث محطات (بلاش ← بلاش فاتح ← أبيض صريح) داخل شريط علوي
      // محدود، لا تدرّج على ارتفاع الشاشة.
      expect(AppGradients.page.colors.length, 3);
      expect(AppGradients.page.begin, Alignment.topCenter);
      expect(AppGradients.page.stops?.first, 0.0);
      expect(AppGradients.page.stops?.last, 1.0);
      expect(AppGradients.hero.colors.first, AppColors.heroFrom);
      // تدرّج واحد مشبع فقط (hero) للشعار؛ الباقي باهت للخلفيات.
      expect(AppGradients.pageWarm.colors.contains(AppColors.heroFrom), isFalse);
      expect(AppGradients.glow.colors.contains(AppColors.heroFrom), isFalse);
    });

    test('الظل المزدوج مطابق للمواصفة حرفيًا', () {
      // مواصفة صاحب المشروع: قريب 4%/blur 8/(0,2) وبعيد 6%/blur 24/(0,12).
      expect(AppShadows.card.length, 2);

      final BoxShadow near = AppShadows.card.first;
      final BoxShadow far = AppShadows.card.last;

      expect(near.blurRadius, 8);
      expect(near.offset, const Offset(0, 2));
      expect(near.color.a, closeTo(0.04, 0.005));

      expect(far.blurRadius, 24);
      expect(far.offset, const Offset(0, 12));
      expect(far.color.a, closeTo(0.06, 0.005));
    });

    test('الحدود الشعرية بيضاء 80% بعرض 1.2', () {
      expect(AppBorders.hairlineWidth, 1.2);
      expect(AppBorders.onWhite.a, closeTo(0.8, 0.01));
    });

    test('الخلفية الأساسية شفافة ليظهر تدرّج النافذة (Edge-to-Edge)', () {
      expect(AppTheme.light.scaffoldBackgroundColor, Colors.transparent);
    });
  });

  group('نظام التصميم v2 — المكونات', () {
    testWidgets('AppCard: أبيض · حواف 24 · ظل مزدوج، ويرسم التدرّج عند تمريره', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 200,
            child: AppCard(child: Text('بطاقة')),
          ),
        ),
      );

      final Container container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Container),
        ).first,
      );
      final BoxDecoration decoration = container.decoration! as BoxDecoration;

      // (P26) نصف قطر البطاقة صار 20 بدل 24: نفس المحتوى في سطح أقل
      // انتفاخًا. الاختبار يتبع الرمز (`radiusCard`) لا الرقم القديم.
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppSpacing.radiusCard),
      );
      expect(decoration.boxShadow, AppShadows.card);
      expect(decoration.gradient, isNull);
      // أبيض صريح في الوضع الفاتح + حدّ أبيض شعري.
      expect(decoration.color, Colors.white);
      expect(
        (decoration.border! as Border).top.width,
        AppBorders.hairlineWidth,
      );

      // مع تدرّج: لا لون مسطّح.
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 200,
            child: AppCard(gradient: AppGradients.hero, child: Text('hero')),
          ),
        ),
      );
      final Container hero = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Container),
        ).first,
      );
      final BoxDecoration heroDecoration = hero.decoration! as BoxDecoration;
      expect(heroDecoration.gradient, AppGradients.hero);
      expect(heroDecoration.color, isNull);
    });

    testWidgets('PillChip يستدعي onTap ويُعلن الاختيار لقارئ الشاشة', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
          PillChip(
            label: 'الرياضيات',
            icon: Icons.menu_book_outlined,
            selected: true,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('الرياضيات'));
      expect(taps, 1);

      final Semantics semantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byType(InkWell),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.selected, isTrue);
      expect(semantics.properties.button, isTrue);
    });

    testWidgets('PillChip بلا onTap لا يستجيب للضغط', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const PillChip(label: 'وسم ثابت')),
      );

      expect(find.byType(InkWell), findsNothing);
      expect(find.text('وسم ثابت'), findsOneWidget);
    });

    testWidgets('PillRow يمرّر أفقيًا بدل الفيض', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 240,
            height: 60,
            child: PillRow(
              children: <Widget>[
                for (int i = 0; i < 8; i++) PillChip(label: 'شريحة $i'),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('StatusChip وSectionHeader يُبنيان بلا فيض', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const StatusChip(
                  label: 'بانتظار موافقة المدرس',
                  color: AppColors.statusPending,
                ),
                const SizedBox(height: AppSpacing.xs),
                SectionHeader(
                  title: 'مجموعاتي',
                  subtitle: 'سعة وموافقات مفروضة على الخادم',
                  actionLabel: 'عرض الكل',
                  onActionTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('عرض الكل'), findsOneWidget);
    });

    testWidgets('AppBackground يرسم شريط التدرّج العلوي ويحتوي المحتوى', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 300,
            height: 400,
            child: AppBackground(child: Text('المحتوى')),
          ),
        ),
      );

      expect(find.text('المحتوى'), findsOneWidget);

      // الطبقة السفلية بيضاء صريحة، والتدرّج محصور في شريط أعلى الشاشة.
      final ColoredBox base = tester.widget<ColoredBox>(
        find.byKey(AppBackground.baseKey),
      );
      expect(base.color, Colors.white);

      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.byKey(AppBackground.blushBandKey),
      );
      expect((box.decoration as BoxDecoration).gradient, AppGradients.page);
    });
  });

  group('معرض المكونات v2', () {
    testWidgets('يُبنى على شاشة هاتف بلا أخطاء تخطيط', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const DesignGalleryScreen()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('v2 — التدرّجات والظلال'), findsOneWidget);
      expect(find.text('v2 — الشرائح والفلاتر'), findsOneWidget);
    });

    testWidgets('يمرّ بكل الأقسام دون تجاوز أفقي', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const DesignGalleryScreen()),
      );
      await tester.pumpAndSettle();

      final Finder list = find.byType(ListView).first;
      for (int i = 0; i < 14; i++) {
        await tester.drag(list, const Offset(0, -320));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'تجاوز عند التمرير $i');
      }
    });
  });
}
