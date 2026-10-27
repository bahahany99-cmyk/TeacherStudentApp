import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/models/group_filter.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/validation/discovery_rules.dart';

StudyGroup _group({
  String id = 'g1',
  String title = 'مجموعة الرياضيات — التفاضل',
  String teacherName = 'أ. سارة الخطيب',
  String subject = 'الرياضيات',
  String stage = 'الثانوية العامة',
  int seatsTotal = 12,
  int seatsTaken = 9,
  GroupMeetingMode mode = GroupMeetingMode.center,
  bool isActive = true,
}) {
  return StudyGroup(
    id: id,
    teacherId: 'teacher-1',
    teacherName: teacherName,
    title: title,
    subject: subject,
    stage: stage,
    seatsTotal: seatsTotal,
    seatsTaken: seatsTaken,
    meetingMode: mode,
    isActive: isActive,
  );
}

void main() {
  final List<StudyGroup> sample = <StudyGroup>[
    _group(id: 'a', seatsTaken: 9), // 3 مقاعد
    _group(
      id: 'b',
      title: 'مجموعة الفيزياء — الكهربية',
      subject: 'الفيزياء',
      seatsTotal: 10,
      seatsTaken: 10,
    ), // مكتملة
    _group(
      id: 'c',
      title: 'تأسيس النحو',
      teacherName: 'أ. منى عبد الرحمن',
      subject: 'اللغة العربية',
      stage: 'الإعدادية',
      seatsTotal: 15,
      seatsTaken: 5,
      mode: GroupMeetingMode.online,
    ), // 10 مقاعد
    _group(id: 'd', title: 'موقوفة', isActive: false),
  ];

  group('DiscoveryRules — الفلترة', () {
    test('بلا فلاتر: كل المنشور فقط، والموقوفة لا تظهر', () {
      final GroupSearchResult result = DiscoveryRules.search(
        sample,
        GroupFilter.empty,
      );

      expect(result.total, 3);
      expect(result.groups, hasLength(3));
      expect(
        result.groups.any((StudyGroup g) => g.id == 'd'),
        isFalse,
        reason: 'المجموعة الموقوفة لا تُعرض للطالب',
      );
    });

    test('فلتر المادة يستبعد غيرها', () {
      final GroupSearchResult result = DiscoveryRules.search(
        sample,
        const GroupFilter(subject: 'الفيزياء'),
      );

      expect(result.groups.map((StudyGroup g) => g.id), <String>['b']);
      expect(result.total, 3, reason: 'الإجمالي قبل الفلترة يبقى 3');
    });

    test('فلتر المرحلة وطريقة الحضور', () {
      expect(
        DiscoveryRules.search(
          sample,
          const GroupFilter(stage: 'الإعدادية'),
        ).groups.map((StudyGroup g) => g.id),
        <String>['c'],
      );
      // المجموعتان «سنتر» مرتبتان بالأنسب: الأكثر مقاعد أولًا.
      expect(
        DiscoveryRules.search(
          sample,
          const GroupFilter(meetingMode: GroupMeetingMode.center),
        ).groups.map((StudyGroup g) => g.id),
        <String>['a', 'b'],
      );
    });

    test('فلتر المقاعد: المتاحة تُظهر ما فيها مقعد، والمكتملة عكسه', () {
      final GroupSearchResult available = DiscoveryRules.search(
        sample,
        const GroupFilter(availability: GroupAvailability.available),
      );
      final GroupSearchResult full = DiscoveryRules.search(
        sample,
        const GroupFilter(availability: GroupAvailability.full),
      );

      expect(available.groups.map((StudyGroup g) => g.id), isNot(contains('b')));
      expect(full.groups.map((StudyGroup g) => g.id), <String>['b']);
    });

    test('البحث النصي يتجاوز التشكيل وصيغ الألف والياء', () {
      final List<StudyGroup> groups = <StudyGroup>[
        _group(title: 'مراجعة التفاضل', teacherName: 'أحمد علي'),
        _group(id: 'x', title: 'نحو', teacherName: 'منى', subject: 'عربي'),
      ];

      // «تفاضل» جزء من «التفاضل».
      expect(
        DiscoveryRules.search(groups, const GroupFilter(query: 'تفاضل'))
            .groups
            .length,
        1,
      );
      // «احمد» بلا همزة يطابق «أحمد».
      expect(
        DiscoveryRules.search(groups, const GroupFilter(query: 'احمد'))
            .groups
            .single
            .teacherName,
        'أحمد علي',
      );
      // المسافات الطرفية لا تُفشل البحث.
      expect(
        DiscoveryRules.search(groups, const GroupFilter(query: '  نحو  '))
            .groups
            .single
            .id,
        'x',
      );
    });

    test('بحث بلا نتيجة يعيد قائمة فارغة مع الإجمالي', () {
      final GroupSearchResult result = DiscoveryRules.search(
        sample,
        const GroupFilter(query: 'كيمياء'),
      );

      expect(result.isEmpty, isTrue);
      expect(result.total, 3);
    });

    test('الفلترة مجتمعة: مادة + توفر + بحث', () {
      final GroupSearchResult result = DiscoveryRules.search(
        sample,
        const GroupFilter(subject: 'الرياضيات', query: 'سارة'),
      );

      expect(result.groups.single.id, 'a');
    });
  });

  group('DiscoveryRules — الترتيب', () {
    test('الأنسب: أكثر مقاعد متاحة أولًا ثم العنوان', () {
      final GroupSearchResult result = DiscoveryRules.search(
        sample,
        const GroupFilter(sort: GroupSort.recommended),
      );

      expect(result.groups.map((StudyGroup g) => g.id), <String>['c', 'a', 'b']);
    });

    test('الأقرب امتلاءً: أقل مقاعد أولًا', () {
      final GroupSearchResult result = DiscoveryRules.search(
        sample,
        const GroupFilter(sort: GroupSort.fewestSeats),
      );

      expect(result.groups.map((StudyGroup g) => g.id), <String>['b', 'a', 'c']);
    });

    test('أبجديًا بالعنوان', () {
      final GroupSearchResult result = DiscoveryRules.search(
        sample,
        const GroupFilter(sort: GroupSort.title),
      );

      final List<String> titles = result.groups
          .map((StudyGroup g) => g.title)
          .toList(growable: false);
      final List<String> sortedTitles = <String>[...titles]..sort();
      expect(titles, sortedTitles);
    });
  });

  group('DiscoveryRules — خيارات ونصوص', () {
    test('الخيارات مشتقة من البيانات ومميزة ومرتبة', () {
      expect(DiscoveryRules.subjectOptions(sample), <String>[
        'الرياضيات',
        'الفيزياء',
        'اللغة العربية',
      ]);
      expect(DiscoveryRules.stageOptions(sample), <String>[
        'الإعدادية',
        'الثانوية العامة',
      ]);
      expect(DiscoveryRules.subjectOptions(const <StudyGroup>[]), isEmpty);
    });

    test('سطر النتائج يوضّح أثر الفلترة', () {
      expect(
        DiscoveryRules.resultsLine(
          const GroupSearchResult(groups: <StudyGroup>[], total: 0),
        ),
        'لا مجموعات منشورة',
      );
      expect(
        DiscoveryRules.resultsLine(
          GroupSearchResult(groups: <StudyGroup>[_group()], total: 1),
        ),
        '1 مجموعة',
      );
      expect(
        DiscoveryRules.resultsLine(
          GroupSearchResult(groups: <StudyGroup>[_group()], total: 4),
        ),
        '1 من 4 مجموعة',
      );
    });

    test('رسالة الفراغ تشرح السبب', () {
      expect(
        DiscoveryRules.emptyMessage(
          const GroupFilter(availability: GroupAvailability.available),
        ),
        contains('مكتملة'),
      );
      expect(
        DiscoveryRules.emptyMessage(const GroupFilter(query: 'كيمياء')),
        contains('تقليل'),
      );
      expect(
        DiscoveryRules.emptyMessage(GroupFilter.empty),
        contains('نشرها'),
      );
    });
  });

  group('GroupFilter', () {
    test('copyWith يزيل الفلتر ويمسحه صريحًا', () {
      const GroupFilter filter = GroupFilter(subject: 'الرياضيات', query: 'س');
      final GroupFilter cleared = filter.copyWith(subject: null);

      expect(cleared.subject, isNull);
      expect(cleared.query, 'س');
      expect(filter.copyWith(query: 'جديد').subject, 'الرياضيات');
      expect(filter.activeCount, 2);
      expect(cleared.activeCount, 1);
      expect(cleared.isActive, isTrue);
    });

    test('cleared يحافظ على الترتيب', () {
      const GroupFilter filter = GroupFilter(
        subject: 'الرياضيات',
        stage: 'الإعدادية',
        availability: GroupAvailability.full,
        sort: GroupSort.title,
      );
      final GroupFilter cleared = filter.cleared();

      expect(cleared.subject, isNull);
      expect(cleared.stage, isNull);
      expect(cleared.availability, GroupAvailability.any);
      expect(cleared.sort, GroupSort.title);
      expect(cleared.isActive, isTrue, reason: 'الترتيب المخصص فعل');
    });

    test('التساوي يشمل الفلتر كله (لتفادي قراءات زائدة)', () {
      expect(
        const GroupFilter(query: ' نحو ') == const GroupFilter(query: 'نحو'),
        isTrue,
      );
      expect(
        const GroupFilter(subject: 'أ') == const GroupFilter(subject: 'ب'),
        isFalse,
      );
      expect(
        const GroupFilter().hashCode,
        const GroupFilter(query: '  ').hashCode,
      );
    });
  });
}
