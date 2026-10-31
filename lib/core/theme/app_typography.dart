import 'package:flutter/material.dart';

/// نظام الخطوط (Typography) — **الهوية 5**.
///
/// الخط المعتمد: **IBM Plex Sans Arabic** (SIL OFL 1.1) بأوزان 400 / 600 / 700،
/// مُسجَّل في `pubspec.yaml` وملف ترخيصه `assets/fonts/OFL-IBMPlexSansArabic.txt`.
///
/// **لماذا تغيّرنا من Cairo؟** Cairo خط جيد لكنه دائري واسع، وأوزانه على
/// الشاشات الصغيرة تُقرأ «باهتة» كما وصف المستخدم: الفرق بين 400 و600 فيه
/// بسيط بصريًا. IBM Plex Sans Arabic صُمِّم أصلًا لواجهات رقمية: ارتفاع حرف
/// (x-height) أكبر، وتفريق أوضح بين الأوزان، وارتفاع سطر طبيعي للنص العربي
/// يُقصّر الصفحات بدل أن يمدّها.
///
/// قواعد النص العربي:
/// - **لا استخدام لوزن غير مسجَّل** (يُصنَّع اصطناعيًا فيبدو رديئًا).
/// - ارتفاع السطر للنصوص الطويلة ≥ 1.6، وللعناوين 1.4–1.5 (لا فراغ مهدور).
/// - `letterSpacing: 0`: تتبّع الحروف اللاتيني يفصل الحروف العربية.
/// - أحجام بأسلوب «سلّم 1.125»: 28 ← 24 ← 21 ← 18 ← 15.5 ← 14 ← 12.5 ← 11.5،
///   فيبقى التدرّج البصري واضحًا بين العنوان والوصف والتسمية.
abstract final class AppTypography {
  /// عائلة الخط المعتمدة.
  static const String fontFamily = 'IBMPlexSansArabic';

  /// خطوط احتياطية في حال تعذّر تحميل الخط (نادر، لأنه مضمَّن).
  static const List<String> fontFamilyFallback = <String>[
    'Cairo',
    'Noto Naskh Arabic',
    'Noto Sans Arabic',
    'Roboto',
  ];

  /// أقل ارتفاع سطر مقبول للنص العربي.
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
      // العناوين: ثقيلة وواضحة، وارتفاع سطر أقصر (العنوان لا يُقرأ كفقرة).
      displaySmall: t(base.displaySmall, 28, FontWeight.w700, 1.35),
      headlineMedium: t(base.headlineMedium, 24, FontWeight.w700, 1.35),
      headlineSmall: t(base.headlineSmall, 21, FontWeight.w700, 1.4),
      titleLarge: t(base.titleLarge, 18, FontWeight.w700, 1.4),
      titleMedium: t(base.titleMedium, 15.5, FontWeight.w700, 1.45),
      titleSmall: t(base.titleSmall, 13.5, FontWeight.w600, 1.5),
      // المتن: مريح للقراءة الطويلة.
      bodyLarge: t(base.bodyLarge, 15.5, FontWeight.w400, 1.7),
      bodyMedium: t(base.bodyMedium, 14, FontWeight.w400, 1.75),
      bodySmall: t(base.bodySmall, 12.5, FontWeight.w400, 1.7),
      // التسميات والأزرار: شبه ثقيلة، لا تُقرأ كنبض باهت.
      labelLarge: t(base.labelLarge, 14, FontWeight.w600, 1.35),
      labelMedium: t(base.labelMedium, 12.5, FontWeight.w600, 1.35),
      labelSmall: t(base.labelSmall, 11.5, FontWeight.w600, 1.4),
    );

    return sized.apply(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
  }
}
