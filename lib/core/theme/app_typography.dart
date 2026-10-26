import 'package:flutter/material.dart';

/// نظام الخطوط (Typography).
///
/// الوضع الحالي: نستخدم خط النظام مع سلسلة احتياطية عربية.
/// عند إضافة خط عربي مخصص:
/// 1) ضع ملفات الخط في `assets/fonts/` وسجّلها في `pubspec.yaml`.
/// 2) اضبط [fontFamily] هنا فقط — لا تعدّل الشاشات.
abstract final class AppTypography {
  /// اسم عائلة الخط المخصص، أو `null` لاستخدام خط النظام.
  static const String? fontFamily = null;

  /// خطوط احتياطية عربية مضمونة على أجهزة Android.
  static const List<String> fontFamilyFallback = <String>[
    'Noto Naskh Arabic',
    'Noto Sans Arabic',
    'Roboto',
  ];

  /// تحسين أحجام العناوين والنصوص لتكون مريحة بالعربية على شاشات مختلفة.
  static TextTheme textTheme(TextTheme base) {
    TextStyle? t(TextStyle? style, double size, FontWeight weight, double height) {
      return style?.copyWith(
        fontSize: size,
        fontWeight: weight,
        height: height,
      );
    }

    final TextTheme sized = base.copyWith(
      displaySmall: t(base.displaySmall, 32, FontWeight.w700, 1.35),
      headlineMedium: t(base.headlineMedium, 26, FontWeight.w700, 1.35),
      headlineSmall: t(base.headlineSmall, 22, FontWeight.w600, 1.4),
      titleLarge: t(base.titleLarge, 19, FontWeight.w700, 1.4),
      titleMedium: t(base.titleMedium, 16, FontWeight.w600, 1.45),
      bodyLarge: t(base.bodyLarge, 16, FontWeight.w400, 1.7),
      bodyMedium: t(base.bodyMedium, 14, FontWeight.w400, 1.7),
      labelLarge: t(base.labelLarge, 15, FontWeight.w600, 1.3),
      labelSmall: t(base.labelSmall, 12, FontWeight.w500, 1.3),
    );

    if (fontFamily == null) {
      // نطبّق الاحتياطي فقط عندما لا يوجد خط مخصص.
      return sized.apply(fontFamilyFallback: fontFamilyFallback);
    }
    return sized.apply(fontFamily: fontFamily);
  }
}
