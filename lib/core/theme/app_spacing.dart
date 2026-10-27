import 'package:flutter/widgets.dart';

/// مقاييس المسافات والحواف والارتفاعات.
///
/// لا تُكتب أرقام مسافات مباشرة في الشاشات؛ استخدم هذه القيم.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // أنصاف أقطار الحواف
  //
  // نسخة 2 (2026-10-27): الحواف صارت أكبر وأوضح — البطاقة 24 والحقل 18 —
  // لتقترب من الطابع «العائم» في المرجع البصري المعتمد.
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusXxl = 32;
  static const double radiusPill = 999;

  // ارتفاعات عناصر
  static const double buttonHeight = 52;
  static const double avatarSm = 40;
  static const double avatarMd = 56;
  static const double avatarLg = 80;

  // التخطيط المتجاوب
  static const double tabletBreakpoint = 640;
  static const double maxContentWidth = 760;

  // ── النسخة 3: مساحات أوسع («whitespace سخي») ──────────────────────────────
  /// حافة أفقية للصفحات. رُفعت من 16 إلى 20 لتبتعد عن الإحساس «المضغوط».
  static const double pageGutter = 20;

  /// نصف قطر البطاقة المعتمد في المواصفة (24).
  static const double radiusCard = radiusXl;

  /// المسافة بين الأقسام الرئيسية في الصفحة.
  static const double sectionGap = 28;

  // حشوات جاهزة
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: pageGutter,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(20);

  /// حشوة أوسع للبطاقة التمهيدية داخل الصفحة.
  static const EdgeInsets heroPadding = EdgeInsets.all(lg);
  static const EdgeInsets listGap = EdgeInsets.only(bottom: sm);
}
