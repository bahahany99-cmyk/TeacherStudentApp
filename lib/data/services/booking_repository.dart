import 'package:teacher_student_app/data/models/booking_request.dart';

/// عقد الحجوزات (P10).
///
/// **النموذج المعتمد (A-74):** الطالب يقترح موعدًا محددًا، والمدرس يقبل أو يرفض
/// أو يقترح وقتًا بديلًا. لا يوجد محرّك توفّر في هذه المرحلة.
///
/// **الضمانات (A-75/A-76):**
/// - لا يصبح أي حجز مؤكدًا إلا بقرار المدرس.
/// - لا يُقبل حجز يتقاطع مع حجز مؤكد آخر لنفس المدرس؛ الفحص **داخل معاملة**
///   على مستند تقويم يومي واحد لكل مدرس، فتتسلسل القرارات المتزامنة.
/// - الإلغاء داخل 12 ساعة قبل الموعد يُسجّل `cancelledLate` لا `cancelled`.
abstract interface class BookingRepository {
  /// طلبات المستخدم الحالي (طالبًا كان أو مدرسًا).
  Future<List<BookingRequest>> listMine();

  /// (P25) **نفس القائمة حيًّا** — يغلق «الحجز المقبول لا يظهر للطالب».
  ///
  /// المشكلة التي كانت قائمة: شاشة الحجوزات تقرأ مرة واحدة عند الفتح. المدرس
  /// يقبل الطلب، والطالب يبقى أمام «لا توجد طلبات» حتى يخرج من التبويب ويعود
  /// (أو يُعيد تشغيل التطبيق). التدفّق يقرأ الاستعلامين (كطالب وكمعلم) ويعيد
  /// دمجهما عند كل تغيير، فتصل حالة `accepted` في اللحظة نفسها.
  Stream<List<BookingRequest>> watchMine();

  /// طلب واحد بالمعرّف، أو `null` إن لم يوجد أو لم يكن للمستخدم الحالي.
  Future<BookingRequest?> findById(String id);

  /// ينشئ الطالب طلب حجز بموعد محدد.
  ///
  /// يرفض مبكرًا (برسالة عربية) إن كان الموعد في الماضي أو خارج النافذة
  /// الزمنية أو متقاطعًا مع حجز مؤكد — والتحقق النهائي داخل المعاملة.
  Future<BookingRequest> createRequest({
    required String teacherId,
    required String teacherName,
    required String studentId,
    required String studentName,
    required String subject,
    required DateTime startsAt,
    required int durationMinutes,
    String? note,
  });

  /// قرار المدرس: قبول (مع حجز الوقت) أو رفض.
  ///
  /// القبول يقرأ تقويم اليوم داخل المعاملة، ويرفض بـ[BookingRules.conflictMessage]
  /// إن تقاطع الموعد مع حجز مؤكد آخر.
  Future<BookingRequest> decideRequest({
    required BookingRequest request,
    required String teacherId,
    required bool approve,
  });

  /// إلغاء أحد الطرفين. الحالة تُصنَّف مبكرًا/متأخرًا حسب وقت الإلغاء.
  Future<BookingRequest> cancelRequest({
    required BookingRequest request,
    required String actorId,
    required bool byTeacher,
  });

  /// اقتراح وقت بديل (من أي من الطرفين) لطلب معلّق أو مؤكد.
  Future<BookingRequest> proposeReschedule({
    required BookingRequest request,
    required String actorId,
    required bool byTeacher,
    required DateTime startsAt,
  });

  /// ردّ الطرف الآخر على الاقتراح: قبول (يصبح الموعد الجديد مؤكدًا) أو رفض.
  Future<BookingRequest> respondToProposal({
    required BookingRequest request,
    required String actorId,
    required bool byTeacher,
    required bool accept,
  });

  /// المدرس يعلن تنفيذ الحصة بعد انتهاء موعدها.
  Future<BookingRequest> completeRequest({
    required BookingRequest request,
    required String teacherId,
  });
}
