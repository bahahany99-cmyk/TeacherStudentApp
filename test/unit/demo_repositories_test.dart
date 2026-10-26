import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/config/firebase_bootstrap.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';

void main() {
  group('DemoTeacherRepository', () {
    test('يعيد الملفات المعتمدة فقط', () async {
      final DemoTeacherRepository repository = DemoTeacherRepository();
      final List<TeacherProfile> teachers = await repository.listApproved();

      expect(teachers, isNotEmpty);
      expect(
        teachers.every(
          (TeacherProfile t) => t.status == TeacherProfileStatus.approved,
        ),
        isTrue,
        reason: 'ملف قيد المراجعة يجب ألا يظهر في قائمة المدرسين',
      );
      expect(
        teachers.any((TeacherProfile t) => t.id == 'demo-teacher-6-review'),
        isFalse,
      );
    });

    test('قسم المميزين مجموعة فرعية من المعتمدين', () async {
      final DemoTeacherRepository repository = DemoTeacherRepository();
      final List<TeacherProfile> featured = await repository.listFeatured();

      expect(featured, isNotEmpty);
      expect(
        featured.every(
          (TeacherProfile t) =>
              t.isFeatured && t.status == TeacherProfileStatus.approved,
        ),
        isTrue,
      );
    });
  });

  group('DemoGroupRepository', () {
    test('تصفية مجموعات مدرس واحد', () async {
      final DemoGroupRepository repository = DemoGroupRepository();
      final groups = await repository.listForTeacher('demo-teacher-1');

      expect(groups, isNotEmpty);
      expect(groups.every((g) => g.teacherId == 'demo-teacher-1'), isTrue);
    });

    test('المقاعد المتاحة لا تقل عن صفر', () async {
      final DemoGroupRepository repository = DemoGroupRepository();
      final groups = await repository.listDiscoverable();

      expect(groups.every((g) => g.seatsAvailable >= 0), isTrue);
      expect(
        groups.any((g) => g.isFull),
        isTrue,
        reason: 'بيانات تجريبية تشمل مجموعة مكتملة لاختبار العرض',
      );
    });
  });

  test('Firebase غير مهيأ افتراضيًا في هذه المرحلة', () {
    expect(FirebaseBootstrap.status, FirebaseStatus.disabled);
  });
}
