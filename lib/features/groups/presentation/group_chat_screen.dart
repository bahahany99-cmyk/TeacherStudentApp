import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/group_message.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/message_repository.dart';
import 'package:teacher_student_app/data/validation/message_rules.dart';
import 'package:teacher_student_app/data/validation/move_rules.dart';
import 'package:teacher_student_app/data/validation/model_validators.dart';

/// محادثة المجموعة (P9) — قناة واحدة لكل مجموعة.
///
/// **من يشارك؟** المدرس صاحب المجموعة وكل عضو قُبل طلبه. القواعد تفحص العضوية
/// بـ`exists()` على مستند العضو، والواجهة تعرض نفس القاعدة قبل الإرسال.
///
/// **التحديث:** لا بثّ حيّ في هذه المرحلة. القائمة تُقرأ عند الفتح وبعد كل
/// إرسال، مع زر تحديث صريح — أرخص في القراءات وأصدق من إيهام المستخدم بأن
/// الرسائل تصل لحظيًا.
class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _input = TextEditingController();
  int _revision = 0;
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _revision++);

  Future<_ChatData> _load() async {
    final SessionController session = SessionScope.read(context);
    final services = AppServicesScope.of(context);

    final StudyGroup? group = await services.groups.findById(widget.groupId);
    if (group == null) {
      throw const AppException.notFound(debugMessage: 'group missing');
    }

    // المعرّف المعروض: مدرس أو طالب حسب الدور الحالي في الجلسة.
    final bool isTeacher = session.role == UserRole.teacher;
    final String viewerId = isTeacher
        ? CurrentTeacher.idOf(session)
        : CurrentStudent.idOf(session);
    final String viewerName = isTeacher
        ? CurrentTeacher.nameOf(session)
        : CurrentStudent.nameOf(session);

    final bool isOwner = viewerId == group.teacherId;
    final bool isMember = isOwner
        ? false
        : await services.groups.isMember(
            groupId: group.id,
            userId: viewerId,
          );

    final bool canParticipate = MessageRules.canParticipate(
      viewerId: viewerId,
      isOwner: isOwner,
      isMember: isMember,
    );

    final List<GroupMessage> messages = canParticipate
        ? await services.messages.listForGroup(group.id)
        : const <GroupMessage>[];

    return _ChatData(
      group: group,
      messages: messages,
      viewerId: viewerId,
      viewerName: viewerName,
      viewerRole: isTeacher ? UserRole.teacher : UserRole.student,
      isOwner: isOwner,
      isMember: isMember,
    );
  }

  Future<void> _send(_ChatData data) async {
    final MessageRepository messages = AppServicesScope.of(context).messages;

    try {
      await messages.sendMessage(
        groupId: data.group.id,
        senderId: data.viewerId,
        senderName: data.viewerName,
        senderRole: data.viewerRole,
        text: _input.text,
      );
      if (!mounted) {
        return;
      }
      _input.clear();
      setState(() {
        _sending = false;
        _revision++;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _sending = false);
      AppSnackBar.show(
        context,
        error.overrideMessage ?? error.message,
        type: AppMessageType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('محادثة المجموعة'),
        actions: <Widget>[
          IconButton(
            tooltip: 'تحديث',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: AsyncView<_ChatData>(
            key: ValueKey<int>(_revision),
            load: _load,
            builder: (BuildContext context, _ChatData data) {
              if (!data.canParticipate) {
                return ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'المحادثة لأعضاء المجموعة',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            MessageRules.blockedReason(
                                  viewerId: data.viewerId,
                                  isOwner: data.isOwner,
                                  isMember: data.isMember,
                                ) ??
                                '',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const InfoNote(text: MoveRules.notMemberHint),
                          const SizedBox(height: AppSpacing.sm),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pushNamed(
                              RoutePaths.groupDetails,
                              arguments: data.group.id,
                            ),
                            child: const Text('عرض المجموعة'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: data.messages.isEmpty
                        ? const EmptyState(
                            icon: Icons.forum_outlined,
                            title: 'لا رسائل بعد',
                            message: 'اكتب أول رسالة لتظهر لبقية أعضاء المجموعة.',
                          )
                        : ListView.builder(
                            // الأحدث في الأسفل: القائمة مقلوبة كما في كل تطبيقات
                            // الدردشة، والبيانات تصل تصاعدية من المستودع.
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            itemCount: data.messages.length,
                            itemBuilder: (BuildContext context, int index) {
                              final GroupMessage message =
                                  data.messages[data.messages.length - 1 - index];
                              return _MessageBubble(
                                message: message,
                                isMine: message.isMine(data.viewerId),
                              );
                            },
                          ),
                  ),
                  const InfoNote(
                    text:
                        'الرسائل تظهر عند التحديث (زر التحديث أعلى الشاشة) — لا '
                        'يوجد بثّ لحظي في هذه المرحلة، ولا يمكن تعديل رسالة بعد '
                        'إرسالها.',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _Composer(
                    controller: _input,
                    sending: _sending,
                    onSend: () {
                      final ValidationResult result = MessageRules.validate(
                        _input.text,
                      );
                      if (!result.isValid) {
                        AppSnackBar.show(
                          context,
                          result.problems.first.issue == FieldIssue.tooLong
                              ? 'الرسالة أطول من ${MessageRules.maxLength} حرفًا.'
                              : 'لا يمكن إرسال رسالة فارغة.',
                          type: AppMessageType.warning,
                        );
                        return;
                      }
                      setState(() => _sending = true);
                      _send(data);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// بيانات الشاشة في كائن واحد.
class _ChatData {
  const _ChatData({
    required this.group,
    required this.messages,
    required this.viewerId,
    required this.viewerName,
    required this.viewerRole,
    required this.isOwner,
    required this.isMember,
  });

  final StudyGroup group;
  final List<GroupMessage> messages;
  final String viewerId;
  final String viewerName;
  final UserRole viewerRole;
  final bool isOwner;
  final bool isMember;

  bool get canParticipate => MessageRules.canParticipate(
    viewerId: viewerId,
    isOwner: isOwner,
    isMember: isMember,
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final GroupMessage message;
  final bool isMine;

  String _time(DateTime value) {
    final String hour = value.hour % 12 == 0 ? '12' : '${value.hour % 12}';
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'م' : 'ص'}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool fromTeacher = message.senderRole == UserRole.teacher;

    final Color background = isMine
        ? theme.colorScheme.primary.withAlpha(22)
        : Colors.white;
    final BorderRadiusDirectional radius = BorderRadiusDirectional.only(
      topStart: const Radius.circular(AppSpacing.radiusLg),
      topEnd: const Radius.circular(AppSpacing.radiusLg),
      bottomStart: Radius.circular(isMine ? AppSpacing.radiusLg : 6),
      bottomEnd: Radius.circular(isMine ? 6 : AppSpacing.radiusLg),
    );

    return Align(
      alignment: isMine
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: AppBorders.side(
            isMine ? AppBorders.onTint : AppBorders.onWhite,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    message.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (fromTeacher) ...<Widget>[
                  const SizedBox(width: AppSpacing.xxs),
                  StatusChip(
                    label: 'مدرس',
                    color: theme.colorScheme.primary,
                  ),
                ],
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _time(message.sentAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// صندوق الكتابة + زر الإرسال.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: MessageRules.maxLength,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'اكتب رسالة…',
                // لا عدّاد على كل حرف: يزاحم سطر الكتابة، والحد معلن في
                // validation عند تجاوزه.
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton.filled(
            tooltip: 'إرسال',
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
