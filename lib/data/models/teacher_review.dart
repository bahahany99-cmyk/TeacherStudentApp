/// تقييم مدرس كتبه طالب بعد حصة **منفّذة** (P13).
///
/// **بوابة الأهلية G7:** لا يُكتب التقييم إلا إذا كان بين الطالب والمدرس حجز
/// حالته `completed`. والتحقق مزدوج:
/// - في الطبقة الوسطى (`ReviewRules.eligibilityProblem`) قبل الكتابة،
/// - وفي `firestore.rules` عند الكتابة، بقراءة الحجز نفسه.
///
/// **معرّف التقييم = معرّف الحجز** (A-84). هذا اختيار مقصود لا تفصيل: به تصبح
/// «منع التكرار» خاصية بنيوية لا فحصًا إضافيًا — مستند واحد لكل حصة، ومحاولة
/// تقييم الحصة نفسها مرتين تصطدم بإنشاء مستند قائم فيُرفض.
class TeacherReview {
  const TeacherReview({
    required this.bookingId,
    required this.teacherId,
    required this.studentId,
    required this.studentName,
    required this.rating,
    required this.createdAt,
    this.comment,
  });

  /// معرّف الحجز الذي يوثّق الأهلية — وهو نفسه معرّف مستند التقييم.
  final String bookingId;

  final String teacherId;

  /// كاتب التقييم — القواعد تفرض أنه صاحب الحجز نفسه.
  final String studentId;

  /// الاسم كما هو منسوخ من الحجز عند الكتابة (للقراءة وحدها، لا يُختار بحرية).
  final String studentName;

  /// من 1 إلى 5 نجوم.
  final int rating;

  /// التعليق اختياري، وبحدّ طول مفروض في القواعد.
  final String? comment;

  final DateTime createdAt;

  bool get hasComment => comment != null && comment!.trim().isNotEmpty;

  /// خريطة الإنشاء — الحقول المسموح بها في `firestore.rules` فقط.
  Map<String, Object?> toCreateMap() => <String, Object?>{
    'bookingId': bookingId,
    'teacherId': teacherId,
    'studentId': studentId,
    'studentName': studentName,
    'rating': rating,
    if (hasComment) 'comment': comment,
    'createdAt': createdAt,
  };
}
