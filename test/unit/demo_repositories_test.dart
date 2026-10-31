import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/config/firebase_bootstrap.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';

void main() {
  group('DemoTeacherRepository', () {
    test('يعيد الملفات المعتمدة فقط', () async {
      final DemoTeacherRepository repository = DemoTeacherRepository();
      final List<TeacherProfile> teachers = await repository.listVerified();

      expect(teachers, isNotEmpty);
      expect(
        teachers.every(
          (TeacherProfile t) => t.status == TeacherProfileStatus.verified,
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
              t.isFeatured && t.status == TeacherProfileStatus.verified,
        ),
        isTrue,
      );
    });
  });

  group('البحث بالمعرّف (P3)', () {
    test('ملف مدرس معتمد يُعاد، وغير المعتمد لا يُكشف', () async {
      final DemoTeacherRepository repository = DemoTeacherRepository();

      final TeacherProfile? verified = await repository.findById(
        'demo-teacher-1',
      );
      final TeacherProfile? pending = await repository.findById(
        'demo-teacher-6-review',
      );
      final TeacherProfile? missing = await repository.findById('غير-موجود');

      expect(verified?.displayName, 'أ. سارة الخطيب');
      expect(pending, isNull, reason: 'الملف قيد المراجعة لا يظهر للطلاب');
      expect(missing, isNull);
    });

    test('مجموعة معروفة تُعاد وغير المعروفة null', () async {
      final DemoGroupRepository repository = DemoGroupRepository();

      final StudyGroup? group = await repository.findById('demo-group-1');
      final StudyGroup? missing = await repository.findById('غير-موجود');

      expect(group?.title, 'مجموعة الرياضيات — التفاضل');
      expect(missing, isNull);
    });

    test('طلب معروف يُعاد وغير المعروف null', () async {
      final DemoBookingRepository repository = DemoBookingRepository();

      final BookingRequest? booking = await repository.findById(
        'demo-booking-1',
      );

      expect(booking?.status, BookingStatus.pending);
      expect(await repository.findById('غير-موجود'), isNull);
    });

    test('عدد الأعضاء يطابق المقاعد المشغولة', () async {
      final DemoGroupRepository repository = DemoGroupRepository();
      final List<StudyGroup> groups = await repository.listDiscoverable();

      for (final StudyGroup group in groups) {
        final List<GroupMember> members = await repository.listMembers(group.id);
        expect(
          members.length,
          group.seatsTaken,
          reason: 'شاشة الأعضاء يجب أن تطابق عدد المقاعد في ${group.title}',
        );
        expect(
          members.every(
            (GroupMember member) =>
                member.status == GroupMemberStatus.active,
          ),
          isTrue,
        );
      }

      expect(await repository.listMembers('غير-موجود'), isEmpty);
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
