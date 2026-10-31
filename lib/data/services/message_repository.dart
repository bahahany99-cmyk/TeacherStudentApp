import 'package:teacher_student_app/data/models/group_message.dart';
import 'package:teacher_student_app/data/models/user_role.dart';

/// عقد محادثة المجموعة (P9).
///
/// قناة واحدة لكل مجموعة، لأعضائها المقبولين وصاحبها فقط. القراءة تعيد آخر
/// الرسائل بترتيب زمني تصاعدي (الأقدم أولًا) لتُعرض مقلوبة في الواجهة.
///
/// ⚠️ لا يوجد بثّ حيّ (stream) في هذه المرحلة: العقد `Future` حتى لا يفتح كل
/// مستمع اتصالًا دائمًا يستهلك حصة القراءة. الواجهة تحدّث عند الإرسال وعند
/// السحب للتحديث — والترقية إلى `snapshots()` لاحقة لا تغيّر الشاشات.
abstract interface class MessageRepository {
  Future<List<GroupMessage>> listForGroup(String groupId);

  /// إرسال رسالة. `senderId` يُقارن بـ`request.auth.uid` في القواعد، فلا
  /// يمكن انتحال مرسل آخر.
  Future<GroupMessage> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required UserRole senderRole,
    required String text,
  });
}
