import 'package:teacher_student_app/core/config/firebase_bootstrap.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/firebase/firebase_auth_service.dart';
import 'package:teacher_student_app/data/firebase/firestore_repositories.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';
import 'package:teacher_student_app/data/services/booking_repository.dart';
import 'package:teacher_student_app/data/services/direct_chat_repository.dart';
import 'package:teacher_student_app/data/services/favorite_repository.dart';
import 'package:teacher_student_app/data/services/notification_repository.dart';
import 'package:teacher_student_app/data/services/review_repository.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';
import 'package:teacher_student_app/data/services/message_repository.dart';
import 'package:teacher_student_app/data/services/schedule_repository.dart';
import 'package:teacher_student_app/data/services/teacher_repository.dart';

/// حاوية واحدة تعرّف "حدود" طبقة البيانات أمام الواجهات.
///
/// الشاشات لا تستورد Firebase ولا أي حزمة شبكة؛ تطلب هذه العقود فقط.
/// استبدال التنفيذ التجريبي بتنفيذ Firestore يتم في مكان واحد (هذه الحاوية).
class AppServices {
  const AppServices({
    required this.auth,
    required this.teachers,
    required this.groups,
    required this.bookings,
    required this.schedules,
    required this.messages,
    required this.chats,
    required this.notifications,
    required this.reviews,
    required this.favorites,
  });

  final AuthService auth;
  final TeacherRepository teachers;
  final GroupRepository groups;
  final BookingRepository bookings;

  /// الجدول الأسبوعي للمجموعات (P9).
  final ScheduleRepository schedules;

  /// محادثة المجموعة (P9).
  final MessageRepository messages;

  /// المحادثات المباشرة بين الطالب والمدرس (P11).
  final DirectChatRepository chats;

  /// الإشعارات داخل التطبيق (P12).
  final NotificationRepository notifications;

  /// تقييمات المدرسين ومتوسطاتها (P13).
  final ReviewRepository reviews;

  /// مفضلة الطالب: مدرسون ومجموعات (P13).
  final FavoriteRepository favorites;

  /// الحزمة المناسبة للبيئة الحالية.
  ///
  /// - Firebase جاهز ← مصادقة وقراءة حقيقية من Firestore (P4 + P5).
  /// - غير جاهز ← حزمة تجريبية كاملة (وضع الزائر)، والتطبيق يعمل بلا خادم.
  ///
  /// التبديل يحدث **هنا فقط**: الشاشات لا تعرف أي تنفيذ وراء العقد، ولا تستورد
  /// Firebase.
  factory AppServices.bootstrap() {
    if (FirebaseBootstrap.status == FirebaseStatus.ready) {
      return AppServices.firebase();
    }
    return AppServices.demo();
  }

  /// حزمة متصلة بـFirestore (تُستخدم فقط بعد نجاح التهيئة).
  factory AppServices.firebase() {
    // كاتب إشعارات واحد يخدم المستودعات الثلاثة التي تُنتج إشعارات (P12)،
    // فتبقى سياسة الإشعارات في مكان واحد.
    final FirestoreNotificationRepository notifications =
        FirestoreNotificationRepository();
    return AppServices(
      auth: FirebaseAuthService(),
      teachers: FirestoreTeacherRepository(),
      groups: FirestoreGroupRepository(notifications: notifications),
      bookings: FirestoreBookingRepository(notifications: notifications),
      schedules: FirestoreScheduleRepository(),
      messages: FirestoreMessageRepository(),
      chats: FirestoreDirectChatRepository(notifications: notifications),
      notifications: notifications,
      reviews: FirestoreReviewRepository(),
      favorites: FirestoreFavoriteRepository(),
    );
  }

  /// حزمة تجريبية كاملة للعمل بلا خادم (الوضع الافتراضي في المرحلة 2).
  factory AppServices.demo() {
    // المستودعات مترابطة عمدًا: المحادثة تتحقق من «الأصل الموثّق» (حجز قائم أو
    // عضوية مجموعة) من نفس مصادر البيانات، فلا يمرّ خيط بلا علاقة حقيقية.
    final DemoNotificationRepository notifications =
        DemoNotificationRepository();
    final DemoBookingRepository bookings = DemoBookingRepository(
      notifications: notifications,
    );
    final DemoGroupRepository groups = DemoGroupRepository(
      notifications: notifications,
    );
    return AppServices(
      auth: const DemoAuthService(),
      teachers: DemoTeacherRepository(),
      groups: groups,
      bookings: bookings,
      schedules: DemoScheduleRepository(),
      messages: DemoMessageRepository(),
      chats: DemoDirectChatRepository(
        findBooking: bookings.findById,
        isMember: groups.isMember,
        notifications: notifications,
      ),
      notifications: notifications,
      // التقييم يقرأ الحجز طازجًا من نفس المستودع، فلا يُقيَّم حجز لم يُنفَّذ.
      reviews: DemoReviewRepository(findBooking: bookings.findById),
      favorites: DemoFavoriteRepository(),
    );
  }
}
