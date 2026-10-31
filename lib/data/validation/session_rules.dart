import 'package:teacher_student_app/data/models/group_session.dart';
import 'package:teacher_student_app/data/validation/model_validators.dart';

/// قواعد الجدول الأسبوعي — **دوال نقية** بلا Flutter ولا شبكة.
///
/// نفس فلسفة `GroupRules`/`JoinRules` (A-55): الطبقة الوسطى تعطي رسالة عربية
/// فورية، و`firestore.rules` هي الحارس، واختبارات المحاكي تثبت التطابق.
abstract final class SessionRules {
  /// حدود الحقول — مطابقة حرفيًا لـ`firestore.rules`.
  static const int titleMin = 3;
  static const int titleMax = 60;
  static const int locationMax = 60;
  static const int durationMin = 15;
  static const int durationMax = 240;

  /// آخر دقيقة يُسمح ببدء الحصة فيها (23:00) حتى تنتهي قبل منتصف الليل.
  static const int latestStartMinutes = 23 * 60;

  static const List<int> durationOptions = <int>[30, 45, 60, 90, 120];

  /// «5:30 م» — تنسيق عربي 12 ساعة بلا حزمة `intl`.
  ///
  /// الأرقام لاتينية مقصودة: الخط المضمَّن (IBM Plex Sans Arabic) يرسمها بوضوح على كل
  /// الأجهزة، وتوحيد الشكل يمنع اختلاف العرض بين لوحة مفاتيح عربية وأخرى.
  static String formatMinutes(int minutes) {
    final int safe = minutes.clamp(0, 24 * 60);
    final int hour24 = safe ~/ 60;
    final int minute = safe % 60;
    final bool isPm = hour24 >= 12;
    int hour12 = hour24 % 12;
    if (hour12 == 0) {
      hour12 = 12;
    }
    final String minutePart = minute.toString().padLeft(2, '0');
    return '$hour12:$minutePart ${isPm ? 'م' : 'ص'}';
  }

  /// «90 دقيقة» — أو «ساعة ونصف» للقيم الشائعة (أقرب للعربية الطبيعية).
  static String formatDuration(int minutes) {
    return switch (minutes) {
      30 => 'نصف ساعة',
      45 => '45 دقيقة',
      60 => 'ساعة',
      90 => 'ساعة ونصف',
      120 => 'ساعتان',
      _ => '$minutes دقيقة',
    };
  }

  /// «5:30 م — 7:00 م».
  static String formatRange(GroupSession session) =>
      '${formatMinutes(session.startMinutes)} — ${formatMinutes(session.endMinutes)}';

  /// التحقق الكامل من المسودة.
  static ValidationResult validateDraft(
    SessionDraft draft, {
    List<GroupSession> existing = const <GroupSession>[],
    String? ignoreSessionId,
  }) {
    final List<ValidationProblem> problems = <ValidationProblem>[];

    final String title = draft.normalizedTitle;
    if (title.isEmpty) {
      problems.add(const ValidationProblem('title', FieldIssue.missing));
    } else if (title.length < titleMin) {
      problems.add(const ValidationProblem('title', FieldIssue.tooShort));
    } else if (title.length > titleMax) {
      problems.add(const ValidationProblem('title', FieldIssue.tooLong));
    }

    final String? location = draft.normalizedLocation;
    if (location != null && location.length > locationMax) {
      problems.add(const ValidationProblem('locationNote', FieldIssue.tooLong));
    }

    if (draft.startMinutes < 0 || draft.startMinutes > latestStartMinutes) {
      problems.add(const ValidationProblem('startMinutes', FieldIssue.outOfRange));
    }

    if (draft.durationMinutes < durationMin ||
        draft.durationMinutes > durationMax ||
        draft.durationMinutes % 5 != 0) {
      problems.add(
        const ValidationProblem('durationMinutes', FieldIssue.outOfRange),
      );
    } else if (draft.startMinutes + draft.durationMinutes > 24 * 60) {
      // الحصة لا تعبر منتصف الليل: تجعل حساب «اليوم» غامضًا في الجدول.
      problems.add(
        const ValidationProblem('durationMinutes', FieldIssue.outOfRange),
      );
    }

    if (findConflict(draft, existing, ignoreSessionId: ignoreSessionId) != null) {
      problems.add(const ValidationProblem('weekday', FieldIssue.outOfRange));
    }

    return ValidationResult(List<ValidationProblem>.unmodifiable(problems));
  }

  /// أول حصة أخرى تتداخل مع المسودة (تجاهل الحصة الجاري تعديلها).
  static GroupSession? findConflict(
    SessionDraft draft,
    List<GroupSession> existing, {
    String? ignoreSessionId,
  }) {
    final GroupSession candidate = GroupSession(
      id: ignoreSessionId ?? '__candidate__',
      groupId: '',
      teacherId: '',
      title: draft.normalizedTitle,
      weekday: draft.weekday,
      startMinutes: draft.startMinutes,
      durationMinutes: draft.durationMinutes,
    );

    for (final GroupSession session in existing) {
      if (session.id == ignoreSessionId || session.isCancelled) {
        continue;
      }
      if (candidate.overlaps(session)) {
        return session;
      }
    }
    return null;
  }

  /// رسالة تداخل جاهزة للعرض — أو `null` إن لا تداخل.
  static String? conflictMessage(
    SessionDraft draft,
    List<GroupSession> existing, {
    String? ignoreSessionId,
  }) {
    final GroupSession? conflict = findConflict(
      draft,
      existing,
      ignoreSessionId: ignoreSessionId,
    );
    if (conflict == null) {
      return null;
    }
    return 'يتعارض مع «${conflict.title}» (${formatRange(conflict)}).';
  }

  /// مسودة بداية لا تتعارض مع الجدول الحالي.
  ///
  /// النموذج الفارغ يبدأ السبت 5 مساءً؛ إن كان هذا الموعد مشغولًا نتحرك بنصف
  /// ساعة حتى نجد فراغًا. بدون ذلك يفتح المدرس «موعد جديد» ويجد رسالة تعارض
  /// قبل أن يكتب حرفًا واحدًا.
  static SessionDraft suggestedDraft(List<GroupSession> existing) {
    SessionDraft draft = SessionDraft.empty();
    while (findConflict(draft, existing) != null &&
        draft.startMinutes + 30 <= latestStartMinutes) {
      draft = draft.copyWith(startMinutes: draft.startMinutes + 30);
    }
    return draft;
  }

  /// ترتيب الجدول: اليوم ثم وقت البداية. الملغاة في نهاية يومها.
  static List<GroupSession> sorted(List<GroupSession> sessions) {
    final List<GroupSession> result = <GroupSession>[...sessions];
    result.sort((GroupSession a, GroupSession b) {
      if (a.weekday != b.weekday) {
        return a.weekday.index.compareTo(b.weekday.index);
      }
      if (a.isCancelled != b.isCancelled) {
        return a.isCancelled ? 1 : -1;
      }
      return a.startMinutes.compareTo(b.startMinutes);
    });
    return List<GroupSession>.unmodifiable(result);
  }

  /// تجميع الجدول حسب اليوم (بالترتيب العربي) — الأيام الفارغة تُحذف.
  static List<MapEntry<GroupWeekday, List<GroupSession>>> byWeekday(
    List<GroupSession> sessions,
  ) {
    final List<MapEntry<GroupWeekday, List<GroupSession>>> groups =
        <MapEntry<GroupWeekday, List<GroupSession>>>[];
    for (final GroupWeekday day in GroupWeekday.values) {
      final List<GroupSession> daySessions = sorted(sessions)
          .where((GroupSession s) => s.weekday == day)
          .toList(growable: false);
      if (daySessions.isNotEmpty) {
        groups.add(MapEntry<GroupWeekday, List<GroupSession>>(day, daySessions));
      }
    }
    return List<MapEntry<GroupWeekday, List<GroupSession>>>.unmodifiable(groups);
  }

  /// ملخص عربي للجدول: «حصتان أسبوعيًا — 3 ساعات».
  static String weeklySummary(List<GroupSession> sessions) {
    final List<GroupSession> active = sessions
        .where((GroupSession s) => !s.isCancelled)
        .toList(growable: false);
    if (active.isEmpty) {
      return 'لا مواعيد أسبوعية بعد.';
    }
    final int totalMinutes = active.fold<int>(
      0,
      (int sum, GroupSession s) => sum + s.durationMinutes,
    );
    final String count = active.length == 1
        ? 'حصة واحدة'
        : (active.length == 2 ? 'حصتان' : '${active.length} حصص');
    return '$count أسبوعيًا — ${formatDuration(totalMinutes)} إجمالًا';
  }
}
