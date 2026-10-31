import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/migration/account_hidden_backfill.dart';

/// مستودع وهمي حتمي: يقرأ قائمة معرّفات وحالة الحقل، ويسجّل كل كتابة.
///
/// لا Firebase هنا: المنطق (ما يُحدَّث وما لا يُلمس) قابل للاختبار وحده، ويبقى
/// اختبار المحاكي مسؤولًا عن سلوك Firestore نفسه.
class _FakeGateway implements AccountHiddenBackfillGateway {
  _FakeGateway({
    required Map<String, bool> profiles,
    Set<String> failing = const <String>{},
  }) : _profiles = profiles,
       _failing = failing;

  final Map<String, bool> _profiles;

  /// معرّفات محسوم الفشل (صلاحيات/شبكة) لإثبات أن مستندًا واحدًا لا يوقف البقية.
  final Set<String> _failing;

  final List<String> writes = <String>[];

  @override
  Future<List<TeacherProfileFlagRecord>> listTeacherProfiles() async {
    return <TeacherProfileFlagRecord>[
      for (final MapEntry<String, bool> entry in _profiles.entries)
        TeacherProfileFlagRecord(
          id: entry.key,
          hasAccountHiddenFlag: entry.value,
        ),
    ];
  }

  @override
  Future<void> setAccountHiddenFalse(String teacherId) async {
    if (_failing.contains(teacherId)) {
      throw StateError('permission-denied:$teacherId');
    }
    writes.add(teacherId);
    _profiles[teacherId] = true;
  }
}

void main() {
  group('ترحيل accountHidden — المعاينة لا تكتب', () {
    test('Dry Run يعرض العدد والمعرّفات دون أي كتابة', () async {
      final _FakeGateway gateway = _FakeGateway(
        profiles: <String, bool>{
          'legacy-1': false,
          'legacy-2': false,
          'new-1': true,
        },
      );

      final AccountHiddenBackfillReport report = await AccountHiddenBackfill.run(
        gateway: gateway,
        dryRun: true,
      );

      expect(report.dryRun, isTrue);
      expect(report.scanned, 3);
      expect(report.needsMigration, 2);
      expect(report.missingIds, <String>['legacy-1', 'legacy-2']);
      expect(report.updatedIds, isEmpty);
      expect(gateway.writes, isEmpty, reason: 'المعاينة كتبت في المستودع');
      expect(report.summary, contains('معاينة'));
    });
  });

  group('ترحيل accountHidden — التنفيذ', () {
    test('يضيف الحقل للناقص فقط ولا يمسّ الموجود', () async {
      final _FakeGateway gateway = _FakeGateway(
        profiles: <String, bool>{
          'legacy-1': false,
          'hidden-account': true,
          'visible-account': true,
        },
      );

      final AccountHiddenBackfillReport report = await AccountHiddenBackfill.run(
        gateway: gateway,
        dryRun: false,
      );

      expect(report.updatedIds, <String>['legacy-1']);
      expect(
        gateway.writes,
        <String>['legacy-1'],
        reason: 'مستند يحمل الحقل (بقيمته) لا يُكتب عليه أبدًا',
      );
      expect(report.failures, isEmpty);
      expect(report.summary, contains('حُدِّث'));
    });

    test('التكرار آمن: التشغيل الثاني يجد صفرًا', () async {
      final _FakeGateway gateway = _FakeGateway(
        profiles: <String, bool>{'legacy-1': false},
      );

      await AccountHiddenBackfill.run(gateway: gateway, dryRun: false);
      final AccountHiddenBackfillReport second = await AccountHiddenBackfill.run(
        gateway: gateway,
        dryRun: false,
      );

      expect(second.needsMigration, 0);
      expect(second.isClean, isTrue);
      expect(gateway.writes, <String>['legacy-1'], reason: 'كتابة مكرّرة');
      expect(second.summary, contains('لا حاجة لترحيل'));
    });

    test('فشل مستند لا يُسقط البقية ويُبلَّغ عنه', () async {
      final _FakeGateway gateway = _FakeGateway(
        profiles: <String, bool>{'a': false, 'b': false, 'c': false},
        failing: <String>{'b'},
      );

      final AccountHiddenBackfillReport report = await AccountHiddenBackfill.run(
        gateway: gateway,
        dryRun: false,
      );

      expect(report.updatedIds, <String>['a', 'c']);
      expect(report.failures, hasLength(1));
      expect(report.failures.single.id, 'b');
      expect(report.isComplete, isFalse);
      expect(report.summary, contains('فشل 1'));
    });

    test('لا ملفات ⇒ تقرير نظيف بلا كتابة', () async {
      final _FakeGateway gateway = _FakeGateway(
        profiles: <String, bool>{},
      );

      final AccountHiddenBackfillReport report = await AccountHiddenBackfill.run(
        gateway: gateway,
        dryRun: false,
      );

      expect(report.scanned, 0);
      expect(report.isClean, isTrue);
      expect(report.summary, contains('لا توجد ملفات'));
    });

    test('المعرّفات مرتّبة (تقرير حتمي قابل للمقارنة)', () async {
      final _FakeGateway gateway = _FakeGateway(
        profiles: <String, bool>{'z': false, 'a': false, 'm': false},
      );

      final AccountHiddenBackfillReport report = await AccountHiddenBackfill.run(
        gateway: gateway,
        dryRun: true,
      );

      expect(report.missingIds, <String>['a', 'm', 'z']);
    });
  });
}
