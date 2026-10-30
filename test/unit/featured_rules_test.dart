import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/validation/featured_rules.dart';

/// مدرس موثّق بمعرّف وحالة حضور محدّدين.
TeacherProfile _teacher(
  String id, {
  required bool online,
  bool featured = false,
  TeacherProfileStatus status = TeacherProfileStatus.verified,
}) {
  return TeacherProfile(
    id: id,
    displayName: 'مدرس $id',
    subject: 'الرياضيات',
    stage: 'الثانوية العامة',
    area: 'القاهرة',
    bio: 'نبذة',
    status: status,
    isOnline: online,
    isFeatured: featured,
  );
}

/// 12 ملفًا: 6 أونلاين و6 أوفلاين (يكفي لملء عشر بطاقات).
List<TeacherProfile> _pool() => <TeacherProfile>[
  for (int i = 0; i < 6; i++) _teacher('on-$i', online: true),
  for (int i = 0; i < 6; i++) _teacher('off-$i', online: false),
];

void main() {
  final DateTime week1 = DateTime.utc(2026, 10, 20, 12);

  group('P25 — اختيار المدرسين المميزين الأسبوعي', () {
    test('خمس بطاقات أونلاين وخمس أوفلاين بالضبط', () {
      final FeaturedSelection selection = FeaturedRules.selectWeekly(
        _pool(),
        now: week1,
      );

      expect(selection.online, hasLength(FeaturedRules.slotsPerSegment));
      expect(selection.offline, hasLength(FeaturedRules.slotsPerSegment));
      expect(selection.visibleCount, FeaturedRules.totalSlots);
      expect(
        selection.online.every((TeacherProfile t) => t.isOnline),
        isTrue,
        reason: 'الشريحة الأولى أونلاين فقط',
      );
      expect(
        selection.offline.every((TeacherProfile t) => !t.isOnline),
        isTrue,
        reason: 'الشريحة الثانية أوفلاين فقط',
      );
    });

    test('القوائم الكاملة تُعاد بلا قصّ لصفحة «عرض الكل»', () {
      final FeaturedSelection selection = FeaturedRules.selectWeekly(
        _pool(),
        now: week1,
      );
      expect(selection.allOnline, hasLength(6));
      expect(selection.allOffline, hasLength(6));
    });

    test('الاختيار ثابت داخل الأسبوع نفسه (لا قفز بين إعادة البناء)', () {
      final FeaturedSelection first = FeaturedRules.selectWeekly(
        _pool(),
        now: week1,
      );
      final FeaturedSelection second = FeaturedRules.selectWeekly(
        _pool(),
        now: week1.add(const Duration(days: 3)),
      );

      expect(
        second.online.map((TeacherProfile t) => t.id),
        first.online.map((TeacherProfile t) => t.id),
      );
      expect(second.weekIndex, first.weekIndex);
    });

    test('الأسبوع التالي يغيّر الترشيح على الأقل في أسبوع من أربعة', () {
      final List<String> baseline = FeaturedRules.selectWeekly(
        _pool(),
        now: week1,
      ).online.map((TeacherProfile t) => t.id).toList();

      final bool changed = <int>[1, 2, 3, 4].any((int offset) {
        final List<String> other = FeaturedRules.selectWeekly(
          _pool(),
          now: week1.add(Duration(days: 7 * offset)),
        ).online.map((TeacherProfile t) => t.id).toList();
        return !_sameOrder(baseline, other);
      });

      expect(changed, isTrue, reason: 'الدوران الأسبوعي يجب أن يُغيّر القائمة');
    });

    test('المميّز إداريًا يتقدّم على غيره', () {
      final List<TeacherProfile> pool = <TeacherProfile>[
        ..._pool(),
        _teacher('featured-1', online: true, featured: true),
      ];

      final FeaturedSelection selection = FeaturedRules.selectWeekly(
        pool,
        now: week1,
      );
      expect(selection.allOnline.first.id, 'featured-1');
    });

    test('الملفات غير الموثّقة أو المخفية لا تُرشَّح', () {
      final List<TeacherProfile> pool = <TeacherProfile>[
        _teacher('draft', online: true, status: TeacherProfileStatus.draft),
        _teacher(
          'pending',
          online: true,
          status: TeacherProfileStatus.pendingReview,
        ),
        _teacher('ok', online: false),
      ];

      final FeaturedSelection selection = FeaturedRules.selectWeekly(
        pool,
        now: week1,
      );
      expect(selection.allOnline, isEmpty);
      expect(selection.allOffline.map((TeacherProfile t) => t.id), <String>['ok']);
    });

    test('مجموعة أقل من خمسة لا تُنتج بطاقات وهمية', () {
      final FeaturedSelection selection = FeaturedRules.selectWeekly(
        <TeacherProfile>[_teacher('only', online: true)],
        now: week1,
      );
      expect(selection.online, hasLength(1));
      expect(selection.offline, isEmpty);
    });
  });
}

bool _sameOrder(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
