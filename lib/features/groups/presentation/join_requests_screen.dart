import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
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
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/booking_rules.dart';

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
        child: isTeacher
            // (P25) لوحة المدرس العامة: انضمام + حجز، حيّة، وكل الطلبات.
            ? _TeacherRequestsPanel(
                teacherId: CurrentTeacher.idOf(session),
                busyId: _busyId,
                onDecide: _decide,
              )
            : _StudentRequestsList(
                key: ValueKey<int>(_revision),
                studentId: CurrentStudent.idOf(session),
                busyId: _busyId,
                onCancel: _cancel,
              ),
      ),
    );
  }
}

/// لوحة طلبات المدرس (P25 — البند 5).
///
/// ## العطل الذي تُصلحه
/// كانت الشاشة تقرأ `listRequestsForGroup(groupId)` — **مجموعة واحدة**،
/// وتُبنى عند فتحها من صفحة تلك المجموعة فقط. فصلاحًا لذلك:
/// - المدرس الذي يملك خمس مجموعات يرى طلبات مجموعة واحدة ويظن الباقي فارغًا.
/// - «طلبات الحجز» لم تكن هنا إطلاقًا، فكان عليه أن يفتح تبويبًا آخر ليعرف أن
///   طالبًا ينتظره.
/// - كل قراءة كانت لقطة عند البناء، فالطلب الجديد لا يظهر إلا بإعادة فتح.
///
/// ## الحل
/// بثّان مباشران: `groups.watchIncomingRequests(teacherId)` و
/// `bookings.watchMine()` (مفلترًا على طلبات هذا المدرس المنتظرة). كلاهما بثّ
/// خادم، فيظهر الطلب **فور وصوله** بلا تحديث يدوي.
///
/// **الترتيب:** الانضمام أولًا (يحتاج قرارًا لمقعد)، ثم الحجز. كل قسم يعرض
/// حالته الفارغة الخاصة به، فلا يختفي قسم لأن الآخر فارغ.
class _TeacherRequestsPanel extends StatelessWidget {
  const _TeacherRequestsPanel({
    required this.teacherId,
    required this.busyId,
    required this.onDecide,
  });

  final String teacherId;
  final String? busyId;
  final Future<void> Function(GroupJoinRequest request, {required bool approve})
  onDecide;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SectionHeader(
                title: 'طلبات الانضمام',
                icon: Icons.person_add_alt_1_outlined,
                subtitle: 'كل مجموعاتك — تظهر لحظة إرسالها',
              ),
              StreamBuilder<List<GroupJoinRequest>>(
                stream: AppServicesScope.of(
                  context,
                ).groups.watchIncomingRequests(teacherId),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<GroupJoinRequest>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return const AppCard(
                      child: InfoNote(
                        icon: Icons.wifi_off_rounded,
                        text: 'تعذّر تحميل طلبات الانضمام. تحقّق من الاتصال.',
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const _RequestsLoading();
                  }
                  final List<GroupJoinRequest> requests = snapshot.data!;
                  final List<GroupJoinRequest> pending = requests
                      .where((GroupJoinRequest r) => r.isPending)
                      .toList(growable: false);
                  final List<GroupJoinRequest> decided = requests
                      .where((GroupJoinRequest r) => !r.isPending)
                      .toList(growable: false);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (pending.isEmpty)
                        const AppCard(
                          child: InfoNote(
                            text: 'لا طلبات انضمام معلّقة الآن.',
                            icon: Icons.check_circle_outline,
                          ),
                        )
                      else ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.xxs,
                          ),
                          child: Text(
                            '${pending.length} طلبًا بانتظار قرارك',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.statusPending),
                          ),
                        ),
                        for (final GroupJoinRequest request in pending)
                          Padding(
                            padding: AppSpacing.listGap,
                            child: _RequestCard(
                              request: request,
                              isTeacher: true,
                              busy: busyId == request.id,
                              onApprove: () =>
                                  onDecide(request, approve: true),
                              onReject: () =>
                                  onDecide(request, approve: false),
                            ),
                          ),
                      ],
                      if (decided.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
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
                              isTeacher: true,
                              busy: false,
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const SectionHeader(
                title: 'طلبات الحجز',
                icon: Icons.event_note_outlined,
                subtitle: 'الطلبات التي تنتظر ردّك على موعد',
              ),
              StreamBuilder<List<BookingRequest>>(
                stream: AppServicesScope.of(context).bookings.watchMine(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<BookingRequest>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return const AppCard(
                      child: InfoNote(
                        icon: Icons.wifi_off_rounded,
                        text: 'تعذّر تحميل طلبات الحجز. تحقّق من الاتصال.',
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const _RequestsLoading();
                  }
                  // طلبات هذا المدرس المنتظرة فقط — `watchMine` تُرجع الاتجاهين
                  // (كطالب وكمعلم)، والقسم هنا لصفته كمعلّم.
                  final List<BookingRequest> pending = snapshot.data!
                      .where(
                        (BookingRequest b) =>
                            b.teacherId == teacherId && b.waitingForTeacher,
                      )
                      .toList(growable: false);

                  if (pending.isEmpty) {
                    return const AppCard(
                      child: InfoNote(
                        text: 'لا طلبات حجز معلّقة الآن.',
                        icon: Icons.check_circle_outline,
                      ),
                    );
                  }
                  return Column(
                    children: <Widget>[
                      for (final BookingRequest booking in pending)
                        Padding(
                          padding: AppSpacing.listGap,
                          child: AppCard(
                            onTap: () => Navigator.of(context).pushNamed(
                              RoutePaths.bookingDetails,
                              arguments: booking.id,
                            ),
                            child: Row(
                              children: <Widget>[
                                CircleAvatar(
                                  radius: AppSpacing.avatarSm / 2,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withAlpha(24),
                                  child: Text(
                                    booking.studentName.trim().isEmpty
                                        ? '؟'
                                        : booking.studentName.trim().substring(
                                            0,
                                            1,
                                          ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        booking.studentName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(
                                        booking.hasSchedule
                                            ? '${booking.subject} — '
                                                  '${BookingRules.slotLabel(booking)}'
                                            : booking.subject,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                const StatusChip(
                                  label: 'قيد الانتظار',
                                  color: AppColors.statusPending,
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
                text: 'القبول يحجز المقعد ويضيف الطالب إلى المجموعة في خطوة '
                    'واحدة، ولا يمكن أن يتجاوز العدد السعة حتى لو قُبل طلبان '
                    'في اللحظة نفسها.',
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestsLoading extends StatelessWidget {
  const _RequestsLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
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

/// قائمة الطالب: طلباته هو، مع إمكانية إلغاء المعلّق.
class _StudentRequestsList extends StatelessWidget {
  const _StudentRequestsList({
    super.key,
    required this.studentId,
    required this.busyId,
    required this.onCancel,
  });

  final String studentId;
  final String? busyId;
  final Future<void> Function(GroupJoinRequest request) onCancel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AsyncView<List<GroupJoinRequest>>(
                load: () => AppServicesScope.of(
                  context,
                ).groups.listMyRequests(studentId),
                isEmpty: (List<GroupJoinRequest> items) => items.isEmpty,
                emptyBuilder: (BuildContext context) => const EmptyState(
                  icon: Icons.mark_email_unread_outlined,
                  title: 'لم تُرسل طلبات انضمام',
                  message: 'افتح أي مجموعة من تبويب «المجموعات» وأرسل طلب '
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
                            title: 'قيد المراجعة',
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
                                  isTeacher: false,
                                  busy: busyId == request.id,
                                  onCancel: () => onCancel(request),
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
                                  isTeacher: false,
                                  busy: false,
                                ),
                              ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          const InfoNote(
                            text: 'طلب الانضمام يحتاج موافقة المدرس. المقعد '
                                'يُحجز لحظة القبول فقط، لا لحظة إرسال الطلب.',
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
                const PillChip(
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
