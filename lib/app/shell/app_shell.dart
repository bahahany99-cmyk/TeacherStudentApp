import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/app_tab.dart';
import 'package:teacher_student_app/app/shell/shell_controller.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:teacher_student_app/features/admin/presentation/moderation_screen.dart';
import 'package:teacher_student_app/features/admin/presentation/teacher_verification_screen.dart';
import 'package:teacher_student_app/features/bookings/presentation/bookings_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/groups_screen.dart';
import 'package:teacher_student_app/features/profile/presentation/profile_screen.dart';
import 'package:teacher_student_app/features/student/presentation/student_home_screen.dart';
import 'package:teacher_student_app/features/teacher/presentation/teacher_home_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/teachers_screen.dart';

/// الهيكل الرئيسي بعد تسجيل الدخول.
///
/// المسؤوليات:
/// - شريط تنقّل يختلف حسب الدور (المصدر: [AppTabs]).
/// - الحفاظ على حالة كل قسم عبر `IndexedStack` (لا يُعاد بناء القسم عند التبديل).
/// - سلوك رجوع واحد: من أي قسم غير الرئيسية → العودة للرئيسية؛ ومن الرئيسية →
///   الخروج من التطبيق (بعد تأكيد قصير أول مرة).
///
/// ملاحظة أمنية: الفصل بين تجربتي الطالب والمدرس **للتجربة فقط**؛ الصلاحيات
/// الحقيقية تُفرض على الخادم، وليست بإخفاء تبويب هنا.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final ShellController _shell;
  bool _exitHintShown = false;

  @override
  void initState() {
    super.initState();
    _shell = ShellController();
  }

  @override
  void dispose() {
    _shell.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = SessionScope.of(context);
    final UserRole? role = session.role;

    if (session.needsRoleSelection) {
      return const _RoleChoiceRequiredScreen();
    }

    // (P14) الدور الإداري مسموح **فقط** لجلسة تحمل صلاحية إدارية حقيقية؛
    // وإلا فدور غير معروف = جلسة غير صالحة لهذا الهيكل.
    final bool adminAllowed = role == UserRole.admin && session.isAdmin;
    if (!session.isSignedIn ||
        role == null ||
        (!role.isEndUser && !adminAllowed)) {
      return const _SessionRequiredScreen();
    }

    final List<AppTabSpec> specs = AppTabs.forRole(role);
    final AppTab firstTab = specs.first.tab;

    return ShellScope(
      controller: _shell,
      child: AnimatedBuilder(
        animation: _shell,
        builder: (BuildContext context, Widget? _) {
          // إن لم يكن القسم الحالي متاحًا لهذا الدور (مثلًا بعد تبديل واجهة
          // المعاينة)، نعرض الرئيسية دون تعديل الحالة أثناء البناء.
          final bool allowed = specs.any(
            (AppTabSpec spec) => spec.tab == _shell.current,
          );
          final AppTab effectiveTab = allowed ? _shell.current : firstTab;
          final int index = specs.indexWhere(
            (AppTabSpec spec) => spec.tab == effectiveTab,
          );
          final AppTabSpec currentSpec = specs[index < 0 ? 0 : index];

          final String viewerId = switch (role) {
            UserRole.teacher => CurrentTeacher.idOf(session),
            UserRole.student => CurrentStudent.idOf(session),
            // جرس الإدارة يقرأ إشعارات حساب المسؤول نفسه إن وُجدت.
            UserRole.admin => session.user?.id ?? '',
          };

          return PopScope(
            // نعترض الرجوع دائمًا لتنفيذ سلوك واحد واضح:
            // - من قسم غير الرئيسية → العودة للرئيسية.
            // - من الرئيسية → تلميح أول مرة، ثم خروج فعلي في المرة الثانية.
            canPop: false,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (didPop) {
                return;
              }

              if (effectiveTab != firstTab) {
                _shell.goTo(firstTab);
                return;
              }

              if (!_exitHintShown) {
                setState(() {
                  _exitHintShown = true;
                });
                AppSnackBar.show(
                  context,
                  'اضغط رجوع مرة أخرى للخروج من التطبيق',
                  type: AppMessageType.info,
                );
                return;
              }

              SystemNavigator.pop();
            },
            // الخلفية المتدرّجة عالمية الآن (MaterialApp.builder)، فالـScaffold
            // هنا شفاف ويعرضها. لا نكرّر التدرّج محليًا.
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Text(currentSpec.label),
                actions: <Widget>[
                  // جرس الإشعارات (P12): عدّاد حيّ من الخادم، والقيمة 0 تُخفي
                  // الوسم بدل عرض «0».
                  NotificationBell(viewerId: viewerId),
                  if (effectiveTab != firstTab)
                    IconButton(
                      tooltip: 'الرئيسية',
                      onPressed: () => _shell.goTo(firstTab),
                      icon: const Icon(Icons.home_outlined),
                    ),
                  // (P21) جلسة استعراض: وسم قصير بلغة المنتج لا لغة التطوير.
                  // يبقى ظاهرًا لأن ما يراه المستخدم أمثلة توضيحية، وإخفاؤه
                  // التام سيجعل أمثلةً وهمية تبدو بيانات حقيقية.
                  if (session.isDemoSession)
                    const Padding(
                      padding: EdgeInsetsDirectional.only(end: AppSpacing.md),
                      child: Tooltip(
                        message: 'جولة تعريفية بأمثلة توضيحية — أنشئ حسابًا '
                            'لحفظ بياناتك',
                        child: StatusChip(
                          label: 'جولة',
                          color: AppColors.attentionForeground,
                        ),
                      ),
                    ),
                ],
              ),
              body: SafeArea(
                bottom: false,
                child: IndexedStack(
                  index: index < 0 ? 0 : index,
                  children: <Widget>[
                    for (final AppTabSpec spec in specs)
                      _pageFor(spec.tab, role),
                  ],
                ),
              ),
              // شريط التنقّل: خلفية بيضاء تمتد تحت شريط النظام (SafeArea سفلية
              // داخلية) حتى لا تظهر فجوة سوداء أسفل الشاشة.
              bottomNavigationBar: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).navigationBarTheme.backgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withAlpha(120),
                      width: 0.8,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: NavigationBar(
                    selectedIndex: index < 0 ? 0 : index,
                    onDestinationSelected: (int selected) =>
                        _shell.goTo(specs[selected].tab),
                    destinations: <Widget>[
                      for (final AppTabSpec spec in specs)
                        NavigationDestination(
                          icon: Icon(spec.icon),
                          selectedIcon: Icon(spec.selectedIcon),
                          label: spec.label,
                          tooltip: spec.label,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// يربط كل قسم بشاشته. المفتاح ثابت حتى لا يُعاد بناء القسم عند كل تبديل.
  Widget _pageFor(AppTab tab, UserRole role) {
    return switch (tab) {
      AppTab.home => role == UserRole.teacher
          ? const TeacherHomeScreen(key: ValueKey<String>('tab-home'))
          : const StudentHomeScreen(key: ValueKey<String>('tab-home')),
      AppTab.teachers => const TeachersScreen(key: ValueKey<String>('tab-teachers')),
      AppTab.groups => role == UserRole.teacher
          ? const GroupsScreen.forTeacher(key: ValueKey<String>('tab-groups'))
          : const GroupsScreen.discover(key: ValueKey<String>('tab-groups')),
      AppTab.bookings => BookingsScreen(
        key: const ValueKey<String>('tab-bookings'),
        viewerRole: role,
      ),
      // (P14) أقسام الإدارة: نفس الشاشات التي تفتحها المسارات المحمية.
      AppTab.adminHome => const AdminDashboardScreen(
        key: ValueKey<String>('tab-admin-home'),
      ),
      AppTab.adminVerification => const TeacherVerificationScreen(
        key: ValueKey<String>('tab-admin-verification'),
      ),
      AppTab.adminModeration => const ModerationScreen(
        key: ValueKey<String>('tab-admin-moderation'),
      ),
      AppTab.profile => const ProfileScreen(key: ValueKey<String>('tab-profile')),
    };
  }
}

/// تُعرض إذا كان الحساب مسجّلًا لكنه لم يختر دوره بعد.
///
/// لا نعرض الهيكل بدور مفترض: الدور قرار يُحفظ في الخادم، لا تخمين في الواجهة.
class _RoleChoiceRequiredScreen extends StatelessWidget {
  const _RoleChoiceRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: EmptyState(
            icon: Icons.badge_outlined,
            title: 'اختر نوع الحساب',
            message: 'ينقص حسابك خطوة واحدة: تحديد إن كنت طالبًا أم مدرسًا.',
            actionLabel: 'اختيار نوع الحساب',
            onActionTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
              RoutePaths.roleSelection,
              (Route<dynamic> route) => false,
            ),
          ),
        ),
      ),
    );
  }
}

/// تُعرض إذا فُتح الهيكل بدون جلسة صالحة (مثلًا بعد تسجيل الخروج).
class _SessionRequiredScreen extends StatelessWidget {
  const _SessionRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: EmptyState(
            icon: Icons.lock_outline,
            title: 'الجلسة غير متاحة',
            message: 'سجّل الدخول للمتابعة.',
            actionLabel: 'تسجيل الدخول',
            onActionTap: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                RoutePaths.login,
                (Route<dynamic> route) => false,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// جرس الإشعارات مع عدّاد غير المقروء (P12).
///
/// **لماذا لا يُبنى داخل الشاشة؟** لأن العدّاد يجب أن يظهر في كل الأقسام،
/// وتحديثه يجب أن يبقى واحدًا لا نسخة لكل قسم. يستمع إلى عدّاد صغير من
/// الخادم (`recipientId` + `readAt == null`) ويعرض وسمًا عند وجود جديد.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.viewerId});

  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return StreamBuilder<int>(
      stream: AppServicesScope.of(
        context,
      ).notifications.watchUnreadCount(viewerId),
      initialData: 0,
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        final int count = snapshot.data ?? 0;

        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            IconButton(
              tooltip: count == 0 ? 'الإشعارات' : 'الإشعارات ($count غير مقروء)',
              onPressed: () => Navigator.of(
                context,
              ).pushNamed(RoutePaths.notifications),
              icon: const Icon(Icons.notifications_none),
            ),
            if (count > 0)
              PositionedDirectional(
                top: 8,
                end: 6,
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusPill,
                      ),
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                    child: Text(
                      // أكثر من 9 يُعرض «9+» حتى لا يتضخّم الوسم.
                      count > 9 ? '9+' : '$count',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
