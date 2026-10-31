import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/user_role.dart';

/// عقد المحادثة المباشرة بين طالب ومدرس (P11).
///
/// **محادثة واحدة لكل زوج** ([DirectChat.idFor])، وأصل مُوثّق (حجز/مجموعة/
/// استفسار). القواعد على الخادم هي الحارس الحقيقي؛ هذه الطبقة تُنفّذ نفس القواعد
/// محليًا حتى تصل الرسالة الخطأ إلى المستخدم كسبب مفهوم لا كخطأ صلاحيات.
///
/// **البثّ:** [watchMessages] يعيد تدفقًا حيًّا (P11 يطلب تحديثًا لحظيًا)، وكل
/// مستمع يفتح اتصالًا واحدًا على المحادثة المفتوحة فقط — لا قائمة محادثات
/// تُبَثّ كلها.
abstract interface class DirectChatRepository {
  Future<DirectChat?> findById(String chatId);

  /// محادثات [viewerId] (طالبًا أو مدرسًا)، الأحدث رسالةً أولًا.
  ///
  /// المعرّف صريح لأن الواجهة تعرفه من الجلسة (`CurrentStudent`/`CurrentTeacher`)
  /// في وضع الزائر أيضًا (A-56)، وليس دائمًا `auth.uid`.
  Future<List<DirectChat>> listMine(String viewerId);

  /// محادثات [viewerId] **حيًّا** — الأحدث رسالةً أولًا.
  ///
  /// **لماذا بثّ لا `Future`؟** لأن `listMine` لقطة عند البناء: لو أنشأ الطالب
  /// محادثة (بعد إرسال طلب انضمام أو حجز) بينما صفحة محادثات المدرس مفتوحة،
  /// فلن تظهر حتى يُغلقها ويعيد فتحها — وهو بالضبط عطل «المحادثات لا تظهر».
  /// المصدران (مدرس/طالب) يُدمجان في العميل لأن Firestore لا يدعم `OR` على
  /// حقلين بلا فهرس مركّب.
  Stream<List<DirectChat>> watchMine(String viewerId);

  /// رسائل المحادثة حيًّا، تصاعديًا (الأقدم أولًا).
  Stream<List<DirectChatMessage>> watchMessages(String chatId);

  /// المحادثة نفسها حيًّا: يُحدَّث بها عنوان الشاشة وحالة القراءة (P11).
  ///
  /// مستند واحد فقط، فيصل تغيير «قرأ الطرف الآخر» إلى الشاشة بلا استعلام.
  Stream<DirectChat?> watchChat(String chatId);

  /// هل يستقبل المدرس رسائل قبل الحجز؟ (غياب الإعداد ⇒ `false` متشدّدة)
  Future<bool> allowDirectMessages(String teacherId);

  /// تعديل الخيار — للمدرس نفسه فقط (تفرضه القواعد).
  Future<void> setAllowDirectMessages({
    required String teacherId,
    required bool allow,
  });

  /// فتح المحادثة أو إرجاع القائمة إن وُجدت.
  ///
  /// [origin] يحدد سبب الفتح: حجز ([bookingId])، أو عضوية مجموعة ([groupId])،
  /// أو استفسار (لا يحتاج مرجعًا، ويشترط سماح المدرس).
  Future<DirectChat> openChat({
    required String teacherId,
    required String teacherName,
    required String studentId,
    required String studentName,
    required DirectChatOrigin origin,
    String? subject,
    String? bookingId,
    String? groupId,
  });

  /// إرسال رسالة — [senderId] يجب أن يكون أحد طرفي المحادثة.
  ///
  /// (P24) [imageId] يجعل الرسالة مصوّرة: النص حينها اختياري (تعليق على
  /// الصورة)، والصورة نفسها في [ChatImageRepository] بموعد انتهاء.
  Future<DirectChatMessage> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required UserRole senderRole,
    required String text,
    String? imageId,
  });

  /// تعليم المحادثة مقروءة لهذا الطرف (يكتب حقل الطرف فقط).
  Future<void> markRead({
    required String chatId,
    required String viewerId,
    required DateTime at,
  });
}
