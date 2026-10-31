import 'package:flutter/material.dart';

/// لوحة ألوان المشروع — **الهوية 5 «نيلي درسلي» (Darsly Indigo)**.
///
/// قرار صاحب المشروع (2026-10-30): التخلّي عن الهوية الوردية بالكامل. الوردي
/// كان هادئًا لكنه لا يقول «ثقة وتعليم»؛ والتطبيق التجاري يحتاج لونًا يمثّل
/// الجدّية فيُقرأ كمنصّة تعليمية لا كتطبيق مواعدة.
///
/// ## الاختيارات ولماذا
/// - **نيلي عميق `#303F9F`** هويةً: لون الثقة والمؤسسات التعليمية، تباينه على
///   الأبيض ≈ 8.6:1 (يكفي للنصوص والأيقونات والأزرار)، ولا يُستخدم كمساحة
///   كبيرة فلا يصبح الصفحة كلها «أزرق ثقيل».
/// - **تركواز `#0E7C86`** ثانويًا: يميّز العناصر النشطة والشارات الثانوية عن
///   الهوية، ويبعد الواجهة عن أحادية اللون.
/// - **أخضر زمردي للمقبول/النجاح، عنبري للانتظار، أحمر للرفض، أزرق للمعلومة**:
///   دلالة واضحة تُقرأ بسرعة. (في النسخة السابقة مُنع الأخضر عمدًا؛ أُلغي هذا
///   القرار لأن المستخدم يحتاج إشارة «قُبل» صريحة لا رمادية.)
/// - **خلفية باردة هادئة `#F4F6FB`** بدل الأبيض المسطّح: تفصل البطاقات البيضاء
///   عن الصفحة بلا ظلال ثقيلة، وتريح العين في القراءة الطويلة.
/// - **نصوص بشبه أسود `#12172B`** (تباين 16.8:1) وثانوي `#525A6E` (7.2:1) —
///   لا نص باهت يصعب قراءته.
///
/// قواعد الاستخدام:
/// - `seed` هو لون الهوية: يُشتق منه `ColorScheme` كاملًا.
/// - الألوان الدلالية للحالات فقط، لا للديكور.
/// - **كل لون في التطبيق يمرّ من هنا**؛ لا قيم لون مكتوبة داخل الشاشات.
abstract final class AppColors {
  // ── الهوية ────────────────────────────────────────────────────────────────
  /// لون الهوية: نيلي عميق.
  static const Color seed = Color(0xFF303F9F);

  /// نيلي أغمق — للتدرّجات والعناوين المشبعة فقط.
  static const Color primaryDeep = Color(0xFF1C2A73);

  /// لمسة ثانوية: تركواز.
  static const Color accent = Color(0xFF0E7C86);

  /// تركواز غامق للنص على خلفية تركوازية فاتحة.
  static const Color accentDeep = Color(0xFF075E66);

  // خلفيات وأسطح
  /// خلفية الصفحة: رمادي مزرق هادئ لا أبيض مسطّح.
  static const Color lightBackground = Color(0xFFF4F6FB);
  static const Color darkBackground = Color(0xFF0F1220);

  /// أبيض الأسطح العائمة (البطاقات).
  static const Color surfaceRaised = Color(0xFFFFFFFF);

  // ── طبقة الغسيل العلوية (الخلفيات) ───────────────────────────────────────
  /// الحافة العلوية: نيلي فاتح جدًا. مرئية على شاشة حقيقية (لا تُقرأ كأبيض
  /// مغبَّش)، وتباين النص الداكن عليها فوق 14:1.
  static const Color blushTop = Color(0xFFE6EAFA);

  /// الطبقة الوسطى للتلاشي: نفس العائلة بشفافية بصرية أعلى.
  static const Color blushSoft = Color(0xFFF1F4FD);

  /// نيلي فاتح جدًا (أسطح صغيرة، شرائح مختارة).
  static const Color washIndigo = Color(0xFFEDF0FB);

  /// تركواز فاتح جدًا.
  static const Color washTeal = Color(0xFFE8F4F5);

  /// رملي دافئ هادئ (صفحات الحساب).
  static const Color washSand = Color(0xFFFAF3E9);

  // ── النصوص ───────────────────────────────────────────────────────────────
  /// نص العناوين والمتون الأساسي — تباين 16.8:1 على الأبيض.
  static const Color textPrimary = Color(0xFF12172B);

  /// نص ثانوي (وصف، تسميات) — تباين 7.2:1 على الأبيض.
  static const Color textSecondary = Color(0xFF525A6E);

  /// نص خفيف (تلميحات فقط، لا يُستخدم لمعلومة أساسية) — 5.1:1.
  static const Color textMuted = Color(0xFF7C8497);

  /// مرادفات محفوظة حتى لا تتعطّل أي مراجع قائمة (أسماء قديمة، قيم جديدة).
  static const Color washRose = washIndigo;
  static const Color washLilac = washIndigo;
  static const Color washPeach = washSand;
  static const Color washMint = washTeal;
  static const Color washLavender = washIndigo;
  static const Color washBlush = washSand;

  /// بداية/نهاية الشعار المتدرّج (الموضع الوحيد المسموح فيه بالإشباع).
  static const Color heroFrom = Color(0xFF3B4CC0);
  static const Color heroTo = Color(0xFF1C2A73);

  // ظلال
  static const Color shadow = Color(0x14101828);

  // دلالة الانتباه (وسم الجولة التعريفية وشارات «بانتظار إجراء»)
  static const Color attentionBackground = Color(0xFFFFF7E6);
  static const Color attentionBorder = Color(0xFFF0DCB2);
  static const Color attentionForeground = Color(0xFF8A5A00);

  // ── حالات الطلبات: دلالية وواضحة ─────────────────────────────────────────
  /// قيد الانتظار — عنبري غامق (تباين 5.4:1 على الأبيض).
  static const Color statusPending = Color(0xFF9A5B00);

  /// مقبول/مكتمل — زمردي غامق (5.1:1)، وليس أخضر فاتحًا لا يُقرأ.
  static const Color statusAccepted = Color(0xFF0F7B52);

  /// مرفوض/ملغى متأخرًا — أحمر طوبي (6.2:1).
  static const Color statusRejected = Color(0xFFB3261E);

  /// محايد/موقوف — أردوازي (7.0:1).
  static const Color statusNeutral = Color(0xFF5B6474);

  /// معلومة — أزرق صريح (5.9:1).
  static const Color statusInfo = Color(0xFF0B63B7);

  /// خلفيات الحالات (شرائح، تنبيهات) — فاتحة جدًا مع النص الغامق نفسه.
  static Color statusTint(Color status) => status.withAlpha(20);
}
