import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/features/bookings/presentation/bookings_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/groups_screen.dart';
import 'package:teacher_student_app/features/profile/presentation/profile_screen.dart';
import 'package:teacher_student_app/features/student/presentation/student_home_screen.dart';
import 'package:teacher_student_app/features/teacher/presentation/teacher_home_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/teachers_screen.dart';

/// عنصر تنقّل واحد داخل التطبيق.
class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}

/// الهيكل الرئيسي بعد تسجيل الدخول.
///
/// يفصل تجربة الطالب عن تجربة المدرس عبر قائمة تنقّل مختلفة لكل دور.
/// ملاحظة أمنية: هذا الفصل **للتجربة فقط**؛ الوصول الحقيقي إلى بيانات الأدوار
/// يُفرض على الخادم، وليس بإخفاء تبويب هنا.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  List<_Destination> _destinationsFor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return <_Destination>[
          _Destination(
            label: 'الرئيسية',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            builder: (BuildContext context) => const StudentHomeScreen(),
          ),
          _Destination(
            label: 'المدرسون',
            icon: Icons.person_search_outlined,
            selectedIcon: Icons.person_search_rounded,
            builder: (BuildContext context) => const TeachersScreen(),
          ),
          _Destination(
            label: 'المجموعات',
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups_rounded,
            builder: (BuildContext context) => const GroupsScreen.discover(),
          ),
          _Destination(
            label: 'الحجوزات',
            icon: Icons.event_note_outlined,
            selectedIcon: Icons.event_note_rounded,
            builder: (BuildContext context) =>
                const BookingsScreen(viewerRole: UserRole.student),
          ),
          _Destination(
            label: 'حسابي',
            icon: Icons.account_circle_outlined,
            selectedIcon: Icons.account_circle_rounded,
            builder: (BuildContext context) => const ProfileScreen(),
          ),
        ];
      case UserRole.teacher:
        return <_Destination>[
          _Destination(
            label: 'الرئيسية',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            builder: (BuildContext context) => const TeacherHomeScreen(),
          ),
          _Destination(
            label: 'مجموعاتي',
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups_rounded,
            // في المرحلة 2 نستخدم معرف المدرس التجريبي.
            builder: (BuildContext context) =>
                const GroupsScreen.forTeacher(teacherId: DemoData.demoTeacherId),
          ),
          _Destination(
            label: 'الطلبات',
            icon: Icons.event_note_outlined,
            selectedIcon: Icons.event_note_rounded,
            builder: (BuildContext context) =>
                const BookingsScreen(viewerRole: UserRole.teacher),
          ),
          _Destination(
            label: 'حسابي',
            icon: Icons.account_circle_outlined,
            selectedIcon: Icons.account_circle_rounded,
            builder: (BuildContext context) => const ProfileScreen(),
          ),
        ];
      case UserRole.admin:
        // لوحة الإدارة ليست جزءًا من هذه المرحلة.
        return <_Destination>[
          _Destination(
            label: 'حسابي',
            icon: Icons.account_circle_outlined,
            selectedIcon: Icons.account_circle_rounded,
            builder: (BuildContext context) => const ProfileScreen(),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = SessionScope.of(context);
    final UserRole? role = session.role;

    if (!session.isSignedIn || role == null || !role.isEndUser) {
      return const _SessionRequiredScreen();
    }

    final List<_Destination> destinations = _destinationsFor(role);
    final int safeIndex = _index < destinations.length ? _index : 0;
    final _Destination current = destinations[safeIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(current.label),
        actions: <Widget>[
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
          index: safeIndex,
          children: destinations
              .map((_Destination d) => d.builder(context))
              .toList(growable: false),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (int index) => setState(() => _index = index),
        destinations: destinations
            .map(
              (_Destination d) => NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
            )
            .toList(growable: false),
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
