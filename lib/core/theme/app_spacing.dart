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
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 18;
  static const double radiusPill = 999;

  // ارتفاعات عناصر
  static const double buttonHeight = 52;
  static const double avatarSm = 40;
  static const double avatarMd = 56;
  static const double avatarLg = 80;

  // التخطيط المتجاوب
  static const double tabletBreakpoint = 640;
  static const double maxContentWidth = 760;

  // حشوات جاهزة
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets listGap = EdgeInsets.only(bottom: sm);
}
