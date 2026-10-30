import 'package:flutter/material.dart';

import 'package:teacher_student_app/data/models/user_role.dart';

/// أقسام التطبيق الأساسية.
///
/// نستخدم تعدادًا بدل أرقام، حتى يكون التنقل مكتوبًا بالاسم
/// (`AppTab.groups`) ولا يعتمد على ترتيب القائمة.
enum AppTab {
  home,
  teachers,
  groups,
  bookings,
  profile,

  /// (P14) أقسام الإدارة — لا تظهر لأي دور آخر.
  adminHome,
  adminVerification,
  adminModeration,
}

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

  /// (P28) «الطلبات» صندوق وارد لا تقويم: يحوي طلبات الحجز والانضمام معًا.
  static const AppTabSpec requests = AppTabSpec(
    tab: AppTab.bookings,
    label: 'الطلبات',
    icon: Icons.inbox_outlined,
    selectedIcon: Icons.inbox_rounded,
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

  static const AppTabSpec adminHome = AppTabSpec(
    tab: AppTab.adminHome,
    label: 'الإدارة',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard_rounded,
  );

  static const AppTabSpec adminVerification = AppTabSpec(
    tab: AppTab.adminVerification,
    label: 'التوثيق',
    icon: Icons.verified_user_outlined,
    selectedIcon: Icons.verified_user_rounded,
  );

  static const AppTabSpec adminModeration = AppTabSpec(
    tab: AppTab.adminModeration,
    label: 'المراجعة',
    icon: Icons.flag_outlined,
    selectedIcon: Icons.flag_rounded,
  );

  /// أقسام الدور الإداري (P14): لوحة، طابور توثيق، مراجعة، حساب.
  static const List<AppTabSpec> admin = <AppTabSpec>[
    adminHome,
    adminVerification,
    adminModeration,
    profile,
  ];

  static List<AppTabSpec> forRole(UserRole role) {
    return switch (role) {
      UserRole.student => student,
      UserRole.teacher => teacher,
      UserRole.admin => admin,
    };
  }
}
