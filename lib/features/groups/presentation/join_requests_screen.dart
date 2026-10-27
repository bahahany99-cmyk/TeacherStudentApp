import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';

/// طلبات الانضمام (P8) — شاشة واحدة للطرفين:
/// - **المدرس صاحب المجموعة:** يرى الطلبات المعلّقة ويقبل/يرفض.
/// - **الطالب:** يرى حالة طلباته (معلّق/مقبول/مرفوض) ويمكنه إلغاء المعلّق.
///
/// القبول هنا ليس «تحديث واجهة»: المستودع ينفّذ معاملة تقرأ المجموعة والطلب
/// من الخادم، وتزيد المقعد بمقدار واحد، وتنشئ مستند العضو، وتغيّر حالة الطلب —
/// كلها أو لا شيء. لذلك كل قرار يبدأ بتأكيد صريح، ثم يُقرأ من جديد.
class JoinRequestsScreen extends StatefulWidget {
  const JoinRequestsScreen({super.key, required this.groupId});

  /// المجموعة التي تُعرض طلباتها (يستخدمه المدرس؛ وواجهة الطالب تعرض كل
  /// طلباته عبر `listMyRequests`).
  final String groupId;

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  /// عدّاد إعادة الجلب بعد كل قرار — لا نُعدّل القائمة محليًا كما لو أن القرار
  /// نجح قبل تأكيد الخادم.
  int _revision = 0;

  /// معرّف الطلب الجاري معالجته (لتعطيل أزراره وحده).
  String? _busyId;

  Future<void> _decide(GroupJoinRequest request, {required bool approve}) async {
    final SessionController session = SessionScope.read(context);
    final String teacherId = CurrentTeacher.idOf(session);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text(approve ? 'قبول الطلب؟' : 'رفض الطلب؟'),
        content: Text(
          approve
              ? 'سيُحجز مقعد لـ«${request.studentName}» فورًا. لو امتلأت المجموعة '
                    'قبل التنفيذ سيُرفض القبول ولن يُحجز شيء.'
              : 'سيُرفض طلب «${request.studentName}»، ويمكنه التقديم مرة أخرى.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(approve ? 'تأكيد القبول' : 'تأكيد الرفض'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _busyId = request.id);
    try {
      await AppServicesScope.of(context).groups.decideJoinRequest(
        request: request,
        teacherId: teacherId,
        approve: approve,
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        approve ? 'تم قبول الطلب وحجز المقعد.' : 'تم رفض الطلب.',
        type: approve ? AppMessageType.success : AppMessageType.info,
      );
      setState(() {
        _busyId = null;
        _revision++;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        error.overrideMessage ?? error.message,
        type: AppMessageType.error,
      );
      setState(() {
        _busyId = null;
        // إعادة القراءة ضرورية: قد يكون السبب أن المجموعة امتلأت للتو.
        _revision++;
      });
    }
  }

  Future<void> _cancel(GroupJoinRequest request) async {
    final String studentId = CurrentStudent.idOf(SessionScope.read(context));
    setState(() => _busyId = request.id);
    try {
      await AppServicesScope.of(context).groups.cancelJoinRequest(
        request: request,
        studentId: studentId,
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, 'تم إلغاء الطلب.', type: AppMessageType.info);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        error.message,
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyId = null;
          _revision++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = SessionScope.of(context);
    final bool isTeacher = session.role == UserRole.teacher;

    return Scaffold(
      // شفاف لعرض خلفية v4.1 العالمية.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(isTeacher ? 'طلبات الانضمام' : 'طلباتي'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const DemoBanner(),
                  AsyncView<List<GroupJoinRequest>>(
                    key: ValueKey<int>(_revision),
                    load: () {
                      final GroupRepository groups = AppServicesScope.of(
                        context,
                      ).groups;
                      return isTeacher
                          ? groups.listRequestsForGroup(
                              widget.groupId,
                              teacherId: CurrentTeacher.idOf(session),
                            )
                          : groups.listMyRequests(CurrentStudent.idOf(session));
                    },
                    isEmpty: (List<GroupJoinRequest> items) => items.isEmpty,
                    emptyBuilder: (BuildContext context) => EmptyState(
                      icon: Icons.mark_email_unread_outlined,
                      title: isTeacher
                          ? 'لا توجد طلبات انضمام'
                          : 'لم تُرسل طلبات انضمام',
                      message: isTeacher
                          ? 'ستظهر هنا طلبات الطلاب، ومعها زر القبول الذي يحجز '
                                'المقعد على الخادم.'
                          : 'افتح أي مجموعة من تبويب «المجموعات» وأرسل طلب '
                                'انضمام لتتابعه هنا.',
                    ),
                    builder:
                        (BuildContext context, List<GroupJoinRequest> requests) {
                          final List<GroupJoinRequest> pending = requests
                              .where((GroupJoinRequest r) => r.isPending)
                              .toList(growable: false);
                          final List<GroupJoinRequest> decided = requests
                              .where((GroupJoinRequest r) => !r.isPending)
                              .toList(growable: false);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              SectionHeader(
                                title: isTeacher
                                    ? 'بانتظار قرارك'
                                    : 'قيد المراجعة',
                                icon: Icons.hourglass_empty,
                                subtitle: '${pending.length} طلبًا معلّقًا',
                              ),
                              if (pending.isEmpty)
                                const AppCard(
                                  child: InfoNote(
                                    text: 'لا طلبات معلّقة الآن.',
                                    icon: Icons.check_circle_outline,
                                  ),
                                )
                              else
                                for (final GroupJoinRequest request in pending)
                                  Padding(
                                    padding: AppSpacing.listGap,
                                    child: _RequestCard(
                                      request: request,
                                      isTeacher: isTeacher,
                                      busy: _busyId == request.id,
                                      onApprove: () => _decide(
                                        request,
                                        approve: true,
                                      ),
                                      onReject: () => _decide(
                                        request,
                                        approve: false,
                                      ),
                                      onCancel: () => _cancel(request),
                                    ),
                                  ),
                              if (decided.isNotEmpty) ...<Widget>[
                                const SizedBox(height: AppSpacing.sectionGap),
                                SectionHeader(
                                  title: 'طلبات سابقة',
                                  icon: Icons.history,
                                  subtitle: '${decided.length} طلبًا',
                                ),
                                for (final GroupJoinRequest request in decided)
                                  Padding(
                                    padding: AppSpacing.listGap,
                                    child: _RequestCard(
                                      request: request,
                                      isTeacher: isTeacher,
                                      busy: false,
                                    ),
                                  ),
                              ],
                              const SizedBox(height: AppSpacing.sm),
                              InfoNote(
                                text: isTeacher
                                    ? 'القبول يزيد المقعد المشغول ويُنشئ عضوية '
                                          'الطالب في معاملة واحدة على الخادم، فلا '
                                          'يمكن تجاوز السعة حتى لو قُبل طلبان في '
                                          'اللحظة نفسها.'
                                    : 'طلب الانضمام يحتاج موافقة المدرس. '
                                          'المقعد يُحجز لحظة القبول فقط، لا لحظة '
                                          'إرسال الطلب.',
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                          );
                        },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isTeacher,
    required this.busy,
    this.onApprove,
    this.onReject,
    this.onCancel,
  });

  final GroupJoinRequest request;
  final bool isTeacher;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  String _formatDate(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Color get _statusColor => switch (request.status) {
    JoinRequestStatus.pending => AppColors.statusPending,
    JoinRequestStatus.accepted => AppColors.statusAccepted,
    JoinRequestStatus.rejected => AppColors.statusRejected,
    JoinRequestStatus.cancelled => AppColors.statusNeutral,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: AppSpacing.avatarSm / 2,
                backgroundColor: theme.colorScheme.primary.withAlpha(24),
                child: Text(
                  request.studentName.trim().isEmpty
                      ? '؟'
                      : request.studentName.trim().substring(0, 1),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      request.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      request.groupTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              StatusChip(label: request.status.label, color: _statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'أُرسل في ${_formatDate(request.requestedAt)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (request.isPending && isTeacher) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onApprove,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('قبول'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    child: const Text('رفض'),
                  ),
                ),
              ],
            ),
          ],
          if (request.isPending && !isTeacher) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                PillChip(
                  label: 'بانتظار موافقة المدرس',
                  icon: Icons.schedule,
                  color: AppColors.statusPending,
                  dense: true,
                ),
                const Spacer(),
                TextButton(
                  onPressed: busy ? null : onCancel,
                  child: const Text('إلغاء الطلب'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
