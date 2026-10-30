import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/app_tab.dart';
import 'package:teacher_student_app/app/shell/shell_controller.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/core/widgets/user_avatar_view.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/booking_rules.dart';

/// تبويب «الطلبات» عند المدرس (P28) — **مصدر واحد لكل ما ينتظر قراره**.
///
/// ## لماذا دُمجت هنا طلبات الانضمام والحجز؟
///
/// كان تبويب «الطلبات» يعرض الحجوزات فقط، أما طلبات الانضمام فمكانها الوحيد
/// شاشة داخل كل مجموعة. فالمدرس الذي يرى «٣ طلبات» في الرئيسية لا يجد إلا
/// واحدًا في التبويب — تناقض يجعله يظن أن الطلب «ضاع». الشاشة الآن تجمع النوعين
/// في قائمة واحدة مرتّبة زمنيًا، مع مرشّح بالحالة، وتفتح كل طلب على تفاصيله حيث
/// تُنفَّذ القرارات (نفس المسارات القديمة، لا منطق مكرّر).
///
/// ## الحالات
///
/// `جديد` (بانتظار قرارك) → `قيد المراجعة` (اقترحت موعدًا بديلًا) →
/// `مقبول` / `مرفوض`. المرشّحات تقرأ من نفس الثوابت في المستودع، فلا تختلف
/// التسمية عن الحالة المخزَّنة.
class TeacherRequestsScreen extends StatefulWidget {
  const TeacherRequestsScreen({super.key});

  @override
  State<TeacherRequestsScreen> createState() => _TeacherRequestsScreenState();
}

/// أداة الترشيح — تُقرأ من الحالة الحقيقية للمستند.
enum _Filter {
  all('الكل'),
  pending('جديد'),
  review('قيد المراجعة'),
  accepted('مقبول'),
  rejected('مرفوض');

  const _Filter(this.label);

  final String label;
}

/// صف موحّد: حجز أو انضمام، بنفس الشكل حتى لا يبدو التطبيق تطبيقين.
class _RequestEntry {
  _RequestEntry({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.groupLabel,
    required this.subjectLine,
    required this.sentAt,
    required this.statusLabel,
    required this.statusColor,
    required this.filter,
    required this.isJoin,
    required this.raw,
  });

  final String id;
  final String studentId;
  final String studentName;

  /// اسم المجموعة (لطلب الانضمام) أو نوع الحجز (للحجز).
  final String groupLabel;

  /// المادة + المرحلة إن توفّرت — لا تُختلق إن غابت.
  final String subjectLine;

  final DateTime sentAt;
  final String statusLabel;
  final Color statusColor;
  final _Filter filter;
  final bool isJoin;
  final Object raw;
}

class _TeacherRequestsScreenState extends State<TeacherRequestsScreen> {
  _Filter _filter = _Filter.all;

  Future<void> _open(_RequestEntry entry) {
    if (entry.isJoin) {
      final GroupJoinRequest request = entry.raw as GroupJoinRequest;
      return Navigator.of(context).pushNamed(
        RoutePaths.groupRequests,
        arguments: request.groupId,
      );
    }
    return Navigator.of(context).pushNamed(
      RoutePaths.bookingDetails,
      arguments: entry.id,
    );
  }

  /// تسمية حالة قصيرة للبطاقة (النص الكامل يبقى في شاشة التفاصيل).
  static String _shortLabel(BookingStatus status) => switch (status) {
    BookingStatus.pending => 'بانتظار قرارك',
    BookingStatus.accepted => 'مقبول',
    BookingStatus.rejected => 'مرفوض',
    BookingStatus.cancelled => 'ملغى',
    BookingStatus.cancelledLate => 'ملغى متأخرًا',
    BookingStatus.rescheduleProposed => 'وقت بديل',
    BookingStatus.completed => 'منفّذ',
  };

  Color _bookingColor(BookingStatus status) => switch (status) {
    BookingStatus.pending => AppColors.statusPending,
    BookingStatus.accepted => AppColors.statusAccepted,
    BookingStatus.rejected => AppColors.statusRejected,
    BookingStatus.cancelled => AppColors.statusNeutral,
    BookingStatus.cancelledLate => AppColors.statusRejected,
    BookingStatus.rescheduleProposed => AppColors.statusInfo,
    BookingStatus.completed => AppColors.statusAccepted,
  };

  _Filter _bookingFilter(BookingStatus status) => switch (status) {
    BookingStatus.pending => _Filter.pending,
    BookingStatus.rescheduleProposed => _Filter.review,
    BookingStatus.accepted || BookingStatus.completed => _Filter.accepted,
    BookingStatus.rejected ||
    BookingStatus.cancelled ||
    BookingStatus.cancelledLate => _Filter.rejected,
  };

  _Filter _joinFilter(JoinRequestStatus status) => switch (status) {
    JoinRequestStatus.pending => _Filter.pending,
    JoinRequestStatus.accepted => _Filter.accepted,
    JoinRequestStatus.rejected => _Filter.rejected,
    // ألغاه الطالب: انتهى بلا قرار، فيُقرأ مع «مرفوض» لا «جديد».
    JoinRequestStatus.cancelled => _Filter.rejected,
  };

  List<_RequestEntry> _entries(
    List<BookingRequest> bookings,
    List<GroupJoinRequest> joins,
    Map<String, StudyGroup> groupsById,
  ) {
    final List<_RequestEntry> entries = <_RequestEntry>[];

    for (final BookingRequest booking in bookings) {
      entries.add(
        _RequestEntry(
          id: booking.id,
          studentId: booking.studentId ?? '',
          studentName: booking.studentName,
          groupLabel: 'حجز حصة',
          subjectLine: booking.hasSchedule
              ? '${booking.subject} · ${BookingRules.slotLabel(booking)}'
              : booking.subject,
          sentAt: booking.requestedAt,
          // تسمية قصيرة على البطاقة: النص الكامل («بانتظار موافقة المدرس»)
          // يفيض على شاشة 320dp ويقطع الاسم.
          statusLabel: _shortLabel(booking.status),
          statusColor: _bookingColor(booking.status),
          filter: _bookingFilter(booking.status),
          isJoin: false,
          raw: booking,
        ),
      );
    }

    for (final GroupJoinRequest request in joins) {
      final StudyGroup? group = groupsById[request.groupId];
      entries.add(
        _RequestEntry(
          id: request.id,
          studentId: request.studentId,
          studentName: request.studentName,
          groupLabel: group?.title ?? request.groupTitle,
          subjectLine: group == null
              ? 'طلب انضمام إلى مجموعة'
              : '${group.subject} · ${group.stage}',
          sentAt: request.requestedAt,
          statusLabel: switch (request.status) {
            JoinRequestStatus.pending => 'بانتظار قرارك',
            JoinRequestStatus.accepted => 'مقبول',
            JoinRequestStatus.rejected => 'مرفوض',
            JoinRequestStatus.cancelled => 'ألغاه الطالب',
          },
          statusColor: switch (request.status) {
            JoinRequestStatus.pending => AppColors.statusPending,
            JoinRequestStatus.accepted => AppColors.statusAccepted,
            JoinRequestStatus.rejected => AppColors.statusRejected,
            JoinRequestStatus.cancelled => AppColors.statusNeutral,
          },
          filter: _joinFilter(request.status),
          isJoin: true,
          raw: request,
        ),
      );
    }

    // الأحدث أولًا: ما وصل لتوّه يجب أن يُرى بلا تمرير.
    entries.sort((_RequestEntry a, _RequestEntry b) {
      final int byDate = b.sentAt.compareTo(a.sentAt);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final teacherId = CurrentTeacher.idOf(SessionScope.of(context));
    final services = AppServicesScope.of(context);

    return AsyncView<List<StudyGroup>>(
      load: () => services.groups.listForTeacher(teacherId),
      builder: (BuildContext context, List<StudyGroup> groups) {
        final Map<String, StudyGroup> groupsById = <String, StudyGroup>{
          for (final StudyGroup group in groups) group.id: group,
        };

        return StreamBuilder<List<GroupJoinRequest>>(
          // (P28) طلبات الانضمام تُقرأ من مستنداتها هي، لا من ملخّص في مجموعة.
          stream: services.groups.watchIncomingRequests(teacherId),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<GroupJoinRequest>> joinSnapshot,
          ) {
            return StreamBuilder<List<BookingRequest>>(
              stream: services.bookings.watchMine(),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<BookingRequest>> bookingSnapshot,
              ) {
                if (joinSnapshot.hasError || bookingSnapshot.hasError) {
                  return _ScaffoldBody(
                    filter: _filter,
                    onFilter: (f) => setState(() => _filter = f),
                    counts: const <_Filter, int>{},
                    child: const EmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'تعذّر تحميل الطلبات',
                      message:
                          'تحقّق من اتصالك بالإنترنت ثم أعد المحاولة — لم '
                          'يُفقد شيء من طلباتك.',
                    ),
                  );
                }
                if (!joinSnapshot.hasData || !bookingSnapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                // الحجوزات الواردة إليّ فقط — `watchMine` تُعيد ما يخصّني كطرفين.
                final List<BookingRequest> mine = bookingSnapshot.data!
                    .where((BookingRequest b) => b.teacherId == teacherId)
                    .toList(growable: false);

                final List<_RequestEntry> all = _entries(
                  mine,
                  joinSnapshot.data!,
                  groupsById,
                );

                final Map<_Filter, int> counts = <_Filter, int>{
                  for (final _Filter filter in _Filter.values)
                    filter: all
                        .where(
                          (_RequestEntry e) =>
                              filter == _Filter.all || e.filter == filter,
                        )
                        .length,
                };

                final List<_RequestEntry> visible = all
                    .where(
                      (_RequestEntry e) =>
                          _filter == _Filter.all || e.filter == _filter,
                    )
                    .toList(growable: false);

                return _ScaffoldBody(
                  filter: _filter,
                  onFilter: (f) => setState(() => _filter = f),
                  counts: counts,
                  child: visible.isEmpty
                      ? _EmptyForFilter(
                          filter: _filter,
                          total: all.length,
                          onShowAll: () =>
                              setState(() => _filter = _Filter.all),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (final _RequestEntry entry in visible)
                              Padding(
                                padding: AppSpacing.listGap,
                                child: _RequestCard(
                                  entry: entry,
                                  onTap: () => _open(entry),
                                ),
                              ),
                          ],
                        ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// الهيكل: عنوان + مرشّحات + المحتوى.
class _ScaffoldBody extends StatelessWidget {
  const _ScaffoldBody({
    required this.filter,
    required this.onFilter,
    required this.counts,
    required this.child,
  });

  final _Filter filter;
  final ValueChanged<_Filter> onFilter;
  final Map<_Filter, int> counts;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('الطلبات', style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                'طلبات الحجز والانضمام في مكان واحد · افتح الطلب للقرار',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // مرشّحات أفقية مضغوطة (P24: لا صفوف فلاتر ضخمة).
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (final _Filter option in _Filter.values) ...<Widget>[
                      if (option != _Filter.values.first)
                        const SizedBox(width: AppSpacing.xxs),
                      ChoiceChip(
                        key: Key('requests-filter-${option.name}'),
                        label: Text(
                          counts[option] == null
                              ? option.label
                              : '${option.label} (${counts[option]})',
                        ),
                        selected: filter == option,
                        onSelected: (_) => onFilter(option),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              child,
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }
}

/// فراغ عام (لا طلبات إطلاقًا) أو فراغ مرشّح (توجد طلبات بحالات أخرى).
class _EmptyForFilter extends StatelessWidget {
  const _EmptyForFilter({
    required this.filter,
    required this.total,
    required this.onShowAll,
  });

  final _Filter filter;
  final int total;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      final ShellController? shell = ShellScope.readOrNull(context);
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: 'لا توجد طلبات بعد',
        message:
            'سيظهر هنا كل طلب حجز أو طلب انضمام لحظة إرساله من الطالب، '
            'وستصلك إشعارات به.',
        primaryActionLabel: shell == null ? null : 'إدارة مجموعاتي',
        onPrimaryAction: shell == null
            ? null
            : () {
                shell.goTo(AppTab.groups);
              },
      );
    }

    return EmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: 'لا طلبات في «${filter.label}»',
      message: 'لديك $total طلبًا بحالات أخرى — اعرضها كلها.',
      primaryActionLabel: 'عرض كل الطلبات',
      onPrimaryAction: onShowAll,
    );
  }
}

/// بطاقة طلب: صورة الطالب + اسمه + المجموعة والمادة + تاريخ الإرسال + الحالة.
///
/// ترتيب المعلومات يتبع قرار المدرس: **من؟** ثم **على ماذا؟** ثم **متى؟**
/// ثم **الحالة**. لا معلومة مكرّرة، ولا صف يفيض على 320dp.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.entry, required this.onTap});

  final _RequestEntry entry;
  final VoidCallback onTap;

  String get _sentLabel {
    final String day = entry.sentAt.day.toString().padLeft(2, '0');
    final String month = entry.sentAt.month.toString().padLeft(2, '0');
    final String hour = entry.sentAt.hour.toString().padLeft(2, '0');
    final String minute = entry.sentAt.minute.toString().padLeft(2, '0');
    return '$day/$month/${entry.sentAt.year} · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      key: Key('request-card-${entry.isJoin ? 'join' : 'booking'}-${entry.id}'),
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UserAvatarLoader(
            userId: entry.studentId,
            initials: entry.studentName,
            size: AppSpacing.avatarMd,
            semanticLabel: 'صورة ${entry.studentName}',
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
                        entry.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Flexible(
                      child: StatusChip(
                        label: entry.statusLabel,
                        color: entry.statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  entry.groupLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  entry.subjectLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.schedule,
                      size: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'أُرسل $_sentLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    Text(
                      'التفاصيل',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      Icons.chevron_left,
                      size: 16,
                      color: theme.colorScheme.primary,
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
