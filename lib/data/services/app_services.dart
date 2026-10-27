import 'package:teacher_student_app/core/config/firebase_bootstrap.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/firebase/firebase_auth_service.dart';
import 'package:teacher_student_app/data/firebase/firestore_repositories.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';
import 'package:teacher_student_app/data/services/booking_repository.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';
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
  });

  final AuthService auth;
  final TeacherRepository teachers;
  final GroupRepository groups;
  final BookingRepository bookings;

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
    return AppServices(
      auth: FirebaseAuthService(),
      teachers: FirestoreTeacherRepository(),
      groups: FirestoreGroupRepository(),
      bookings: FirestoreBookingRepository(),
    );
  }

  /// حزمة تجريبية كاملة للعمل بلا خادم (الوضع الافتراضي في المرحلة 2).
  factory AppServices.demo() {
    return AppServices(
      auth: const DemoAuthService(),
      teachers: DemoTeacherRepository(),
      groups: DemoGroupRepository(),
      bookings: DemoBookingRepository(),
    );
  }
}
