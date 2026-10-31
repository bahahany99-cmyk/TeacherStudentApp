import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/teacher_filter.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/validation/teacher_discovery_rules.dart';

/// ملف مدرس للاختبار — كل حقل اختياري له قيمة صريحة، فلا يعتمد الاختبار على
/// ترتيب معاملات ولا على قيم افتراضية خفية.
TeacherProfile _teacher({
  required String id,
  String name = 'أ. مدرس',
  String subject = 'الرياضيات',
  String stage = 'الثانوية العامة',
  String area = 'القاهرة',
  bool online = false,
  String? governorate,
  String? district,
  bool featured = false,
  int featuredOrder = 0,
  TeacherProfileStatus status = TeacherProfileStatus.verified,
  double rating = 4,
  int reviews = 10,
}) {
  return TeacherProfile(
    id: id,
    displayName: name,
    subject: subject,
    stage: stage,
    area: area,
    bio: 'نبذة',
    status: status,
    isOnline: online,
    governorate: governorate,
    district: district,
    isFeatured: featured,
    featuredOrder: featuredOrder,
    rating: rating,
    reviewsCount: reviews,
  );
}

void main() {
  group('TeacherFilter (P15)', () {
    test('الفلتر المحايد غير نشط', () {
      expect(TeacherFilter.empty.isActive, isFalse);
      expect(TeacherFilter.empty.activeCount, 0);
      expect(TeacherFilter.empty.delivery, TeacherDeliveryFilter.any);
    });

    test('كل خيار يزيد العدّاد، والتفريغ يمسح الكل ويحفظ الترتيب', () {
      const TeacherFilter filter = TeacherFilter(
        query: 'رياضيات',
        subject: 'الرياضيات',
        stage: 'الثانوية العامة',
        governorate: 'القاهرة',
        delivery: TeacherDeliveryFilter.inPerson,
        sort: TeacherSort.name,
      );

      expect(filter.isActive, isTrue);
      expect(filter.activeCount, 5);
      expect(filter.cleared(), const TeacherFilter(sort: TeacherSort.name));
    });

    test('copyWith يفرّق بين «اتركه» و«احذفه»', () {
      const TeacherFilter base = TeacherFilter(governorate: 'أسيوط');

      expect(base.copyWith(delivery: TeacherDeliveryFilter.online).governorate, 'أسيوط');
      expect(base.copyWith(governorate: null).governorate, isNull);
    });

    test('المساواة تتجاهل فروق المسافات في نص البحث فقط', () {
      expect(
        const TeacherFilter(query: ' أحمد '),
        const TeacherFilter(query: 'أحمد'),
      );
      expect(
        const TeacherFilter(query: 'أحمد'),
        isNot(const TeacherFilter(query: 'أحمد', subject: 'الفيزياء')),
      );
    });

    test('«حضوري بمحافظة» يوسم الفلتر بأنه محصور مكانيًا', () {
      expect(TeacherFilter.empty.isInPersonScoped, isFalse);
      expect(
        const TeacherFilter(governorate: 'القاهرة').isInPersonScoped,
        isTrue,
      );
      expect(
        const TeacherFilter(
          delivery: TeacherDeliveryFilter.inPerson,
        ).isInPersonScoped,
        isTrue,
      );
    });
  });

  group('قواعد الاستكشاف (P15)', () {
    final List<TeacherProfile> source = <TeacherProfile>[
      _teacher(
        id: 'online-1',
        name: 'أ. منى',
        online: true,
        rating: 4.6,
        reviews: 60,
      ),
      _teacher(
        id: 'offline-cairo',
        name: 'أ. سارة',
        governorate: 'القاهرة',
        district: 'المعادي',
        rating: 4.8,
        reviews: 120,
      ),
      _teacher(
        id: 'offline-asyut',
        name: 'أ. أحمد',
        subject: 'الفيزياء',
        stage: 'الإعدادية',
        governorate: 'أسيوط',
        district: 'أسيوط',
        rating: 4.5,
        reviews: 40,
      ),
      _teacher(
        id: 'pending',
        name: 'أ. خالد',
        status: TeacherProfileStatus.pendingReview,
        governorate: 'القاهرة',
      ),
      _teacher(
        id: 'rejected',
        name: 'أ. عمرو',
        status: TeacherProfileStatus.rejected,
        online: true,
      ),
    ];

    test('الملفات غير الموثّقة لا تظهر ولا تُحسب في الإجمالي', () {
      final TeacherSearchResult result = TeacherDiscoveryRules.search(
        source,
        TeacherFilter.empty,
      );

      expect(result.total, 3);
      expect(
        result.teachers.map((TeacherProfile t) => t.id),
        isNot(contains('pending')),
      );
      expect(
        result.teachers.map((TeacherProfile t) => t.id),
        isNot(contains('rejected')),
      );
    });

    test('«عن بُعد» يعيد المتاحين عن بُعد فقط', () {
      final TeacherSearchResult result = TeacherDiscoveryRules.search(
        source,
        const TeacherFilter(delivery: TeacherDeliveryFilter.online),
      );

      expect(result.teachers.map((TeacherProfile t) => t.id), <String>['online-1']);
      expect(result.total, 1);
    });

    test('«حضوري فقط» يستبعد من يقبل الحصص عن بُعد', () {
      final TeacherSearchResult result = TeacherDiscoveryRules.search(
        source,
        const TeacherFilter(delivery: TeacherDeliveryFilter.inPerson),
      );

      expect(
        result.teachers.map((TeacherProfile t) => t.id),
        <String>['offline-cairo', 'offline-asyut'],
      );
      expect(result.total, 2);
    });

    test('فلتر المحافظة يعيد أهلها فقط، والإجمالي بعد شروط الخادم', () {
      final TeacherSearchResult result = TeacherDiscoveryRules.search(
        source,
        const TeacherFilter(governorate: 'القاهرة'),
      );

      expect(result.teachers.map((TeacherProfile t) => t.id), <String>['offline-cairo']);
      // الإجمالي = ما يمرّ بشروط الخادم (محافظة القاهرة) لا كل الموثّقين.
      expect(result.total, 1);
    });

    test('البحث النصي يتجاوز شكل الهمزة ويطابق المادة والمكان', () {
      final TeacherSearchResult byName = TeacherDiscoveryRules.search(
        source,
        const TeacherFilter(query: 'احمد'),
      );
      expect(byName.teachers.map((TeacherProfile t) => t.id), <String>['offline-asyut']);
      // الإجمالي يبقى كل الموثّقين: النص فلتر عميل.
      expect(byName.total, 3);

      final TeacherSearchResult byPlace = TeacherDiscoveryRules.search(
        source,
        const TeacherFilter(query: 'المعادي'),
      );
      expect(byPlace.teachers.map((TeacherProfile t) => t.id), <String>['offline-cairo']);

      final TeacherSearchResult bySubject = TeacherDiscoveryRules.search(
        source,
        const TeacherFilter(subject: 'الفيزياء'),
      );
      expect(bySubject.teachers.map((TeacherProfile t) => t.id), <String>['offline-asyut']);
    });

    test('الترتيب: الأنسب بالتقييم، ثم الاسم أبجديًا', () {
      final TeacherSearchResult recommended = TeacherDiscoveryRules.search(
        source,
        TeacherFilter.empty,
      );
      expect(
        recommended.teachers.map((TeacherProfile t) => t.id),
        <String>['offline-cairo', 'online-1', 'offline-asyut'],
      );

      final TeacherSearchResult byName = TeacherDiscoveryRules.search(
        source,
        const TeacherFilter(sort: TeacherSort.name),
      );
      expect(
        byName.teachers.map((TeacherProfile t) => t.id),
        <String>['offline-asyut', 'offline-cairo', 'online-1'],
      );
    });

    test('الشريط المميز: الموثّق المميز فقط بترتيب حتمي', () {
      final List<TeacherProfile> featured = TeacherDiscoveryRules.featured(
        <TeacherProfile>[
          _teacher(id: 'b', name: 'ب', featured: true, featuredOrder: 2, rating: 5),
          _teacher(id: 'a', name: 'أ', featured: true, featuredOrder: 1, rating: 3),
          _teacher(id: 'c', name: 'ج', featured: true, featuredOrder: 0, rating: 2),
          // ترتيب 0 مثل «ج»، لكن تقييمه أقل ⇒ يظهر بعده.
          _teacher(id: 'd', name: 'د', featured: true, rating: 1),
          _teacher(
            id: 'draft',
            name: 'مسودة',
            featured: true,
            status: TeacherProfileStatus.pendingReview,
          ),
          _teacher(id: 'plain', name: 'عادي'),
        ],
      );

      // ترتيب 0 أولًا: «ج» و«د» (والتعادل بالتقييم: ج 2 ثم د 1)، ثم 1 (أ)،
      // ثم 2 (ب).
      expect(
        featured.map((TeacherProfile t) => t.id),
        <String>['c', 'd', 'a', 'b'],
      );
    });

    test('خيارات المحافظات والمواد تُشتق من البيانات الفعلية', () {
      expect(
        TeacherDiscoveryRules.governorateOptions(source),
        <String>['أسيوط', 'القاهرة'],
      );
      expect(
        TeacherDiscoveryRules.subjectOptions(source),
        <String>['الرياضيات', 'الفيزياء'],
      );
    });

    test('سطر النتائج ورسالة الفراغ تشرحان الحالة', () {
      final TeacherSearchResult filtered = TeacherDiscoveryRules.search(
        source,
        const TeacherFilter(query: 'لا يوجد'),
      );

      expect(filtered.isEmpty, isTrue);
      expect(
        TeacherDiscoveryRules.resultsLine(
          TeacherDiscoveryRules.search(source, TeacherFilter.empty),
        ),
        '3 مدرسًا',
      );
      expect(TeacherDiscoveryRules.resultsLine(filtered), '0 من 3 مدرسًا');
      expect(
        TeacherDiscoveryRules.emptyMessage(
          const TeacherFilter(governorate: 'المنيا'),
        ),
        contains('المنيا'),
      );
    });
  });

  group('المستودع التجريبي (P15)', () {
    test('الاستكشاف يقرأ البيانات التجريبية نفسها', () async {
      final DemoTeacherRepository repository = DemoTeacherRepository();

      final TeacherSearchResult all = await repository.search(
        TeacherFilter.empty,
      );
      expect(all.total, 5);
      expect(all.teachers.first.id, 'demo-teacher-1'); // الأعلى تقييمًا

      final TeacherSearchResult online = await repository.search(
        const TeacherFilter(delivery: TeacherDeliveryFilter.online),
      );
      expect(online.total, 2);
      expect(
        online.teachers.map((TeacherProfile t) => t.id),
        <String>['demo-teacher-3', 'demo-teacher-5'],
      );
    });

    test('فلتر المحافظة يعيد مدرسها الحضوري فقط', () async {
      final DemoTeacherRepository repository = DemoTeacherRepository();

      final TeacherSearchResult cairo = await repository.search(
        const TeacherFilter(governorate: 'القاهرة'),
      );
      expect(cairo.teachers.map((TeacherProfile t) => t.id), <String>['demo-teacher-1']);

      final TeacherSearchResult none = await repository.search(
        const TeacherFilter(governorate: 'المنيا'),
      );
      expect(none.isEmpty, isTrue);
      expect(none.total, 0);
    });

    test('شريط المميزين مرتّب بترتيب الإدارة', () async {
      final DemoTeacherRepository repository = DemoTeacherRepository();

      final List<TeacherProfile> featured = await repository.listFeatured();
      expect(
        featured.map((TeacherProfile t) => t.id),
        <String>['demo-teacher-1', 'demo-teacher-2'],
      );
    });
  });

  group('المدرس المخفي بحذف الحساب (P17)', () {
    const TeacherProfile hidden = TeacherProfile(
      id: 'hidden-1',
      displayName: 'أ. سارة المخفية',
      subject: 'الرياضيات',
      stage: 'الثانوية العامة',
      area: 'المعادي',
      bio: 'نبذة',
      status: TeacherProfileStatus.verified,
      isFeatured: true,
      featuredOrder: 0,
      isOnline: true,
      isAccountHidden: true,
    );

    const TeacherProfile visible = TeacherProfile(
      id: 'visible-1',
      displayName: 'أ. سارة الظاهرة',
      subject: 'الرياضيات',
      stage: 'الثانوية العامة',
      area: 'المعادي',
      bio: 'نبذة',
      status: TeacherProfileStatus.verified,
      isFeatured: true,
      featuredOrder: 1,
      isOnline: true,
    );

    test('موثّق لكنه مخفي: لا بحث ولا شريط مميزين', () {
      final List<TeacherProfile> source = <TeacherProfile>[hidden, visible];

      final TeacherSearchResult result = TeacherDiscoveryRules.search(
        source,
        TeacherFilter.empty,
      );
      expect(
        result.teachers.map((TeacherProfile t) => t.id),
        <String>['visible-1'],
      );
      expect(result.total, 1);
      expect(
        TeacherDiscoveryRules.featured(source).map((TeacherProfile t) => t.id),
        <String>['visible-1'],
      );
    });

    test('المستودع التجريبي يسقطه من كل قوائم الاكتشاف', () async {
      final DemoTeacherRepository repository = DemoTeacherRepository(
        source: <TeacherProfile>[hidden, visible],
      );

      expect(
        (await repository.listVerified()).map((TeacherProfile t) => t.id),
        <String>['visible-1'],
      );
      expect(
        (await repository.listFeatured()).map((TeacherProfile t) => t.id),
        <String>['visible-1'],
      );
      expect((await repository.search(TeacherFilter.empty)).total, 1);
      expect(await repository.findById('hidden-1'), isNull);
      expect(await repository.findById('visible-1'), isNotNull);
    });
  });
}
