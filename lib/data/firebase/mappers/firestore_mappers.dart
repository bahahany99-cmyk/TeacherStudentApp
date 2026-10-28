import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/group_message.dart';
import 'package:teacher_student_app/data/models/group_session.dart';
import 'package:teacher_student_app/data/models/group_waitlist_entry.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// تحويل مستندات Firestore إلى نماذج التطبيق — **دوال نقية** بلا Firebase.
///
/// لماذا منفصلة عن المستودعات؟
/// - قابلة للاختبار بلا مشروع Firebase ولا شبكة (المستودعات نفسها لا يمكن
///   اختبارها هنا)، ومعظم أعطال القراءة الحقيقية تكون في التحويل لا في الاستعلام.
/// - سياسة التسامح واضحة في مكان واحد: **مستند ناقص أو نوعه خاطئ لا يُسقط
///   القائمة كلها**؛ إما يُتجاهل (نعيد `null`) أو تُستخدم قيمة افتراضية آمنة.
///
/// كل ما هنا يفترض أن القواعد على الخادم هي من تمنع البيانات غير الصالحة؛
/// لكن الواجهة لا تنهار إن وصلت بيانات قديمة/ناقصة من مشروع قائم.

/// يقرأ نصًا بأمان، ويعيد `null` إن كانت القيمة غائبة أو ليست نصًا.
String? readString(Object? value) {
  if (value is String) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

/// يقرأ رقمًا (يدعم `int` و`double` و`num`)، أو قيمة افتراضية.
int readInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

/// يقرأ رقمًا اختياريًا: `null` إن كانت القيمة غائبة أو ليست رقمًا.
///
/// يختلف عن [readInt] لأن الصفر قيمة صالحة (منتصف الليل = 0 دقيقة)، فلا يصلح
/// كعلامة على الغياب.
int? readOptInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

/// يقرأ عددًا عشريًا، أو قيمة افتراضية.
double readDouble(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

/// يقرأ منطقيًا؛ القيم غير المنطقية تعود إلى [fallback].
bool readBool(Object? value, {bool fallback = false}) => value is bool
    ? value
    : fallback;

/// يقرأ تاريخًا من `Timestamp` أو `DateTime` أو ميلي-ثانية رقمية.
///
/// لا نستورد `cloud_firestore` هنا عمدًا: نقرأ `.toDate()` عبر واجهة ديناميكية
/// ضيّقة، فيبقى هذا الملف قابلًا للاختبار في بيئة بلا Firebase.
DateTime? readDate(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  try {
    // Timestamp في Firestore يوفّر toDate().
    final Object? converted = (value as dynamic).toDate();
    if (converted is DateTime) {
      return converted;
    }
  } on Object {
    // نوع غير مدعوم — نتجاهله بهدوء.
  }
  return null;
}

/// يحوّل حالة ملف المدرس النصية إلى التعداد.
///
/// أي قيمة غير معروفة تُعتبر [TeacherProfileStatus.pendingReview]: الأسلم أن
/// يبقى الملف مخفيًا حتى تُراجع الإدارة بياناته، لا أن يظهر للطلاب بالخطأ.
TeacherProfileStatus parseTeacherStatus(Object? raw) {
  return switch (readString(raw)) {
    'approved' => TeacherProfileStatus.approved,
    'rejected' => TeacherProfileStatus.rejected,
    'draft' => TeacherProfileStatus.draft,
    'pendingReview' => TeacherProfileStatus.pendingReview,
    _ => TeacherProfileStatus.pendingReview,
  };
}

/// يحوّل طريقة الحضور النصية إلى التعداد (الافتراضي: أونلاين).
GroupMeetingMode parseMeetingMode(Object? raw) {
  return switch (readString(raw)) {
    'home' => GroupMeetingMode.home,
    'center' => GroupMeetingMode.center,
    'online' => GroupMeetingMode.online,
    _ => GroupMeetingMode.online,
  };
}

/// يحوّل حالة طلب الحجز النصية إلى التعداد (الافتراضي: قيد الانتظار).
BookingStatus parseBookingStatus(Object? raw) => BookingStatus.parse(raw);

/// يحوّل من اقترح الوقت البديل (الافتراضي: المدرس — الأسلم لأن الطالب هو من
/// يقبل افتراضيًا في الواجهة).
BookingActor? parseBookingActor(Object? raw) =>
    raw == null ? null : BookingActor.parse(raw);

/// `teacherProfiles/{id}` → [TeacherProfile].
///
/// يعيد `null` إن كان المستند بلا اسم (بيانات غير صالحة للعرض).
TeacherProfile? teacherProfileFromMap(String id, Map<String, Object?> data) {
  final String? name = readString(data['displayName']);
  if (name == null) {
    return null;
  }

  return TeacherProfile(
    id: id,
    displayName: name,
    subject: readString(data['subject']) ?? 'غير محدد',
    stage: readString(data['stage']) ?? 'غير محدد',
    area: readString(data['area']) ?? 'غير محدد',
    bio: readString(data['bio']) ?? '',
    status: parseTeacherStatus(data['status']),
    isFeatured: readBool(data['isFeatured']),
    rating: readDouble(data['rating']),
    reviewsCount: readInt(data['reviewsCount']),
    priceHint: readString(data['priceHint']),
  );
}

/// `studyGroups/{id}` → [StudyGroup].
///
/// يعيد `null` إن كان المستند بلا عنوان أو بلا مالك.
StudyGroup? studyGroupFromMap(String id, Map<String, Object?> data) {
  final String? title = readString(data['title']);
  final String? teacherId = readString(data['teacherId']);
  if (title == null || teacherId == null) {
    return null;
  }

  final int seatsTotal = readInt(data['seatsTotal']);
  final int seatsTaken = readInt(data['seatsTaken']);

  return StudyGroup(
    id: id,
    teacherId: teacherId,
    teacherName: readString(data['teacherName']) ?? 'مدرس',
    title: title,
    subject: readString(data['subject']) ?? 'غير محدد',
    stage: readString(data['stage']) ?? 'غير محدد',
    // الحماية من أرقام سالبة أو متناقضة قادمة من بيانات قديمة.
    seatsTotal: seatsTotal < 0 ? 0 : seatsTotal,
    seatsTaken: seatsTaken < 0 ? 0 : seatsTaken,
    meetingMode: parseMeetingMode(data['meetingMode']),
    scheduleNote: readString(data['scheduleNote']),
    isActive: readBool(data['isActive'], fallback: true),
  );
}

/// `studyGroups/{id}/members/{uid}` → [GroupMember].
GroupMember? groupMemberFromMap(String id, Map<String, Object?> data) {
  final String? name = readString(data['name']);
  if (name == null) {
    return null;
  }

  return GroupMember(
    id: id,
    name: name,
    joinedAt: readDate(data['joinedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    status: readString(data['status']) == 'waitlist'
        ? GroupMemberStatus.waitlist
        : GroupMemberStatus.active,
    movedAt: readDate(data['movedAt']),
    movedFromGroupTitle: readString(data['movedFromGroupTitle']),
  );
}

/// `groupWaitlist/{groupId_studentId}` → [GroupWaitlistEntry] (P9).
///
/// يعيد `null` إن كان الصف بلا طالب أو بلا مالك: صف بلا مالك لا يمكن للمدرس
/// رؤيته أصلًا، وصف بلا طالب لا معنى له.
GroupWaitlistEntry? groupWaitlistEntryFromMap(
  String id,
  Map<String, Object?> data,
) {
  final String? groupId = readString(data['groupId']);
  final String? teacherId = readString(data['teacherId']);
  final String? studentId = readString(data['studentId']);
  final String? studentName = readString(data['studentName']);
  if (groupId == null ||
      teacherId == null ||
      studentId == null ||
      studentName == null) {
    return null;
  }

  return GroupWaitlistEntry(
    id: id,
    groupId: groupId,
    groupTitle: readString(data['groupTitle']) ?? '',
    teacherId: teacherId,
    studentId: studentId,
    studentName: studentName,
    status: WaitlistStatus.parse(data['status']),
    addedAt: readDate(data['addedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    decidedAt: readDate(data['decidedAt']),
    decidedBy: readString(data['decidedBy']),
  );
}

/// `studyGroups/{id}/sessions/{id}` → [GroupSession].
///
/// يعيد `null` إن كان المستند بلا عنوان أو بلا مالك — موعد بلا صاحب لا يمكن
/// تعديله ولا نسبته لمدرس.
GroupSession? groupSessionFromMap(String id, Map<String, Object?> data) {
  final String? title = readString(data['title']);
  final String? teacherId = readString(data['teacherId']);
  final String? groupId = readString(data['groupId']);
  if (title == null || teacherId == null || groupId == null) {
    return null;
  }

  final int start = readInt(data['startMinutes'], fallback: -1);
  final int duration = readInt(data['durationMinutes'], fallback: 0);

  return GroupSession(
    id: id,
    groupId: groupId,
    teacherId: teacherId,
    title: title,
    weekday: GroupWeekday.parse(data['weekday']),
    // حماية من بيانات قديمة/فاسدة: نطاقات منطقية بدل رمي استثناء في الواجهة.
    startMinutes: start < 0 || start > 1439 ? 0 : start,
    durationMinutes: duration <= 0 ? 30 : duration,
    locationNote: readString(data['locationNote']),
    isCancelled: readBool(data['isCancelled']),
  );
}

/// `studyGroups/{id}/messages/{id}` → [GroupMessage].
GroupMessage? groupMessageFromMap(String id, Map<String, Object?> data) {
  final String? senderId = readString(data['senderId']);
  final String? text = readString(data['text']);
  final String? groupId = readString(data['groupId']);
  if (senderId == null || text == null || groupId == null) {
    return null;
  }

  return GroupMessage(
    id: id,
    groupId: groupId,
    senderId: senderId,
    senderName: readString(data['senderName']) ?? 'عضو',
    senderRole: parseSenderRole(data['senderRole']),
    text: text,
    sentAt:
        readDate(data['sentAt']) ??
        readDate(data['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// `groupJoinRequests/{id}` → [GroupJoinRequest].
///
/// يعيد `null` إن كان المستند بلا مجموعة أو بلا طالب — طلب بلا طرف لا معنى له
/// ولا يجوز أن يظهر في قائمة المدرس.
GroupJoinRequest? joinRequestFromMap(String id, Map<String, Object?> data) {
  final String? groupId = readString(data['groupId']);
  final String? studentId = readString(data['studentId']);
  final String? teacherId = readString(data['teacherId']);
  if (groupId == null || studentId == null || teacherId == null) {
    return null;
  }

  return GroupJoinRequest(
    id: id,
    groupId: groupId,
    groupTitle: readString(data['groupTitle']) ?? 'مجموعة',
    teacherId: teacherId,
    studentId: studentId,
    studentName: readString(data['studentName']) ?? 'طالب',
    status: JoinRequestStatus.parse(readString(data['status'])),
    requestedAt:
        readDate(data['requestedAt']) ??
        readDate(data['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    decidedAt: readDate(data['decidedAt']),
    decidedBy: readString(data['decidedBy']),
  );
}

/// `bookingRequests/{id}` → [BookingRequest].
///
/// يعيد `null` إن كان المستند بلا اسم طالب أو مدرس.
BookingRequest? bookingFromMap(String id, Map<String, Object?> data) {
  final String? teacherName = readString(data['teacherName']);
  final String? studentName = readString(data['studentName']);
  if (teacherName == null || studentName == null) {
    return null;
  }

  return BookingRequest(
    id: id,
    teacherName: teacherName,
    studentName: studentName,
    teacherId: readString(data['teacherId']),
    studentId: readString(data['studentId']),
    subject: readString(data['subject']) ?? 'غير محدد',
    requestedAt:
        readDate(data['requestedAt']) ??
        readDate(data['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    status: parseBookingStatus(data['status']),
    note: readString(data['note']),
    dateKey: readString(data['dateKey']),
    startMinutes: readOptInt(data['startMinutes']),
    durationMinutes: readOptInt(data['durationMinutes']),
    decidedAt: readDate(data['decidedAt']),
    decidedBy: readString(data['decidedBy']),
    cancelledAt: readDate(data['cancelledAt']),
    cancelledBy: readString(data['cancelledBy']),
    proposalDateKey: readString(data['proposalDateKey']),
    proposalStartMinutes: readOptInt(data['proposalStartMinutes']),
    proposedBy: parseBookingActor(data['proposedBy']),
    proposedAt: readDate(data['proposedAt']),
  );
}

/// يحوّل قائمة مستندات إلى نماذج، متجاهلًا المستندات غير الصالحة.
///
/// الاستخدام في المستودعات يمرّ من هنا فقط، حتى لا يظهر `null` في الواجهة.
List<T> mapDocuments<T>(
  Iterable<(String, Map<String, Object?>)> documents,
  T? Function(String id, Map<String, Object?> data) mapper,
) {
  final List<T> result = <T>[];
  for (final (String id, Map<String, Object?> data) in documents) {
    final T? mapped = mapper(id, data);
    if (mapped != null) {
      result.add(mapped);
    }
  }
  return List<T>.unmodifiable(result);
}
