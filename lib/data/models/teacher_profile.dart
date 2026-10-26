/// حالة ملف المدرس في دورة المراجعة الإدارية.
///
/// هذه الحالة يكتبها الخادم فقط؛ التطبيق يقرأها.
enum TeacherProfileStatus {
  draft,
  pendingReview,
  approved,
  rejected;

  String get label => switch (this) {
    TeacherProfileStatus.draft => 'مسودة',
    TeacherProfileStatus.pendingReview => 'قيد المراجعة',
    TeacherProfileStatus.approved => 'معتمد',
    TeacherProfileStatus.rejected => 'مرفوض',
  };
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

  /// هل يظهر للطلاب؟ القاعدة الحقيقية تُفرض في قواعد Firestore.
  bool get isVisibleToStudents => status == TeacherProfileStatus.approved;

  String get initials {
    final String trimmed = displayName.trim();
    return trimmed.isEmpty ? '؟' : trimmed.substring(0, 1);
  }
}
