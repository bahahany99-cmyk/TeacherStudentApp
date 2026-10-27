import 'package:flutter/material.dart';

/// لوحة ألوان المشروع — **نسخة 4.1: النقطة الحلوة (The Sweet Spot)**.
///
/// قرار صاحب المشروع (2026-10-27): إزالة كل تدرّجات الأخضر والنعناع من التطبيق
/// بالكامل، والانتقال إلى خلفية وردية باستيلية متلاشية إلى الأبيض، مع لمسات
/// وردية/ذهبية هادئة ونصوص داكنة محايدة — مطابقة للمرجع البصري المعتمد.
///
/// قواعد الاستخدام:
/// - `wash*` **للخلفيات فقط** (تباينها منخفض جدًا، لا تُستخدم كنص).
/// - `seed` هو لون الهوية: يُشتق منه `ColorScheme` كاملًا (أزرار، روابط، أيقونات).
///   مُختار غامقًا بما يكفي لتباين جيد على الأبيض.
/// - `hero*` محصور في الشعار الصغير فقط؛ لا كتل مشبعة داخل الصفحات.
/// - **v4.1:** الخلفية بيضاء صريحة، والوردي لا يظهر إلا كتدرّج رقيق في أعلى
///   الصفحة يتلاشى إلى الأبيض. المحتوى نفسه لا يُصبغ.
/// - ألوان الحالات دلالية وليست هوية: لا أخضر عمدًا — «مقبول» صار أزرق رمادي
///   هادئ، و«مرفوض» وردي محروق، و«قيد الانتظار» عسلي ترابي.
abstract final class AppColors {
  /// لون الهوية: وردي عميق (لا فوشيا). تباينه على الأبيض كافٍ للنصوص.
  static const Color seed = Color(0xFF9E4C6C);

  /// لمسة ثانوية: ذهبي وردي هادئ (النجوم والوسام).
  static const Color accent = Color(0xFFB98A5E);

  // خلفيات وأسطح
  static const Color lightBackground = Color(0xFFFDFBFB);
  static const Color darkBackground = Color(0xFF17121A);

  /// أبيض الأسطح العائمة (البطاقات).
  static const Color surfaceRaised = Color(0xFFFFFFFF);

  // ── طبقة الغسيل الوردي (الخلفيات) ─────────────────────────────────────────
  /// **الحافة العلوية للصفحة (v4.1):** بلاش واضح بلا صراخ.
  ///
  /// القيمة مختارة عند «النقطة الحلوة»: مرئية كوردي على شاشة حقيقية (لا تُقرأ
  /// كأبيض مغبَّش)، لكنها بعيدة عن الفوشيا؛ تباين النص الداكن عليها يبقى فوق
  /// 16:1. تقع في مدى تشبّع منخفض (S≈28%) وإضاءة عالية (L≈92%).
  static const Color blushTop = Color(0xFFF8DEE7);

  /// الطبقة الوسطى للتلاشي: نفس الوردية بشفافية بصرية أعلى.
  static const Color blushSoft = Color(0xFFFCEFF3);

  /// وردي هادئ جدًا (يُستخدم في الأسطح الصغيرة، لا في الخلفية).
  static const Color washRose = Color(0xFFFBEDF3);

  /// أسفل الصفحة: لافندر وردي باهت (يعطي العمق بلا إشباع).
  static const Color washLilac = Color(0xFFF5EFFA);

  /// لمسة خوخية دافئة (صفحات الحساب).
  static const Color washPeach = Color(0xFFFDF2EC);

  // ── النصوص (v4.1): أسود شبه صريح لتباين «حادّ» على الأبيض ────────────────
  /// نص العناوين والمتون الأساسي — تباين 17.5:1 على الأبيض.
  static const Color textPrimary = Color(0xFF151217);

  /// نص ثانوي (وصف، تسميات) — تباين 6.4:1 على الأبيض.
  static const Color textSecondary = Color(0xFF5E5865);

  /// نص خفيف (تلميحات فقط، لا يُستخدم لمعلومة أساسية).
  static const Color textMuted = Color(0xFF8A8492);

  // مرادفات النسخة 3 — محفوظة حتى لا تتعطّل أي مراجع قائمة.
  static const Color washMint = washRose;
  static const Color washLavender = washLilac;
  static const Color washBlush = washPeach;

  /// بداية/نهاية الشعار المتدرّج (الموضع الوحيد المسموح فيه بالإشباع).
  static const Color heroFrom = Color(0xFFB76E86);
  static const Color heroTo = Color(0xFF8E465F);

  // ظلال
  static const Color shadow = Color(0x14000000);

  // شريحة وضع الزائر: بيج دافئ محايد (لا أصفر صارخ، ولا أخضر).
  static const Color demoBackground = Color(0xFFFFF8F3);
  static const Color demoBorder = Color(0xFFEFDCCB);
  static const Color demoForeground = Color(0xFF8A6A52);

  // حالات الطلبات — دلالية، خالية من الأخضر بقرار صاحب المشروع.
  static const Color statusPending = Color(0xFFA9762F);
  static const Color statusAccepted = Color(0xFF4A6C8C);
  static const Color statusRejected = Color(0xFFB04A5E);
  static const Color statusNeutral = Color(0xFF6B6670);
}
