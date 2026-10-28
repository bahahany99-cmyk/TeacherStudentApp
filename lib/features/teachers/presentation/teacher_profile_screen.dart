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
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/bookings/presentation/booking_request_sheet.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/group_card.dart';

/// ملف مدرس واحد — الصفحة التي يفتحها الطالب من قائمة المدرسين.
///
/// عرض فقط: لا حجز، ولا محادثة، ولا مراجعات فعلية في هذه المرحلة. نُظهر ما
/// تعرفه البيانات فعلًا، ونقول صراحةً ما لم يُنفَّذ بدل أزرار بلا أثر.
class TeacherProfileScreen extends StatelessWidget {
  const TeacherProfileScreen({super.key, required this.teacherId});

  final String teacherId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // شفاف لعرض تدرّج الخلفية العالمي (نسخة 3).
        backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('ملف المدرس')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: AsyncView<TeacherProfile?>(
                load: () => AppServicesScope.of(
                  context,
                ).teachers.findById(teacherId),
                emptyBuilder: (BuildContext context) => const EmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'الملف غير موجود',
                  message:
                      'ربما لم يُعتمد هذا الملف بعد أو تم حذفه. الملفات غير '
                      'المعتمدة لا تظهر للطلاب.',
                ),
                builder: (BuildContext context, TeacherProfile? teacher) {
                  if (teacher == null) {
                    return const EmptyState(
                      icon: Icons.person_off_outlined,
                      title: 'الملف غير موجود',
                      message: 'ربما لم يُعتمد هذا الملف بعد أو تم حذفه.',
                    );
                  }
                  return _TeacherProfileBody(teacher: teacher);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherProfileBody extends StatelessWidget {
  const _TeacherProfileBody({required this.teacher});

  final TeacherProfile teacher;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    radius: AppSpacing.avatarLg / 2.6,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      teacher.initials,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          teacher.displayName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${teacher.subject} • ${teacher.stage}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xxs,
                          runSpacing: AppSpacing.xxs,
                          children: <Widget>[
                            StatusChip(
                              label: 'معتمد',
                              color: theme.colorScheme.primary,
                            ),
                            if (teacher.isFeatured)
                              const StatusChip(
                                label: 'مميز',
                                color: Color(0xFFB26A00),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              DetailRow(
                icon: Icons.place_outlined,
                label: 'المنطقة',
                value: teacher.area,
              ),
              DetailRow(
                icon: Icons.star_rounded,
                label: 'التقييم',
                value: teacher.reviewsCount == 0
                    ? 'لا توجد تقييمات بعد'
                    : '${teacher.rating.toStringAsFixed(1)} من 5 '
                          '(${teacher.reviewsCount} تقييم)',
              ),
              if (teacher.priceHint != null)
                DetailRow(
                  icon: Icons.payments_outlined,
                  label: 'السعر',
                  value: teacher.priceHint!,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        const SectionHeader(
          title: 'نبذة',
          subtitle: 'كما كتبها المدرس في ملفه',
          icon: Icons.article_outlined,
        ),
        AppCard(
          child: Text(
            teacher.bio,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        const SectionHeader(
          title: 'مجموعات هذا المدرس',
          subtitle: 'افتح المجموعة لإرسال طلب انضمام ينتظر موافقة المدرس',
          icon: Icons.groups_outlined,
        ),
        AsyncView<List<StudyGroup>>(
          load: () => AppServicesScope.of(
            context,
          ).groups.listForTeacher(teacher.id),
          isEmpty: (List<StudyGroup> groups) => groups.isEmpty,
          emptyBuilder: (BuildContext context) => const EmptyState(
            icon: Icons.groups_outlined,
            title: 'لا توجد مجموعات متاحة',
            message: 'لم ينشر هذا المدرس مجموعات بعد.',
          ),
          builder: (BuildContext context, List<StudyGroup> groups) {
            return Column(
              children: groups
                  .map(
                    (StudyGroup group) => GroupCard(
                      group: group,
                      onTap: () => Navigator.of(context).pushNamed(
                        RoutePaths.groupDetails,
                        arguments: group.id,
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            // طلب حجز فعلي (P10): يفتح ورقة الموعد ويكتب للمستودع.
            onPressed: () => showBookingRequestSheet(context, teacher: teacher),
            icon: const Icon(Icons.event_available_outlined, size: 18),
            label: const Text('طلب حجز'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const InfoNote(
          text:
              'البيانات أعلاه تجريبية من الذاكرة المحلية، وليست من Firebase. '
              'الدفع والاتفاق على السعر يتمان خارج التطبيق (C-15).',
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
