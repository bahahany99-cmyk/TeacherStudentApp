import 'package:teacher_student_app/data/demo/demo_repositories.dart';
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
