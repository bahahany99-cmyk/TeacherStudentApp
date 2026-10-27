import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/validation/model_validators.dart';

/// قواعد الانضمام إلى مجموعة دراسية — **دوال نقية** تُستخدم في كل الطبقات.
///
/// نفس فلسفة `GroupRules` (A-55): الطبقة الوسطى تعطي رسالة عربية فورية،
/// و`firestore.rules` هي الحارس الحقيقي، واختبارات المحاكي تُثبت التطابق.
///
/// **الجزء الحرج: السعة.** القرار `canAccept` لا يُتخذ أبدًا على بيانات الواجهة
/// المخزَّنة، بل داخل معاملة Firestore على المستند المقروء طازجًا. الدالة هنا
/// مستخدمة هناك لأنها تُجيب على السؤال نفسه: هل ما زال هناك مقعد؟
abstract final class JoinRules {
  /// أقصى عدد طلبات معلّقة لمجموعة واحدة (حماية من إغراق المدرس).
  ///
  /// ⚠️ غير مفروض في القواعد (يحتاج عدًّا لا تدعمه قواعد Firestore)؛ يُفرض في
  /// الواجهة/المستودع فقط، وهو حدّ تجربة استخدام لا حدّ أمني.
  static const int maxPendingPerGroup = 40;

  /// سبب عدم إمكانية إرسال طلب جديد — أو `null` إن كان ممكنًا.
  ///
  /// [existingStatus] حالة طلب سابق لنفس الطالب في نفس المجموعة (إن وُجد).
  static String? requestBlockReason({
    required StudyGroup group,
    required String? viewerId,
    JoinRequestStatus? existingStatus,
    bool isDemoAccount = false,
  }) {
    if (viewerId != null && viewerId == group.teacherId) {
      return 'أنت صاحب المجموعة؛ لا تحتاج إلى طلب انضمام.';
    }
    if (!group.isActive) {
      return 'المجموعة موقوفة؛ لا تقبل طلبات انضمام حاليًا.';
    }
    if (group.seatsAvailable <= 0) {
      return 'المجموعة مكتملة؛ لا توجد مقاعد متاحة.';
    }
    if (existingStatus == JoinRequestStatus.pending) {
      return 'طلبك قيد المراجعة عند المدرس.';
    }
    if (existingStatus == JoinRequestStatus.accepted) {
      return 'أنت عضو في هذه المجموعة بالفعل.';
    }
    // ملاحظة: وضع الزائر يسمح بالتجربة محليًا، والتنبيه في الشاشة يوضّح ذلك.
    return null;
  }

  /// هل يمكن إرسال طلب جديد الآن؟ (فقط لإخفاء/تعطيل الزر)
  static bool canRequestJoin({
    required StudyGroup group,
    required String? viewerId,
    JoinRequestStatus? existingStatus,
  }) =>
      requestBlockReason(
        group: group,
        viewerId: viewerId,
        existingStatus: existingStatus,
      ) ==
      null;

  /// سبب عدم إمكانية قبول الطلب — أو `null` إن كان ممكنًا.
  ///
  /// **تُستدعى داخل المعاملة** بالمجموعة والطلب المقروءين من الخادم، لا من
  /// حالة الواجهة؛ ولهذا تبقى صحيحة حتى لو قُبلت طلبات أخرى بينهما.
  static String? acceptBlockReason({
    required StudyGroup group,
    required GroupJoinRequest request,
  }) {
    if (!request.isPending) {
      return 'هذا الطلب لم يعد معلّقًا.';
    }
    if (!group.isActive) {
      return 'المجموعة موقوفة؛ لا يمكن قبول طلبات جديدة.';
    }
    if (group.seatsAvailable <= 0) {
      return 'امتلأت المجموعة قبل قبول هذا الطلب.';
    }
    return null;
  }

  static bool canAccept({
    required StudyGroup group,
    required GroupJoinRequest request,
  }) =>
      acceptBlockReason(group: group, request: request) == null;

  /// العدد المتوقّع للمقاعد المشغولة بعد القبول (زيادة واحدة بالضبط).
  static int seatsAfterAccept(int seatsTaken) => seatsTaken + 1;

  /// ملخص عربي لحالة السعة — يُعرض أسفل زر الانضمام.
  static String capacityLine(StudyGroup group) {
    if (!group.isActive) {
      return 'المجموعة موقوفة حاليًا.';
    }
    if (group.seatsAvailable <= 0) {
      return 'اكتمل العدد (${group.seatsTaken} من ${group.seatsTotal}).';
    }
    return '${group.seatsAvailable} مقعد متاح من ${group.seatsTotal}.';
  }

  /// تحقق من حقول الطلب قبل الكتابة (حدود مطابقة للقواعد).
  ///
  /// `groupId` غير قابل للتحقق نصيًا هنا (معرّف مستند)، لكن عنوان المجموعة
  /// واسم الطالب مطلوبان لأن المدرس يقرأ الطلب بلا قراءة مستند الطالب (خصوصية).
  static ValidationResult validateRequest({
    String? groupTitle,
    String? studentName,
    String? studentId,
    String? groupId,
  }) {
    final List<ValidationProblem> problems = <ValidationProblem>[];

    void check(
      String field,
      String? value, {
      required int minLength,
      required int maxLength,
    }) {
      final String? text = normalizeText(value);
      if (text == null) {
        problems.add(ValidationProblem(field, FieldIssue.missing));
      } else if (text.length < minLength) {
        problems.add(ValidationProblem(field, FieldIssue.tooShort));
      } else if (text.length > maxLength) {
        problems.add(ValidationProblem(field, FieldIssue.tooLong));
      }
    }

    check(
      'groupTitle',
      groupTitle,
      minLength: 3,
      maxLength: ModelLimits.groupTitle,
    );
    check('studentName', studentName, minLength: 1, maxLength: ModelLimits.displayName);
    check('groupId', groupId, minLength: 1, maxLength: 200);
    check('studentId', studentId, minLength: 1, maxLength: 200);

    return ValidationResult(List<ValidationProblem>.unmodifiable(problems));
  }
}
