import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/validation/model_validators.dart';

/// قواعد دورة حياة المجموعة الدراسية — **دوال نقية**.
///
/// هذه القواعد موجودة في ثلاثة أماكن بقصد، وكل مكان له دور مختلف:
/// 1. **هنا (العميل)**: رسالة عربية فورية قبل أي طلب شبكة، وتجربة كتابة سليمة.
/// 2. **`firestore.rules`**: الحارس الحقيقي؛ العميل غير موثوق.
/// 3. **اختبارات المحاكي**: تُثبت أن (2) يطابق ما نعتقده فعلًا.
///
/// أي تغيير في حدّ هنا يجب أن يقابله تغيير في القواعد — والاختبارات تحمي ذلك.
abstract final class GroupRules {
  /// أقل سعة ذات معنى (مجموعة من مقعد مذاكرة فردية لا مجموعة).
  static const int minSeats = ModelLimits.seatsMin;

  /// أقصى سعة مسموحة — **حدّ صارم 40** (A-70)، مطابق للقواعد.
  static const int maxSeats = ModelLimits.seatsMax;

  /// هل يمكن قبول عضو جديد الآن؟
  ///
  /// المنع النهائي يحدث على الخادم بعملية ذرية عند قبول الطلب (P8)؛ هنا نعرض
  /// الحالة فقط حتى لا يُرسل التطبيق طلبًا سيعرف أنه مرفوض.
  static bool canAcceptMember(StudyGroup group) =>
      group.isActive && group.seatsAvailable > 0;

  /// أقصى قيمة «مقاعد» يجوز للمدرس كتابتها عند التعديل.
  ///
  /// لا يجوز تقليل السعة تحت عدد الطلاب المنضمين فعلًا؛ وإلا صارت المجموعة
  /// «ممتلئة سالبًا» وكسرت شاشة العرض.
  static int minAllowedSeats(int seatsTaken) =>
      seatsTaken > minSeats ? seatsTaken : minSeats;

  /// سبب رفض سعة مقترحة — أو `null` إن كانت مقبولة.
  ///
  /// ثلاث حدود لا يُستثنى منها شيء:
  /// 1. لا تقل عن [minSeats].
  /// 2. لا تزيد عن [maxSeats] (40) — حدّ صارم، فلا «توسيع» يلتف على الاكتمال.
  /// 3. لا تقل عن عدد المنضمين فعلًا؛ وإلا صارت المجموعة ممتلئة بالسالب.
  ///
  /// الدالة تُستخدم في نموذج التعديل وفي المستودعين **داخل المعاملة** على
  /// القراءة الطازجة، فلا تنفع قيمة قديمة من واجهة المستخدم.
  static String? capacityBlockReason({
    required int seatsTotal,
    required int seatsTaken,
  }) {
    if (seatsTotal < minSeats) {
      return 'السعة لا تقل عن $minSeats مقعدين.';
    }
    if (seatsTotal > maxSeats) {
      return 'الحد الأقصى لسعة المجموعة $maxSeats مقعدًا.';
    }
    if (seatsTotal < seatsTaken) {
      return 'لا يمكن تقليل السعة عن $seatsTaken عضوًا منضمًا.';
    }
    return null;
  }

  static bool canSetCapacity({
    required int seatsTotal,
    required int seatsTaken,
  }) =>
      capacityBlockReason(
        seatsTotal: seatsTotal,
        seatsTaken: seatsTaken,
      ) ==
      null;

  /// تحقق كامل من المسودة (إنشاء أو تعديل).
  ///
  /// [seatsTaken] تُمرَّر عند التعديل فقط؛ عند الإنشاء تكون صفرًا.
  static ValidationResult validateDraft(
    GroupDraft draft, {
    int seatsTaken = 0,
  }) {
    final List<ValidationProblem> problems = <ValidationProblem>[
      ...validateGroupDraft(
        title: draft.title,
        subject: draft.subject,
        stage: draft.stage,
        seatsTotal: draft.seatsTotal,
        scheduleNote: draft.scheduleNote,
      ).problems,
    ];

    if (draft.seatsTotal < seatsTaken) {
      problems.add(
        const ValidationProblem('seatsTotal', FieldIssue.outOfRange),
      );
    }

    return ValidationResult(List<ValidationProblem>.unmodifiable(problems));
  }

  /// هل التعديل محاولة «إغلاق» للمجموعة؟ (يُستخدم لتأكيد قبل الحفظ.)
  static bool isBecomingInactive(StudyGroup? current, bool newIsActive) =>
      current != null && current.isActive && !newIsActive;

  /// ملخص عربي لحالة السعة — يُعرض في بطاقة المجموعة داخل نموذج التعديل.
  static String capacitySummary(StudyGroup group) {
    if (!group.isActive) {
      return 'المجموعة موقوفة: لا تظهر للطلاب ولا تُقبل طلبات انضمام جديدة.';
    }
    if (group.seatsAvailable <= 0) {
      return 'المجموعة مكتملة (${group.seatsTaken} من ${group.seatsTotal}).';
    }
    return 'متاح ${group.seatsAvailable} من ${group.seatsTotal} مقعدًا.';
  }
}
