import 'package:flutter/material.dart';

/// نظام الخطوط (Typography).
///
/// الخط المعتمد: **Cairo** (SIL OFL 1.1) بأوزان 400 / 600 / 700، مُسجَّل في
/// `pubspec.yaml` وملف ترخيصه في `assets/fonts/OFL.txt`.
///
/// ملاحظات عربية:
/// - نرفع ارتفاع السطر (line-height) لأن الحروف العربية تحتاج مساحة رأسية أكبر
///   من اللاتينية، خاصةً مع التشكيل.
/// - نستخدم أوزانًا محدودة (400/600/700) فقط، لأن أي وزن غير مُسجَّل يُصنَّعه
///   المحرك (synthetic) ويبدو رديئًا بالعربية.
abstract final class AppTypography {
  /// عائلة الخط المعتمدة.
  static const String fontFamily = 'Cairo';

  /// خطوط احتياطية في حال تعذّر تحميل Cairo (نادر، لأن الخط مضمَّن).
  static const List<String> fontFamilyFallback = <String>[
    'Noto Naskh Arabic',
    'Noto Sans Arabic',
    'Roboto',
  ];

  /// أقصر ارتفاع سطر مقبول للنص العربي.
  static const double minLineHeight = 1.6;

  /// يبني `TextTheme` عربيًا متسقًا من الثيم الأساسي.
  static TextTheme textTheme(TextTheme base) {
    TextStyle? t(TextStyle? style, double size, FontWeight weight, double height) {
      return style?.copyWith(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: 0, // تتبّع حروف لاتيني لا يناسب العربية
      );
    }

    final TextTheme sized = base.copyWith(
      displaySmall: t(base.displaySmall, 30, FontWeight.w700, 1.4),
      headlineMedium: t(base.headlineMedium, 25, FontWeight.w700, 1.4),
      headlineSmall: t(base.headlineSmall, 22, FontWeight.w700, 1.45),
      titleLarge: t(base.titleLarge, 19, FontWeight.w700, 1.45),
      titleMedium: t(base.titleMedium, 16, FontWeight.w600, 1.5),
      titleSmall: t(base.titleSmall, 14, FontWeight.w600, 1.5),
      bodyLarge: t(base.bodyLarge, 16, FontWeight.w400, 1.75),
      bodyMedium: t(base.bodyMedium, 14, FontWeight.w400, 1.75),
      bodySmall: t(base.bodySmall, 12.5, FontWeight.w400, 1.7),
      labelLarge: t(base.labelLarge, 15, FontWeight.w600, 1.4),
      labelMedium: t(base.labelMedium, 13, FontWeight.w600, 1.4),
      labelSmall: t(base.labelSmall, 12, FontWeight.w600, 1.45),
    );

    return sized.apply(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
  }
}
