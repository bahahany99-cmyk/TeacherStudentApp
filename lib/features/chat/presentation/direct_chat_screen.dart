import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/core/widgets/error_state.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/direct_chat_repository.dart';
import 'package:teacher_student_app/data/validation/direct_chat_rules.dart';
import 'package:teacher_student_app/data/validation/message_rules.dart';
import 'package:teacher_student_app/data/validation/model_validators.dart';

/// محادثة مباشرة بين طالب ومدرس (P11).
///
/// **حيّة:** الرسائل تصل عبر `watchMessages` (بثّ Firestore أو مشغّل تجريبي)،
/// وحالة القراءة عبر `watchChat` — فلا يحتاج المستخدم زر تحديث.
///
/// **مقيدة بالأصل:** يُحسب سبب المنع من [DirectChatRules] باستخدام إعداد
/// المدرس وحالة الحجز المرتبط، فيظهر سبب عربي بدل خطأ صلاحيات متأخر.
class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _input = TextEditingController();
  bool _sending = false;

  /// آخر منع محسوب (null = الإرسال متاح).
  String? _blockedReason;
  bool _accessResolved = false;
  bool _resolvingAccess = false;

  /// آخر لحظة علّمنا فيها المحادثة مقروءة — يمنع حلقة كتابة/قراءة.
  String? _markedReadFor;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// يقرأ الإعدادات وحالة الحجز المرتبطة لحساب سبب المنع مرة واحدة.
  Future<void> _resolveAccess(DirectChat chat, String viewerId) async {
    _resolvingAccess = true;
    // نلتقط المستودعين قبل أي `await` حتى لا نستخدم `context` بعده.
    final AppServices services = AppServicesScope.of(context);
    final DirectChatRepository repo = services.chats;
    try {
      final bool allow = await repo.allowDirectMessages(chat.teacherId);
      bool rejected = false;
      final String? bookingId = chat.bookingId;
      if (bookingId != null) {
        final BookingRequest? booking = await services.bookings.findById(
          bookingId,
        );
        rejected = booking?.status == BookingStatus.rejected;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvingAccess = false;
        _blockedReason = DirectChatRules.sendBlockedReason(
          chat: chat,
          viewerId: viewerId,
          allowDirectMessages: allow,
          bookingRejected: rejected,
        );
        _accessResolved = true;
      });
    } catch (error) {
      // (P16) فشل الشبكة أثناء التحقق: نفشل **مغلقين** — لا نرسل بلا معرفة
      // الإعداد، ونقول للمستخدم ما حدث بدل تركه أمام زر لا يعمل بلا سبب.
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvingAccess = false;
        _accessResolved = true;
        _blockedReason = toAppException(error).message;
      });
    }
  }

  Future<void> _markRead(DirectChat chat, String viewerId) async {
    if (!chat.hasUnreadFor(viewerId) && _markedReadFor == chat.id) {
      return;
    }
    _markedReadFor = chat.id;
    try {
      await AppServicesScope.of(context).chats.markRead(
        chatId: chat.id,
        viewerId: viewerId,
        at: DateTime.now(),
      );
    } catch (_) {
      // أفضل جهد: علامة القراءة ليست شرطًا لعرض الرسائل، وفقدانها بسبب شبكة
      // متعثرة لا يستحق إزعاج المستخدم برسالة خطأ.
    }
  }

  Future<void> _send(DirectChat chat, String viewerId, String viewerName) async {
    if (_blockedReason != null) {
      AppSnackBar.show(
        context,
        _blockedReason!,
        type: AppMessageType.warning,
      );
      return;
    }

    final ValidationResult valid = MessageRules.validate(_input.text);
    if (!valid.isValid) {
      AppSnackBar.show(
        context,
        valid.problems.first.issue == FieldIssue.tooLong
            ? 'الرسالة أطول من ${DirectChatRules.maxLength} حرفًا.'
            : 'لا يمكن إرسال رسالة فارغة.',
        type: AppMessageType.warning,
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await AppServicesScope.of(context).chats.sendMessage(
        chatId: chat.id,
        senderId: viewerId,
        senderName: viewerName,
        senderRole: SessionScope.read(context).role ?? UserRole.student,
        text: _input.text,
      );
      if (!mounted) {
        return;
      }
      _input.clear();
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        error.overrideMessage ?? error.message,
        type: AppMessageType.error,
      );
    } catch (error) {
      // (P16) أي استثناء غير متوقع يُترجم ولا يصل كسطر تقني.
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        toAppException(error).message,
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = SessionScope.of(context);
    final bool isTeacher = session.role == UserRole.teacher;
    final String viewerId = isTeacher
        ? CurrentTeacher.idOf(session)
        : CurrentStudent.idOf(session);
    final String viewerName = isTeacher
        ? CurrentTeacher.nameOf(session)
        : CurrentStudent.nameOf(session);

    return Scaffold(
      // شفاف لعرض تدرّج الخلفية العالمي (نسخة 3).
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('محادثة مباشرة')),
      body: SafeArea(
        child: ResponsiveContent(
          child: StreamBuilder<DirectChat?>(
            stream: AppServicesScope.of(context).chats.watchChat(widget.chatId),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<DirectChat?> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  // (P16) انقطاع البثّ لا يعني «محادثة غير متاحة»: نعرض سببًا
                  // حقيقيًا وزر إعادة محاولة يعيد الاشتراك.
                  if (snapshot.hasError) {
                    return ErrorState(
                      error: snapshot.error!,
                      onRetry: () => setState(() {}),
                    );
                  }

                  final DirectChat? chat = snapshot.data;
                  if (chat == null || !chat.involves(viewerId)) {
                    return const EmptyState(
                      icon: Icons.forum_outlined,
                      title: 'المحادثة غير متاحة',
                      message:
                          'هذه المحادثة خاصة بالطرفين المعنيين فقط، ولا تظهر '
                          'لأي حساب آخر.',
                    );
                  }

                  if (!_accessResolved && !_resolvingAccess) {
                    _resolveAccess(chat, viewerId);
                  }
                  if (chat.hasUnreadFor(viewerId)) {
                    _markRead(chat, viewerId);
                  }

                  return _ChatBody(
                    chat: chat,
                    viewerId: viewerId,
                    blockedReason: _blockedReason,
                    input: _input,
                    sending: _sending,
                    onSend: () => _send(chat, viewerId, viewerName),
                    // التدفّقان يُنشآن في `build`، فإعادة البناء = إعادة اشتراك
                    // (التدفّق المنتهي بالخطأ لا يُعاد تشغيله تلقائيًا).
                    onRetryStreams: () => setState(() {}),
                  );
                },
          ),
        ),
      ),
    );
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.chat,
    required this.viewerId,
    required this.blockedReason,
    required this.input,
    required this.sending,
    required this.onSend,
    required this.onRetryStreams,
  });

  final DirectChat chat;
  final String viewerId;
  final String? blockedReason;
  final TextEditingController input;
  final bool sending;
  final VoidCallback onSend;

  /// يعيد الاشتراك في تدفّقي المحادثة والرسائل بعد انقطاعهما.
  final VoidCallback onRetryStreams;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: AppSpacing.avatarLg / 2.8,
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
                    Text(
                      chat.partnerNameFor(viewerId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chat.subject ?? chat.origin.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: chat.origin.label,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<DirectChatMessage>>(
            stream: AppServicesScope.of(
              context,
            ).chats.watchMessages(chat.id),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<DirectChatMessage>> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ErrorState(
                      error: snapshot.error!,
                      onRetry: onRetryStreams,
                    );
                  }
                  final List<DirectChatMessage> messages =
                      snapshot.data ?? const <DirectChatMessage>[];
                  if (messages.isEmpty) {
                    return const EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'لا رسائل بعد',
                      message:
                          'اكتب أول رسالة — ستصل للطرف الآخر فورًا داخل '
                          'التطبيق.',
                    );
                  }

                  final DateTime? partnerRead =
                      chat.partnerLastReadAtFor(viewerId);
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (BuildContext context, int index) {
                      final int i = messages.length - 1 - index;
                      final DirectChatMessage message = messages[i];
                      final bool showDay = DirectChatRules.startsNewDay(
                        messages,
                        i,
                      );
                      final bool isLast = i == messages.length - 1;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (showDay)
                            _DayDivider(
                              label: DirectChatRules.dayLabel(
                                message.sentAt,
                                now: DateTime.now(),
                              ),
                            ),
                          _MessageBubble(
                            message: message,
                            isMine: message.isMine(viewerId),
                            readByPartner: isLast
                                ? message.isReadByPartner(partnerRead, viewerId)
                                : null,
                          ),
                        ],
                      );
                    },
                  );
                },
          ),
        ),
        if (blockedReason != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: InfoNote(text: blockedReason!),
          )
        else
          _Composer(
            controller: input,
            sending: sending,
            onSend: onSend,
          ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

/// فاصل اليوم بين مجموعات الرسائل.
class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            border: AppBorders.side(AppBorders.onWhite),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.readByPartner,
  });

  final DirectChatMessage message;
  final bool isMine;

  /// `null` يعني «لا نعرض حالة القراءة» (ليست آخر رسالة لي).
  final bool? readByPartner;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

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
          color: isMine ? theme.colorScheme.primary.withAlpha(22) : Colors.white,
          borderRadius: radius,
          border: AppBorders.side(
            isMine ? AppBorders.onTint : AppBorders.onWhite,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  DirectChatRules.timeLabel(message.sentAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                if (readByPartner != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    readByPartner!
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 14,
                    color: readByPartner!
                        ? theme.colorScheme.primary
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    readByPartner! ? 'مقروء' : 'أُرسلت',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: readByPartner!
                          ? theme.colorScheme.primary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            maxLength: DirectChatRules.maxLength,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'اكتب رسالة…',
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
    );
  }
}
