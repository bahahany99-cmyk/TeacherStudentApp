import 'package:teacher_student_app/data/validation/model_validators.dart';

/// أيام الأسبوع في الترتيب العربي المعتاد (الأسبوع الدراسي يبدأ بالسبت).
///
/// `index` هنا لا يُستخدم في القواعد؛ القواعد تقرأ [name] النصي، والقيمة
/// الرقمية `iso` هي ما يُخزَّن فعلًا حتى لا يتغيّر المعنى عند إعادة ترتيب
/// التعداد.
enum GroupWeekday {
  saturday('saturday', 6, 'السبت'),
  sunday('sunday', 7, 'الأحد'),
  monday('monday', 1, 'الاثنين'),
  tuesday('tuesday', 2, 'الثلاثاء'),
  wednesday('wednesday', 3, 'الأربعاء'),
  thursday('thursday', 4, 'الخميس'),
  friday('friday', 5, 'الجمعة');

  const GroupWeekday(this.id, this.iso, this.label);

  /// القيمة النصية المخزَّنة (يطابقها `firestore.rules`).
  final String id;

  /// رقم اليوم بصيغة `DateTime.weekday` (الاثنين = 1).
  final int iso;

  /// الاسم العربي للعرض.
  final String label;

  /// تحويل متسامح: أي قيمة غير معروفة تعود إلى السبت (أول يوم في الأسبوع هنا).
  static GroupWeekday parse(Object? raw) {
    for (final GroupWeekday day in GroupWeekday.values) {
      if (day.id == raw) {
        return day;
      }
    }
    return GroupWeekday.saturday;
  }

  /// من رقم `DateTime.weekday`.
  static GroupWeekday fromIso(int weekday) {
    for (final GroupWeekday day in GroupWeekday.values) {
      if (day.iso == weekday) {
        return day;
      }
    }
    return GroupWeekday.saturday;
  }
}

/// حصة/موعد أسبوعي داخل مجموعة دراسية.
///
/// التمثيل الزمني **نسبي للأسبوع** لا تاريخ مطلق:
/// - [weekday] + [startMinutes] (دقائق من منتصف الليل).
/// - السبب: المواعيد المتكررة هي الحالة الغالبة للمجموعات، والتاريخ المطلق
///   يُنتج عشرات المستندات الشهرية بلا فائدة، ويحتاج منطقة زمنية لكل مستخدم.
///   (المواعيد الاستثنائية/المؤجلة قرار لاحق، غير ممثَّل هنا.)
class GroupSession {
  const GroupSession({
    required this.id,
    required this.groupId,
    required this.teacherId,
    required this.title,
    required this.weekday,
    required this.startMinutes,
    required this.durationMinutes,
    this.locationNote,
    this.isCancelled = false,
  });

  final String id;
  final String groupId;
  final String teacherId;
  final String title;
  final GroupWeekday weekday;

  /// دقيقة البداية من منتصف الليل (0..1439).
  final int startMinutes;

  /// مدة الحصة بالدقائق (15..240).
  final int durationMinutes;

  /// مكان/رابط الحضور (اختياري): «سنتر المعادي»، «Google Meet»…
  final String? locationNote;

  /// حصة ملغاة تبقى معروضة (بوسم «ملغاة») بدل حذفها من الجدول.
  final bool isCancelled;

  int get endMinutes => startMinutes + durationMinutes;

  /// هل هذه الحصة منتهية في يوم معيّن ودقيقة معيّنة؟
  bool hasEndedAt({required GroupWeekday day, required int minuteOfDay}) {
    if (day != weekday) {
      return false;
    }
    return minuteOfDay >= endMinutes;
  }

  /// هل تتداخل مع حصة أخرى؟ (نفس اليوم + تقاطع في المجال الزمني)
  bool overlaps(GroupSession other) {
    if (other.weekday != weekday) {
      return false;
    }
    return startMinutes < other.endMinutes && other.startMinutes < endMinutes;
  }

  GroupSession copyWith({
    String? title,
    GroupWeekday? weekday,
    int? startMinutes,
    int? durationMinutes,
    String? locationNote,
    bool? isCancelled,
  }) {
    return GroupSession(
      id: id,
      groupId: groupId,
      teacherId: teacherId,
      title: title ?? this.title,
      weekday: weekday ?? this.weekday,
      startMinutes: startMinutes ?? this.startMinutes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      locationNote: locationNote ?? this.locationNote,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }

  /// خريطة الإنشاء — الحقول المسموح بها في القواعد فقط.
  Map<String, Object?> toCreateMap(SessionDraft draft) {
    return <String, Object?>{
      'teacherId': teacherId,
      'title': draft.normalizedTitle,
      'weekday': draft.weekday.id,
      'startMinutes': draft.startMinutes,
      'durationMinutes': draft.durationMinutes,
      'locationNote': draft.normalizedLocation ?? '',
      'isCancelled': false,
    };
  }
}

/// مسودة إنشاء/تعديل موعد — نفس فكرة `GroupDraft`: كائن واحد للنموذج
/// والتحقق وخريطة Firestore، فلا يتباعد التنفيذان.
class SessionDraft {
  const SessionDraft({
    required this.title,
    required this.weekday,
    required this.startMinutes,
    required this.durationMinutes,
    this.locationNote,
  });

  factory SessionDraft.fromSession(GroupSession session) {
    return SessionDraft(
      title: session.title,
      weekday: session.weekday,
      startMinutes: session.startMinutes,
      durationMinutes: session.durationMinutes,
      locationNote: session.locationNote,
    );
  }

  factory SessionDraft.empty() {
    return const SessionDraft(
      title: '',
      weekday: GroupWeekday.saturday,
      startMinutes: 17 * 60,
      durationMinutes: 60,
    );
  }

  final String title;
  final GroupWeekday weekday;
  final int startMinutes;
  final int durationMinutes;
  final String? locationNote;

  String get normalizedTitle => normalizeText(title) ?? '';
  String? get normalizedLocation => normalizeText(locationNote);

  SessionDraft copyWith({
    String? title,
    GroupWeekday? weekday,
    int? startMinutes,
    int? durationMinutes,
    String? locationNote,
  }) {
    return SessionDraft(
      title: title ?? this.title,
      weekday: weekday ?? this.weekday,
      startMinutes: startMinutes ?? this.startMinutes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      locationNote: locationNote ?? this.locationNote,
    );
  }

  /// التحديث لا يمسّ المالك ولا المجموعة.
  Map<String, Object?> toUpdateMap({bool? isCancelled}) {
    return <String, Object?>{
      'title': normalizedTitle,
      'weekday': weekday.id,
      'startMinutes': startMinutes,
      'durationMinutes': durationMinutes,
      'locationNote': normalizedLocation ?? '',
      if (isCancelled != null) 'isCancelled': isCancelled,
    };
  }
}
