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
      final String char = String.fromCharCode(rune);
      buffer.write(switch (char) {
        'أ' || 'إ' || 'آ' || 'ٱ' => 'ا',
        'ى' => 'ي',
        'ة' => 'ه',
        'ؤ' => 'و',
        'ئ' => 'ي',
        _ => char,
      });
    }
    return buffer.toString();
  }
}
