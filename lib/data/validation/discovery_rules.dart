import 'package:teacher_student_app/core/utils/arabic_text.dart';
import 'package:teacher_student_app/data/models/group_filter.dart';
import 'package:teacher_student_app/data/models/study_group.dart';

/// قواعد استكشاف المجموعات — **دوال نقية** بلا Flutter ولا شبكة.
///
/// ما يمكن دفعه إلى Firestore وما لا يمكن:
/// - **يُدفع:** `isActive == true` ومساواة المادة/المرحلة/طريقة الحضور. كلها
///   مساواة على حقل واحد، فلا تحتاج فهرسًا مركّبًا ولا تمنعها القواعد (القواعد
///   تقرأ `isActive`، فالاستعلام الذي يقيّده يُقبل).
/// - **لا يُدفع:** البحث النصي («تفاضل»)، وشرط «بها مقعد» لأنه يقارن حقلين
///   (`seatsTaken < seatsTotal`) ولا تعبير له في استعلام Firestore. يُطبَّقان
///   هنا على النتائج المُرجعَة. القرار A-66 يشرح البديل المؤجّل (حقل
///   `hasSeats` منسوخ + فهرسة بحث خارجية).
abstract final class DiscoveryRules {
  static const List<GroupMeetingMode> meetingModes = GroupMeetingMode.values;

  /// يطبّق الفلتر كاملًا على مجموعة مُقروءة من المصدر.
  ///
  /// الترتيب مهم للاختبارات: «الأنسب» يعطي الأكثر مقاعد أولًا، والتعادل
  /// يُحسم بالعنوان، فيكون الناتج حتميًا لا يعتمد على ترتيب القائمة الأصلية.
  static GroupSearchResult search(List<StudyGroup> groups, GroupFilter filter) {
    final List<StudyGroup> visible = groups
        // دفاع لا استعلام: المجموعة الموقوفة لا تُعرض للطالب مهما أرسل المستودع.
        .where((StudyGroup g) => g.isActive)
        .toList(growable: false);

    final String needle = _normalize(filter.query);
    final List<StudyGroup> matches = visible
        .where((StudyGroup g) {
          if (filter.subject != null && g.subject != filter.subject) {
            return false;
          }
          if (filter.stage != null && g.stage != filter.stage) {
            return false;
          }
          if (filter.meetingMode != null &&
              g.meetingMode != filter.meetingMode) {
            return false;
          }
          switch (filter.availability) {
            case GroupAvailability.any:
              break;
            case GroupAvailability.available:
              if (g.seatsAvailable <= 0) {
                return false;
              }
            case GroupAvailability.full:
              if (!g.isFull) {
                return false;
              }
          }
          if (needle.isEmpty) {
            return true;
          }
          return _matchesText(g, needle);
        })
        .toList();

    sort(matches, filter.sort);

    return GroupSearchResult(
      groups: List<StudyGroup>.unmodifiable(matches),
      total: visible.length,
    );
  }

  /// البحث النصي يشمل العنوان والمدرس والمادة والمرحلة.
  ///
  /// التطبيع يقصّ الأطراف ويوحّد شكل الألف/الياء/التاء المربوطة ويحذف التشكيل،
  /// فيجد «احمد» عند كتابة «أحمد» ويجد «تفاضل» داخل «التفاضل».
  static bool _matchesText(StudyGroup group, String needle) {
    return _normalize(group.title).contains(needle) ||
        _normalize(group.teacherName).contains(needle) ||
        _normalize(group.subject).contains(needle) ||
        _normalize(group.stage).contains(needle);
  }

  /// الترتيب في المكان (نفس القائمة) — لا يعيد نسخة جديدة.
  static void sort(List<StudyGroup> groups, GroupSort sort) {
    switch (sort) {
      case GroupSort.recommended:
        groups.sort((StudyGroup a, StudyGroup b) {
          final int bySeats = b.seatsAvailable.compareTo(a.seatsAvailable);
          return bySeats != 0 ? bySeats : a.title.compareTo(b.title);
        });
      case GroupSort.fewestSeats:
        groups.sort((StudyGroup a, StudyGroup b) {
          final int bySeats = a.seatsAvailable.compareTo(b.seatsAvailable);
          return bySeats != 0 ? bySeats : a.title.compareTo(b.title);
        });
      case GroupSort.title:
        groups.sort((StudyGroup a, StudyGroup b) => a.title.compareTo(b.title));
    }
  }

  /// المواد الموجودة فعلًا في البيانات — نعرض ما هو متاح لا قائمة نظرية.
  static List<String> subjectOptions(List<StudyGroup> groups) =>
      _distinct(groups.map((StudyGroup g) => g.subject));

  /// المراحل الموجودة فعلًا.
  static List<String> stageOptions(List<StudyGroup> groups) =>
      _distinct(groups.map((StudyGroup g) => g.stage));

  static List<String> _distinct(Iterable<String> values) {
    final List<String> unique = <String>[];
    for (final String value in values) {
      if (value.trim().isEmpty || unique.contains(value)) {
        continue;
      }
      unique.add(value);
    }
    unique.sort();
    return List<String>.unmodifiable(unique);
  }

  /// رسالة «لا نتائج» تشرح السبب بدل صمت مربك.
  static String emptyMessage(GroupFilter filter) {
    if (filter.availability == GroupAvailability.available) {
      return 'كل المجموعات المطابقة مكتملة الآن. جرّب إظهار المكتملة أو '
          'انضم لقائمة انتظار مجموعة.';
    }
    if (filter.isActive) {
      return 'لا توجد مجموعة تطابق هذه الفلاتر. جرّب تقليل عددها.';
    }
    return 'يعرض المدرسون مجموعاتهم عند نشرها.';
  }

  /// سطر النتائج: «3 من 12 مجموعة» — يوضّح أثر الفلترة.
  static String resultsLine(GroupSearchResult result) {
    if (result.total == 0) {
      return 'لا مجموعات منشورة';
    }
    if (result.groups.length == result.total) {
      return '${result.total} مجموعة';
    }
    return '${result.groups.length} من ${result.total} مجموعة';
  }

  /// تطبيع مشترك — انظر [ArabicText.normalize] (نُقل في P15).
  static String _normalize(String value) => ArabicText.normalize(value);
}
