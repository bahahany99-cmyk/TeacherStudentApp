import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/app_tab.dart';
import 'package:teacher_student_app/app/shell/shell_controller.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/user_avatar_view.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/notification_rules.dart';

/// صندوق المحادثات المباشرة (P11) — **حيّ** ومنظّم.
///
/// ## العطل الذي أُصلح (P28)
///
/// كانت الشاشة تقرأ `chats.listMine(viewerId)` **مرة واحدة** عند البناء
/// (`AsyncView` + `_revision` يُزاد فقط عند العودة من محادثة). فلو أنشأ الطالب
/// محادثةً جديدة (بعد إرسال طلب انضمام أو حجز) بينما الصفحة مفتوحة عند
/// المدرس، أو وصلت رسالة جديدة، **لا يظهر شيء** حتى يُغلق الصفحة ويعيد فتحها.
/// هذا هو «المحادثات لا تظهر في حساب المعلم». المصدر الآن بثّ خادم
/// (`chats.watchMine`) عبر `StreamBuilder`، فلا حاجة لأي إعادة فتح.
///
/// **الوصول:** مدخل المحادثات لم يبقَ حبيس «حسابي»؛ صار زرًا في شريط التطبيق
/// العلوي لكل الأدوار (بعدّاد غير المقروء) واختصارًا في الرئيسية.
class DirectChatsScreen extends StatefulWidget {
  const DirectChatsScreen({super.key});

  @override
  State<DirectChatsScreen> createState() => _DirectChatsScreenState();
}

class _DirectChatsScreenState extends State<DirectChatsScreen> {
  Future<void> _open(String chatId) async {
    await Navigator.of(
      context,
    ).pushNamed(RoutePaths.directChat, arguments: chatId);
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = SessionScope.of(context);
    final bool isTeacher = session.role == UserRole.teacher;
    final String viewerId = isTeacher
        ? CurrentTeacher.idOf(session)
        : CurrentStudent.idOf(session);

    return Scaffold(
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
                  SectionHeader(
                    title: isTeacher ? 'محادثات الطلاب' : 'محادثاتي',
                    subtitle: isTeacher
                        ? 'لا يصل إليك إلا من له حجز أو عضوية مجموعة — '
                              'أو من سمحت له بالاستفسار'
                        : 'محادثاتك مع المدرسين مرتبطة بحجز أو باستفسار '
                              'قبل الحجز',
                    icon: Icons.forum_outlined,
                  ),
                  StreamBuilder<List<DirectChat>>(
                    stream: AppServicesScope.of(
                      context,
                    ).chats.watchMine(viewerId),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<List<DirectChat>> snapshot,
                    ) {
                      if (snapshot.hasError) {
                        return const EmptyState(
                          icon: Icons.wifi_off_rounded,
                          title: 'تعذّر تحميل المحادثات',
                          message: 'تحقّق من الاتصال ثم أعد المحاولة.',
                        );
                      }
                      if (!snapshot.hasData) {
                        return const _ChatsLoading();
                      }

                      final List<DirectChat> chats = snapshot.data!;
                      if (chats.isEmpty) {
                        return _ChatsEmpty(isTeacher: isTeacher);
                      }

                      final int unread = chats
                          .where((DirectChat c) => c.hasUnreadFor(viewerId))
                          .length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (unread > 0)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              child: Text(
                                '$unread محادثة فيها رسائل لم تُقرأ',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: AppColors.accent),
                              ),
                            ),
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

/// تحميل أوّلي مختصر (لا دوّارة في وسط فراغ ضخم).
class _ChatsLoading extends StatelessWidget {
  const _ChatsLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// لا محادثات: فرق بين «لم تبدأ» و«لا يسمح المدرس» — والشرح يوضّح الخطوة.
class _ChatsEmpty extends StatelessWidget {
  const _ChatsEmpty({required this.isTeacher});

  final bool isTeacher;

  @override
  Widget build(BuildContext context) {
    final ShellController? shell = ShellScope.readOrNull(context);
    final AppTab destination = isTeacher ? AppTab.groups : AppTab.teachers;

    return EmptyState(
      icon: Icons.forum_outlined,
      title: isTeacher ? 'لا محادثات بعد' : 'لا محادثات بعد',
      message: isTeacher
          ? 'تُفتح المحادثة تلقائيًا عندما يرسل طالب طلب حجز أو طلب انضمام '
                'إلى إحدى مجموعاتك.'
          : 'تُفتح المحادثة من طلب حجز أو من ملف المدرس (إذا كان يستقبل '
                'الرسائل قبل الحجز).',
      primaryActionLabel: shell == null
          ? null
          : (isTeacher ? 'إدارة مجموعاتي' : 'استكشف المدرسين الآن'),
      onPrimaryAction: shell == null
          ? null
          : () {
              shell.goTo(destination);
              Navigator.of(context).maybePop();
            },
    );
  }
}

/// صف محادثة: الطرف الآخر + سياقها + آخر رسالة + الوقت + عدّاد غير المقروء.
class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.chat,
    required this.viewerId,
    required this.onTap,
  });

  final DirectChat chat;
  final String viewerId;
  final VoidCallback onTap;

  /// سياق المحادثة كما يفهمه المستخدم (لا اسم التعداد الداخلي).
  String get _context {
    final String? subject = chat.subject?.trim();
    final String base = switch (chat.origin) {
      DirectChatOrigin.booking => 'حجز حصة',
      DirectChatOrigin.group => 'مجموعة',
      DirectChatOrigin.joinRequest => 'طلب انضمام',
      DirectChatOrigin.inquiry => 'استفسار',
    };
    return subject == null || subject.isEmpty ? base : '$base · $subject';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool unread = chat.hasUnreadFor(viewerId);
    final DateTime? lastAt = chat.lastMessageAt;
    final String? partnerId = chat.partnerIdFor(viewerId);
    final String partnerName = chat.partnerNameFor(viewerId);
    final String? lastText = chat.lastMessageText?.trim();

    return AppCard(
      key: ValueKey<String>('chat-row-${chat.id}'),
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      // المحادثة التي فيها رسائل جديدة تُحاط بحدّ ملوّن — تمييز بلا ضجيج.
      borderColor: unread ? theme.colorScheme.primary.withAlpha(90) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UserAvatarLoader(
            userId: partnerId ?? '',
            initials: partnerName,
            size: AppSpacing.avatarSm,
            semanticLabel: 'صورة $partnerName',
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
                        partnerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (lastAt != null)
                      Text(
                        NotificationRules.relativeTime(lastAt, now: DateTime.now()),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: unread
                              ? theme.colorScheme.primary
                              : AppColors.textMuted,
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _context,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        lastText == null || lastText.isEmpty
                            ? 'ابدأ المحادثة'
                            : lastText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: unread
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: unread
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (unread) ...<Widget>[
                      const SizedBox(width: AppSpacing.xxs),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        // دلالة غير لونية كذلك (قارئ الشاشة).
                        child: Semantics(
                          label: 'رسائل غير مقروءة',
                          container: true,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
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
