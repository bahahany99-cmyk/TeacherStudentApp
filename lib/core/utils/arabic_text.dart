/// تطبيع نص عربي بسيط بلا حزم خارجية — مشترك بين استكشاف المجموعات والمدرسين.
///
/// القاعدة: «أحمد» يجب أن يجد «أحمد» و«احمد» و«أحـمد»؛ التاريخ في المشروع
/// أثبت أن اختلاف الهمزة أو التاء المربوطة يجعل البحث يبدو معطوبًا.
///
/// هذا الملف نُقل من `DiscoveryRules` في P15 ليتشاركه بحثان بلا نسختين
/// تنحرفان عن بعضهما.
abstract final class ArabicText {
  /// يقصّ الأطراف، يوحّد الألف/الياء/التاء المربوطة، ويحذف التشكيل والتطويل.
  static String normalize(String value) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in value.trim().toLowerCase().runes) {
      // التشكيل والتطويل: يُحذف لأنه يمنع المطابقة بلا فائدة بصرية.
      if ((rune >= 0x064B && rune <= 0x0652) || rune == 0x0640) {
        continue;
      }
      // الأرقام العربية-الهندية (٠-٩) والفارسية (۰-۹) تُقابَل باللاتينية.
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.write(rune - 0x0660);
        continue;
      }
      if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.write(rune - 0x06F0);
        continue;
      }
      final String char = String.fromCharCode(rune);
      buffer.write(switch (char) {
        // كل أشكال الألف (بما فيها الألف الخنجرية) تُوحَّد، فـ«أسامة/اسامة/
        // إسامة» نص واحد عند البحث.
        'أ' || 'إ' || 'آ' || 'ٱ' || 'ٲ' || 'ٳ' => 'ا',
        'ى' || 'ئ' || 'ي' => 'ي',
        'ة' => 'ه',
        'ؤ' => 'و',
        'ک' => 'ك',
        'گ' => 'ك',
        'پ' => 'ب',
        'ڤ' => 'ف',
        _ => char,
      });
    }
    return buffer.toString();
  }

  /// إزالة «ال» التعريف من بداية الكلمة (للمقارنة فقط).
  ///
  /// لازمة لأن المدرس يكتب مادته «الرياضيات» والطالب يبحث «رياضيات» (والعكس)
  /// — وهو أشهر سبب لظهور «لا نتائج» مع وجود نتيجة مطابقة.
  static String _stripArticle(String value) {
    if (value.length > 3 && value.startsWith('ال')) {
      return value.substring(2);
    }
    return value;
  }

  /// مطابقة نصّية تتجاوز اختلاف الهمزات والتشكيل و«ال» التعريف.
  ///
  /// [needle] يجب أن يكون مُطبَّعًا مسبقًا (`normalize`)، والتطبيع متكرّر الآثار
  /// فلا يضرّ تطبيعه مرتين.
  static bool matches(String haystack, String needle) {
    final String normalizedNeedle = normalize(needle);
    if (normalizedNeedle.isEmpty) {
      return true;
    }
    final String hay = normalize(haystack);
    if (hay.contains(normalizedNeedle)) {
      return true;
    }
    final String bareHay = _stripArticle(hay);
    final String bareNeedle = _stripArticle(normalizedNeedle);
    return bareNeedle.isNotEmpty && bareHay.contains(bareNeedle);
  }
}
