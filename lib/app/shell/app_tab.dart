import 'package:flutter/material.dart';

import 'package:teacher_student_app/data/models/user_role.dart';

/// أقسام التطبيق الأساسية.
///
/// نستخدم تعدادًا بدل أرقام، حتى يكون التنقل مكتوبًا بالاسم
/// (`AppTab.groups`) ولا يعتمد على ترتيب القائمة.
enum AppTab { home, teachers, groups, bookings, profile }

/// وصف قسم: التسمية والأيقونات.
class AppTabSpec {
  const AppTabSpec({
    required this.tab,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final AppTab tab;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// أقسام كل دور — المصدر الوحيد لشريط التنقل.
///
/// فصل تجربة الطالب عن المدرس يحدث هنا فقط (وثيقة §6.3)، مع العلم أن هذا
/// **للتجربة فقط**؛ الصلاحيات الحقيقية تُفرض على الخادم.
abstract final class AppTabs {
  static const AppTabSpec home = AppTabSpec(
    tab: AppTab.home,
    label: 'الرئيسية',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  );

  static const AppTabSpec homeTeacher = AppTabSpec(
    tab: AppTab.home,
    label: 'الرئيسية',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
  );

  static const AppTabSpec teachers = AppTabSpec(
    tab: AppTab.teachers,
    label: 'المدرسون',
    icon: Icons.person_search_outlined,
    selectedIcon: Icons.person_search_rounded,
  );

  static const AppTabSpec groups = AppTabSpec(
    tab: AppTab.groups,
    label: 'المجموعات',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
  );

  static const AppTabSpec myGroups = AppTabSpec(
    tab: AppTab.groups,
    label: 'مجموعاتي',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
  );

  static const AppTabSpec bookings = AppTabSpec(
    tab: AppTab.bookings,
    label: 'الحجوزات',
    icon: Icons.event_note_outlined,
    selectedIcon: Icons.event_note_rounded,
  );

  static const AppTabSpec requests = AppTabSpec(
    tab: AppTab.bookings,
    label: 'الطلبات',
    icon: Icons.event_note_outlined,
    selectedIcon: Icons.event_note_rounded,
  );

  static const AppTabSpec profile = AppTabSpec(
    tab: AppTab.profile,
    label: 'حسابي',
    icon: Icons.account_circle_outlined,
    selectedIcon: Icons.account_circle_rounded,
  );

  /// أقسام الطالب بالترتيب.
  static const List<AppTabSpec> student = <AppTabSpec>[
    home,
    teachers,
    groups,
    bookings,
    profile,
  ];

  /// أقسام المدرس بالترتيب.
  static const List<AppTabSpec> teacher = <AppTabSpec>[
    homeTeacher,
    myGroups,
    requests,
    profile,
  ];

  /// أقسام الدور الإداري (لوحة الإدارة لم تُنفَّذ بعد — P14).
  static const List<AppTabSpec> admin = <AppTabSpec>[profile];

  static List<AppTabSpec> forRole(UserRole role) {
    return switch (role) {
      UserRole.student => student,
      UserRole.teacher => teacher,
      UserRole.admin => admin,
    };
  }
}
