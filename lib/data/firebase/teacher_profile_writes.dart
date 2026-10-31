import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// حمولات الكتابة على `teacherProfiles/{uid}` — **دوال نقية** قابلة للاختبار.
///
/// الهدف: نقل «أي حقول تُكتب» من داخل مستودع Firestore إلى مكان واحد يُختبر
/// بلا Firebase. الحاجة نشأت من عطل P29: قرار التوثيق الإداري كان يكتب الحالة
/// وحدها، فملف بلا `accountHidden` يبقى غير قابل للاكتشاف إلى الأبد، رغم أن
/// الإدارة تراه موثّقًا في لوحتها.
abstract final class TeacherProfileWrites {
  /// حمولة قرار الإدارة (توثيق/رفض).
  ///
  /// **قاعدة الإخفاء:** يُضاف `accountHidden: false` **فقط** إذا كان الحقل
  /// غائبًا في المستند الحالي ([accountHiddenFlagPresent] خطأ). أما إن كان
  /// موجودًا — `false` أو `true` — فلا يُمَس إطلاقًا: قرار الإدارة لا يجوز أن
  /// يُعيد إلى الظهور حسابًا أخفاه المسؤول أو صاحبه (حذف ناعم).
  ///
  /// [deletedValue] و[serverTimestamp] يُمرَّران من طبقة Firebase
  /// (`FieldValue.delete()` / `FieldValue.serverTimestamp()`) ليبقى هذا الملف
  /// خاليًا من اعتماد Firebase ويُختبر بقيَم بديلة.
  static Map<String, Object?> adminDecision({
    required TeacherProfileStatus status,
    required String? reviewNote,
    required Object deletedValue,
    required Object serverTimestamp,
    required bool accountHiddenFlagPresent,
    String? adminUid,
  }) {
    return <String, Object?>{
      'status': status.wireValue,
      // `??` صريح: سبب الرفض يُحذف عند الاعتماد حتى لا يبقى سبب قديم معلّقًا.
      'reviewNote': reviewNote ?? deletedValue,
      'reviewedAt': serverTimestamp,
      if (adminUid != null) 'reviewedBy': adminUid,
      if (!accountHiddenFlagPresent) 'accountHidden': false,
    };
  }

  /// الترقيع الذي يضيفه حفظ صاحب الملف عند تعديل ملفه.
  ///
  /// نفس القاعدة: لا يكتب شيئًا إن كان الحقل موجودًا (فلا يُعيد حسابًا مخفيًا
  /// إلى الظهور)، ويضيف `false` فقط عند غيابه — فيُصلح الملف تلقائيًا عند أول
  /// تعديل يقوم به المدرس نفسه.
  static Map<String, Object?> ownerSaveBackfill({
    required bool accountHiddenFlagPresent,
  }) {
    return accountHiddenFlagPresent
        ? const <String, Object?>{}
        : const <String, Object?>{'accountHidden': false};
  }
}
