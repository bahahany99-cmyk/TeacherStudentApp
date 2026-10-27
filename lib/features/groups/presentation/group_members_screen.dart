import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// أعضاء مجموعة دراسية — واجهة المدرس.
///
/// عرض فقط: لا إضافة/إزالة عضو، ولا تغيير حالة. الأسماء وهمية في هذه المرحلة،
/// والشريط التجريبي أعلى الشاشة يوضّح ذلك.
class GroupMembersScreen extends StatelessWidget {
  const GroupMembersScreen({super.key, required this.groupId});

  final String groupId;

  String _formatDate(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أعضاء المجموعة')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const DemoBanner(),
                  AsyncView<List<GroupMember>>(
                    load: () =>
                        AppServicesScope.of(context).groups.listMembers(groupId),
                    isEmpty: (List<GroupMember> members) => members.isEmpty,
                    emptyBuilder: (BuildContext context) => const EmptyState(
                      icon: Icons.person_add_alt_outlined,
                      title: 'لا يوجد أعضاء بعد',
                      message: 'قبول طلبات الانضمام غير مفعّل في هذه المرحلة.',
                    ),
                    builder:
                        (BuildContext context, List<GroupMember> members) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              SectionHeader(
                                title: 'قائمة الأعضاء',
                                subtitle:
                                    '${members.length} عضوًا — تُقرأ من بيانات '
                                    'تجريبية',
                              ),
                              for (final GroupMember member in members)
                                Padding(
                                  padding: AppSpacing.listGap,
                                  child: AppCard(
                                    child: Row(
                                      children: <Widget>[
                                        CircleAvatar(
                                          radius: AppSpacing.avatarSm / 2,
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                          child: Text(member.initials),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                member.name,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleMedium,
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.xxs,
                                              ),
                                              Text(
                                                'انضم في ${_formatDate(member.joinedAt)}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        StatusChip(
                                          label: member.status.label,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const InfoNote(
                    text:
                        'أسماء الأعضاء وهمية في هذه المرحلة. الوصول الحقيقي '
                        'محصور في قواعد Firestore: المدرس يرى أعضاء مجموعته فقط، '
                        'والطالب لا يرى أسماء بقية الطلاب.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
