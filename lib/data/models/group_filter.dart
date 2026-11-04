import 'package:teacher_student_app/data/models/study_group.dart';

/// توفّر المقاعد — فلتر استكشاف المجموعات.
enum GroupAvailability {
  any('كل المجموعات'),
  available('فيها مقعد'),
  full('مكتملة');

  const GroupAvailability(this.label);

  final String label;
}

/// ترتيب نتائج الاستكشاف.
enum GroupSort {
  /// الأنسب: مقاعد متاحة أكثر أولًا، ثم العنوان.
  recommended('الأنسب'),

  /// الأقرب امتلاءً: مقاعد أقل أولًا (من يريد الانضمام سريعًا).
  fewestSeats('الأقرب امتلاءً'),

  /// أبجديًا بالعنوان — ثابت ومتوقّع.
  title('أبجديًا');

  const GroupSort(this.label);

  final String label;
}

/// فلتر استكشاف المجموعات — **قيمة ثابتة** لا حالة قابلة للتغيير.
///
/// الفلتر نموذج لا واجهة: يُنشأ في طبقة العرض ويُمرَّر إلى المستودع، فتكون
/// القاعدة التي تُطبَّق واحدة أينما استُخدم (شاشة، اختبار، أو استعلام).
class GroupFilter {
  const GroupFilter({
    this.query = '',
    this.subject,
    this.stage,
    this.meetingMode,
    this.availability = GroupAvailability.any,
    this.sort = GroupSort.recommended,
  });

  /// فلتر محايد (كل المجموعات المنشورة).
  static const GroupFilter empty = GroupFilter();

  /// نص البحث الحر (عنوان/مدرس/مادة/مرحلة).
  final String query;

  /// مادة محددة — `null` تعني كل المواد.
  final String? subject;

  /// مرحلة محددة — `null` تعني كل المراحل.
  final String? stage;

  /// طريقة حضور محددة — `null` تعني الكل.
  final GroupMeetingMode? meetingMode;

  final GroupAvailability availability;
  final GroupSort sort;

  /// هل اختار المستخدم أي شيء؟ (لإظهار زر «تفريغ الفلاتر»)
  bool get isActive =>
      query.trim().isNotEmpty ||
      subject != null ||
      stage != null ||
      meetingMode != null ||
      availability != GroupAvailability.any ||
      sort != GroupSort.recommended;

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
    if (meetingMode != null) {
      count++;
    }
    if (availability != GroupAvailability.any) {
      count++;
    }
    return count;
  }

  static const Object _keep = Object();

  /// نسخة معدّلة. مرّر [_keep] (الافتراضي) لحقل تريد إبقاءه، و`null` صريحًا
  /// لإزالته — لذلك الحقول النصية من نوع `Object?`.
  GroupFilter copyWith({
    String? query,
    Object? subject = _keep,
    Object? stage = _keep,
    Object? meetingMode = _keep,
    GroupAvailability? availability,
    GroupSort? sort,
  }) {
    return GroupFilter(
      query: query ?? this.query,
      subject: subject == _keep ? this.subject : subject as String?,
      stage: stage == _keep ? this.stage : stage as String?,
      meetingMode: meetingMode == _keep
          ? this.meetingMode
          : meetingMode as GroupMeetingMode?,
      availability: availability ?? this.availability,
      sort: sort ?? this.sort,
    );
  }

  /// تفريغ الفلاتر مع الحفاظ على ترتيب المستخدم.
  GroupFilter cleared() => GroupFilter(sort: sort);

  @override
  bool operator ==(Object other) {
    return other is GroupFilter &&
        other.query.trim() == query.trim() &&
        other.subject == subject &&
        other.stage == stage &&
        other.meetingMode == meetingMode &&
        other.availability == availability &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(
    query.trim(),
    subject,
    stage,
    meetingMode,
    availability,
    sort,
  );

  @override
  String toString() =>
      'GroupFilter(query: $query, subject: $subject, stage: $stage, '
      'mode: $meetingMode, availability: $availability, sort: $sort)';
}

/// نتيجة استكشاف: المجموعات الظاهرة + إجمالي ما ورد من المصدر.
///
/// **لماذا نحتاج الإجمالي؟** لأن الفلترة النصية تحدث في العميل بعد استعلام
/// Firestore، فنقول للمستخدم «3 من 12» بدل أن نوهمه أن المنصة فيها 3 مجموعات.
class GroupSearchResult {
  const GroupSearchResult({required this.groups, required this.total});

  const GroupSearchResult.empty() : groups = const <StudyGroup>[], total = 0;

  final List<StudyGroup> groups;

  /// عدد المجموعات قبل تطبيق فلاتر العميل (النص/التوفر/الترتيب).
  final int total;

  bool get isEmpty => groups.isEmpty;
}
