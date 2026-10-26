import 'package:flutter/material.dart';

/// لوحة ألوان المشروع.
///
/// كل تعديل تصميمي يجب أن يحدث هنا (أو في `app_theme.dart`) وليس داخل الشاشات.
abstract final class AppColors {
  /// اللون الأساسي: أخضر مزرق هادئ (مناسب لسياق تعليمي).
  static const Color seed = Color(0xFF0E7C66);

  /// لون تمييز ثانوي: عسلي دافئ.
  static const Color accent = Color(0xFFE8A33D);

  // خلفيات وأسطح
  static const Color lightBackground = Color(0xFFF7F9F8);
  static const Color darkBackground = Color(0xFF101613);

  // ظلال
  static const Color shadow = Color(0x1A0E1F1B);

  // شريط الوضع التجريبي
  static const Color demoBackground = Color(0xFFFFF4DB);
  static const Color demoBorder = Color(0xFFE8A33D);
  static const Color demoForeground = Color(0xFF7A4E00);

  // حالات الطلبات
  static const Color statusPending = Color(0xFFB26A00);
  static const Color statusAccepted = Color(0xFF1B7F4B);
  static const Color statusRejected = Color(0xFFB3261E);
  static const Color statusNeutral = Color(0xFF5F6B66);
}
