import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/models/group_session.dart';
import 'package:teacher_student_app/data/validation/session_rules.dart';

GroupSession _session({
  String id = 's1',
  GroupWeekday weekday = GroupWeekday.saturday,
  int start = 17 * 60,
  int duration = 90,
  bool isCancelled = false,
  String title = 'التفاضل',
  String? location,
}) {
  return GroupSession(
    id: id,
    groupId: 'g1',
    teacherId: 'teacher-1',
    title: title,
    weekday: weekday,
    startMinutes: start,
    durationMinutes: duration,
    locationNote: location,
    isCancelled: isCancelled,
  );
}

SessionDraft _draft({
  String title = 'حل تدريبات',
  GroupWeekday weekday = GroupWeekday.sunday,
  int start = 18 * 60,
  int duration = 60,
  String? location,
}) {
  return SessionDraft(
    title: title,
    weekday: weekday,
    startMinutes: start,
    durationMinutes: duration,
    locationNote: location,
  );
}

void main() {
  group('SessionRules — التنسيق العربي', () {
    test('الوقت 12 ساعة ص/م مع منتصف الليل والظهر', () {
      expect(SessionRules.formatMinutes(0), '12:00 ص');
      expect(SessionRules.formatMinutes(9 * 60 + 5), '9:05 ص');
      expect(SessionRules.formatMinutes(12 * 60), '12:00 م');
      expect(SessionRules.formatMinutes(17 * 60 + 30), '5:30 م');
      expect(SessionRules.formatMinutes(23 * 60 + 59), '11:59 م');
    });

    test('المدة بصيغة عربية طبيعية', () {
      expect(SessionRules.formatDuration(30), 'نصف ساعة');
      expect(SessionRules.formatDuration(60), 'ساعة');
      expect(SessionRules.formatDuration(90), 'ساعة ونصف');
      expect(SessionRules.formatDuration(120), 'ساعتان');
      expect(SessionRules.formatDuration(45), '45 دقيقة');
    });

    test('المدى يجمع البداية والنهاية', () {
      expect(
        SessionRules.formatRange(_session(start: 17 * 60, duration: 90)),
        '5:00 م — 6:30 م',
      );
    });
  });

  group('SessionRules — التحقق', () {
    test('مسودة صحيحة تُقبل', () {
      expect(SessionRules.validateDraft(_draft()).isValid, isTrue);
    });

    test('العنوان القصير أو الطويل مرفوض', () {
      expect(
        SessionRules.validateDraft(_draft(title: 'أب')).problems.first.field,
        'title',
      );
      expect(
        SessionRules.validateDraft(_draft(title: 'ا' * 61)).isValid,
        isFalse,
      );
      expect(
        SessionRules.validateDraft(_draft(title: '   ')).isValid,
        isFalse,
      );
    });

    test('المدة خارج النطاق أو غير قابلة للقسمة على 5 مرفوضة', () {
      expect(SessionRules.validateDraft(_draft(duration: 10)).isValid, isFalse);
      expect(SessionRules.validateDraft(_draft(duration: 245)).isValid, isFalse);
      expect(SessionRules.validateDraft(_draft(duration: 47)).isValid, isFalse);
    });

    test('الحصة التي تعبر منتصف الليل مرفوضة', () {
      // 23:30 + 60 دقيقة = 00:30 من اليوم التالي.
      final result = SessionRules.validateDraft(
        _draft(start: 23 * 60 + 30, duration: 60),
      );
      expect(result.isValid, isFalse);
      expect(result.problems.first.field, 'durationMinutes');
    });

    test('البداية بعد 11 مساءً مرفوضة', () {
      expect(
        SessionRules.validateDraft(_draft(start: 23 * 60 + 30, duration: 15)).isValid,
        isFalse,
      );
    });

    test('مكان أطول من 60 حرفًا مرفوض', () {
      expect(
        SessionRules.validateDraft(_draft(location: 'ا' * 61)).problems.first.field,
        'locationNote',
      );
    });
  });

  group('SessionRules — التداخل', () {
    test('تداخل في نفس اليوم مرفوض مع رسالة تسمّي الموعد', () {
      final List<GroupSession> existing = <GroupSession>[_session()];
      // 17:00-18:30 مقابل 18:00-19:00.
      final SessionDraft draft = _draft(
        weekday: GroupWeekday.saturday,
        start: 18 * 60,
        duration: 60,
      );

      final String? message = SessionRules.conflictMessage(draft, existing);
      expect(message, contains('التفاضل'));
      expect(SessionRules.validateDraft(draft, existing: existing).isValid, isFalse);
    });

    test('يوم مختلف بلا تداخل، والملاصق بلا تداخل', () {
      final List<GroupSession> existing = <GroupSession>[_session()];

      expect(
        SessionRules.validateDraft(
          _draft(weekday: GroupWeekday.sunday, start: 17 * 60),
          existing: existing,
        ).isValid,
        isTrue,
      );
      // 18:30 بالضبط = نهاية الحصة الأولى ⇒ ليست تداخلًا.
      expect(
        SessionRules.validateDraft(
          _draft(weekday: GroupWeekday.saturday, start: 18 * 60 + 30),
          existing: existing,
        ).isValid,
        isTrue,
      );
    });

    test('الموعد الملغى لا يشارك في فحص التداخل', () {
      final List<GroupSession> existing = <GroupSession>[
        _session(isCancelled: true),
      ];

      expect(
        SessionRules.validateDraft(
          _draft(weekday: GroupWeekday.saturday, start: 17 * 60),
          existing: existing,
        ).isValid,
        isTrue,
      );
    });

    test('تعديل موعد لا يتعارض مع نفسه', () {
      final List<GroupSession> existing = <GroupSession>[_session()];
      final SessionDraft sameSlot = SessionDraft.fromSession(existing.first);

      expect(
        SessionRules.validateDraft(
          sameSlot,
          existing: existing,
          ignoreSessionId: 's1',
        ).isValid,
        isTrue,
      );
      // وبدون تجاهله يتعارض مع نفسه (إثبات أن الفحص فعّال).
      expect(
        SessionRules.validateDraft(sameSlot, existing: existing).isValid,
        isFalse,
      );
    });
  });

  group('SessionRules — العرض', () {
    test('الترتيب: اليوم ثم الوقت، والملغاة في نهاية يومها', () {
      final List<GroupSession> sorted = SessionRules.sorted(<GroupSession>[
        _session(id: 'c', weekday: GroupWeekday.monday, start: 10 * 60),
        _session(id: 'a', weekday: GroupWeekday.saturday, start: 20 * 60),
        _session(id: 'b', weekday: GroupWeekday.saturday, start: 9 * 60),
        _session(
          id: 'd',
          weekday: GroupWeekday.saturday,
          start: 8 * 60,
          isCancelled: true,
        ),
      ]);

      expect(
        sorted.map((GroupSession s) => s.id).toList(),
        <String>['b', 'a', 'd', 'c'],
      );
    });

    test('التجميع حسب اليوم يتخطى الأيام الفارغة', () {
      final List<MapEntry<GroupWeekday, List<GroupSession>>> groups =
          SessionRules.byWeekday(<GroupSession>[
            _session(id: 'a', weekday: GroupWeekday.tuesday),
            _session(id: 'b', weekday: GroupWeekday.tuesday, start: 19 * 60),
          ]);

      expect(groups, hasLength(1));
      expect(groups.first.key, GroupWeekday.tuesday);
      expect(groups.first.value, hasLength(2));
    });

    test('ملخص أسبوعي بالعربية', () {
      expect(SessionRules.weeklySummary(const <GroupSession>[]),
          'لا مواعيد أسبوعية بعد.');
      expect(
        SessionRules.weeklySummary(<GroupSession>[_session(duration: 60)]),
        'حصة واحدة أسبوعيًا — ساعة إجمالًا',
      );
      expect(
        SessionRules.weeklySummary(<GroupSession>[
          _session(duration: 60),
          _session(id: 's2', weekday: GroupWeekday.monday, duration: 60),
        ]),
        contains('حصتان'),
      );
      // الملغاة لا تُحسب في الملخص.
      expect(
        SessionRules.weeklySummary(<GroupSession>[
          _session(duration: 60),
          _session(id: 's2', weekday: GroupWeekday.monday, isCancelled: true),
        ]),
        'حصة واحدة أسبوعيًا — ساعة إجمالًا',
      );
    });

    test('معرّف اليوم بصيغة ISO للتحويل من التاريخ', () {
      expect(GroupWeekday.fromIso(DateTime.saturday), GroupWeekday.saturday);
      expect(GroupWeekday.fromIso(DateTime.monday), GroupWeekday.monday);
      expect(GroupWeekday.fromIso(99), GroupWeekday.saturday);
      expect(GroupWeekday.parse('friday'), GroupWeekday.friday);
      expect(GroupWeekday.parse('nonsense'), GroupWeekday.saturday);
    });
  });
}
