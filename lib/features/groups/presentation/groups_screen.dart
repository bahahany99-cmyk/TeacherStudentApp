import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/error_state.dart';
import 'package:teacher_student_app/core/widgets/loading_state.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/data/models/favorite.dart';
import 'package:teacher_student_app/data/models/group_filter.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/discovery_rules.dart';
import 'package:teacher_student_app/features/favorites/presentation/favorite_star.dart';
import 'package:teacher_student_app/features/groups/presentation/group_discovery_controller.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/group_card.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/group_filter_bar.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/teacher_groups_section.dart';

/// صفحة المجموعات الدراسية — صفحة مستقلة (وليست قائمة داخل الرئيسية).
///
/// وضعان:
/// - `GroupsScreen.discover()`: استكشاف المجموعات بفلاتر (واجهة الطالب، P9).
/// - `GroupsScreen.forTeacher()`: إدارة مجموعات المدرس صاحب الجلسة.
///
/// (P23) أُزيل معامل `teacherId`: كان لا يُستخدم في أي شيء (القسم يقرأ معرّف
/// صاحب الجلسة بنفسه)، فبقاؤه كان يوهم بأن الشاشة تعرض مجموعات مدرس آخر.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen.discover({super.key}) : _isDiscover = true;

  const GroupsScreen.forTeacher({super.key}) : _isDiscover = false;

  final bool _isDiscover;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_isDiscover) ...<Widget>[
                const SectionHeader(
                  title: 'مجموعات متاحة',
                  subtitle: 'اختر المادة أو المرحلة لتضيق نتائجك',
                ),
                const _DiscoverBody(),
              ],
              // واجهة المدرس: قسم إدارة كامل (إنشاء + تعديل + إيقاف).
              // الزر الأساسي الوحيد للإنشاء يوفّره القسم نفسه.
              if (!_isDiscover) const TeacherGroupsSection(),
              const SizedBox(height: AppSpacing.md),
              Text(
                'السعة المتاحة محسوبة للعرض فقط. عند امتلاء المجموعة ينتقل '
                'الطلب إلى قائمة الانتظار تلقائيًا، ويُحجز المقعد عند القبول '
                'فقط.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }
}

/// جسم الاستكشاف: يحمل المتحكّم في حالته ويعرض الشريط والنتائج.
class _DiscoverBody extends StatefulWidget {
  const _DiscoverBody();

  @override
  State<_DiscoverBody> createState() => _DiscoverBodyState();
}

class _DiscoverBodyState extends State<_DiscoverBody> {
  GroupDiscoveryController? _controller;

  /// خيارات الفلاتر تُشتق من **كل** المجموعات المنشورة لا من النتائج المفلترة،
  /// وإلا اختفت الخيارات بعد أول نقرة ولم يستطع المستخدم التراجع.
  List<StudyGroup> _universe = const <StudyGroup>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final controller = GroupDiscoveryController(
        repository: AppServicesScope.of(context).groups,
      );
      _controller = controller;
      controller.addListener(_onControllerChanged);
      controller.load();
      _loadUniverse();
    }
  }

  Future<void> _loadUniverse() async {
    final List<StudyGroup> groups = await AppServicesScope.of(
      context,
    ).groups.listDiscoverable();
    if (!mounted) {
      return;
    }
    setState(() => _universe = groups);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GroupDiscoveryController controller = _controller!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GroupFilterBar(
          filter: controller.filter,
          subjectOptions: DiscoveryRules.subjectOptions(_universe),
          stageOptions: DiscoveryRules.stageOptions(_universe),
          resultLabel: controller.isLoading
              ? '…'
              : '${controller.groups.length} من ${controller.total}',
          onChanged: controller.applyFilter,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (controller.isLoading)
          const LoadingState()
        else if (controller.error != null)
          ErrorState(error: controller.error!, onRetry: controller.load)
        else if (controller.groups.isEmpty)
          EmptyState(
            icon: Icons.search_off,
            title: 'لا نتائج',
            message: DiscoveryRules.emptyMessage(controller.filter),
            actionLabel: controller.filter.isActive ? 'تفريغ الفلاتر' : null,
            onActionTap: controller.filter.isActive ? controller.reset : null,
          )
        else ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  DiscoveryRules.resultsLine(
                    GroupSearchResult(
                      groups: controller.groups,
                      total: controller.total,
                    ),
                  ),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          for (final StudyGroup group in controller.groups)
            GroupCard(
              group: group,
              // المفضلة للطالب (P13): الشاشة استكشاف، فلا حاجة لفحص الدور هنا.
              favoriteAction: FavoriteStar(
                kind: FavoriteKind.group,
                targetId: group.id,
              ),
              onTap: () => Navigator.of(context).pushNamed(
                RoutePaths.groupDetails,
                arguments: group.id,
              ),
            ),
          if (controller.filter.availability == GroupAvailability.full) ...[
            const SizedBox(height: AppSpacing.xs),
            AppCard(
              child: Text(
                'المجموعات المكتملة تقبل الانضمام إلى قائمة انتظار، ويقبلها '
                'المدرس عندما يتحرر مقعد.',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
