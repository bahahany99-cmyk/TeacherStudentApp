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
      final InputBorder? border = theme.inputDecorationTheme.enabledBorder
          as OutlineInputBorder?;

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
      expect(AppGradients.page.colors.length, 3);
      expect(AppGradients.page.begin, Alignment.topCenter);
      expect(AppGradients.hero.colors.first, AppColors.heroFrom);
      // تدرّج واحد مشبع فقط (hero) — الباقي باهت للخلفيات.
      expect(AppGradients.pageWarm.colors.contains(AppColors.heroFrom), isFalse);
    });

    test('الظل المزدوج رقيق (شفافية أقل من 15%)', () {
      for (final BoxShadow shadow in AppShadows.card) {
        expect(shadow.color.a, lessThan(0.2));
      }
      expect(AppShadows.card.length, 2);
    });
  });

  group('نظام التصميم v2 — المكونات', () {
    testWidgets('AppCard بحواف 24 وظل، ويرسم التدرّج عند تمريره', (
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

      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppSpacing.radiusXl),
      );
      expect(decoration.boxShadow, isNotEmpty);
      expect(decoration.gradient, isNull);

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

    testWidgets('AppBackground يرسم تدرّجًا ويحتوي المحتوى', (
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

      final DecoratedBox box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppBackground),
              matching: find.byType(DecoratedBox),
            )
            .first,
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
