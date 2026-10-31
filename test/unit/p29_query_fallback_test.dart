import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/utils/arabic_text.dart';
import 'package:teacher_student_app/data/models/teacher_filter.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/validation/teacher_discovery_rules.dart';
import 'package:teacher_student_app/data/validation/teacher_visibility_fallback.dart';

/// (P29) احتياطي «الحقل الغائب = ظاهر» ومطابقة البحث العربية.
///
/// لا Firebase هنا: السياسة نفسها (صرّح ← واسع ← رجوع عند الرفض) منطق نقي،
/// فيُختبر بمصادر وهمية حتمية.

class _PermissionDenied implements Exception {}

TeacherProfile _teacher({
  required String id,
  String name = 'أ. سارة الخطيب',
  String subject = 'الرياضيات',
  String stage = 'الثانوية العامة',
  String? governorate,
  bool online = false,
}) {
  return TeacherProfile(
    id: id,
    displayName: name,
    subject: subject,
    stage: stage,
    area: 'المعادي',
    bio: 'شرح مبسّط',
    status: TeacherProfileStatus.verified,
    governorate: governorate,
    isOnline: online,
  );
}

void main() {
  group('TeacherVisibilityFallback — ترتيب المحاولات', () {
    test('نتيجة صارمة غير فارغة: لا يُجرَّب الاستعلام الواسع', () async {
      int broadCalls = 0;
      final List<String> result = await TeacherVisibilityFallback.resolve<
        List<String>
      >(
        strict: () async => <String>['strict'],
        broad: () async {
          broadCalls++;
          return <String>['broad'];
        },
        isEmpty: (List<String> value) => value.isEmpty,
        isPermissionDenied: (Object error) => error is _PermissionDenied,
      );

      expect(result, <String>['strict']);
      expect(broadCalls, 0, reason: 'طلب إضافي بلا داعٍ يُبطئ الشاشة');
    });

    test('فارغ صارم: يعود بالواسع (هنا يظهر الملف الناقص الحقل)', () async {
      final List<String> result = await TeacherVisibilityFallback.resolve<
        List<String>
      >(
        strict: () async => const <String>[],
        broad: () async => <String>['legacy'],
        isEmpty: (List<String> value) => value.isEmpty,
        isPermissionDenied: (Object error) => error is _PermissionDenied,
      );

      expect(result, <String>['legacy']);
    });

    test('رفض القواعد للواسع: نعود بالفارغ الصارم بدل إفشال الشاشة', () async {
      final List<String> result = await TeacherVisibilityFallback.resolve<
        List<String>
      >(
        strict: () async => const <String>[],
        broad: () async => throw _PermissionDenied(),
        isEmpty: (List<String> value) => value.isEmpty,
        isPermissionDenied: (Object error) => error is _PermissionDenied,
      );

      expect(result, isEmpty, reason: 'لا نُظهر حسابًا مخفيًا ولا خطأ تقنيًا');
    });

    test('خطأ شبكة/مهلة على الواسع يُعاد رفعه (الفشل لا يصبح «لا نتائج»)', () async {
      expect(
        () => TeacherVisibilityFallback.resolve<List<String>>(
          strict: () async => const <String>[],
          broad: () async => throw StateError('network'),
          isEmpty: (List<String> value) => value.isEmpty,
          isPermissionDenied: (Object error) => error is _PermissionDenied,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('خطأ في الاستعلام الصارم نفسه يُرفع (لا ابتلاع)', () {
      expect(
        () => TeacherVisibilityFallback.resolve<List<String>>(
          strict: () async => throw StateError('strict failed'),
          broad: () async => <String>['x'],
          isEmpty: (List<String> value) => value.isEmpty,
          isPermissionDenied: (Object error) => error is _PermissionDenied,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ArabicText — همزات وتشكيل و«ال» التعريف', () {
    test('كل أشكال الألف متكافئة', () {
      for (final String form in <String>['أحمد', 'إحمد', 'آحمد', 'احمد']) {
        expect(ArabicText.matches('أحمد علي', form), isTrue, reason: form);
      }
    });

    test('التاء المربوطة والياء المقصورة تُوحَّد', () {
      expect(ArabicText.matches('مدرسة النيل', 'مدرسه'), isTrue);
      expect(ArabicText.matches('مصطفى', 'مصطفي'), isTrue);
    });

    test('التشكيل والتطويل لا يمنعان المطابقة', () {
      expect(ArabicText.matches('أحـمَد', 'احمد'), isTrue);
      expect(ArabicText.matches('مُحَمَّد', 'محمد'), isTrue);
    });

    test('«ال» التعريف تُتجاهل في الاتجاهين', () {
      expect(ArabicText.matches('الرياضيات', 'رياضيات'), isTrue);
      expect(ArabicText.matches('رياضيات', 'الرياضيات'), isTrue);
      expect(ArabicText.matches('اللغة العربية', 'عربية'), isTrue);
    });

    test('الأرقام العربية-الهندية تُطابق اللاتينية', () {
      expect(ArabicText.normalize('الصف ٢٠٢٦'), 'الصف 2026');
    });

    test('طلب فارغ يطابق كل شيء (لا فلترة نصية)', () {
      expect(ArabicText.matches('أي نص', '  '), isTrue);
    });

    test('نص غير مطابق لا يُطابق (لا إيجابيات كاذبة)', () {
      expect(ArabicText.matches('الفيزياء', 'رياضيات'), isFalse);
    });
  });

  group('بحث المدرسين — التطبيع العربي داخل الفلترة', () {
    final List<TeacherProfile> sample = <TeacherProfile>[
      _teacher(id: 'math', name: 'أ. شادي محمد', subject: 'الرياضيات'),
      _teacher(
        id: 'physics',
        name: 'أ. منى عبد الرحمن',
        subject: 'الفيزياء',
        stage: 'الإعدادية',
      ),
    ];

    test('«رياضيات» تجد «الرياضيات»', () {
      final TeacherSearchResult result = TeacherDiscoveryRules.search(
        sample,
        const TeacherFilter(query: 'رياضيات'),
      );
      expect(result.teachers.map((TeacherProfile t) => t.id), <String>['math']);
      expect(result.isEmpty, isFalse);
    });

    test('«شادي» بدون همزة تجد «شادي»، و«إعداديه» تجد «الإعدادية»', () {
      expect(
        TeacherDiscoveryRules.search(
          sample,
          const TeacherFilter(query: 'شادي'),
        ).length,
        1,
      );
      expect(
        TeacherDiscoveryRules.search(
          sample,
          const TeacherFilter(query: 'اعداديه'),
        ).length,
        1,
      );
    });
  });

  group('خيارات المحافظات — مصدران', () {
    test('الفارغ من المصدر الأول لا يُفرغ الصف إذا كانت النتائج فيها محافظات', () {
      final List<TeacherProfile> results = <TeacherProfile>[
        _teacher(id: 'g1', governorate: 'الجيزة'),
        _teacher(id: 'g2', governorate: 'القاهرة'),
      ];

      expect(
        TeacherDiscoveryRules.governorateOptions(
          const <TeacherProfile>[],
          extra: results,
        ),
        <String>['الجيزة', 'القاهرة'],
      );
    });

    test('الدمج بلا تكرار، والترتيب حتمي', () {
      final List<TeacherProfile> universe = <TeacherProfile>[
        _teacher(id: 'a', governorate: 'القاهرة'),
      ];
      final List<TeacherProfile> results = <TeacherProfile>[
        _teacher(id: 'a', governorate: 'القاهرة'),
        _teacher(id: 'b', governorate: 'أسيوط'),
      ];

      expect(
        TeacherDiscoveryRules.governorateOptions(universe, extra: results),
        <String>['أسيوط', 'القاهرة'],
      );
    });

    test('المصدران فارغان: صف فارغ (وهو ما تعرضه الشاشة كحبة معلومة)', () {
      expect(
        TeacherDiscoveryRules.governorateOptions(const <TeacherProfile>[]),
        isEmpty,
      );
    });
  });
}
