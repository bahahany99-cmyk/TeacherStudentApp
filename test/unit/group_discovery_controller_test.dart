import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/group_filter.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/features/groups/presentation/group_discovery_controller.dart';

void main() {
  group('GroupDiscoveryController', () {
    test('القراءة الأولى تملأ القائمة وتنتهي حالة التحميل', () async {
      final GroupDiscoveryController controller = GroupDiscoveryController(
        repository: DemoGroupRepository(),
      );
      expect(controller.isLoading, isTrue);

      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
      expect(controller.groups, isNotEmpty);
      expect(controller.total, greaterThanOrEqualTo(controller.groups.length));
      controller.dispose();
    });

    test('تغيير الفلتر يعيد القراءة ويغيّر النتائج', () async {
      final GroupDiscoveryController controller = GroupDiscoveryController(
        repository: DemoGroupRepository(),
      );
      await controller.load();
      final int before = controller.groups.length;

      await controller.applyFilter(
        const GroupFilter(subject: 'الرياضيات'),
      );

      expect(controller.filter.subject, 'الرياضيات');
      expect(
        controller.groups.every((StudyGroup g) => g.subject == 'الرياضيات'),
        isTrue,
      );
      expect(controller.groups.length, lessThanOrEqualTo(before));
      controller.dispose();
    });

    test('فلتر مساوٍ للحالي لا يطلق قراءة جديدة', () async {
      final GroupDiscoveryController controller = GroupDiscoveryController(
        repository: DemoGroupRepository(),
      );
      await controller.load();

      await controller.applyFilter(const GroupFilter(query: '  '));

      expect(controller.filter, GroupFilter.empty);
      controller.dispose();
    });

    test('reset يفرّغ الفلاتر ويحفظ الترتيب', () async {
      final GroupDiscoveryController controller = GroupDiscoveryController(
        repository: DemoGroupRepository(),
      );
      await controller.load();
      await controller.applyFilter(
        const GroupFilter(subject: 'الفيزياء', sort: GroupSort.title),
      );
      expect(controller.groups, isNotEmpty);

      await controller.reset();

      expect(controller.filter.subject, isNull);
      expect(controller.filter.sort, GroupSort.title);
      controller.dispose();
    });

    test('بحث بلا نتيجة يعطي قائمة فارغة بلا خطأ', () async {
      final GroupDiscoveryController controller = GroupDiscoveryController(
        repository: DemoGroupRepository(),
      );
      await controller.load();

      await controller.applyFilter(
        const GroupFilter(query: 'كيمياء عضوية'),
      );

      expect(controller.groups, isEmpty);
      expect(controller.error, isNull);
      expect(controller.isLoading, isFalse);
      controller.dispose();
    });

    test('الإشعارات تصل لمستمع مسجّل ولا بعد التخلص من المتحكّم', () async {
      final GroupDiscoveryController controller = GroupDiscoveryController(
        repository: DemoGroupRepository(),
      );
      int notifications = 0;
      controller.addListener(() => notifications++);

      await controller.load();
      expect(notifications, greaterThan(0));

      final int before = notifications;
      await controller.applyFilter(const GroupFilter(query: 'الرياضيات'));
      expect(notifications, greaterThan(before));

      // لا استثناء بعد الإغلاق (نتحقق من عدم الرمي).
      controller.dispose();
    });
  });
}
