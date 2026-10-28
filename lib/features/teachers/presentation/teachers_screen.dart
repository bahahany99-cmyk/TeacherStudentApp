import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_card.dart';

/// صفحة استعراض المدرسين (بنية عرض فقط).
///
/// - البحث والفلاتر غير مفعّلة (Phase 6).
/// - قسم المميزين منفصل عن قائمة كل المدرسين.
/// - المستودع يعرض الملفات المعتمدة فقط، تأكيدًا لمبدأ C-06 على مستوى الواجهة
///   (والفرض الحقيقي سيكون في قواعد Firestore).
class TeachersScreen extends StatelessWidget {
  const TeachersScreen({super.key});

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
              TextField(
                enabled: false,
                decoration: const InputDecoration(
                  hintText: 'ابحث باسم المدرس أو المادة (Phase 6)',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // صف فلاتر أفقي (نسخة 3): شرائح «حبة دواء» تُمرَّر أفقيًا ولا
              // تلتف إلى صفوف — مطابق للمرجع. الفلاتر نفسها غير مفعّلة بعد.
              PillRow(
                children: const <Widget>[
                  PillChip(label: 'المادة', icon: Icons.expand_more),
                  PillChip(label: 'المرحلة الدراسية', icon: Icons.expand_more),
                  PillChip(label: 'المنطقة', icon: Icons.expand_more),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const SectionHeader(
                title: 'مدرسون مميزون',
                subtitle: 'يُدار التمييز من الإدارة فقط',
              ),
              AsyncView<List<TeacherProfile>>(
                load: () => AppServicesScope.of(context).teachers.listFeatured(),
                builder: (BuildContext context, List<TeacherProfile> teachers) {
                  if (teachers.isEmpty) {
                    return const EmptyState(
                      icon: Icons.workspace_premium_outlined,
                      title: 'لا يوجد مدرسون مميزون حاليًا',
                    );
                  }
                  return Column(
                    children: teachers
                        .map(
                          (TeacherProfile t) => TeacherCard(
                            teacher: t,
                            onTap: () => Navigator.of(context).pushNamed(
                              RoutePaths.teacherProfile,
                              arguments: t.id,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const SectionHeader(
                title: 'كل المدرسين',
                subtitle: 'الملفات المعتمدة فقط',
              ),
              AsyncView<List<TeacherProfile>>(
                load: () => AppServicesScope.of(context).teachers.listVerified(),
                builder: (BuildContext context, List<TeacherProfile> teachers) {
                  if (teachers.isEmpty) {
                    return const EmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'لا توجد ملفات مدرسين معتمدة',
                    );
                  }
                  return Column(
                    children: <Widget>[
                      for (final TeacherProfile t in teachers)
                        TeacherCard(teacher: t),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          'الفلاتر والبحث والصفحات التالية غير مفعّلة في هذه المرحلة.',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
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
