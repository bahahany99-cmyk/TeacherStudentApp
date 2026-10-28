import 'package:teacher_student_app/data/models/user_role.dart';

/// أصل المحادثة المباشرة (P11).
///
/// كل محادثة **مرتبطة بسبب**: حجز قائم، أو عضوية مجموعة عند المدرس، أو استفسار
/// قبل الحجز يسمح به المدرس صراحةً. لا توجد «محادثة عشوائية» بين غريبين.
enum DirectChatOrigin {
  /// حجز بين الطرفين (أي حالة غير الرفض).
  booking('مرتبطة بحجز'),

  /// الطالب عضو مجموعة عند هذا المدرس.
  group('عضو مجموعة'),

  /// استفسار قبل الحجز — مسموح فقط إذا فعّل المدرس استقبال الرسائل.
  inquiry('استفسار قبل الحجز');

  const DirectChatOrigin(this.label);

  final String label;

  static DirectChatOrigin parse(Object? raw) {
    return switch (raw) {
      'booking' => DirectChatOrigin.booking,
      'group' => DirectChatOrigin.group,
      _ => DirectChatOrigin.inquiry,
    };
  }
}

/// محادثة مباشرة بين طالب ومدرس (P11).
///
/// **معرّف واحد لكل زوج** ([idFor]): `{teacherId}_{studentId}`. لماذا؟
/// - يمنع تكرار المحادثات لنفس الطرفين (لا عشرة خيوط لطلب واحد).
/// - يجعل «هل توجد محادثة بيننا؟» قراءة مستند واحد بلا استعلام ولا فهرس.
/// - تفرض القواعد على المعرّف أن يطابق الطرفين، فلا يمكن إنشاء خيط مزيّف.
class DirectChat {
  const DirectChat({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.studentId,
    required this.studentName,
    required this.origin,
    required this.createdAt,
    this.subject,
    this.bookingId,
    this.groupId,
    this.lastMessageAt,
    this.lastMessageText,
    this.lastSenderId,
    this.studentLastReadAt,
    this.teacherLastReadAt,
  });

  final String id;
  final String teacherId;
  final String teacherName;
  final String studentId;
  final String studentName;

  /// مادة المحادثة (من الحجز أو من ملف المدرس) — للعرض فقط.
  final String? subject;

  final DirectChatOrigin origin;

  /// الحجز المرتبط (إلزامي حين يكون الأصل [DirectChatOrigin.booking]).
  final String? bookingId;

  /// المجموعة التي تُثبت العضوية (إلزامية حين يكون الأصل
  /// [DirectChatOrigin.group]).
  final String? groupId;

  final DateTime createdAt;

  /// ملخّص آخر رسالة — يُكتب مع الرسالة في دفعة واحدة، فلا يحتاج صندوق
  /// المحادثات إلى قراءة المستندات الفرعية.
  final DateTime? lastMessageAt;
  final String? lastMessageText;
  final String? lastSenderId;

  /// آخر لحظة قراءة لكل طرف. نخزّنها على المحادثة لا على كل رسالة: التكلفة
  /// قراءة/كتابة واحدة بدل مستند لكل قارئ لكل رسالة.
  final DateTime? studentLastReadAt;
  final DateTime? teacherLastReadAt;

  /// المعرّف الثابت لزوج (مدرس، طالب).
  static String idFor({required String teacherId, required String studentId}) =>
      '${teacherId}_$studentId';

  bool involves(String? viewerId) =>
      viewerId != null && (viewerId == teacherId || viewerId == studentId);

  bool isTeacherViewer(String? viewerId) =>
      viewerId != null && viewerId == teacherId;

  /// الطرف الآخر كما يراه [viewerId].
  String partnerNameFor(String? viewerId) =>
      isTeacherViewer(viewerId) ? studentName : teacherName;

  String? partnerIdFor(String? viewerId) =>
      isTeacherViewer(viewerId) ? studentId : teacherId;

  /// آخر لحظة قرأ فيها [viewerId] (null إن لم يقرأ شيئًا بعد).
  DateTime? lastReadAtFor(String? viewerId) =>
      isTeacherViewer(viewerId) ? teacherLastReadAt : studentLastReadAt;

  /// آخر لحظة قرأها **الطرف الآخر** — تُستخدم لعرض «مقروء» أسفل رسائلي.
  DateTime? partnerLastReadAtFor(String? viewerId) =>
      isTeacherViewer(viewerId) ? studentLastReadAt : teacherLastReadAt;

  /// هل وصلت رسالة من الطرف الآخر بعد آخر قراءة؟
  bool hasUnreadFor(String? viewerId) {
    if (viewerId == null || !involves(viewerId)) {
      return false;
    }
    final DateTime? last = lastMessageAt;
    if (last == null || lastSenderId == viewerId) {
      return false;
    }
    final DateTime? read = lastReadAtFor(viewerId);
    return read == null || last.isAfter(read);
  }

  DirectChat copyWith({
    DateTime? lastMessageAt,
    String? lastMessageText,
    String? lastSenderId,
    DateTime? studentLastReadAt,
    DateTime? teacherLastReadAt,
  }) {
    return DirectChat(
      id: id,
      teacherId: teacherId,
      teacherName: teacherName,
      studentId: studentId,
      studentName: studentName,
      subject: subject,
      origin: origin,
      bookingId: bookingId,
      groupId: groupId,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      studentLastReadAt: studentLastReadAt ?? this.studentLastReadAt,
      teacherLastReadAt: teacherLastReadAt ?? this.teacherLastReadAt,
    );
  }
}

/// رسالة داخل محادثة مباشرة.
///
/// **بلا حقل مقروء لكل رسالة:** حالة القراءة على المحادثة نفسها (انظر
/// [DirectChat.studentLastReadAt])، وهي كافية لعرض «مقروء» وعدّ غير المقروء.
class DirectChatMessage {
  const DirectChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final UserRole senderRole;
  final String text;
  final DateTime sentAt;

  bool isMine(String? viewerId) => viewerId != null && viewerId == senderId;

  /// هل قرأها الطرف الآخر؟ [partnerLastReadAt] من المحادثة.
  bool isReadByPartner(DateTime? partnerLastReadAt, String? viewerId) {
    if (partnerLastReadAt == null || !isMine(viewerId)) {
      return false;
    }
    return !sentAt.isAfter(partnerLastReadAt);
  }

  /// خريطة الإنشاء — الحقول المسموح بها في القواعد فقط.
  Map<String, Object?> toCreateMap() {
    return <String, Object?>{
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole.name,
      'text': text,
      'sentAt': sentAt,
    };
  }
}
