import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/data/models/teacher_filter.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/teacher_discovery_rules.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/featured_teachers_carousel.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_card.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_filter_bar.dart';

/// صفحة استعراض المدرسين (P15): شريط مميزين + بحث وفلاتر تعمل فعلًا.
///
/// ما تُطبّقه الشاشة وما لا:
/// - **المستودع** يقرأ الموثّقين فقط، ويطبّق شرط «عن بُعد/حضوري» والمحافظة في
///   الاستعلام (`TeacherRepository.search`).
/// - **الشاشة** تعرض، وتترك النص والمادة والترتيب لقواعد نقيّة في
///   `TeacherDiscoveryRules`، فلا منطق فلترة مكتوب في الودجت.
class TeachersScreen extends StatefulWidget {
  const TeachersScreen({super.key});

  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends State<TeachersScreen> {
  TeacherFilter _filter = TeacherFilter.empty;

  /// كل الموثّقين — تُشتق منها خيارات الفلاتر (لا خيارات نظرية).
  List<TeacherProfile> _universe = const <TeacherProfile>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_universe.isEmpty) {
      _loadUniverse();
    }
  }

  Future<void> _loadUniverse() async {
    final AppServices services = AppServicesScope.of(context);
    try {
      final List<TeacherProfile> teachers = await services.teachers
          .listVerified();
      if (mounted) {
        setState(() => _universe = teachers);
      }
    } catch (_) {
      // (P16) لا نُفشل الشاشة بسبب خيارات الفلترة: البحث نفسه يعرض خطأه.
      // والالتقاط عام: خطأ غير متوقع في هذا التحميل الثانوي لا يجوز أن يصل
      // كاستثناء غير معالَج ويسقط الشاشة.
      _universe = const <TeacherProfile>[];
    }
  }

  void _openProfile(TeacherProfile teacher) {
    Navigator.of(context).pushNamed(
      RoutePaths.teacherProfile,
      arguments: teacher.id,
    );
  }

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
              const SectionHeader(
                title: 'مدرسون مميزون',
                subtitle: 'يُدار التمييز من الإدارة فقط',
              ),
              AsyncView<List<TeacherProfile>>(
                load: () => AppServicesScope.of(context).teachers.listFeatured(),
                builder:
                    (BuildContext context, List<TeacherProfile> featured) {
                      if (featured.isEmpty) {
                        return const EmptyState(
                          icon: Icons.workspace_premium_outlined,
                          title: 'لا يوجد مدرسون مميزون حاليًا',
                        );
                      }
                      return FeaturedTeachersCarousel(
                        teachers: featured,
                        onTeacherTap: _openProfile,
                      );
                    },
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const SectionHeader(
                title: 'كل المدرسين',
                subtitle: 'الملفات الموثّقة فقط',
              ),
              TeacherFilterBar(
                filter: _filter,
                governorates: TeacherDiscoveryRules.governorateOptions(
                  _universe,
                ),
                resultLabel: _filter.isActive
                    ? 'نتائج مفلترة'
                    : 'اعرض الكل أو اختر طريقة تقديم',
                onChanged: (TeacherFilter next) {
                  setState(() => _filter = next);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AsyncView<TeacherSearchResult>(
                key: ValueKey<TeacherFilter>(_filter),
                load: () =>
                    AppServicesScope.of(context).teachers.search(_filter),
                isEmpty: (TeacherSearchResult result) => result.isEmpty,
                emptyBuilder: (BuildContext context) => EmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'لا نتائج',
                  message: TeacherDiscoveryRules.emptyMessage(_filter),
                ),
                builder:
                    (BuildContext context, TeacherSearchResult result) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            TeacherDiscoveryRules.resultsLine(result),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          for (final TeacherProfile teacher
                              in result.teachers)
                            TeacherCard(
                              teacher: teacher,
                              onTap: () => _openProfile(teacher),
                            ),
                        ],
                      );
                    },
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }
}
