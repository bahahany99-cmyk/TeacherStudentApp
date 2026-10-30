import 'dart:async';

import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/app_shell.dart';
import 'package:teacher_student_app/app/shell/app_tab.dart';
import 'package:teacher_student_app/app/shell/shell_controller.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/utils/greetings.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/user_avatar_view.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/featured_rules.dart';
import 'package:teacher_student_app/features/student/presentation/widgets/global_search_panel.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/featured_teachers_strip.dart';

/// الصفحة الرئيسية لواجهة الطالب — إعادة تصميم P25.
///
/// ## ترتيب الشاشة (وهو مقصود بالكامل)
///
/// 1. **رأس ذكي:** تحيّة حسب وقت اليوم + صورة الطالب + جرس الإشعارات بالعدّاد
///    الحيّ. كان الرأس بطاقة كبيرة بلا وظيفة؛ الآن سطران يحملان ما يهمّ فعلًا.
/// 2. **بحث شامل حيّ:** يبحث في المدرسين **والمجموعات** معًا نتيجة بكتابة
///    الحرف (انظر `GlobalSearchPanel`)، ويعرض النتائج تحت الحقل مباشرة.
///    أثناء وجود نص بحث تُخفى الأقسام — لا يقرأ الطالب قسمين في وقت واحد.
/// 3. **حبوب تنقّل سريعة:** المجموعات · البحث عن مدرس · المميزون.
/// 4. **المدرسون المميزون:** مبدّل [أونلاين]/[أوفلاين] وخمس بطاقات للشريحة
///    الواحدة (المجموع عشر أسبوعيًا — [FeaturedRules])، وزر «عرض الكل» يفتح
///    شاشة كاملة.
/// 5. **نشاطك:** مجموعاتك المقبولة وحجوزاتك القادمة، أو حالة فراغ مهذّبة.
///
/// ## ما لم يتغيّر ولماذا
/// البحث عند الإرسال ما زال ينتقل إلى قسم المدرسين (اختبار P18) — لكنه لم يبقَ
/// **الطريق الوحيد**: النتائج تُعرض الآن في مكانها. الانتقال مزايا إضافية
/// (فلترة وترتيب كاملان) لا بديل عن رؤية النتائج.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key, this.now});

  /// حقن الوقت للاختبار (التحيّة والاختيار الأسبوعي حتميان بذلك).
  final DateTime? now;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final TextEditingController _search = TextEditingController();

  /// نص البحث **المُستقرّ** (بعد مهلة الكتابة) — لا نص الحرف الأخير.
  String _committedQuery = '';

  /// هل الحقل غير فارغ؟ (لزرّ المسح وحده — لا يُشغّل استعلامًا.)
  bool _hasText = false;

  /// مهلة قصيرة: البحث في Firestore عند كل حرف يعني طلبًا لكل ضغطة، ويُظهر
  /// نتائج «لا شيء» بينما الطالب ما زال يكتب.
  Timer? _debounce;
  static const Duration _debounceDelay = Duration(milliseconds: 350);

  int _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onQueryChanged);
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final String raw = _search.text.trim();
    final bool hasText = raw.isNotEmpty;
    _debounce?.cancel();
    if (hasText != _hasText) {
      // زرّ المسح يظهر/يختفي فورًا لا بعد مهلة البحث.
      setState(() => _hasText = hasText);
    }
    if (!hasText) {
      // إفراغ فوري بلا مهلة: الطالب محا الحقل، فلا معنى لإبقاء نتائج قديمة.
      if (_committedQuery.isNotEmpty) {
        setState(() => _committedQuery = '');
      }
      return;
    }
    _debounce = Timer(_debounceDelay, () {
      if (!mounted || _committedQuery == raw) {
        return;
      }
      setState(() => _committedQuery = raw);
    });
  }

  void _go(AppTab tab) => ShellScope.readOrNull(context)?.goTo(tab);

  void _openFeatured() => Navigator.of(
    context,
  ).pushNamed(RoutePaths.featuredTeachers);

  /// الإرسال ينقل إلى قسم المدرسين بالفلتر الكامل (الترتيب/المادة/المرحلة).
  void _submitSearch() {
    final String query = _search.text.trim();
    final ShellController? shell = ShellScope.readOrNull(context);
    if (shell == null) {
      return;
    }
    shell.openTeachers(query: query);
    _search.clear();
    if (mounted) {
      setState(() {
        _committedQuery = '';
        _hasText = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshToken++);
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  /// مجموعة المميزين: المميزون + كل الموثّقين (مكرّرة بالمعرّف، والمميّز يفوز).
  ///
  /// **لماذا الموثّقون أيضًا؟** المطلوب عشر بطاقات أسبوعيًا؛ في أسبوع يكون فيه
  /// مميزان فقط كانت الشاشة تعرض بطاقتين وثمانية فراغات. الموثّق مرشّح شرعي،
  /// والتمييز أولوية عرض لا شرط ظهور.
  Future<List<TeacherProfile>> _loadFeaturedPool() async {
    final services = AppServicesScope.of(context);
    final (List<TeacherProfile> verified, List<TeacherProfile> featured) = await (
      services.teachers.listVerified(),
      services.teachers.listFeatured(),
    ).wait;

    final Map<String, TeacherProfile> byId = <String, TeacherProfile>{
      for (final TeacherProfile teacher in verified) teacher.id: teacher,
      for (final TeacherProfile teacher in featured) teacher.id: teacher,
    };
    return byId.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SessionController session = SessionScope.of(context);
    final String name = session.user?.displayName ?? 'طالب';
    final String studentId = CurrentStudent.idOf(session);
    final String? viewerId = session.user?.id;
    final String? avatarId =
        (session.user?.isDemoAccount ?? true) ? null : viewerId;
    final DateTime now = widget.now ?? DateTime.now();
    final bool searching = _committedQuery.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: <Widget>[
          ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _HomeHeader(
                  name: name,
                  userId: avatarId,
                  initialsFallback: name,
                  now: now,
                  notificationBell: viewerId == null
                      ? null
                      : NotificationBell(viewerId: viewerId),
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── البحث الشامل ──────────────────────────────────────────
                TextField(
                  key: homeSearchFieldKey,
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submitSearch(),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 4,
                    ),
                    hintText: 'ابحث عن مدرس أو مجموعة أو مادة',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: !_hasText
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _search.clear();
                              FocusScope.of(context).unfocus();
                            },
                          ),
                  ),
                ),

                if (searching) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  GlobalSearchPanel(
                    query: _committedQuery,
                    onTeacherTap: (TeacherProfile teacher) =>
                        Navigator.of(context).pushNamed(
                          RoutePaths.teacherProfile,
                          arguments: teacher.id,
                        ),
                    onGroupTap: (StudyGroup group) => Navigator.of(context)
                        .pushNamed(
                          RoutePaths.groupDetails,
                          arguments: group.id,
                        ),
                    onSeeAllTeachers: _submitSearch,
                    onSeeAllGroups: () => _go(AppTab.groups),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ] else ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  // ── حبوب التنقّل السريع ─────────────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        PillChip(
                          key: const Key('home-quick-groups'),
                          icon: Icons.groups_outlined,
                          label: 'المجموعات',
                          onTap: () => _go(AppTab.groups),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        PillChip(
                          key: const Key('home-quick-teachers'),
                          icon: Icons.person_search_outlined,
                          label: 'ابحث عن مدرس',
                          onTap: () => _go(AppTab.teachers),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        PillChip(
                          key: const Key('home-quick-featured'),
                          icon: Icons.workspace_premium_outlined,
                          label: 'المميزون',
                          onTap: _openFeatured,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── المميزون: عشر بطاقات أسبوعية بمبدّل شرائح ───────────
                  SectionHeader(
                    title: 'مدرسون مميزون',
                    subtitle: 'خمسة أونلاين وخمسة أوفلاين — تتجدّد أسبوعيًا',
                    icon: Icons.workspace_premium_outlined,
                    actionLabel: 'عرض الكل',
                    onActionTap: _openFeatured,
                  ),
                  AsyncView<List<TeacherProfile>>(
                    reloadKey: _refreshToken,
                    keepPreviousData: true,
                    load: _loadFeaturedPool,
                    builder:
                        (
                          BuildContext context,
                          List<TeacherProfile> pool,
                        ) {
                          final FeaturedSelection selection =
                              FeaturedRules.selectWeekly(pool, now: now);
                          if (selection.isEmpty) {
                            return const EmptyState(
                              icon: Icons.workspace_premium_outlined,
                              title: 'لا يوجد مدرسون موثّقون بعد',
                              message: 'سيظهر هنا المدرسون الموثّقون فور '
                                  'اعتماد ملفاتهم.',
                            );
                          }
                          return FeaturedTeachersStrip(
                            selection: selection,
                            onViewAll: _openFeatured,
                            onTeacherTap: (TeacherProfile teacher) =>
                                Navigator.of(context).pushNamed(
                                  RoutePaths.teacherProfile,
                                  arguments: teacher.id,
                                ),
                          );
                        },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── نشاطك: المجموعات ثم الحجوزات ───────────────────────
                  const SectionHeader(
                    title: 'نشاطك',
                    subtitle: 'مجموعاتك المقبولة وحجوزاتك القادمة',
                    icon: Icons.insights_outlined,
                  ),
                  Text(
                    'مجموعاتي',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  AsyncView<List<GroupJoinRequest>>(
                    reloadKey: _refreshToken,
                    keepPreviousData: true,
                    load: () => AppServicesScope.of(
                      context,
                    ).groups.listMyRequests(studentId),
                    builder:
                        (
                          BuildContext context,
                          List<GroupJoinRequest> requests,
                        ) {
                          // العضوية تُقرأ من الحقيقة: طلب **مقبول** = عضو
                          // (القبول ينشئ مستند العضوية في المعاملة نفسها).
                          final List<GroupJoinRequest> mine = requests
                              .where(
                                (GroupJoinRequest r) =>
                                    r.status == JoinRequestStatus.accepted,
                              )
                              .take(2)
                              .toList(growable: false);
                          if (mine.isEmpty) {
                            return EmptyState(
                              icon: Icons.groups_outlined,
                              title: 'لا مجموعات بعد',
                              message: 'تصفّح المجموعات المتاحة واطلب '
                                  'الانضمام إلى ما يناسبك.',
                              actionLabel: 'تصفّح المجموعات',
                              onActionTap: () => _go(AppTab.groups),
                            );
                          }
                          return Column(
                            children: <Widget>[
                              for (final GroupJoinRequest group in mine)
                                Padding(
                                  padding: AppSpacing.listGap,
                                  child: AppCard(
                                    onTap: () => _go(AppTab.groups),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.groups_rounded,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Expanded(
                                          child: Text(
                                            group.groupTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleMedium,
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_left,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
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
                  Text(
                    'حجوزاتي القادمة',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  AsyncView<List<BookingRequest>>(
                    reloadKey: _refreshToken,
                    keepPreviousData: true,
                    load: () =>
                        AppServicesScope.of(context).bookings.listMine(),
                    builder:
                        (
                          BuildContext context,
                          List<BookingRequest> bookings,
                        ) {
                          // (P25) لا نعرض «قيد الانتظار» فقط: بعد موافقة
                          // المدرس يصبح الحجز «مقبولًا»، وكانت الرئيسية تُخفي
                          // كل ما ليس قيد الانتظار فيظهر الفراغ وكأن القبول
                          // ألغى الحجز. الترتيب: ما يحتاج انتباهًا أولًا.
                          final List<BookingRequest> next = bookings
                              .where(
                                (BookingRequest b) =>
                                    b.waitingForTeacher ||
                                    b.status == BookingStatus.accepted,
                              )
                              .take(2)
                              .toList(growable: false);
                          if (next.isEmpty) {
                            return const EmptyState(
                              icon: Icons.event_available_outlined,
                              title: 'لا توجد حجوزات قادمة',
                              message: 'سيظهر هنا أي حجز طلبته أو قبله مدرسك.',
                            );
                          }
                          return Column(
                            children: next
                                .map(
                                  (BookingRequest b) => Padding(
                                    padding: AppSpacing.listGap,
                                    child: AppCard(
                                      onTap: () => _go(AppTab.bookings),
                                      child: Row(
                                        children: <Widget>[
                                          Icon(
                                            b.waitingForTeacher
                                                ? Icons.schedule_outlined
                                                : Icons.event_available_rounded,
                                            color: b.waitingForTeacher
                                                ? AppColors.statusPending
                                                : AppColors.statusAccepted,
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text(
                                                  b.teacherName,
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium,
                                                ),
                                                Text(
                                                  b.subject,
                                                  style: theme.textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            b.status.label,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: b.waitingForTeacher
                                                      ? AppColors.statusPending
                                                      : AppColors
                                                            .statusAccepted,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          );
                        },
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// مفتاح حقل البحث في الرئيسية — تثبته الاختبارات.
const Key homeSearchFieldKey = Key('home-search-field');

/// رأس الرئيسية: تحيّة + صورة + جرس إشعارات.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.name,
    required this.userId,
    required this.initialsFallback,
    required this.now,
    required this.notificationBell,
  });

  final String name;

  /// معرّف المستخدم لتحميل صورته. `null` = لا نعرف (جلسة تجريبية أو مستخدم
  /// غير محمّل) فنعرض الحرف الأول بدل طلب صورة بمعرّف فارغ.
  final String? userId;
  final String initialsFallback;
  final DateTime now;
  final Widget? notificationBell;

  String get _initial {
    final String trimmed = initialsFallback.trim();
    return trimmed.isEmpty ? '؟' : trimmed.substring(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        if (userId != null)
          UserAvatarLoader(
            userId: userId!,
            initials: _initial,
            size: AppSpacing.avatarSm + 6,
            semanticLabel: 'صورتك',
          )
        else
          Container(
            width: AppSpacing.avatarSm + 6,
            height: AppSpacing.avatarSm + 6,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(24),
              shape: BoxShape.circle,
            ),
            child: Text(
              _initial,
              style: theme.textTheme.titleSmall?.copyWith(
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
                '${Greetings.lineFor(now)}، $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                Greetings.subtitleFor(now),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (notificationBell != null) notificationBell!,
      ],
    );
  }
}
