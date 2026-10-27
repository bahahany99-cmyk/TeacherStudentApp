import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/group_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';

/// صفحة المجموعات الدراسية — صفحة مستقلة (وليست قائمة داخل الرئيسية).
///
/// وضعان:
/// - `GroupsScreen.discover()`: استكشاف المجموعات (واجهة الطالب).
/// - `GroupsScreen.forTeacher(teacherId: …)`: مجموعات مدرس محدّد.
///
/// إنشاء المجموعات وإدارة الأعضاء وطلبات الانضمام خارج نطاق هذه المرحلة.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen.discover({super.key})
    : teacherId = null,
      _isDiscover = true;

  const GroupsScreen.forTeacher({super.key, required this.teacherId})
    : _isDiscover = false;

  final String? teacherId;
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
              const DemoBanner(),
              SectionHeader(
                title: _isDiscover ? 'مجموعات متاحة' : 'مجموعاتي',
                subtitle: _isDiscover
                    ? 'طلب الانضمام يحتاج موافقة المدرس (C-09)'
                    : 'السعة والموافقات تُفرض على الخادم',
              ),
              AsyncView<List<StudyGroup>>(
                load: () => _isDiscover
                    ? AppServicesScope.of(context).groups.listDiscoverable()
                    : AppServicesScope.of(
                        context,
                      ).groups.listForTeacher(teacherId ?? ''),
                builder: (BuildContext context, List<StudyGroup> groups) {
                  if (groups.isEmpty) {
                    return EmptyState(
                      icon: Icons.groups_outlined,
                      title: _isDiscover
                          ? 'لا توجد مجموعات متاحة الآن'
                          : 'لم تُنشأ مجموعات بعد',
                      message: 'إنشاء المجموعات وإدارة الأعضاء قيد التنفيذ لاحقًا.',
                    );
                  }
                  return Column(
                    children: groups
                        .map(
                          (StudyGroup g) => GroupCard(
                            group: g,
                            onTap: () => Navigator.of(context).pushNamed(
                              RoutePaths.groupDetails,
                              arguments: g.id,
                            ),
                            // واجهة المدرس لا تطلب الانضمام لمجموعته.
                            onJoinTap: _isDiscover
                                ? () => _showComingSoon(context)
                                : null,
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'السعة المتاحة محسوبة للعرض فقط. منع تجاوز السعة يتم بعملية '
                'ذرية على الخادم عند قبول طلب الانضمام (Phase 8).',
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

  void _showComingSoon(BuildContext context) {
    AppSnackBar.show(context, AppStrings.comingSoon);
  }
}
