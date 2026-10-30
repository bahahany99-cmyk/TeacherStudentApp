import 'dart:typed_data';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';

/// قراءة/كتابة صورة الحساب (P22).
///
/// الواجهات لا تعرف Firestore: تقرأ من هذا العقد، فيمكن استبدال التنفيذ
/// (تجريبي ← Firestore ← Storage لاحقًا) بلا لمس أي شاشة.
abstract interface class AvatarRepository {
  /// صورة المستخدم. تُعيد `null` إن لم يوجد مستند إطلاقًا.
  ///
  /// **`null` ليست خطأ**: مستخدم جديد بلا صورة = الصورة الافتراضية المرسومة.
  Future<UserAvatar?> getFor(String uid);

  /// رفع صورة مخصّصة.
  ///
  /// [bytes] صورة **مضغوطة أصلًا** على الجهاز؛ هذا الطبقة تتحقق من الحدود
  /// (الحجم/النوع) قبل الكتابة، والقواعد تتحقق مرة أخرى على الخادم.
  Future<UserAvatar> upload({
    required String uid,
    required Uint8List bytes,
    required String mimeType,
  });

  /// حذف الصورة المخصّصة والعودة إلى الافتراضية.
  Future<void> remove(String uid);

  /// تثبيت صورة افتراضية على مستند المستخدم (تُكتب عند أول دخول).
  Future<void> ensureDefault(String uid);

  /// اختيار صورة افتراضية أخرى (P22) — يُحفظ على `users/{uid}`.
  ///
  /// الصورة الافتراضية رقم واحد صغير، فمكانها الطبيعي مع بيانات الحساب؛ أما
  /// الصورة المخصّصة (بايتات) فمستندها منفصل.
  Future<void> setPreset({required String uid, required int preset});
}

/// تنفيذ فارغ: لا صورة مخصّصة، ولا كتابة.
///
/// **لماذا موجود؟** لأن `AppServices` يُنشأ في اختبارات كثيرة بحزمة مصغّرة لا
/// تعرف الصور. الفارغ هنا يجعل «لا صورة» هي الحالة الافتراضية الصحيحة،
/// والواجهة ترسم الصورة الافتراضية الحتمية من المعرّف — فلا شاشة فارغة ولا
/// انهيار، ولا يحتاج كل اختبار قديم إلى تعديل.
///
/// ⚠️ الرفع عليه يرمي خطأً صريحًا لا ينجح صامتًا: لو نسيت حقن التنفيذ
/// الحقيقي في شاشة، يظهر فشل واضح بدل «حُفظت الصورة» وهي لم تُحفظ.
class EmptyAvatarRepository implements AvatarRepository {
  const EmptyAvatarRepository();

  @override
  Future<UserAvatar?> getFor(String uid) async => null;

  @override
  Future<UserAvatar> upload({
    required String uid,
    required Uint8List bytes,
    required String mimeType,
  }) {
    throw const AppException(
      AppErrorKind.unavailable,
      debugMessage: 'avatar repository not configured',
      overrideTitle: 'غير متاح الآن',
      overrideMessage: 'تعذّر حفظ الصورة. أعد المحاولة بعد قليل.',
    );
  }

  @override
  Future<void> remove(String uid) async {}

  @override
  Future<void> ensureDefault(String uid) async {}

  @override
  Future<void> setPreset({required String uid, required int preset}) async {}
}
