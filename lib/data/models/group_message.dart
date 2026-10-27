import 'package:teacher_student_app/data/models/user_role.dart';

/// رسالة داخل محادثة مجموعة دراسية.
///
/// **قناة واحدة لكل مجموعة**، متاحة لهؤلاء فقط: المدرس صاحب المجموعة والأعضاء
/// المقبولون. ليست محادثة خاصة بين طالب ومدرس — تلك تحتاج نموذجًا منفصلًا
/// (خيوط محادثة) وهو خارج نطاق هذه المرحلة.
///
/// لماذا لا يوجد حقل `readBy` هنا؟ علامة «مقروء» لكل عضو تحتاج مستندًا لكل
/// قارئ لكل رسالة (تكلفة قراءات عالية على الحصص المجانية). تُؤجَّل حتى تثبت
/// الحاجة إليها في الاستخدام الفعلي.
class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String groupId;
  final String senderId;
  final String senderName;

  /// دور المرسل وقت الإرسال (منسوخ في المستند: عرض الوسم لا يحتاج قراءة
  /// مستند المستخدم، وهو ما تحدّه القواعد بعشر قراءات لكل استعلام).
  final UserRole senderRole;

  final String text;
  final DateTime sentAt;

  bool isMine(String? viewerId) => viewerId != null && viewerId == senderId;

  /// خريطة الإنشاء — الحقول المسموح بها في القواعد فقط.
  Map<String, Object?> toCreateMap() {
    return <String, Object?>{
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole.name,
      'text': text,
      'sentAt': sentAt,
    };
  }
}

/// دور المرسل النصي ⇄ التعداد.
UserRole parseSenderRole(Object? raw) {
  return raw == 'teacher' ? UserRole.teacher : UserRole.student;
}
