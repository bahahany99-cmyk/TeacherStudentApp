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

  // ── (P32) حالة القراءة لكل عضو ─────────────────────────────────────────
  /// آخر وقت قرأه هذا المشارك في هذه المجموعة، أو `null`.
  ///
  /// **أين تُخزَّن؟** في `studyGroups/{id}/reads/{uid}` — مستند لكل مشارك
  /// (مالكًا أو عضوًا) فيه حقل `lastReadAt` وحده. **لماذا مستند منفصل؟** لأن
  /// الحالة **لكل عضو** منفصلة: علامة واحدة مشتركة في مستند المجموعة تجعل قراءة
  /// طالب تُسكت عدّاد طالب آخر؛ ومستند العضوية لا يصلح لأن صاحب المجموعة ليس
  /// عضوًا. المستند غائب = «لم يقرأ شيئًا»، فلا هجرة ولا كسر لبيانات قائمة.
  Future<DateTime?> lastReadAt({
    required String groupId,
    required String memberId,
  });

  /// عدد الرسائل غير المقروءة لهذا العضو (رسائله هو لا تُحتسب).
  ///
  /// يُقرأ بعدد محدود (لا كل التاريخ) لأن الشارة تعرض «9+» على الأكثر.
  Future<int> unreadCount({
    required String groupId,
    required String memberId,
  });

  /// يُثبّت `lastReadAt = الآن` في مستند القراءة — للمشارك نفسه فقط.
  ///
  /// القواعد تسمح للمشارك (مالك أو عضو) بكتابة هذا الحقل وحده في مستنده؛
  /// ومحاولة كتابة أي حقل آخر، أو مستند مشارك آخر، أو أن يدّعي غير المشارك
  /// قراءة — كلها تُرفض على الخادم.
  Future<void> markRead({
    required String groupId,
    required String memberId,
  });

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
