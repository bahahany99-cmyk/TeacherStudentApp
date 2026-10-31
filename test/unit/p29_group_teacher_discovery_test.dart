import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/validation/group_teacher_discovery.dart';
import 'package:teacher_student_app/data/validation/teacher_visibility_fallback.dart';

/// (P29) الطريق العملي لظهور المدرسين: مجموعة ظاهرة ⇒ معرّف المدرّس ⇒ قراءة
/// مباشرة لملفه.
///
/// هذا ما يجعل البحث عن «shady» يعطي نتيجة في الإنتاج: الاستعلامات لا تستطيع
/// مطابقة الحقل الغائب، لكن اسم المدرّس معروف من مجموعته، وملفه مقروء بالمعرّف
/// (وهو نفس المسار الذي يرسم شارة «مدرس موثّق» في بطاقة المجموعة).

Map<String, Object?> _group(String teacherId) => <String, Object?>{
  'teacherId': teacherId,
  'isActive': true,
};

void main() {
  group('GroupTeacherDiscovery.teacherIds', () {
    test('يجمع المعرّفات بلا تكرار وبترتيب الظهور', () {
      expect(
        GroupTeacherDiscovery.teacherIds(<Map<String, Object?>>[
          _group('shady'),
          _group('bebo83184'),
          _group('shady'),
        ]),
        <String>['shady', 'bebo83184'],
      );
    });

    test('يتجاهل الغائب والفارغ وغير النصي', () {
      expect(
        GroupTeacherDiscovery.teacherIds(<Map<String, Object?>>[
          <String, Object?>{'title': 'بلا مدرس'},
          _group('   '),
          _group(''),
          <String, Object?>{'teacherId': 42},
          _group('ok'),
        ]),
        <String>['ok'],
      );
    });

    test('يحترم السقف (حماية من تكلفة غير متوقعة)', () {
      final List<Map<String, Object?>> groups = <Map<String, Object?>>[
        for (int i = 0; i < 10; i++) _group('t$i'),
      ];
      expect(GroupTeacherDiscovery.teacherIds(groups, max: 3), hasLength(3));
    });
  });

  group('GroupTeacherDiscovery.resolve', () {
    test('يتجاهل الملف الذي يرفض الخادم قراءته ويكمل', () async {
      final List<String> loaded = <String>[];
      final List<String> result = await GroupTeacherDiscovery.resolve<String>(
        <String>['shady', 'hidden-teacher', 'bebo'],
        load: (String id) async {
          loaded.add(id);
          if (id == 'hidden-teacher') {
            throw StateError('permission-denied');
          }
          return id;
        },
      );

      expect(result, <String>['shady', 'bebo']);
      expect(loaded, <String>['shady', 'hidden-teacher', 'bebo']);
    });

    test('يُطبّق المرشّح النهائي (موثّق وغير مخفي)', () async {
      final Map<String, Map<String, Object?>> store =
          <String, Map<String, Object?>>{
            'verified-visible': <String, Object?>{'status': 'verified'},
            'verified-hidden': <String, Object?>{
              'status': 'verified',
              'accountHidden': true,
            },
            'pending': <String, Object?>{'status': 'pendingReview'},
          };

      final List<String> result = await GroupTeacherDiscovery.resolve<String>(
        store.keys.toList(),
        load: (String id) async => id,
        isAcceptable: (String id) =>
            store[id]!['status'] == 'verified' &&
            !TeacherVisibilityFallback.isExplicitlyHidden(store[id]!),
      );

      expect(result, <String>['verified-visible']);
    });

    test('ملف غائب (null) لا يضيف عنصرًا', () async {
      expect(
        await GroupTeacherDiscovery.resolve<String>(
          <String>['a', 'b'],
          load: (String id) async => id == 'a' ? 'doc' : null,
        ),
        <String>['doc'],
      );
    });

    test('كل الملفات فاشلة ⇒ قائمة فارغة بلا استثناء', () async {
      expect(
        await GroupTeacherDiscovery.resolve<String>(
          <String>['a', 'b'],
          load: (String id) async => throw StateError('network'),
        ),
        isEmpty,
      );
    });
  });

  group('TeacherVisibilityFallback — الدمج ثلاثي المصادر', () {
    test('الصارم ثم الواسع ثم المشتق، بلا تكرار، وإسقاط المخفي', () {
      final List<String> merged = TeacherVisibilityFallback.mergeVisible<String>(
        primary: <String>['strict-1', 'shared'],
        extra: <String>['shared', 'broad-legacy', 'derived-shady', 'hidden'],
        idOf: (String id) => id,
        isHidden: (String id) => id == 'hidden',
      );

      expect(merged, <String>['strict-1', 'shared', 'broad-legacy', 'derived-shady']);
    });

    test('المخفي لا يدخل حتى من المصدر الأساسي إن عاد', () {
      final List<String> merged = TeacherVisibilityFallback.mergeVisible<String>(
        primary: <String>['a'],
        extra: <String>['hidden'],
        idOf: (String id) => id,
        isHidden: (String id) => id == 'hidden',
      );
      expect(merged, <String>['a']);
    });
  });

  group('فلاتر الخادم المحاكاة على الملفات المقروءة بالمعرّف', () {
    final Map<String, Object?> online = <String, Object?>{
      'isOnline': true,
      'governorate': 'القاهرة',
    };
    final Map<String, Object?> inPerson = <String, Object?>{
      'isOnline': false,
      'governorate': 'الجيزة',
    };
    final Map<String, Object?> legacyNoFlag = <String, Object?>{'governorate': 'القاهرة'};

    test('«الكل» يمرّر الجميع', () {
      expect(
        TeacherVisibilityFallback.matchesOnlineFlag(online, null),
        isTrue,
      );
      expect(
        TeacherVisibilityFallback.matchesOnlineFlag(inPerson, null),
        isTrue,
      );
    });

    test('«عن بُعد» و«حضوري فقط» كما يفعل فلتر المساواة في الخادم', () {
      expect(TeacherVisibilityFallback.matchesOnlineFlag(online, true), isTrue);
      expect(
        TeacherVisibilityFallback.matchesOnlineFlag(inPerson, true),
        isFalse,
      );
      expect(
        TeacherVisibilityFallback.matchesOnlineFlag(inPerson, false),
        isTrue,
      );
      // الحقل الغائب لا يطابق مساواة صريحة — نفس سلوك الخادم.
      expect(
        TeacherVisibilityFallback.matchesOnlineFlag(legacyNoFlag, false),
        isFalse,
      );
    });

    test('المحافظة: null يمرّر الكل، والمحددة تُطابق صراحةً', () {
      expect(
        TeacherVisibilityFallback.matchesGovernorate(online, null),
        isTrue,
      );
      expect(
        TeacherVisibilityFallback.matchesGovernorate(online, 'القاهرة'),
        isTrue,
      );
      expect(
        TeacherVisibilityFallback.matchesGovernorate(inPerson, 'القاهرة'),
        isFalse,
      );
      expect(
        TeacherVisibilityFallback.matchesGovernorate(legacyNoFlag, 'القاهرة'),
        isTrue,
      );
    });
  });
}
