import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/features/auth/presentation/widgets/google_sign_in_button.dart';

import '../helpers/test_app.dart';

/// (P18) زر Google بالشكل المعتمد: خلفية بيضاء + الشعار الرسمي.
void main() {
  Future<void> pumpLogin(WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(buildTestApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  group('زر المتابعة باستخدام Google', () {
    testWidgets('يظهر في شاشة الدخول بخلفية بيضاء (لا لون الهوية)', (
      WidgetTester tester,
    ) async {
      await pumpLogin(tester);

      final Finder button = find.byType(GoogleSignInButton);
      expect(button, findsOneWidget);

      final Material material = tester.widget<Material>(
        find
            .descendant(of: button, matching: find.byType(Material))
            .first,
      );
      // شرط العلامة التجارية: الخلفية بيضاء صريحة، وليست لون التطبيق.
      expect(material.color, Colors.white);
    });

    testWidgets('يستخدم شعار Google الرسمي (أصل صور) لا حرفًا ولا أيقونة', (
      WidgetTester tester,
    ) async {
      await pumpLogin(tester);

      final Finder imageFinder = find.descendant(
        of: find.byType(GoogleSignInButton),
        matching: find.byType(Image),
      );
      expect(imageFinder, findsOneWidget);

      final Image image = tester.widget<Image>(imageFinder);
      final AssetImage provider = image.image as AssetImage;
      expect(provider.assetName, 'assets/images/google_g.png');
      expect(image.width, 20);
      expect(image.height, 20);

      // لا يوجد نص «G» بديل داخل الزر.
      expect(
        find.descendant(
          of: find.byType(GoogleSignInButton),
          matching: find.text('G'),
        ),
        findsNothing,
      );
    });

    testWidgets('نصه هو نص الموافقة المُعتمد', (WidgetTester tester) async {
      await pumpLogin(tester);

      expect(
        find.descendant(
          of: find.byType(GoogleSignInButton),
          matching: find.text('المتابعة باستخدام Google'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('حدّه الرمادي #DADCE0 وحوافه دائرية كاملة', (
      WidgetTester tester,
    ) async {
      await pumpLogin(tester);

      final Container container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(GoogleSignInButton),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration decoration = container.decoration! as BoxDecoration;
      final Border border = decoration.border! as Border;

      expect(border.top.color, const Color(0xFFDADCE0));
      expect(container.constraints?.maxHeight, isNotNull);
    });
  });
}
