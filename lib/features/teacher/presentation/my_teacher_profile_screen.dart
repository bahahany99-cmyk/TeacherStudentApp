import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/detail_row.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// «ملفي» — الملف التعريفي كما يراه المدرس صاحبه.
///
/// نقرأ الملف التجريبي المرتبط بحساب المعاينة ([DemoData.demoTeacherId])، ونعرض
/// حالته الحقيقية من البيانات بدل وسم ثابت. التعديل يفتح نموذجًا لا يحفظ على
/// أي خادم (انظر [RoutePaths.editTeacherProfile]).
class MyTeacherProfileScreen extends StatelessWidget {
  const MyTeacherProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // شفاف لعرض تدرّج الخلفية العالمي (نسخة 3).
        backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('ملفي التعريفي')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: AsyncView<TeacherProfile?>(
                load: () => AppServicesScope.of(
                  context,
                ).teachers.findById(DemoData.demoTeacherId),
                emptyBuilder: (BuildContext context) => const EmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'لا يوجد ملف تعريفي',
                  message: 'لم يُنشأ ملف المدرس بعد.',
                ),
                builder: (BuildContext context, TeacherProfile? profile) {
                  if (profile == null) {
                    return const EmptyState(
                      icon: Icons.person_off_outlined,
                      title: 'لا يوجد ملف تعريفي',
                    );
                  }
                  return _MyProfileBody(profile: profile);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyProfileBody extends StatelessWidget {
  const _MyProfileBody({required this.profile});

  final TeacherProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const DemoBanner(),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      profile.displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  StatusChip(
                    label: profile.status.label,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${profile.subject} • ${profile.stage}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        const SectionHeader(
          title: 'المعلومات الظاهرة للطلاب',
          subtitle: 'هذه هي الحقول التي تُعرض في ملفك العام',
          icon: Icons.visibility_outlined,
        ),
        AppCard(
          child: Column(
            children: <Widget>[
              DetailRow(
                icon: Icons.menu_book_outlined,
                label: 'المادة',
                value: profile.subject,
              ),
              DetailRow(
                icon: Icons.school_outlined,
                label: 'المرحلة',
                value: profile.stage,
              ),
              DetailRow(
                icon: Icons.place_outlined,
                label: 'المنطقة',
                value: profile.area,
              ),
              DetailRow(
                icon: Icons.payments_outlined,
                label: 'السعر',
                value: profile.priceHint ?? 'غير محدد',
              ),
              DetailRow(
                icon: Icons.notes_outlined,
                label: 'النبذة',
                value: profile.bio,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pushNamed(
              RoutePaths.editTeacherProfile,
            ),
            child: const Text('تعديل المعلومات'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const InfoNote(
          text:
              'الحفظ على الخادم غير منفّذ: النموذج يتحقق من المدخلات فقط ولا '
              'يرسل أي شيء. ربط الحفظ بـFirestore يتم في مرحلة لاحقة.',
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
