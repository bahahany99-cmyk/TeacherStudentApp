import 'package:flutter/material.dart';

/// حقل اختيار (قائمة منسدلة) بشكل موحّد مع بقية حقول التطبيق.
///
/// **المشكلة التي يحلّها:** `DropdownButtonFormField` يرفض `value` غير موجود
/// في `items` ويعيد `assert`. ولأن بيانات ما قبل P19 قد تحمل نصًا حرًا
/// («الرياضيات — التفاضل») أو محافظة بترتيب مختلف، لا يجوز أن ينكسر نموذج
/// التحرير لمستخدم قديم، ولا أن يُمحى ما كتبه بصمت.
///
/// الحل: القيمة المحفوظة غير الموجودة في القائمة تُضاف كخيار أول موسوم
/// «(قيمة محفوظة سابقًا)»، فيراها صاحبها ويعيد اختياره من القائمة المعتمدة
/// متى شاء — **بلا فقدان بيانات**.
class AppSelectField extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.validator,
    this.helperText,
    this.enabled = true,
    this.isRequired = false,
    this.extraOptions = const <String>[],
    this.optionLabel,
  });

  final String label;

  /// القيمة الحالية (قد تكون `null` للحقول الاختيارية).
  final String? value;

  /// الخيارات المعتمدة.
  final List<String> options;

  /// تُستدعى بالقيمة المختارة. `null` = «بلا اختيار» (مسموح فقط إذا لم يكن
  /// الحقل مطلوبًا، أو عند اختيار «لا شيء» في حقل اختياري).
  final ValueChanged<String?> onChanged;

  final FormFieldValidator<String>? validator;
  final String? helperText;
  final bool enabled;
  final bool isRequired;

  /// خيارات إضافية غير معتمدة لكنها **قابلة للاختيار** (P22).
  ///
  /// تُستخدم لخيار «أخرى (كتابة يدوية / تخصيص)» الذي يفتح حقل نص. وهي مختلفة
  /// عن [legacyValue]: تلك قيمة محفوظة سابقًا للعرض فقط، وهذه خيار يختاره
  /// المستخدم الآن.
  final List<String> extraOptions;

  /// نص بديل لعرض خيار (مثل `__custom__` ← «أخرى…»).
  ///
  /// القيمة المحفوظة تبقى كما هي؛ التغيير في العرض وحده.
  final String Function(String value)? optionLabel;

  /// القيمة الحالية إن كانت غير موجودة في [options] (بيانات قديمة).
  String? get legacyValue {
    final String? current = _clean(value);
    if (current == null ||
        options.contains(current) ||
        extraOptions.contains(current)) {
      return null;
    }
    return current;
  }

  static String? _clean(String? raw) {
    final String text = (raw ?? '').trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final String? current = _clean(value);
    final String? legacy = legacyValue;

    // الخيارات = (القيمة القديمة إن وُجدت) + القائمة المعتمدة.
    final List<DropdownMenuItem<String>> items = <DropdownMenuItem<String>>[
      if (legacy != null)
        DropdownMenuItem<String>(
          value: legacy,
          child: Text('$legacy (قيمة محفوظة سابقًا)'),
        ),
      for (final String option in options)
        DropdownMenuItem<String>(
          value: option,
          child: Text(optionLabel?.call(option) ?? option),
        ),
      for (final String option in extraOptions)
        DropdownMenuItem<String>(
          value: option,
          child: Text(optionLabel?.call(option) ?? option),
        ),
      if (!isRequired)
        const DropdownMenuItem<String>(
          value: '',
          child: Text('بدون تحديد'),
        ),
    ];

    // `''` هي تمثيل «بدون تحديد» لأن عناصر القائمة لا تقبل `null`. في الحقل
    // المطلوب لا نُدرج `''` أصلًا، فتبقى القيمة `null` ويظهر `hint` ويفشل
    // `validator` — وهو المطلوب.
    final String selected = current ?? '';

    return DropdownButtonFormField<String>(
      // `initialValue` هو الاسم الحالي في Flutter 3.3x+؛ `value` مهجور.
      initialValue: items.any((DropdownMenuItem<String> i) => i.value == selected)
          ? selected
          : null,
      items: items,
      onChanged: enabled
          ? (String? next) => onChanged(_clean(next))
          : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        alignLabelWithHint: true,
      ),
      validator: validator,
      // نص الحقل الفارغ يحتاج مؤشرًا مفهومًا بدل مربع فارغ.
      hint: Text(isRequired ? 'اختر $label' : 'بدون تحديد'),
    );
  }
}
