import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/group_message.dart';
import 'package:teacher_student_app/data/models/group_session.dart';
import 'package:teacher_student_app/data/models/group_waitlist_entry.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/user_role.dart';

/// ⚠️ بيانات تجريبية وهمية بالكامل.
///
/// - لا تمثّل مدرسين أو طلابًا حقيقيين.
/// - ليست قادمة من Firebase، وليست مكتوبة في Firestore.
/// - تُستخدم فقط لعرض الواجهات في المرحلة 2، وتُحذف عند ربط المستودعات
///   الحقيقية (Firestore).
abstract final class DemoData {
  static const String studentName = 'طالب تجريبي';

  static const String teacherName = 'مدرس تجريبي';

  /// معرف حساب المدرس المستخدم في وضع المعاينة (يطابق أول مدرس تجريبي).
  static const String demoTeacherId = 'demo-teacher-1';

  /// معرف حساب الطالب في وضع المعاينة (يطابق `studentId` في الحجوزات
  /// التجريبية وطلبات الانضمام المحلية).
  static const String demoStudentId = 'demo-student';

  static const List<TeacherProfile> teachers = <TeacherProfile>[
    TeacherProfile(
      id: 'demo-teacher-1',
      displayName: 'أ. سارة الخطيب',
      subject: 'الرياضيات',
      stage: 'الثانوية العامة',
      area: 'المعادي — القاهرة',
      bio: 'شرح مبسّط للجبر والتفاضل مع تدريبات محلولة بعد كل حصة.',
      status: TeacherProfileStatus.approved,
      isFeatured: true,
      rating: 4.8,
      reviewsCount: 126,
      priceHint: 'سعر استرشادي: 150 ج.م / حصة',
    ),
    TeacherProfile(
      id: 'demo-teacher-2',
      displayName: 'أ. أحمد الشناوي',
      subject: 'الفيزياء',
      stage: 'الثانوية العامة',
      area: 'سموحة — الإسكندرية',
      bio: 'متابعة أسبوعية وتقارير مستوى لولي الأمر.',
      status: TeacherProfileStatus.approved,
      isFeatured: true,
      rating: 4.7,
      reviewsCount: 98,
      priceHint: 'سعر استرشادي: 180 ج.م / حصة',
    ),
    TeacherProfile(
      id: 'demo-teacher-3',
      displayName: 'أ. منى عبد الرحمن',
      subject: 'اللغة العربية',
      stage: 'الإعدادية',
      area: 'طنطا — الغربية',
      bio: 'تأسيس في النحو والقراءة، ومتابعة فروض المدرسة.',
      status: TeacherProfileStatus.approved,
      rating: 4.6,
      reviewsCount: 64,
      priceHint: 'سعر استرشادي: 100 ج.م / حصة',
    ),
    TeacherProfile(
      id: 'demo-teacher-4',
      displayName: 'أ. يوسف كامل',
      subject: 'اللغة الإنجليزية',
      stage: 'الابتدائية',
      area: 'المنصورة — الدقهلية',
      bio: 'تأسيس قراءة وكتابة للأطفال، وأنشطة محادثة بسيطة.',
      status: TeacherProfileStatus.approved,
      rating: 4.5,
      reviewsCount: 41,
      priceHint: 'سعر استرشادي: 90 ج.م / حصة',
    ),
    TeacherProfile(
      id: 'demo-teacher-5',
      displayName: 'أ. هدى مصطفى',
      subject: 'الكيمياء',
      stage: 'الثانوية العامة',
      area: 'أسيوط',
      bio: 'مراجعات نهائية وبنك أسئلة إلكتروني.',
      status: TeacherProfileStatus.approved,
      rating: 4.4,
      reviewsCount: 33,
    ),
    // ملف لم يُعتمد بعد — لا يجب أن يظهر في نتائج البحث.
    // وجوده هنا للتحقق من أن طبقة المستودع تُفلتره.
    TeacherProfile(
      id: 'demo-teacher-6-review',
      displayName: 'أ. خالد إبراهيم',
      subject: 'الأحياء',
      stage: 'الثانوية العامة',
      area: 'الزقازيق — الشرقية',
      bio: 'ملف جديد بانتظار مراجعة الإدارة.',
      status: TeacherProfileStatus.pendingReview,
      rating: 0,
      reviewsCount: 0,
    ),
  ];

  static const List<StudyGroup> groups = <StudyGroup>[
    StudyGroup(
      id: 'demo-group-1',
      teacherId: 'demo-teacher-1',
      teacherName: 'أ. سارة الخطيب',
      title: 'مجموعة الرياضيات — التفاضل',
      subject: 'الرياضيات',
      stage: 'الثانوية العامة',
      seatsTotal: 12,
      seatsTaken: 9,
      meetingMode: GroupMeetingMode.center,
      scheduleNote: 'السبت والثلاثاء — 5 مساءً',
    ),
    StudyGroup(
      id: 'demo-group-2',
      teacherId: 'demo-teacher-2',
      teacherName: 'أ. أحمد الشناوي',
      title: 'مجموعة الفيزياء — الحديثة',
      subject: 'الفيزياء',
      stage: 'الثانوية العامة',
      seatsTotal: 10,
      seatsTaken: 10,
      meetingMode: GroupMeetingMode.online,
      scheduleNote: 'الجمعة — 7 مساءً',
    ),
    StudyGroup(
      id: 'demo-group-3',
      teacherId: 'demo-teacher-3',
      teacherName: 'أ. منى عبد الرحمن',
      title: 'تأسيس النحو',
      subject: 'اللغة العربية',
      stage: 'الإعدادية',
      seatsTotal: 15,
      seatsTaken: 5,
      meetingMode: GroupMeetingMode.home,
      scheduleNote: 'الأحد والأربعاء — 4 عصرًا',
    ),
    StudyGroup(
      id: 'demo-group-4',
      teacherId: 'demo-teacher-4',
      teacherName: 'أ. يوسف كامل',
      title: 'محادثة إنجليزي للأطفال',
      subject: 'اللغة الإنجليزية',
      stage: 'الابتدائية',
      seatsTotal: 8,
      seatsTaken: 3,
      meetingMode: GroupMeetingMode.online,
      scheduleNote: 'الاثنين — 6 مساءً',
    ),
    // مجموعة مكتملة **لصاحب الجلسة التجريبية** حتى يجرّب المستخدم مسار
    // قائمة الانتظار من الجهتين: طالبًا ينتظر، ومدرسًا يقبل منتظرًا.
    StudyGroup(
      id: 'demo-group-5',
      teacherId: demoTeacherId,
      teacherName: 'أ. سارة الخطيب',
      title: 'التفاضل — المستوى الثاني',
      subject: 'الرياضيات',
      stage: 'الثانوية العامة',
      seatsTotal: 6,
      seatsTaken: 6,
      meetingMode: GroupMeetingMode.online,
      scheduleNote: 'الخميس — 8 مساءً',
    ),
  ];

  static final List<BookingRequest> bookings = <BookingRequest>[
    BookingRequest(
      id: 'demo-booking-1',
      teacherName: 'أ. سارة الخطيب',
      studentName: 'طالب تجريبي',
      teacherId: 'demo-teacher-1',
      studentId: 'demo-student',
      subject: 'الرياضيات — التفاضل',
      requestedAt: DateTime(2026, 10, 24, 18, 30),
      status: BookingStatus.pending,
      note: 'أحتاج حصة لمراجعة الوحدة الثانية.',
      // موعد مقترح (P10): التاريخ ثابت مثل بقية البيانات التجريبية.
      dateKey: '2026-10-26',
      startMinutes: 18 * 60,
      durationMinutes: 60,
    ),
    BookingRequest(
      id: 'demo-booking-2',
      teacherName: 'أ. منى عبد الرحمن',
      studentName: 'طالب تجريبي',
      teacherId: 'demo-teacher-3',
      studentId: 'demo-student',
      subject: 'اللغة العربية — النحو',
      requestedAt: DateTime(2026, 10, 20, 11, 0),
      status: BookingStatus.accepted,
      dateKey: '2026-10-21',
      startMinutes: 16 * 60,
      durationMinutes: 60,
      decidedAt: DateTime(2026, 10, 20, 12, 0),
      decidedBy: 'demo-teacher-3',
    ),
    BookingRequest(
      id: 'demo-booking-3',
      teacherName: 'أ. أحمد الشناوي',
      studentName: 'طالب تجريبي',
      teacherId: 'demo-teacher-2',
      studentId: 'demo-student',
      subject: 'الفيزياء — الكهربية',
      requestedAt: DateTime(2026, 10, 12, 9, 15),
      status: BookingStatus.rejected,
      note: 'الموعد غير مناسب حاليًا.',
      dateKey: '2026-10-14',
      startMinutes: 17 * 60,
      durationMinutes: 45,
      decidedAt: DateTime(2026, 10, 12, 10, 0),
      decidedBy: 'demo-teacher-2',
    ),
  ];

  /// أسماء وهمية لتوليد أعضاء المجموعات.
  ///
  /// نولّد العدد من `seatsTaken` حتى تكون شاشة الأعضاء متوافقة مع عدد المقاعد
  /// المعروض في البطاقة، ولا تظهر بيانات متناقضة للمراجع.
  static const List<String> _memberNamesPool = <String>[
    'محمد سامي',
    'مريم أشرف',
    'عبد الرحمن فتحي',
    'نور الهدى',
    'يوسف عمرو',
    'سلمى مجدي',
    'كريم طارق',
    'هبة الله',
    'أحمد جمال',
    'رنا شريف',
  ];

  /// أعضاء مجموعة تجريبية عددهم = المقاعد المشغولة.
  ///
  /// ⚠️ وهميون بالكامل، ولا يمثّلون طلابًا حقيقيين.
  // ── P9: جدول أسبوعي تجريبي لمجموعة العرض الأولى ──────────────────────────
  //
  // موعدان لا يتداخلان، حتى يجرّب المستخدم الإضافة والتعديل والإلغاء بلا أن
  // يصطدم برسالة تداخل مباشرة.
  static const String demoSessionTeacherId = 'demo-teacher-1';

  static const List<GroupSession> sessions = <GroupSession>[
    GroupSession(
      id: 'demo-session-1',
      groupId: 'demo-group-1',
      teacherId: demoSessionTeacherId,
      title: 'التفاضل — مراجعة الوحدة الثانية',
      weekday: GroupWeekday.saturday,
      startMinutes: 17 * 60,
      durationMinutes: 90,
      locationNote: 'سنتر المعادي',
    ),
    GroupSession(
      id: 'demo-session-2',
      groupId: 'demo-group-1',
      teacherId: demoSessionTeacherId,
      title: 'حلّ تدريبات',
      weekday: GroupWeekday.tuesday,
      startMinutes: 19 * 60 + 30,
      durationMinutes: 60,
    ),
  ];

  // ── P9: محادثة تجريبية لمجموعة العرض الأولى ──────────────────────────────
  static final List<GroupMessage> messages = <GroupMessage>[
    GroupMessage(
      id: 'demo-message-1',
      groupId: 'demo-group-1',
      senderId: demoSessionTeacherId,
      senderName: 'أ. سارة الخطيب',
      senderRole: UserRole.teacher,
      text: 'ممتاز يا شباب، هنبدأ الوحدة الثانية السبت. راجعوا القوانين قبل الحصة.',
      sentAt: DateTime(2026, 9, 1, 18, 5),
    ),
  ];

  // ── P9: قائمة انتظار لمجموعة العرض المكتملة ──────────────────────────────
  //
  // الصفان يخصّان مجموعة مكتملة (6 من 6) حتى تكون البيانات متسقة مع القاعدة:
  // لا طابور لمجموعة فيها مقعد.
  static final List<GroupWaitlistEntry> waitlist = <GroupWaitlistEntry>[
    GroupWaitlistEntry(
      id: GroupWaitlistEntry.idFor(
        groupId: 'demo-group-5',
        studentId: 'demo-waitlist-1',
      ),
      groupId: 'demo-group-5',
      groupTitle: 'التفاضل — المستوى الثاني',
      teacherId: demoTeacherId,
      studentId: 'demo-waitlist-1',
      studentName: 'سلمى مجدي',
      status: WaitlistStatus.waiting,
      addedAt: DateTime(2026, 10, 20, 19, 30),
    ),
    GroupWaitlistEntry(
      id: GroupWaitlistEntry.idFor(
        groupId: 'demo-group-5',
        studentId: 'demo-waitlist-2',
      ),
      groupId: 'demo-group-5',
      groupTitle: 'التفاضل — المستوى الثاني',
      teacherId: demoTeacherId,
      studentId: 'demo-waitlist-2',
      studentName: 'كريم طارق',
      status: WaitlistStatus.waiting,
      addedAt: DateTime(2026, 10, 22, 21, 10),
    ),
  ];

  // ── P11: المحادثات المباشرة وإعدادات الخصوصية ────────────────────────────
  //
  // الخيار الافتراضي في المنتج **مغلق** (A-78). هنا نفعّله للمدرس التجريبي وحده
  // حتى تُجرَّب مسارات الاستفسار، ونتركه مغلقًا لغيره لإظهار الحالة المتشدّدة.
  static const Map<String, bool> directMessageSettings = <String, bool>{
    'demo-teacher-1': true,
    'demo-teacher-2': false,
    'demo-teacher-3': true,
  };

  /// محادثتان تجريبيتان: واحدة مرتبطة بحجز، وأخرى استفسار بدأه المدرس.
  static final List<DirectChat> directChats = <DirectChat>[
    DirectChat(
      id: DirectChat.idFor(teacherId: 'demo-teacher-1', studentId: demoStudentId),
      teacherId: 'demo-teacher-1',
      teacherName: 'أ. سارة الخطيب',
      studentId: demoStudentId,
      studentName: 'طالب تجريبي',
      subject: 'الرياضيات — التفاضل',
      origin: DirectChatOrigin.booking,
      bookingId: 'demo-booking-1',
      createdAt: DateTime(2026, 10, 24, 18, 40),
      lastMessageAt: DateTime(2026, 10, 24, 19, 5),
      lastMessageText: 'تمام يا أستاذة، أجهّز أسئلة الوحدة الثانية.',
      lastSenderId: demoStudentId,
      studentLastReadAt: DateTime(2026, 10, 24, 19, 10),
      teacherLastReadAt: DateTime(2026, 10, 24, 19, 6),
    ),
    DirectChat(
      id: DirectChat.idFor(teacherId: 'demo-teacher-3', studentId: demoStudentId),
      teacherId: 'demo-teacher-3',
      teacherName: 'أ. منى عبد الرحمن',
      studentId: demoStudentId,
      studentName: 'طالب تجريبي',
      subject: 'اللغة العربية — النحو',
      origin: DirectChatOrigin.inquiry,
      createdAt: DateTime(2026, 10, 22, 10, 0),
      lastMessageAt: DateTime(2026, 10, 22, 10, 15),
      lastMessageText: 'أهلًا بك، اسأل عن أي شيء يخصّ النحو قبل الحجز.',
      lastSenderId: 'demo-teacher-3',
      teacherLastReadAt: DateTime(2026, 10, 22, 10, 15),
    ),
  ];

  /// رسائل المحادثتين أعلاه — مرتّبة تصاعديًا كما يعيدها المستودع.
  static final List<DirectChatMessage> directMessages = <DirectChatMessage>[
    DirectChatMessage(
      id: 'demo-direct-message-1',
      chatId: DirectChat.idFor(
        teacherId: 'demo-teacher-1',
        studentId: demoStudentId,
      ),
      senderId: demoStudentId,
      senderName: 'طالب تجريبي',
      senderRole: UserRole.student,
      text: 'السلام عليكم، أرسلت طلب حجز لمراجعة التفاضل. هل الموعد مناسب؟',
      sentAt: DateTime(2026, 10, 24, 18, 40),
    ),
    DirectChatMessage(
      id: 'demo-direct-message-2',
      chatId: DirectChat.idFor(
        teacherId: 'demo-teacher-1',
        studentId: demoStudentId,
      ),
      senderId: 'demo-teacher-1',
      senderName: 'أ. سارة الخطيب',
      senderRole: UserRole.teacher,
      text: 'وعليكم السلام، نعم مناسب. سأؤكد الطلب خلال ساعة.',
      sentAt: DateTime(2026, 10, 24, 19, 0),
    ),
    DirectChatMessage(
      id: 'demo-direct-message-3',
      chatId: DirectChat.idFor(
        teacherId: 'demo-teacher-1',
        studentId: demoStudentId,
      ),
      senderId: demoStudentId,
      senderName: 'طالب تجريبي',
      senderRole: UserRole.student,
      text: 'تمام يا أستاذة، أجهّز أسئلة الوحدة الثانية.',
      sentAt: DateTime(2026, 10, 24, 19, 5),
    ),
    DirectChatMessage(
      id: 'demo-direct-message-4',
      chatId: DirectChat.idFor(
        teacherId: 'demo-teacher-3',
        studentId: demoStudentId,
      ),
      senderId: 'demo-teacher-3',
      senderName: 'أ. منى عبد الرحمن',
      senderRole: UserRole.teacher,
      text: 'أهلًا بك، اسأل عن أي شيء يخصّ النحو قبل الحجز.',
      sentAt: DateTime(2026, 10, 22, 10, 15),
    ),
  ];

  // ── P12: إشعارات تجريبية ─────────────────────────────────────────────────
  //
  // اثنان للطالب (واحد غير مقروء) وواحد للمدرس غير مقروء، حتى يظهر عدّاد
  // الجرس في الدورين ويُجرَّب «تعليم الكل مقروء».
  static final List<AppNotification> notifications = <AppNotification>[
    AppNotification(
      id: 'demo-notification-1',
      recipientId: demoTeacherId,
      type: NotificationType.bookingRequested,
      actorId: demoStudentId,
      actorName: 'طالب تجريبي',
      targetId: 'demo-booking-1',
      title: 'طلب حجز جديد من طالب تجريبي',
      body: 'المادة: الرياضيات — التفاضل. راجع الطلب واقبله أو اقترح وقتًا بديلًا.',
      createdAt: DateTime(2026, 10, 24, 18, 31),
    ),
    AppNotification(
      id: 'demo-notification-2',
      recipientId: demoStudentId,
      type: NotificationType.bookingAccepted,
      actorId: 'demo-teacher-3',
      actorName: 'أ. منى عبد الرحمن',
      targetId: 'demo-booking-2',
      title: 'قبلت أ. منى عبد الرحمن طلب الحجز',
      body: 'موعدك أصبح مؤكدًا: الأربعاء 21/10 — 4:00 م.',
      createdAt: DateTime(2026, 10, 20, 12, 1),
      readAt: DateTime(2026, 10, 20, 12, 30),
    ),
    AppNotification(
      id: 'demo-notification-3',
      recipientId: demoStudentId,
      type: NotificationType.directMessage,
      actorId: 'demo-teacher-3',
      actorName: 'أ. منى عبد الرحمن',
      targetId: DirectChat.idFor(
        teacherId: 'demo-teacher-3',
        studentId: demoStudentId,
      ),
      title: 'رسالة من أ. منى عبد الرحمن',
      body: 'أرسل لك أ. منى عبد الرحمن رسالة جديدة.',
      createdAt: DateTime(2026, 10, 22, 10, 16),
    ),
  ];

  static List<GroupMember> membersFor(String groupId) {
    StudyGroup? group;
    for (final StudyGroup candidate in groups) {
      if (candidate.id == groupId) {
        group = candidate;
        break;
      }
    }
    if (group == null) {
      return const <GroupMember>[];
    }

    return List<GroupMember>.unmodifiable(<GroupMember>[
      for (int i = 0; i < group.seatsTaken; i++)
        GroupMember(
          id: '$groupId-member-${i + 1}',
          name: _memberNamesPool[i % _memberNamesPool.length],
          // تواريخ ثابتة حتى لا تتغير الواجهة بين تشغيلين.
          joinedAt: DateTime(2026, 9, 1).add(Duration(days: i * 3)),
        ),
    ]);
  }
}
