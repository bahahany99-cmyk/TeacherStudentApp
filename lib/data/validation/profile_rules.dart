/// قواعد التحقق للحقول الشخصية (P18) — نقيّة، تُختبر بلا واجهة.
///
/// **لماذا ملف منفصل؟** نفس الحدود مكتوبة في مكانين: هنا (رسائل عربية تظهر
/// للمستخدم) وفي `firestore.rules` (منع فعلي). وجودها في دالة نقيّة واحدة
/// يعني أن التطبيق والاختبارات تقرآن نفس الرقم، وأن تعديل الحدّ لا يمرّ صامتًا.
abstract final class ProfileRules {
  static const int nameMin = 3;
  static const int nameMax = 80;

  /// الهاتف المصري عمليًا 10–13 رقمًا مع مسافة/بادئة، والحدّ هنا أوسع قليلًا
  /// حتى لا نرفض صيغة دولية صحيحة مثل `+20 100 123 4567`.
  static const int phoneMin = 8;
  static const int phoneMax = 20;

  static const int stageMin = 2;
  static const int stageMax = 40;

  /// المراحل المقترحة للطالب — قائمة إرشادية لا حصر: الحقل نصي حر، لأن
  /// المناهج تختلف بين الدول ولا نريد سجن المستخدم في قائمة مصرية فقط.
  static const List<String> stageSuggestions = <String>[
    'الابتدائية',
    'الإعدادية',
    'الثانوية العامة',
    'الجامعة',
  ];

  /// رسالة خطأ الاسم، أو `null` إن كان صالحًا.
  static String? nameProblem(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'الاسم مطلوب';
    }
    if (text.length < nameMin) {
      return 'الاسم قصير جدًا ($nameMin أحرف على الأقل)';
    }
    if (text.length > nameMax) {
      return 'الاسم طويل جدًا ($nameMax حرفًا كحد أقصى)';
    }
    return null;
  }

  /// رسالة خطأ الهاتف، أو `null`. الحقل **اختياري**: الفراغ مقبول.
  ///
  /// نقبل الأرقام و`+` والمسافات والشرطات فقط: أي حرف آخر مؤشر خطأ طباعة،
  /// ومن الأفضل تنبيه المستخدم الآن بدل حفظ رقم لا يمكن الاتصال به.
  static String? phoneProblem(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.length < phoneMin) {
      return 'رقم الهاتف قصير جدًا ($phoneMin محارف على الأقل)';
    }
    if (text.length > phoneMax) {
      return 'رقم الهاتف طويل جدًا ($phoneMax محرفًا كحد أقصى)';
    }
    final bool hasOnlyAllowed = RegExp(r'^[0-9+\-\s()]+$').hasMatch(text);
    if (!hasOnlyAllowed) {
      return 'الهاتف يقبل الأرقام و + و - والمسافات فقط';
    }
    // رقم بلا أرقام كافية (مثل «--------») يمرّ من فحص الطول ولا يفيد أحدًا.
    final int digits = text.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digits < phoneMin) {
      return 'رقم الهاتف يحتاج $phoneMin أرقام على الأقل';
    }
    return null;
  }

  /// رسالة خطأ المرحلة، أو `null`. الحقل **اختياري**.
  static String? stageProblem(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.length < stageMin) {
      return 'المرحلة قصيرة جدًا';
    }
    if (text.length > stageMax) {
      return 'المرحلة طويلة جدًا ($stageMax حرفًا كحد أقصى)';
    }
    return null;
  }

  /// هل البيانات صالحة كاملة؟ (للاختبارات وللتحقق قبل الحفظ)
  static bool isValid({
    required String? displayName,
    required String? phone,
    required String? stage,
  }) {
    return nameProblem(displayName) == null &&
        phoneProblem(phone) == null &&
        stageProblem(stage) == null;
  }
}
