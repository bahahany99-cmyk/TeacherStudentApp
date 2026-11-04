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
    this.featuredOrder = 0,
    this.isOnline = false,
    this.governorate,
    this.district,
    this.isAccountHidden = false,
    this.rating = 0,
    this.reviewsCount = 0,
    this.priceHint,
    this.reviewNote,
    this.photoPath,
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

  /// التمييز يُدار من الإدارة فقط (P15): لا يكتبه صاحب الملف في القواعد،
  /// ويكتبه المسؤول وحده عبر مسار تحديث مقيّد بحقلي التمييز.
  final bool isFeatured;

  /// ترتيب الظهور في شريط المميزين — الأصغر أولًا (P15).
  ///
  /// إداري فقط مثل [isFeatured]، والترتيب النهائي حتمي: (ترتيب، تقييم، اسم)
  /// في `TeacherDiscoveryRules.featured`.
  final int featuredOrder;

  /// يقدّم حصصًا **عن بُعد** — متاحة لأي طالب في أي محافظة (P15).
  ///
  /// العلم مستقلّ عن [governorate]: مدرس يقبل الاثنين يكون `isOnline == true`
  /// وله محافظة. لذلك فلتر «عن بُعد» يضمّه، وفلتر «حضوري فقط» يستبعده
  /// (`!isOnline`) — مساواة واحدة على حقل واحد، بلا استعلام `OR` ولا فهرس
  /// مركّب (A-93).
  final bool isOnline;

  /// المحافظة (للمحاضرة الحضورية) — فلتر الاستكشاف الأساسي في P15.
  final String? governorate;

  /// المركز/الحي داخل المحافظة — أدقّ ما يُعرض للطالب قبل الحجز.
  final String? district;

  /// أخفى صاحبه ملفه بطلب حذف الحساب (P17).
  ///
  /// يُكتب في `teacherProfiles/{uid}` **في نفس حزمة** طلب الحذف، وتقرأه القاعدة
  /// من المستند نفسه. البديل (قراءة `users/{uid}` من داخل القاعدة) أسقط كل ملف
  /// مدرس لا مستند مستخدم له، لأن `get()` على مستند غائب خطأ لا `false` (A-102ب).
  final bool isAccountHidden;

  final double rating;
  final int reviewsCount;

  /// سعر استرشادي نصي (الدفع يتم خارج التطبيق).
  final String? priceHint;

  /// مسار صورة الملف الشخصي (P22) — إلزامي عند الحفظ.
  ///
  /// الشكل المعتمد `avatars/{uid}`: مسار **مستند** يحمل بايتات الصورة.
  /// تركه فارغًا يرفضه التطبيق أولًا ثم `firestore.rules` (شرط
  /// `photoPath` + وجود مستند الصورة)، فلا يُنشأ ملف مدرس بلا صورة.
  final String? photoPath;

  /// هل للملف صورة صالحة للعرض؟
  bool get hasPhoto => (photoPath ?? '').trim().isNotEmpty;

  /// مسار الصورة المتوقّع لصاحب هذا الملف.
  static String photoPathFor(String uid) => 'avatars/$uid';

  /// سبب القرار الإداري عند الرفض (يكتبه المسؤول وحده في القواعد).
  ///
  /// وجوده لا يمنح شيئًا: الملف المرفوض مخفي عن الطلاب في كل الأحوال.
  final String? reviewNote;

  /// هل يظهر للطلاب؟ القاعدة الحقيقية تُفرض في قواعد Firestore.
  ///
  /// (P17) الملف المخفي بحذف الحساب لا يُعدّ ظاهرًا حتى لو بقي موثّقًا.
  bool get isVisibleToStudents =>
      status == TeacherProfileStatus.verified && !isAccountHidden;

  /// وصف المكان للعرض: «المعادي — القاهرة» ثم [area] كبديل للبيانات القديمة.
  ///
  /// المستندات القديمة (قبل P15) لا تحمل `governorate`/`district`، فالسقوط إلى
  /// [area] يمنع ظهور «غير محدد» في كل بطاقة.
  String get locationLabel {
    final String gov = governorate?.trim() ?? '';
    final String dist = district?.trim() ?? '';
    if (dist.isNotEmpty && gov.isNotEmpty) {
      return '$dist — $gov';
    }
    if (gov.isNotEmpty) {
      return gov;
    }
    if (dist.isNotEmpty) {
      return dist;
    }
    return area;
  }

  /// وسم طريقة التقديم: «عن بُعد» أو «حضوري فقط».
  String get deliveryLabel => isOnline ? 'عن بُعد' : 'حضوري فقط';

  /// نسخة معدّلة — تُستخدم في المستودع التجريبي والحسابات المشتقة.
  ///
  /// [clearReviewNote] لأن `copyWith(note: null)` لا يستطيع التمييز بين «لا
  /// تغيير» و«احذف السبب»، وحذف السبب عند التوثيق مقصود في P14.
  TeacherProfile copyWith({
    String? displayName,
    String? subject,
    String? stage,
    String? area,
    String? bio,
    TeacherProfileStatus? status,
    bool? isFeatured,
    int? featuredOrder,
    bool? isOnline,
    String? governorate,
    String? district,
    bool? isAccountHidden,
    double? rating,
    int? reviewsCount,
    String? priceHint,
    String? reviewNote,
    String? photoPath,
    bool clearReviewNote = false,
  }) {
    return TeacherProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      subject: subject ?? this.subject,
      stage: stage ?? this.stage,
      area: area ?? this.area,
      bio: bio ?? this.bio,
      status: status ?? this.status,
      isFeatured: isFeatured ?? this.isFeatured,
      featuredOrder: featuredOrder ?? this.featuredOrder,
      isOnline: isOnline ?? this.isOnline,
      governorate: governorate ?? this.governorate,
      district: district ?? this.district,
      isAccountHidden: isAccountHidden ?? this.isAccountHidden,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      priceHint: priceHint ?? this.priceHint,
      reviewNote: clearReviewNote ? null : (reviewNote ?? this.reviewNote),
      photoPath: photoPath ?? this.photoPath,
    );
  }

  String get initials {
    final String trimmed = displayName.trim();
    return trimmed.isEmpty ? '؟' : trimmed.substring(0, 1);
  }
}
