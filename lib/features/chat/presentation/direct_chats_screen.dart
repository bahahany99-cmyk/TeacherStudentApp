import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/direct_chat_rules.dart';

/// صندوق المحادثات المباشرة (P11).
///
/// يعرض محادثات الطرف الحالي فقط — والتصفية حقيقية في القواعد على الخادم،
/// وهذه الشاشة تقرأ ما سُمح لها به.
class DirectChatsScreen extends StatefulWidget {
  const DirectChatsScreen({super.key});

  @override
  State<DirectChatsScreen> createState() => _DirectChatsScreenState();
}

class _DirectChatsScreenState extends State<DirectChatsScreen> {
  int _revision = 0;

  Future<void> _open(String chatId) async {
    await Navigator.of(
      context,
    ).pushNamed(RoutePaths.directChat, arguments: chatId);
    if (mounted) {
      setState(() => _revision++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = SessionScope.of(context);
    final bool isTeacher = session.role == UserRole.teacher;
    final String viewerId = isTeacher
        ? CurrentTeacher.idOf(session)
        : CurrentStudent.idOf(session);

    return Scaffold(
      // شفاف لعرض تدرّج الخلفية العالمي (نسخة 3).
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('المحادثات')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const DemoBanner(),
                  SectionHeader(
                    title: isTeacher ? 'محادثات الطلاب' : 'محادثاتي',
                    subtitle: isTeacher
                        ? 'لا يصل إليك إلا من له حجز أو عضوية مجموعة '
                              '— أو من سمحت له بالاستفسار'
                        : 'محادثاتك مع المدرسين مرتبطة بحجز أو باستفسار '
                              'قبل الحجز',
                  ),
                  AsyncView<List<DirectChat>>(
                    key: ValueKey<int>(_revision),
                    load: () =>
                        AppServicesScope.of(context).chats.listMine(viewerId),
                    builder:
                        (
                          BuildContext context,
                          List<DirectChat> chats,
                        ) {
                          if (chats.isEmpty) {
                            return const EmptyState(
                              icon: Icons.forum_outlined,
                              title: 'لا محادثات بعد',
                              message:
                                  'تُفتح المحادثة من طلب حجز أو من ملف المدرس '
                                  '(إذا كان يستقبل الرسائل).',
                            );
                          }
                          return Column(
                            children: <Widget>[
                              for (final DirectChat chat in chats)
                                Padding(
                                  padding: AppSpacing.listGap,
                                  child: _ChatRow(
                                    chat: chat,
                                    viewerId: viewerId,
                                    onTap: () => _open(chat.id),
                                  ),
                                ),
                            ],
                          );
                        },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InfoNote(
                    icon: Icons.lock_outline,
                    text: isTeacher
                        ? 'يمكنك إيقاف استقبال رسائل الطلاب قبل الحجز من '
                              '«ملفي التعريفي». إيقافه لا يقطع محادثة مرتبطة '
                              'بحجز أو بعضوية مجموعة.'
                        : 'المدرس لا يرى رقم هاتفك ولا بيانات خارج ما كتبته في '
                              'المحادثة.',
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

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.chat,
    required this.viewerId,
    required this.onTap,
  });

  final DirectChat chat;
  final String viewerId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool unread = chat.hasUnreadFor(viewerId);
    final DateTime? lastAt = chat.lastMessageAt;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: AppSpacing.avatarMd / 2.6,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              chat.partnerNameFor(viewerId).trim().isEmpty
                  ? '؟'
                  : chat.partnerNameFor(viewerId).trim().substring(0, 1),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        chat.partnerNameFor(viewerId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (lastAt != null)
                      Text(
                        DirectChatRules.timeLabel(lastAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  chat.lastMessageText ?? 'لم تُكتب رسائل بعد.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: unread ? AppColors.textPrimary : AppColors.textMuted,
                    fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                // `Wrap` لا `Row`: وسمان عربيان قد يتجاوزان عرض الشاشة الضيقة.
                Wrap(
                  spacing: AppSpacing.xxs,
                  runSpacing: AppSpacing.xxs,
                  children: <Widget>[
                    StatusChip(
                      label: chat.origin.label,
                      color: theme.colorScheme.primary,
                    ),
                    if (unread)
                      StatusChip(
                        label: 'جديد',
                        color: theme.colorScheme.secondary,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
