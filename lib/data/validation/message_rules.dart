import 'package:teacher_student_app/data/validation/model_validators.dart';

/// قواعد إرسال الرسائل — **دوال نقية**.
///
/// حدود النص هنا مطابقة لـ`firestore.rules`؛ وأي تغيير في أحدهما يوجب الآخر
/// (تحرسه اختبارات المحاكي).
abstract final class MessageRules {
  static const int maxLength = 500;
  static const int maxMessagesPerLoad = 100;

  /// هل يمكن للمستخدم استخدام المحادثة؟
  ///
  /// [isOwner] المدرس صاحب المجموعة، [isMember] طالب مقبول في الأعضاء.
  static bool canParticipate({
    required String? viewerId,
    required bool isOwner,
    required bool isMember,
  }) {
    if (viewerId == null || viewerId.isEmpty) {
      return false;
    }
    return isOwner || isMember;
  }

  /// سبب منع المشاركة (أو `null`).
  static String? blockedReason({
    required String? viewerId,
    required bool isOwner,
    required bool isMember,
  }) {
    if (viewerId == null || viewerId.isEmpty) {
      return 'سجّل الدخول للمشاركة في المحادثة.';
    }
    if (isOwner || isMember) {
      return null;
    }
    return 'المحادثة متاحة لأعضاء المجموعة المقبولين فقط. أرسل طلب انضمام '
        'وانتظر موافقة المدرس.';
  }

  /// تنظيف النص: توحيد المسافات والحواف (رسالة من فراغات ليست رسالة).
  static String normalize(String? raw) {
    if (raw == null) {
      return '';
    }
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// تحقق من النص قبل الإرسال.
  static ValidationResult validate(String? raw) {
    final String text = normalize(raw);
    if (text.isEmpty) {
      return const ValidationResult(<ValidationProblem>[
        ValidationProblem('text', FieldIssue.missing),
      ]);
    }
    if (text.length > maxLength) {
      return const ValidationResult(<ValidationProblem>[
        ValidationProblem('text', FieldIssue.tooLong),
      ]);
    }
    return const ValidationResult.valid();
  }

  /// عدّاد الأحرف كما يعرضه صندوق الكتابة.
  static String characterCounter(String? raw) {
    return '${normalize(raw).length} / $maxLength';
  }
}
