import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/app_tab.dart';
import 'package:teacher_student_app/app/shell/shell_controller.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
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

    if (!session.isSignedIn || role == null || !role.isEndUser) {
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
            child: Scaffold(
              appBar: AppBar(
                title: Text(currentSpec.label),
                actions: <Widget>[
                  if (effectiveTab != firstTab)
                    IconButton(
                      tooltip: 'الرئيسية',
                      onPressed: () => _shell.goTo(firstTab),
                      icon: const Icon(Icons.home_outlined),
                    ),
                  if (session.isDemoSession)
                    const Padding(
                      padding: EdgeInsetsDirectional.only(end: AppSpacing.md),
                      child: Tooltip(
                        message: 'وضع تجريبي — بلا Firebase',
                        child: Icon(Icons.science_outlined, size: 20),
                      ),
                    ),
                ],
              ),
              body: SafeArea(
                child: IndexedStack(
                  index: index < 0 ? 0 : index,
                  children: <Widget>[
                    for (final AppTabSpec spec in specs)
                      _pageFor(spec.tab, role),
                  ],
                ),
              ),
              bottomNavigationBar: NavigationBar(
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
          ? const GroupsScreen.forTeacher(
              key: ValueKey<String>('tab-groups'),
              teacherId: DemoData.demoTeacherId,
            )
          : const GroupsScreen.discover(key: ValueKey<String>('tab-groups')),
      AppTab.bookings => BookingsScreen(
        key: const ValueKey<String>('tab-bookings'),
        viewerRole: role,
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
