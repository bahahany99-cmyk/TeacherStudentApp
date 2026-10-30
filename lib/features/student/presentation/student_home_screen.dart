import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
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
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/featured_teachers_carousel.dart';

/// الصفحة الرئيسية لواجهة الطالب.
///
/// ## (P18) إعادة تصميم: بحث حقيقي وتعظيم المحتوى
///
/// قبل الإصلاح كانت الرئيسية تحتوي حقلًا **معطّلًا** (`enabled: false`) بنص
/// «غير مفعّل في هذه المرحلة»: مساحة كبيرة تُهدر، وإشارة إلى ميزة غير موجودة.
/// الآن:
///
/// 1. **البحث يعمل فعلًا.** الكتابة ثم الإرسال (أو زر البحث) تنتقل إلى قسم
///    المدرسين وتُسلّم النص عبر `ShellController.openTeachers`، فيطبّقه حقل
///    البحث الحقيقي هناك ويُنفّذ استعلامًا فعليًا. لا منطق بحث مكرّر هنا.
/// 2. **مساحة أقل للرأس.** بطاقة الترحيب صارت سطرًا واحدًا، و«الاختصارات»
///    صارت صفًا أفقيًا واحدًا قابلًا للتمرير بلا عنوان ولا بطاقة.
/// 3. **«مجموعاتي» ظهرت.** كانت غائبة تمامًا من الرئيسية، وهي الآن قسم فعلي
///    يقرأ عضويات الطالب من طلبات الانضمام المقبولة (نفس مصدر شاشة
///    المجموعات)، لا بيانات تجريبية محلية في الشاشة.
///
/// الترتيب مقصود: المميزون ثم مجموعاتي ثم الحجوزات — وهي الأقسام التي طلب
/// المستخدم إبرازها.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final TextEditingController _search = TextEditingController();

  /// يُغيَّر عند السحب للتحديث لإجبار الأقسام الثلاثة على إعادة القراءة.
  ///
  /// **لماذا هذا لازم في الجلسة الحقيقية؟** الهيكل يستخدم `IndexedStack`، فقسم
  /// الرئيسية يبقى حيًّا ولا يُعاد بناؤه عند العودة إليه. بلا هذا، يبقى
  /// «حجوزاتي» و«مجموعاتي» كما كانا عند أول تشغيل — وقد يبدو ذلك «بيانات
  /// ناقصة» أو حالة فراغ دائمة لحساب حقيقي بينما البيانات موجودة في الخادم.
  int _refreshToken = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// تنقّل داخل الهيكل بلا افتراض وجوده (الشاشة تُختبر منفردة أيضًا).
  void _go(AppTab tab) => ShellScope.readOrNull(context)?.goTo(tab);

  /// البحث: يُسلّم النص إلى قسم المدرسين حيث محرّك البحث الحقيقي.
  ///
  /// النص الفارغ يعني «افتح قسم المدرسين» فقط — لا نُرسل طلب بحث فارغًا.
  void _submitSearch() {
    final String query = _search.text.trim();
    final ShellController? shell = ShellScope.readOrNull(context);
    if (shell == null) {
      return;
    }
    shell.openTeachers(query: query);
    // إفراغ الحقل بعد الانتقال: العودة إلى الرئيسية يجب ألّا تُظهر بحثًا
    // قديمًا وكأنه حالة محفوظة.
    _search.clear();
    if (mounted) {
      setState(() {});
    }
  }

  /// سحب للتحديث: كل قسم يعيد قراءته من مصدره الحقيقي.
  ///
  /// لا نُعيد بناء الشاشة من الصفر (تفقد التمرير)، بل نغيّر مفتاح إعادة
  /// الجلب: كل `AsyncView` يعيد الطلب ويُبقي المعروض حتى تصل البيانات الجديدة.
  Future<void> _refresh() async {
    setState(() => _refreshToken++);
    // مهلة قصيرة: كل قسم بدأ طلبه ويعرض مؤشره الخاص؛ إبقاء دوّارة السحب
    // مفتوحة حتى نهاية الطلبات يحتاج لمسك مستقبلاتها، وهي ملك لكل `AsyncView`.
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SessionController session = SessionScope.of(context);
    final String name = session.user?.displayName ?? 'طالب';
    final String studentId = CurrentStudent.idOf(session);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        // السحب للتحديث يعمل حتى لو كان المحتوى أقصر من الشاشة.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: <Widget>[
          ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ── رأس مُدمج: سطر واحد بدل بطاقة كبيرة ────────────────────
                Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(24),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Icon(
                        Icons.school_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'أهلًا $name',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'جاهز لحصة اليوم؟',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── بحث حقيقي ومُدمج: سطر واحد، ينقل إلى قسم المدرسين ──────
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submitSearch(),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 4,
                    ),
                    hintText: 'ابحث باسم المدرس أو المادة',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    // (P18) حشو صفري: الزر الافتراضي 48×48 يفرض ارتفاعًا أكبر
                    // من بقية السطر فيفقد الحقل صفته «المدمجة».
                    suffixIcon: IconButton(
                      tooltip: 'بحث',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      onPressed: _submitSearch,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── اختصارات: صف أفقي واحد بلا بطاقة ولا عنوان ─────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _ShortcutChip(
                        icon: Icons.person_search_outlined,
                        label: 'ابحث عن مدرس',
                        onTap: () => _go(AppTab.teachers),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _ShortcutChip(
                        icon: Icons.groups_outlined,
                        label: 'المجموعات الدراسية',
                        onTap: () => _go(AppTab.groups),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _ShortcutChip(
                        icon: Icons.event_note_outlined,
                        label: 'حجوزاتي',
                        onTap: () => _go(AppTab.bookings),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── 1) مدرسون مميزون (القسم الأبرز) ───────────────────────
                SectionHeader(
                  title: 'مدرسون مميزون',
                  subtitle: 'قسم مستقل عن نتائج البحث العادي',
                  actionLabel: 'عرض الكل',
                  onActionTap: () => _go(AppTab.teachers),
                ),
                AsyncView<List<TeacherProfile>>(
                  reloadKey: _refreshToken,
                  keepPreviousData: true,
                  load: () =>
                      AppServicesScope.of(context).teachers.listFeatured(),
                  builder:
                      (BuildContext context, List<TeacherProfile> teachers) {
                    if (teachers.isEmpty) {
                      return const EmptyState(
                        icon: Icons.workspace_premium_outlined,
                        title: 'لا يوجد مدرسون مميزون حاليًا',
                      );
                    }
                    return FeaturedTeachersCarousel(
                      teachers: teachers,
                      onTeacherTap: (TeacherProfile teacher) =>
                          Navigator.of(context).pushNamed(
                            RoutePaths.teacherProfile,
                            arguments: teacher.id,
                          ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // ── 2) مجموعاتي ───────────────────────────────────────────
                SectionHeader(
                  title: 'مجموعاتي',
                  subtitle: 'المجموعات التي قُبل انضمامك إليها',
                  actionLabel: 'عرض الكل',
                  onActionTap: () => _go(AppTab.groups),
                ),
                AsyncView<List<GroupJoinRequest>>(
                  reloadKey: _refreshToken,
                  keepPreviousData: true,
                  load: () => AppServicesScope.of(
                    context,
                  ).groups.listMyRequests(studentId),
                  builder:
                      (BuildContext context, List<GroupJoinRequest> requests) {
                        // العضوية تُقرأ من الحقيقة نفسها: طلب انضمام **مقبول**
                        // يعني عضوًا في المجموعة (القبول ينشئ مستند العضوية في
                        // المعاملة نفسها). لا قائمة محلية مزيّفة هنا.
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
                            message: 'تصفّح المجموعات المتاحة واطلب الانضمام '
                                'إلى ما يناسبك.',
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
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                ),
                const SizedBox(height: AppSpacing.md),

                // ── 3) حجوزاتي القادمة ────────────────────────────────────
                const SectionHeader(title: 'حجوزاتي القادمة'),
                AsyncView<List<BookingRequest>>(
                  reloadKey: _refreshToken,
                  keepPreviousData: true,
                  load: () => AppServicesScope.of(context).bookings.listMine(),
                  builder:
                      (BuildContext context, List<BookingRequest> bookings) {
                    final List<BookingRequest> pending = bookings
                        .where((BookingRequest b) => b.waitingForTeacher)
                        .take(2)
                        .toList(growable: false);
                    if (pending.isEmpty) {
                      return const EmptyState(
                        icon: Icons.event_available_outlined,
                        title: 'لا توجد حجوزات قيد الانتظار',
                        message: 'سيظهر هنا أي طلب حجز بانتظار موافقة المدرس.',
                      );
                    }
                    return Column(
                      children: pending
                          .map(
                            (BookingRequest b) => Padding(
                              padding: AppSpacing.listGap,
                              child: AppCard(
                                onTap: () => _go(AppTab.bookings),
                                child: Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.schedule_outlined,
                                      color: AppColors.statusPending,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            b.teacherName,
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          Text(
                                            b.subject,
                                            style: theme.textTheme.labelSmall
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
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: AppColors.statusPending,
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
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// اختصار في الرئيسية ينقل إلى قسم آخر داخل الهيكل (بلا تكرار لمنطق التنقل).
class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelSmall,
      onPressed: onTap,
    );
  }
}
