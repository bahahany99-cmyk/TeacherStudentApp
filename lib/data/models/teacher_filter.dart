import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// طريقة تقديم الحصة — فلتر استكشاف المدرسين (P15).
///
/// **لماذا ثلاث قيم لا مفتاحين؟** لأن الواجهة تعرض «الكل / عن بُعد / حضوري
/// فقط» كمجموعة واحدة حصرية، وواجهة بمفتاحين تسمح بحالة «الاثنان معًا» التي
/// تعني الشيء نفسه كـ«الكل» — حالة رابعة لا معنى لها في الشاشة.
enum TeacherDeliveryFilter {
  any('الكل'),
  online('عن بُعد'),

  /// حضوري **فقط**: من لا يقبل الحصص عن بُعد. من يقبل الاثنين يظهر تحت
  /// «عن بُعد» و«الكل» كما يشرح القرار A-93.
  inPerson('حضوري فقط');

  const TeacherDeliveryFilter(this.label);

  final String label;
}

/// ترتيب نتائج استكشاف المدرسين.
enum TeacherSort {
  /// الأنسب: التقييم الأعلى أولًا، والتعادل يُحسم بعدد المراجعات ثم الاسم.
  recommended('الأنسب'),

  /// الأقل سعرًا ليس متاحًا: السعر نصّ استرشادي (`priceHint`) لا رقم، فترتيبه
  /// سيكون ترتيب نصوص. مؤجّل حتى يُحسم نموذج السعر (Q-07).
  rating('الأعلى تقييمًا'),

  /// أبجديًا بالاسم — ثابت ومتوقّع.
  name('أبجديًا');

  const TeacherSort(this.label);

  final String label;
}

/// فلتر استكشاف المدرسين — **قيمة ثابتة** مثل `GroupFilter`.
///
/// الفلتر نموذج لا واجهة: يُنشأ في طبقة العرض ويُمرَّر إلى المستودع، فتُطبَّق
/// القاعدة نفسها في الشاشة والاختبار والاستعلام.
///
/// ما يُدفع إلى Firestore وما لا:
/// - **يُدفع:** `status == 'verified'` (شرط الظهور)، و`isOnline` مساواة واحدة،
///   و`governorate` مساواة واحدة. كلها مساواة على حقل واحد ⇒ لا فهرس مركّب.
/// - **لا يُدفع:** البحث النصي، والمادة/المرحلة، والترتيب. تُطبَّق في العميل
///   (`TeacherDiscoveryRules.search`)، فتبقى الاستعلامات قابلة للفهرسة أحاديًا.
class TeacherFilter {
  const TeacherFilter({
    this.query = '',
    this.subject,
    this.stage,
    this.governorate,
    this.delivery = TeacherDeliveryFilter.any,
    this.sort = TeacherSort.recommended,
  });

  /// فلتر محايد (كل المدرسين الموثّقين).
  static const TeacherFilter empty = TeacherFilter();

  /// نص البحث الحر (اسم/مادة/مرحلة/مكان).
  final String query;

  /// مادة محددة — `null` تعني كل المواد.
  final String? subject;

  /// مرحلة محددة — `null` تعني كل المراحل.
  final String? stage;

  /// محافظة محددة — `null` تعني كل المحافظات.
  final String? governorate;

  final TeacherDeliveryFilter delivery;
  final TeacherSort sort;

  /// هل اختار المستخدم أي شيء؟ (لإظهار زر «تفريغ الفلاتر»)
  bool get isActive =>
      query.trim().isNotEmpty ||
      subject != null ||
      stage != null ||
      governorate != null ||
      delivery != TeacherDeliveryFilter.any ||
      sort != TeacherSort.recommended;

  /// عدد الفلاتر المختارة — يُعرض على الزر المطويّ.
  int get activeCount {
    int count = 0;
    if (query.trim().isNotEmpty) {
      count++;
    }
    if (subject != null) {
      count++;
    }
    if (stage != null) {
      count++;
    }
    if (governorate != null) {
      count++;
    }
    if (delivery != TeacherDeliveryFilter.any) {
      count++;
    }
    return count;
  }

  /// هل الفلتر يطلب **حضوريًا** بمحافظة محددة؟ (لعرض تلميح المكان)
  bool get isInPersonScoped =>
      delivery == TeacherDeliveryFilter.inPerson || governorate != null;

  static const Object _keep = Object();

  /// نسخة معدّلة. مرّر [_keep] (الافتراضي) لحقل تريد إبقاءه، و`null` صريحًا
  /// لإزالته — لذلك الحقول النصية من نوع `Object?`.
  TeacherFilter copyWith({
    String? query,
    Object? subject = _keep,
    Object? stage = _keep,
    Object? governorate = _keep,
    TeacherDeliveryFilter? delivery,
    TeacherSort? sort,
  }) {
    return TeacherFilter(
      query: query ?? this.query,
      subject: subject == _keep ? this.subject : subject as String?,
      stage: stage == _keep ? this.stage : stage as String?,
      governorate: governorate == _keep
          ? this.governorate
          : governorate as String?,
      delivery: delivery ?? this.delivery,
      sort: sort ?? this.sort,
    );
  }

  /// تفريغ الفلاتر مع الحفاظ على ترتيب المستخدم.
  TeacherFilter cleared() => TeacherFilter(sort: sort);

  @override
  bool operator ==(Object other) {
    return other is TeacherFilter &&
        other.query.trim() == query.trim() &&
        other.subject == subject &&
        other.stage == stage &&
        other.governorate == governorate &&
        other.delivery == delivery &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(
    query.trim(),
    subject,
    stage,
    governorate,
    delivery,
    sort,
  );

  @override
  String toString() =>
      'TeacherFilter(query: $query, subject: $subject, stage: $stage, '
      'governorate: $governorate, delivery: $delivery, sort: $sort)';
}

/// نتيجة استكشاف المدرسين: الظاهرون + إجمالي ما ورد من المصدر.
///
/// **لماذا الإجمالي؟** لأن البحث النصي وفلتر المادة يحدثان في العميل بعد
/// استعلام Firestore، فنقول «3 من 12» بدل أن نوهم المستخدم أن المنصة فيها 3.
class TeacherSearchResult {
  const TeacherSearchResult({required this.teachers, required this.total});

  const TeacherSearchResult.empty()
    : teachers = const <TeacherProfile>[],
      total = 0;

  final List<TeacherProfile> teachers;

  /// عدد المدرسين الموثّقين قبل فلاتر العميل (النص/المادة/المرحلة/الترتيب).
  final int total;

  bool get isEmpty => teachers.isEmpty;

  int get length => teachers.length;
}
