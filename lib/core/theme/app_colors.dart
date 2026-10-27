import 'package:flutter/material.dart';

/// لوحة ألوان المشروع.
///
/// كل تعديل تصميمي يجب أن يحدث هنا (أو في `app_theme.dart`) وليس داخل الشاشات.
///
/// النسخة الثانية من النظام البصري (2026-10-27) أضافت **طبقة التدرّجات
/// الناعمة**: نفس الأخضر المؤسسي، لكن بدرجات مضيئة/مخمّدة تُستخدم كخلفيات
/// فاخرة بدل اللون المسطّح. الألوان الجديدة مخصّصة للخلفيات فقط ولا تُستخدم
/// كنص (تباينها منخفض).
abstract final class AppColors {
  /// اللون الأساسي: أخضر مزرق هادئ (مناسب لسياق تعليمي).
  static const Color seed = Color(0xFF0E7C66);

  /// لون تمييز ثانوي: عسلي دافئ.
  static const Color accent = Color(0xFFE8A33D);

  // خلفيات وأسطح
  static const Color lightBackground = Color(0xFFF7F9F8);
  static const Color darkBackground = Color(0xFF101613);

  /// أبيض الأسطح العائمة (البطاقات) — أنقى من لون الخلفية قليلًا.
  static const Color surfaceRaised = Color(0xFFFFFFFF);

  // ── طبقة التدرّجات (نسخة 2) ────────────────────────────────────────────────
  /// أعلى الصفحة: لمسة نعناعية باهتة.
  static const Color mistMint = Color(0xFFE8F4EF);

  /// وسط الصفحة: لمسة لافندر باردة (تعطي الإحساس «الفاخر» في المرجع).
  static const Color mistLavender = Color(0xFFEFEDFB);

  /// أسفل الصفحة: لمسة وردية دافئة خفيفة جدًا.
  static const Color mistBlush = Color(0xFFFBEFF3);

  /// بداية/نهاية تدرّج البطاقة المميّزة (hero).
  static const Color heroFrom = Color(0xFF128C73);
  static const Color heroTo = Color(0xFF0A5D4C);

  // ظلال
  static const Color shadow = Color(0x1A0E1F1B);

  // شريط وضع الزائر
  static const Color demoBackground = Color(0xFFFFF4DB);
  static const Color demoBorder = Color(0xFFE8A33D);
  static const Color demoForeground = Color(0xFF7A4E00);

  // حالات الطلبات
  static const Color statusPending = Color(0xFFB26A00);
  static const Color statusAccepted = Color(0xFF1B7F4B);
  static const Color statusRejected = Color(0xFFB3261E);
  static const Color statusNeutral = Color(0xFF5F6B66);
}
