import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/detail_row.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// تفاصيل مجموعة دراسية.
///
/// شاشة واحدة للدورين، والفرق محدود ومقصود:
/// - الطالب: يرى السعة والموعد والمدرس، وزر انضمام غير مفعّل بعد.
/// - المدرس: لا يرى زر انضمام، ويرى بدلًا منه مدخل «أعضاء المجموعة».
///
/// ⚠️ إخفاء زر لا يعني صلاحية: أي قراءة/كتابة حقيقية تُفرض في قواعد Firestore.
class GroupDetailsScreen extends StatelessWidget {
  const GroupDetailsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المجموعة')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: AsyncView<StudyGroup?>(
                load: () => AppServicesScope.of(context).groups.findById(groupId),
                emptyBuilder: (BuildContext context) => const EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'المجموعة غير موجودة',
                  message: 'ربما حُذفت المجموعة أو تغيّر الرابط.',
                ),
                builder: (BuildContext context, StudyGroup? group) {
                  if (group == null) {
                    return const EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'المجموعة غير موجودة',
                    );
                  }
                  return _GroupDetailsBody(group: group);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupDetailsBody extends StatelessWidget {
  const _GroupDetailsBody({required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SessionController session = SessionScope.of(context);
    final bool isTeacherView = session.role == UserRole.teacher;
    final int seatsTaken = group.seatsTaken;
    final int seatsTotal = group.seatsTotal == 0 ? 1 : group.seatsTotal;
    final double fill = (seatsTaken / seatsTotal).clamp(0, 1).toDouble();

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
                      group.title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  StatusChip(
                    label: group.isFull ? 'مكتملة' : 'متاحة',
                    color: group.isFull
                        ? AppColors.statusRejected
                        : AppColors.statusAccepted,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${group.subject} • ${group.stage}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DetailRow(
                icon: Icons.person_outline,
                label: 'المدرس',
                value: group.teacherName,
              ),
              DetailRow(
                icon: Icons.videocam_outlined,
                label: 'طريقة الحضور',
                value: group.meetingMode.label,
              ),
              if (group.scheduleNote != null)
                DetailRow(
                  icon: Icons.schedule_outlined,
                  label: 'الموعد',
                  value: group.scheduleNote!,
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'المقاعد',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '$seatsTaken / ${group.seatsTotal}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                child: LinearProgressIndicator(
                  value: fill,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.primaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                group.isFull
                    ? 'لا توجد مقاعد متاحة حاليًا'
                    : 'متاح ${group.seatsAvailable} مقعد',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (isTeacherView) ...<Widget>[
          const SectionHeader(
            title: 'إدارة المجموعة',
            subtitle: 'إدارة الأعضاء والمواعيد تُنفَّذ على الخادم لاحقًا',
          ),
          AppCard(
            onTap: () => Navigator.of(context).pushNamed(
              RoutePaths.groupMembers,
              arguments: group.id,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.groups_2_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'أعضاء المجموعة ($seatsTaken)',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.chevron_left),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const InfoNote(
            text:
                'هذه الشاشة للعرض فقط: لا إضافة أعضاء ولا إزالة ولا تعديل موعد. '
                'التحقق من السعة يتم على الخادم بعملية ذرية (Phase 8).',
          ),
        ] else ...<Widget>[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => AppSnackBar.show(
                context,
                '${AppStrings.comingSoon}: طلب الانضمام يحتاج موافقة المدرس.',
                type: AppMessageType.info,
              ),
              child: const Text('طلب الانضمام'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const InfoNote(
            text:
                'طلب الانضمام سيُرسل للمدرس للموافقة (C-09)، والسعة تُفرض على '
                'الخادم حتى لا يتجاوز العدد الحدّ المعلن.',
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
