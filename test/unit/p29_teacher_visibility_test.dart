import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/firebase/teacher_profile_writes.dart';
import 'package:teacher_student_app/data/migration/account_hidden_backfill.dart';
import 'package:teacher_student_app/data/models/teacher_filter.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/validation/teacher_discovery_rules.dart';
import 'package:teacher_student_app/data/validation/teacher_visibility_fallback.dart';

/// (P29) سلسلة كاملة: المستند الخام ← الترحيل/القرار الإداري ← الاكتشاف.
///
/// هذه هي الحلقة التي كانت مكسورة: ملف موثّق بلا `accountHidden` **يُقرأ**
/// (القواعد تسمح) لكنه **لا يُكتشف** (فلتر المساواة يستبعده)، فيرى الطالب
/// مجموعته وشارة توثيقه بينما صفحة المدرسين فارغة.

/// مستودع وهمي يحاكي مستندات Firestore خامًا (المفتاح موجود أو غائب).
class _RawStore implements AccountHiddenBackfillGateway {
  _RawStore(this.docs);

  /// معرّف ← خريطة الحقول كما في Firestore.
  final Map<String, Map<String, Object?>> docs;

  @override
  Future<List<TeacherProfileFlagRecord>> listTeacherProfiles() async {
    return <TeacherProfileFlagRecord>[
      for (final MapEntry<String, Map<String, Object?>> entry in docs.entries)
        TeacherProfileFlagRecord(
          id: entry.key,
          hasAccountHiddenFlag: entry.value.containsKey('accountHidden'),
        ),
    ];
  }

  @override
  Future<void> setAccountHiddenFalse(String teacherId) async {
    // كما في Firestore: لا يُعاد كتابة قيمة موجودة في هذا الترحيل.
    docs[teacherId]!.putIfAbsent('accountHidden', () => false);
  }
}

Map<String, Object?> _rawProfile({
  required String id,
  String displayName = 'أ. سارة الخطيب',
  String status = 'verified',
  bool withFlag = false,
  bool? hiddenValue,
  String governorate = 'القاهرة',
  String subject = 'الرياضيات',
  String stage = 'الثانوية العامة',
}) {
  return <String, Object?>{
    'ownerId': id,
    'displayName': displayName,
    'status': status,
    'subject': subject,
    'stage': stage,
    'area': 'المعادي',
    'bio': 'شرح مبسّط',
    if (withFlag) 'accountHidden': hiddenValue ?? false,
    'governorate': governorate,
  };
}

/// يقلّد استعلام الاكتشاف: `verified && accountHidden == false` (مساواة صريحة،
/// فالمفتاح الغائب **لا** يطابق) ثم بناء النموذج كما يفعل المُحوِّل.
List<TeacherProfile> _discover(Map<String, Map<String, Object?>> docs) {
  return <TeacherProfile>[
    for (final MapEntry<String, Map<String, Object?>> entry in docs.entries)
      if (entry.value['status'] == 'verified' &&
          entry.value.containsKey('accountHidden') &&
          entry.value['accountHidden'] == false)
        TeacherProfile(
          id: entry.key,
          displayName: entry.value['displayName']! as String,
          subject: entry.value['subject']! as String,
          stage: entry.value['stage']! as String,
          area: entry.value['area']! as String,
          bio: entry.value['bio']! as String,
          status: TeacherProfileStatus.verified,
          governorate: entry.value['governorate'] as String?,
        ),
  ];
}

void main() {
  group('(P29) الظهور بعد الترحيل', () {
    test('مدرس موثّق بلا accountHidden لا يظهر قبل الترحيل ويظهر بعده', () async {
      final _RawStore store = _RawStore(<String, Map<String, Object?>>{
        'shady': _rawProfile(id: 'shady', displayName: 'أ. شادي'),
      });

      // 1) الحالة المكسورة: القراءة المباشرة تنجح (النموذج يُبنى) لكن الاكتشاف لا.
      expect(_discover(store.docs), isEmpty);

      // 2) معاينة: تقرير فقط بلا كتابة.
      final AccountHiddenBackfillReport preview = await AccountHiddenBackfill.run(
        gateway: store,
        dryRun: true,
      );
      expect(preview.missingIds, <String>['shady']);
      expect(store.docs['shady']!.containsKey('accountHidden'), isFalse);

      // 3) التنفيذ.
      final AccountHiddenBackfillReport applied = await AccountHiddenBackfill.run(
        gateway: store,
        dryRun: false,
      );
      expect(applied.updatedIds, <String>['shady']);
      expect(store.docs['shady']!['accountHidden'], false);

      // 4) صار ظاهرًا، بلا تغيير أي حقل آخر.
      final List<TeacherProfile> visible = _discover(store.docs);
      expect(visible, hasLength(1));
      expect(visible.single.displayName, 'أ. شادي');
      expect(store.docs['shady']!['status'], 'verified');
      expect(store.docs['shady']!['displayName'], 'أ. شادي');
    });

    test('المحافظات تُشتق من النتائج: فارغة قبل الترحيل وممتلئة بعده', () async {
      final _RawStore store = _RawStore(<String, Map<String, Object?>>{
        'a': _rawProfile(id: 'a', governorate: 'القاهرة'),
        'b': _rawProfile(id: 'b', governorate: 'الجيزة'),
      });

      expect(
        TeacherDiscoveryRules.governorateOptions(_discover(store.docs)),
        isEmpty,
      );

      await AccountHiddenBackfill.run(gateway: store, dryRun: false);

      // الترتيب أبجدي حسب نقاط الشيفرة (كما ينفّذه `governorateOptions`).
      expect(
        TeacherDiscoveryRules.governorateOptions(_discover(store.docs)),
        <String>['الجيزة', 'القاهرة'],
      );
    });
  });

  group('(P29) حساب جديد وحساب مخفي', () {
    test('مدرس جديد ينشئ ملفه عبر التطبيق يظهر فورًا (الحقل يُكتب عند الإنشاء)', () {
      final Map<String, Map<String, Object?>> docs =
          <String, Map<String, Object?>>{
            'fresh': <String, Object?>{
              ..._rawProfile(id: 'fresh', status: 'pendingReview'),
              'accountHidden': false,
            },
          };

      // أثناء المراجعة لا يظهر (الحالة ليست verified)…
      expect(_discover(docs), isEmpty);

      // …وبعد قرار التوثيق يُضاف الحقل فقط إن كان غائبًا (هو موجود، فلا تغيير)
      // وتصبح الحالة verified فيظهر.
      final Map<String, Object?> payload = TeacherProfileWrites.adminDecision(
        status: TeacherProfileStatus.verified,
        reviewNote: null,
        deletedValue: '__DELETE__',
        serverTimestamp: '__TS__',
        accountHiddenFlagPresent: docs['fresh']!.containsKey('accountHidden'),
      );
      expect(payload.containsKey('accountHidden'), isFalse);
      docs['fresh']!['status'] = 'verified';

      expect(_discover(docs).single.id, 'fresh');
    });

    test('حساب موثّق مخفي يبقى مخفيًا بعد الترحيل وبعد قرار التوثيق', () async {
      final _RawStore store = _RawStore(<String, Map<String, Object?>>{
        'hidden': _rawProfile(id: 'hidden', withFlag: true, hiddenValue: true),
      });

      final AccountHiddenBackfillReport report = await AccountHiddenBackfill.run(
        gateway: store,
        dryRun: false,
      );
      expect(report.needsMigration, 0);
      expect(store.docs['hidden']!['accountHidden'], true);

      // قرار إداري جديد (إعادة توثيق) لا يمسّ الحقل أيضًا.
      final Map<String, Object?> payload = TeacherProfileWrites.adminDecision(
        status: TeacherProfileStatus.verified,
        reviewNote: null,
        deletedValue: '__DELETE__',
        serverTimestamp: '__TS__',
        accountHiddenFlagPresent: true,
      );
      expect(payload.containsKey('accountHidden'), isFalse);
      store.docs['hidden']!.addAll(payload);

      expect(store.docs['hidden']!['accountHidden'], true);
      expect(_discover(store.docs), isEmpty);
    });

    test('حساب غير موثّق لا يظهر حتى لو حمل الحقل', () {
      final Map<String, Map<String, Object?>> docs =
          <String, Map<String, Object?>>{
            'pending': _rawProfile(
              id: 'pending',
              status: 'pendingReview',
              withFlag: true,
            ),
          };

      expect(_discover(docs), isEmpty);
    });
  });

  group('(P29) البحث النصي «sh/Shady» مع ملف بلا accountHidden', () {
    /// يقلّد `_visible` في المستودع: دمج الصارم مع الواسع بالمعرّف، مع إسقاط
    /// الموسوم بالإخفاء — لا فرق بين «الاستعلام الأساسي» وأي مسار آخر.
    Future<List<MapEntry<String, Map<String, Object?>>>> merged(
      Map<String, Map<String, Object?>> docs,
    ) {
      return TeacherVisibilityFallback.resolveMerged<
        MapEntry<String, Map<String, Object?>>
      >(
        strict: () async => <MapEntry<String, Map<String, Object?>>>[
          for (final MapEntry<String, Map<String, Object?>> entry
              in docs.entries)
            if (entry.value['status'] == 'verified' &&
                entry.value['accountHidden'] == false)
              entry,
        ],
        broad: () async => <MapEntry<String, Map<String, Object?>>>[
          for (final MapEntry<String, Map<String, Object?>> entry
              in docs.entries)
            if (entry.value['status'] == 'verified') entry,
        ],
        idOf: (MapEntry<String, Map<String, Object?>> entry) => entry.key,
        isHidden: (MapEntry<String, Map<String, Object?>> entry) =>
            TeacherVisibilityFallback.isExplicitlyHidden(entry.value),
      );
    }

    TeacherProfile toProfile(MapEntry<String, Map<String, Object?> entry) {
      return TeacherProfile(
        id: entry.key,
        displayName: entry.value['displayName']! as String,
        subject: entry.value['subject']! as String,
        stage: entry.value['stage']! as String,
        area: entry.value['area']! as String,
        bio: entry.value['bio']! as String,
        status: TeacherProfileStatus.verified,
        governorate: entry.value['governorate'] as String?,
      );
    }

    test('ملف قديم باسم Shady يظهر مع وجود ملفات ظاهرة أخرى', () async {
      final Map<String, Map<String, Object?>> docs =
          <String, Map<String, Object?>>{
            'visible-1': <String, Object?>{
              ..._rawProfile(id: 'visible-1', displayName: 'أ. سارة الخطيب'),
              'accountHidden': false,
            },
            'shady': _rawProfile(id: 'shady', displayName: 'Shady Ali'),
            'hidden-9': _rawProfile(
              id: 'hidden-9',
              displayName: 'Shady Hidden',
              withFlag: true,
              hiddenValue: true,
            ),
          };

      final List<TeacherProfile> teachers = (await merged(
        docs,
      )).map(toProfile).toList();
      expect(
        teachers.map((TeacherProfile t) => t.id),
        <String>['visible-1', 'shady'],
        reason: 'المخفي لا يدخل، والقديم يدخل',
      );

      for (final String query in <String>['sh', 'Shady', 'shady']) {
        final TeacherSearchResult result = TeacherDiscoveryRules.search(
          teachers,
          TeacherFilter(query: query),
        );
        expect(
          result.teachers.map((TeacherProfile t) => t.id),
          <String>['shady'],
          reason: 'بحث «$query»',
        );
      }
    });

    test('بلا ملفات ظاهرة: القديم يظهر أيضًا (لا يشترط وجود ملف يحمل الحقل)', () async {
      final Map<String, Map<String, Object?>> docs =
          <String, Map<String, Object?>>{
            'shady': _rawProfile(id: 'shady', displayName: 'Shady Ali'),
          };

      final List<TeacherProfile> teachers = (await merged(
        docs,
      )).map(toProfile).toList();
      expect(teachers, hasLength(1));
      expect(teachers.single.id, 'shady');
    });
  });

  group('(P29) رسائل الفراغ لا تُخلط بالفشل', () {
    test('الفلتر المفعّل: رسالة «لا نتائج» تنسب الفراغ إلى الفلاتر لا إلى البيانات', () {
      final String message = TeacherDiscoveryRules.emptyMessage(
        const TeacherFilter(subject: 'الفيزياء'),
      );
      expect(message, contains('هذه الفلاتر'));
      expect(message, isNot(contains('وثّقت الإدارة')));
    });

    test('فلتر محافظة: الرسالة تذكر المحافظة نفسها كي يعرف المستخدم ما يغيّره', () {
      const TeacherFilter filter = TeacherFilter(governorate: 'الجيزة');
      expect(TeacherDiscoveryRules.emptyMessage(filter), contains('الجيزة'));
    });

    test('بلا فلتر: النص يشرح الشرط (ملف موثّق) ولا يدّعي خلو التطبيق', () {
      final String message = TeacherDiscoveryRules.emptyMessage(
        TeacherFilter.empty,
      );
      expect(message, contains('وثّقت'));
    });

    test('فشل التحميل: لا يُعرض «لا يوجد مدرسون» بل اعتراف بالجهل + إعادة محاولة', () {
      expect(
        TeacherDiscoveryRules.emptyTitle(dataFailed: true),
        isNot(contains('لا يوجد')),
      );
      expect(
        TeacherDiscoveryRules.emptyTitle(dataFailed: true),
        'تعذّر إكمال تحميل القائمة',
      );
      final String body = TeacherDiscoveryRules.emptyBody(
        dataFailed: true,
        filter: TeacherFilter.empty,
      );
      expect(body, isNot(contains('يظهر هنا كل مدرس')));
      expect(body, contains('أعد المحاولة'));
      expect(
        TeacherDiscoveryRules.emptyActionLabel(
          dataFailed: true,
          filter: TeacherFilter.empty,
        ),
        'إعادة المحاولة',
      );
    });

    test('الفراغ الحقيقي بلا فلتر: لا زر (لا إجراء يغيّر شيئًا)', () {
      expect(TeacherDiscoveryRules.emptyTitle(dataFailed: false), 'لا نتائج');
      expect(
        TeacherDiscoveryRules.emptyActionLabel(
          dataFailed: false,
          filter: TeacherFilter.empty,
        ),
        isNull,
      );
      expect(
        TeacherDiscoveryRules.emptyBody(
          dataFailed: false,
          filter: TeacherFilter.empty,
        ),
        TeacherDiscoveryRules.emptyMessage(TeacherFilter.empty),
      );
    });

    test('الفراغ الحقيقي مع فلتر مفعّل: الزر هو تفريغ الفلتر', () {
      expect(
        TeacherDiscoveryRules.emptyActionLabel(
          dataFailed: false,
          filter: const TeacherFilter(subject: 'الفيزياء'),
        ),
        'إعادة ضبط البحث',
      );
    });
  });
}
