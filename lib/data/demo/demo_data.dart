import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';

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
