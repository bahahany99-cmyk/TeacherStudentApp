import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/config/app_identity.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/theme/app_typography.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/features/design_gallery/presentation/design_gallery_screen.dart';

import '../helpers/test_app.dart';

void main() {
  group('نظام التصميم (P1)', () {
    test('الخط المعتمد هو Cairo ومسجَّل على كل أنماط النص', () {
      expect(AppTypography.fontFamily, 'Cairo');

      final ThemeData theme = AppTheme.light;
      final List<TextStyle?> styles = <TextStyle?>[
        theme.textTheme.displaySmall,
        theme.textTheme.headlineSmall,
        theme.textTheme.titleMedium,
        theme.textTheme.bodyLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.labelSmall,
      ];

      for (final TextStyle? style in styles) {
        expect(style?.fontFamily, 'Cairo', reason: 'نمط بلا خط Cairo: $style');
      }
    });

    test('أوزان النص المستخدمة ضمن الأوزان المسجّلة (400/600/700)', () {
      const Set<int> registered = <int>{400, 600, 700};
      final ThemeData theme = AppTheme.light;
      final List<TextStyle?> styles = <TextStyle?>[
        theme.textTheme.displaySmall,
        theme.textTheme.headlineMedium,
        theme.textTheme.headlineSmall,
        theme.textTheme.titleLarge,
        theme.textTheme.titleMedium,
        theme.textTheme.bodyLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.labelLarge,
        theme.textTheme.labelSmall,
      ];

      for (final TextStyle? style in styles) {
        final int weight = (style?.fontWeight ?? FontWeight.w400).value;
        expect(
          registered,
          contains(weight),
          reason: 'وزن غير مسجّل ($weight) سيُصنَّعه المحرك ويبدو رديئًا بالعربية',
        );
      }
    });

    test('ارتفاع السطر مناسب للعربية', () {
      final ThemeData theme = AppTheme.light;
      expect(theme.textTheme.bodyLarge!.height, greaterThanOrEqualTo(AppTypography.minLineHeight));
      expect(theme.textTheme.bodyMedium!.height, greaterThanOrEqualTo(AppTypography.minLineHeight));
    });

    test('الهوية المؤقتة: الاسم الظاهر «درسلي» ومعلَّم كغير نهائي', () {
      expect(AppIdentity.displayName, 'درسلي');
      expect(AppIdentity.isProvisional, isTrue);
      expect(AppIdentity.technicalId, 'teacher_student_app');
    });
  });

  group('معرض المكونات', () {
    testWidgets('يُبنى بلا أخطاء تخطيط على شاشة هاتف', (WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const DesignGalleryScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('الهوية والخط'), findsOneWidget);
      expect(find.text(AppIdentity.displayName), findsWidgets);
    });

    testWidgets('يمرّ بكل الأقسام دون تجاوز أفقي', (WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const DesignGalleryScreen()),
      );
      await tester.pumpAndSettle();

      // نمرّ على القسم الأخير للتأكد من سلامة التخطيط في كل الأقسام.
      final Finder last = find.text('اختبار الاتجاه (RTL)');
      await tester.scrollUntilVisible(last, 320, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      expect(last, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppCard يعرض محتواه ويمكن الضغط عليه', (WidgetTester tester) async {
      usePhoneSurface(tester);
      int taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppCard(
              onTap: () => taps++,
              child: const Text('محتوى البطاقة'),
            ),
          ),
        ),
      );

      expect(find.text('محتوى البطاقة'), findsOneWidget);
      await tester.tap(find.byType(AppCard));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('StatusChip يقصّ النص الطويل ولا يفيض', (WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SizedBox(
              width: 120,
              child: StatusChip(
                label: 'نص طويل جدًا لاختبار القص والاختصار',
                color: Color(0xFFB26A00),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('نص طويل جدًا لاختبار القص والاختصار'), findsOneWidget);
    });
  });
}
