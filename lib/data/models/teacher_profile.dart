/// حالة ملف المدرس في دورة المراجعة الإدارية.
///
/// هذه الحالة يكتبها الخادم فقط؛ التطبيق يقرأها.
enum TeacherProfileStatus {
  draft,
  pendingReview,
  verified,
  rejected;

  String get label => switch (this) {
    TeacherProfileStatus.draft => 'مسودة',
    TeacherProfileStatus.pendingReview => 'قيد المراجعة',
    TeacherProfileStatus.verified => 'موثّق',
    TeacherProfileStatus.rejected => 'مرفوض',
  };

  /// القيم النصية المخزّنة في Firestore — **مصدر الحقيقة الوحيد** للكتابة.
  ///
  /// القواعد (`firestore.rules`) تقارن النص حرفيًا، فالقيمة هنا وهذا الاسم
  /// يجب أن يبقيا متطابقين (P14: `approved` → `verified`).
  String get wireValue => switch (this) {
    TeacherProfileStatus.draft => 'draft',
    TeacherProfileStatus.pendingReview => 'pendingReview',
    TeacherProfileStatus.verified => 'verified',
    TeacherProfileStatus.rejected => 'rejected',
  };

  /// هل الملف في انتظار قرار الإدارة؟ (يظهر في طابور التوثيق)
  bool get awaitsReview =>
      this == TeacherProfileStatus.draft ||
      this == TeacherProfileStatus.pendingReview;
}

/// ملف مدرس (نموذج عرض فقط في المرحلة 2).
class TeacherProfile {
  const TeacherProfile({
    required this.id,
    required this.displayName,
    required this.subject,
    required this.stage,
    required this.area,
    required this.bio,
    required this.status,
    this.isFeatured = false,
    this.rating = 0,
    this.reviewsCount = 0,
    this.priceHint,
    this.reviewNote,
  });

  final String id;
  final String displayName;

  /// المادة الدراسية.
  final String subject;

  /// المرحلة الدراسية (ابتدائي/إعدادي/ثانوي…).
  final String stage;

  /// المنطقة أو المحافظة.
  final String area;

  final String bio;
  final TeacherProfileStatus status;

  /// التمييز يُدار من الإدارة فقط. قواعد اختيار/ترتيب المميزين **لم تُحسم بعد**
  /// (Q-01..Q-03)؛ الحقل هنا للعرض البنيوي فقط.
  final bool isFeatured;

  final double rating;
  final int reviewsCount;

  /// سعر استرشادي نصي (الدفع يتم خارج التطبيق).
  final String? priceHint;

  /// سبب القرار الإداري عند الرفض (يكتبه المسؤول وحده في القواعد).
  ///
  /// وجوده لا يمنح شيئًا: الملف المرفوض مخفي عن الطلاب في كل الأحوال.
  final String? reviewNote;

  /// هل يظهر للطلاب؟ القاعدة الحقيقية تُفرض في قواعد Firestore.
  bool get isVisibleToStudents => status == TeacherProfileStatus.verified;

  String get initials {
    final String trimmed = displayName.trim();
    return trimmed.isEmpty ? '؟' : trimmed.substring(0, 1);
  }
}
