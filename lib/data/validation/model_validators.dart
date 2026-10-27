/// تحقق من صحة حقول النماذج **قبل** إرسالها إلى Firestore.
///
/// لماذا نحتاجه مع وجود القواعد؟
/// - القواعد هي الحارس الأمني، لكنها لا تعطي رسالة جيدة للمستخدم. هذه الطبقة
///   تُنتج رسالة عربية واضحة قبل أي طلب شبكة.
/// - **ليست بديلًا عن القواعد** (العميل غير موثوق). القيم الحدّية هنا يجب أن
///   تبقى متوافقة مع `firestore.rules`؛ أي تغيير في أحدهما يستلزم الآخر.
///
/// لا تعتمد على `BuildContext` ولا Flutter: دوال نقية قابلة للاختبار.
library;

/// رمز المشكلة — للاستخدام في الترجمة أو في اختبارات الواجهة.
enum FieldIssue {
  missing('هذا الحقل مطلوب.'),
  tooShort('القيمة أقصر من المسموح.'),
  tooLong('القيمة أطول من المسموح.'),
  outOfRange('القيمة خارج النطاق المسموح.');

  const FieldIssue(this.message);

  final String message;
}

/// مشكلة واحدة: اسم الحقل + نوعها.
class ValidationProblem {
  const ValidationProblem(this.field, this.issue);

  final String field;
  final FieldIssue issue;

  /// رسالة جاهزة للعرض.
  String get message => issue.message;
}

/// نتيجة تحقق: قائمة مشاكل (فارغة = صالح).
class ValidationResult {
  const ValidationResult(this.problems);

  const ValidationResult.valid() : problems = const <ValidationProblem>[];

  final List<ValidationProblem> problems;

  bool get isValid => problems.isEmpty;

  /// أول رسالة — للعرض في لقطة واحدة أعلى النموذج.
  String? get firstMessage => problems.isEmpty ? null : problems.first.message;
}

/// الحدود المشتركة بين العميل والقواعد. مصدر واحد للحقيقة في العميل.
abstract final class ModelLimits {
  /// مطابق لـ`firestore.rules`: displayName ≤ 80.
  static const int displayName = 80;
  static const int subject = 40;
  static const int stage = 40;
  static const int area = 60;
  static const int bio = 300;
  static const int priceHint = 40;
  static const int groupTitle = 80;
  static const int scheduleNote = 120;
  static const int bookingNote = 200;

  /// لا مجموعات أقل من مقعدين (لا معنى لمجموعة من مقعد) ولا أكثر من 50
  /// (سعة واقعية للحصة في هذه المرحلة).
  static const int seatsMin = 2;
  static const int seatsMax = 50;
}

/// يحذف المسافات الطرفية ويحوّل النص الفارغ إلى `null`.
String? normalizeText(String? value) {
  final String? trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// تحقق عام من حقل نصي مطلوب بطول محدود.
ValidationResult _text(
  String field,
  String? value, {
  required bool required,
  required int maxLength,
  int minLength = 1,
}) {
  final String? text = normalizeText(value);

  if (text == null) {
    return required
        ? ValidationResult(<ValidationProblem>[
            ValidationProblem(field, FieldIssue.missing),
          ])
        : const ValidationResult.valid();
  }
  if (text.length < minLength) {
    return ValidationResult(<ValidationProblem>[
      ValidationProblem(field, FieldIssue.tooShort),
    ]);
  }
  if (text.length > maxLength) {
    return ValidationResult(<ValidationProblem>[
      ValidationProblem(field, FieldIssue.tooLong),
    ]);
  }
  return const ValidationResult.valid();
}

/// اسم المستخدم/المدرس.
ValidationResult validateDisplayName(String? value) => _text(
  'displayName',
  value,
  required: true,
  maxLength: ModelLimits.displayName,
);

/// حقول الملف التعريفي التي يكتبها المدرس بنفسه.
///
/// `displayName` مطلوب (كما في القواعد)، والبقية اختيارية الآن لأن الملف
/// يُنشأ ناقصًا عند اختيار الدور ثم يُكمل في P7.
ValidationResult validateTeacherProfileDraft({
  required String? displayName,
  String? subject,
  String? stage,
  String? area,
  String? bio,
  String? priceHint,
}) {
  final List<ValidationProblem> problems = <ValidationProblem>[
    ...validateDisplayName(displayName).problems,
    ..._text('subject', subject, required: false, maxLength: ModelLimits.subject)
        .problems,
    ..._text('stage', stage, required: false, maxLength: ModelLimits.stage)
        .problems,
    ..._text('area', area, required: false, maxLength: ModelLimits.area).problems,
    ..._text('bio', bio, required: false, maxLength: ModelLimits.bio).problems,
    ..._text('priceHint', priceHint, required: false, maxLength: ModelLimits.priceHint)
        .problems,
  ];
  return ValidationResult(List<ValidationProblem>.unmodifiable(problems));
}

/// مسودة مجموعة جديدة (تُستخدم في P7 — أُضيفت الآن لأن قواعدها جزء من النموذج).
ValidationResult validateGroupDraft({
  required String? title,
  required String? subject,
  required String? stage,
  required int seatsTotal,
  String? scheduleNote,
}) {
  final List<ValidationProblem> problems = <ValidationProblem>[
    ..._text(
      'title',
      title,
      required: true,
      maxLength: ModelLimits.groupTitle,
      minLength: 3,
    ).problems,
    ..._text('subject', subject, required: true, maxLength: ModelLimits.subject)
        .problems,
    ..._text('stage', stage, required: true, maxLength: ModelLimits.stage)
        .problems,
    ..._text(
      'scheduleNote',
      scheduleNote,
      required: false,
      maxLength: ModelLimits.scheduleNote,
    ).problems,
  ];

  if (seatsTotal < ModelLimits.seatsMin || seatsTotal > ModelLimits.seatsMax) {
    problems.add(
      const ValidationProblem('seatsTotal', FieldIssue.outOfRange),
    );
  }

  return ValidationResult(List<ValidationProblem>.unmodifiable(problems));
}

/// ملاحظة طلب الحجز (اختيارية، بطول محدود).
ValidationResult validateBookingNote(String? note) => _text(
  'note',
  note,
  required: false,
  maxLength: ModelLimits.bookingNote,
);
