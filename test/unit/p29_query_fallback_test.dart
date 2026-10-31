import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/utils/arabic_text.dart';
import 'package:teacher_student_app/data/models/teacher_filter.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/validation/teacher_discovery_rules.dart';
import 'package:teacher_student_app/data/validation/teacher_visibility_fallback.dart';

/// (P29) احتياطي «الحقل الغائب = ظاهر» ومطابقة البحث العربية.
///
/// لا Firebase هنا: السياسة نفسها (دمج الصارم مع الواسع + إسقاط الموسوم
/// بالإخفاء) منطق نقي، فيُختبر بمصادر وهمية حتمية.

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
  group('TeacherVisibilityFallback — دمج الصارم مع الواسع', () {
    test('الصارم غير فارغ ومع ذلك يُدمج الواسع (حالة «Shady»)', () async {
      // العطل السابق: ملف ظاهر واحد كان يمنع قراءة الواسع، فيغيب كل ملف قديم.
      final List<String> result =
          await TeacherVisibilityFallback.resolveMerged<String>(
            strict: () async => <String>['visible-new'],
            broad: () async => <String>['visible-new', 'legacy-shady'],
            idOf: (String id) => id,
            isHidden: (String id) => false,
          );

      expect(result, <String>['visible-new', 'legacy-shady']);
    });

    test('بلا تكرار: المستند العائد من الاستعلامين يظهر مرة واحدة', () async {
      final List<String> result =
          await TeacherVisibilityFallback.resolveMerged<String>(
            strict: () async => <String>['a', 'b'],
            broad: () async => <String>['b', 'a', 'c'],
            idOf: (String id) => id,
            isHidden: (String id) => false,
          );

      expect(result, <String>['a', 'b', 'c']);
    });

    test('الموسوم بالإخفاء في الواسع يُسقط دائمًا', () async {
      final List<String> result =
          await TeacherVisibilityFallback.resolveMerged<String>(
            strict: () async => <String>['visible'],
            broad: () async => <String>['visible', 'hidden', 'legacy'],
            idOf: (String id) => id,
            isHidden: (String id) => id == 'hidden',
          );

      expect(result, <String>['visible', 'legacy']);
    });

    test('فشل الواسع لا يُفشل القائمة (أفضل جهد)', () async {
      final List<String> result =
          await TeacherVisibilityFallback.resolveMerged<String>(
            strict: () async => <String>['visible'],
            broad: () async => throw StateError('permission-denied'),
            idOf: (String id) => id,
            isHidden: (String id) => false,
          );

      expect(result, <String>['visible']);
    });

    test('فشل الصارم يُرفع (الفشل لا يصبح «لا نتائج»)', () {
      expect(
        () => TeacherVisibilityFallback.resolveMerged<String>(
          strict: () async => throw StateError('network'),
          broad: () async => <String>['x'],
          idOf: (String id) => id,
          isHidden: (String id) => false,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('broadErrorIsFatal يجعل فشل الواسع ظاهرًا لمن يريده', () {
      expect(
        () => TeacherVisibilityFallback.resolveMerged<String>(
          strict: () async => <String>['visible'],
          broad: () async => throw StateError('boom'),
          idOf: (String id) => id,
          isHidden: (String id) => false,
          broadErrorIsFatal: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('النتيجتان فارغتان ⇒ قائمة فارغة (لا استثناء)', () async {
      final List<String> result =
          await TeacherVisibilityFallback.resolveMerged<String>(
            strict: () async => const <String>[],
            broad: () async => const <String>[],
            idOf: (String id) => id,
            isHidden: (String id) => false,
          );

      expect(result, isEmpty);
    });
  });

  group('isExplicitlyHidden — الغياب ظاهر', () {
    test('true فقط مخفي، والغياب/false/null ظاهرة', () {
      expect(
        TeacherVisibilityFallback.isExplicitlyHidden(<String, Object?>{}),
        isFalse,
      );
      expect(
        TeacherVisibilityFallback.isExplicitlyHidden(<String, Object?>{
          'accountHidden': false,
        }),
        isFalse,
      );
      expect(
        TeacherVisibilityFallback.isExplicitlyHidden(<String, Object?>{
          'accountHidden': null,
        }),
        isFalse,
      );
      expect(
        TeacherVisibilityFallback.isExplicitlyHidden(<String, Object?>{
          'accountHidden': true,
        }),
        isTrue,
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
