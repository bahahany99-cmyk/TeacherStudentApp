/// المتوسط التراكمي لتقييمات مدرس (P13).
///
/// **لماذا مجموع + عدد لا متوسط واحد؟** لأن المتوسط الكسري لا يمكن التحقق منه
/// بدقة في `firestore.rules` (حساب عشري قابل للتقريب)، بينما `ratingSum` عدد
/// صحيح. القواعد تقارن `ratingSum` الجديد بالقديم زائد تقييم التقييم المنشأ في
/// **نفس الكتابة الذرّية**، فيستحيل تزوير المتوسط أو زيادة العدّاد بلا تقييم
/// حقيقي (A-85). المتوسط يُحسب للعرض فقط.
class TeacherRating {
  const TeacherRating({
    required this.teacherId,
    required this.totalReviews,
    required this.ratingSum,
  });

  /// حالة «لا تقييمات» — عدّاد صفري لا يقود إلى قسمة على صفر.
  const TeacherRating.empty(this.teacherId)
    : totalReviews = 0,
      ratingSum = 0;

  static const int maxStars = 5;

  final String teacherId;
  final int totalReviews;
  final int ratingSum;

  bool get isEmpty => totalReviews <= 0;

  /// المتوسط (0 عند غياب التقييمات — لا `NaN`).
  double get average => totalReviews <= 0 ? 0 : ratingSum / totalReviews;

  /// نص العرض العربي: «4.5 من 5 (تقييمان)» أو «لا توجد تقييمات بعد».
  String get averageLabel {
    if (isEmpty) {
      return 'لا توجد تقييمات بعد';
    }
    return '${average.toStringAsFixed(1)} من $maxStars '
        '(${_reviewsLabel(totalReviews)})';
  }

  /// هل المتوسط محسوب من مجموع غير متسق (بيانات قديمة/مكتوبة يدويًا)؟
  bool get isConsistent => ratingSum >= totalReviews && ratingSum <= totalReviews * maxStars;

  /// نسخة بعد إضافة تقييم جديد — تُستخدم في التنفيذ التجريبي وفي اختبارات
  /// الحساب، بينما التنفيذ الحقيقي يكتب المجموع صريحًا لتتحقق منه القواعد.
  TeacherRating plus(int rating) => TeacherRating(
    teacherId: teacherId,
    totalReviews: totalReviews + 1,
    ratingSum: ratingSum + rating,
  );

  /// صيغة عربية سليمة للعدد (مثنى/جمع) بدل «1 تقييمات».
  static String _reviewsLabel(int count) {
    if (count == 1) {
      return 'تقييم واحد';
    }
    if (count == 2) {
      return 'تقييمان';
    }
    if (count >= 3 && count <= 10) {
      return '$count تقييمات';
    }
    return '$count تقييمًا';
  }

  /// خريطة المستند التراكمي.
  ///
  /// `lastReviewId` ليس للعرض: القواعد تقرأ به **التقييم المنشأ في نفس الكتابة**
  /// وتقارن الزيادة بتقييمه، فهو شاهد الذرّية لا رقم إحصائي.
  Map<String, Object?> toMap({
    required String lastReviewId,
    required DateTime updatedAt,
  }) => <String, Object?>{
    'teacherId': teacherId,
    'totalReviews': totalReviews,
    'ratingSum': ratingSum,
    'lastReviewId': lastReviewId,
    'updatedAt': updatedAt,
  };
}
