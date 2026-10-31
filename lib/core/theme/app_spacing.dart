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
  // نسخة 5 (2026-10-30): البطاقة **20** بدل 24 — تقليل الانتفاخ مع بقاء
  // الحقول 18 والأشرطة 24+. بطاقة 24 على شاشة 360dp تُقرأ «مدوّرة أكثر من
  // اللازم» وتقلّص المساحة الصافية للمحتوى.
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusXxl = 32;
  static const double radiusPill = 999;

  // ارتفاعات عناصر
  /// ارتفاع الزر المعتمد: 48 (كان 52). هدف اللمس الأدنى في Material هو 48dp،
  /// وأي ارتفاع أعلى يستهلك مساحة بلا فائدة في صفحة مليئة بالإجراءات.
  static const double buttonHeight = 48;
  static const double avatarSm = 40;
  static const double avatarMd = 56;
  static const double avatarLg = 80;

  // التخطيط المتجاوب
  static const double tabletBreakpoint = 640;
  static const double maxContentWidth = 760;

  // ── النسخة 5: مقاييس مضغوطة ومتّسقة ──────────────────────────────────────
  /// حافة أفقية للصفحات (ثابتة في كل الشاشات).
  static const double pageGutter = 20;

  /// نصف قطر البطاقة المعتمد: أقل من [radiusXl] قليلًا حتى لا تبدو البطاقة
  /// «بالونًا» على الشاشات الضيقة، ويبقى أكبر من نصف قطر الحقول.
  static const double radiusCard = 20;

  /// المسافة بين الأقسام الرئيسية في الصفحة. كانت 28 — أقصر الآن حتى يظهر
  /// قسمان ونصف على شاشة 640dp بلا تمرير طويل.
  static const double sectionGap = 24;

  /// ارتفاع صف إعدادات مريح للمس (≥ 48dp) مع حشو أقل من بطاقة محتوى.
  static const double settingsTileHeight = 56;

  /// قطر هالة أيقونة الحالة الفارغة.
  static const double emptyHalo = 88;

  // حشوات جاهزة
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: pageGutter,
  );

  /// حشوة بطاقة المحتوى القياسية (16 بدل 20: أكبر فرق بصري في النسخة 5 —
  /// نفس المحتوى في بطاقة أقصر).
  static const EdgeInsets cardPadding = EdgeInsets.all(md);

  /// حشوة مريحة للبطاقة التمهيدية فقط (صف الحساب، بطاقة الملف).
  static const EdgeInsets cardPaddingRoomy = EdgeInsets.all(lg);

  /// حشوة أوسع للبطاقة التمهيدية داخل الصفحة.
  static const EdgeInsets heroPadding = EdgeInsets.all(lg);

  /// المسافة بين بطاقتين متتاليتين في قائمة (12 بدل 16).
  static const EdgeInsets listGap = EdgeInsets.only(bottom: sm);
}
