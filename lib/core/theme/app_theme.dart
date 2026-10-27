import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/theme/app_typography.dart';

/// الثيم الموحّد للتطبيق (فاتح/داكن).
///
/// النسخة 4.1 (2026-10-27):
/// - **حواف دائرية واضحة**: الأزرار والشرائح `StadiumBorder` (حبة دواء)،
///   والبطاقات 24، والحقول 18.
/// - **سطوح عائمة**: خلفية بيضاء بلمسة بلاش علوية (`AppGradients.page`)،
///   والبطاقات بيضاء بظل مزدوج رقيق (`AppShadows.card`).
/// - **نص داكن حادّ**: `onSurface` شبه أسود و`onSurfaceVariant` رمادي متوسط،
///   بلا زرقة ولا صبغة وردية على النص — أعلى تباين ممكن على الأبيض.
///
/// ملاحظة: لا نضيف تخصيصات لمكوّنات لا تُستخدم فعليًا، لتقليل المخاطر عند
/// ترقية Flutter.
abstract final class AppTheme {
  static ThemeData get light => _build(
    _lightScheme(),
    Brightness.light,
  );

  static ThemeData get dark => _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.dark,
    ),
    Brightness.dark,
  );

  /// لوحة النظام في الوضع الفاتح.
  ///
  /// `ColorScheme.fromSeed` يشتق نصًا بنفسجيًا مسائيًا (`onSurface` مائل
  /// للبنفسجي) وخلفيات مصبوغة قليلًا؛ نستبدلها صراحة:
  /// - `onSurface` شبه أسود (تباين 17:1 على الأبيض) ⇒ «حِدّة» الطباعة.
  /// - `onSurfaceVariant` رمادي دافئ متوسط (6.4:1) للنص الثانوي.
  /// - `surface` أبيض صريح: البطاقات والحقول بيضاء لا «بيضاء مائلة».
  static ColorScheme _lightScheme() {
    final ColorScheme seeded = ColorScheme.fromSeed(seedColor: AppColors.seed);
    return seeded.copyWith(
      surface: Colors.white,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outlineVariant: const Color(0xFFEADFE4),
    );
  }

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = AppTypography.textTheme(base.textTheme);
    final bool isLight = brightness == Brightness.light;

    return base.copyWith(
      // شفافة عمدًا: `AppBackground` في `MaterialApp.builder` يرسم التدرّج
      // العالمي خلف كل المسارات. لو عادت الخلفية معتمة لاختفى التدرّج.
      // (الاختبارات التي تبني شاشة منفردة لا تعتمد على هذا اللون.)
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        // شفاف حتى يظهر تدرّج الخلفية خلف الشريط (Edge-to-Edge).
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.pageGutter,
        toolbarHeight: 60,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        // أيقونات شريط الحالة داكنة فوق خلفيتنا الفاتحة — في كل شاشة، بلا
        // تكرار الإعداد داخل الشاشات.
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? Colors.white : scheme.surface,
        surfaceTintColor: Colors.transparent,
        // مؤشّر باستيلي ناعم بدل دائرة بلون الهوية الكامل.
        indicatorColor: scheme.primary.withAlpha(20),
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        border: _inputBorder(scheme.outlineVariant),
        enabledBorder: _inputBorder(scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme.primary, width: 1.6),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight + 2),
          // حبة دواء: الشكل المميز للنسخة 2.
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          side: BorderSide(color: scheme.outlineVariant, width: 1.2),
          backgroundColor: isLight ? Colors.white.withAlpha(180) : null,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: scheme.primary.withAlpha(18),
        selectedColor: scheme.primary.withAlpha(38),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.6,
        space: AppSpacing.md,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        contentPadding: EdgeInsets.zero,
        shape: const StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
