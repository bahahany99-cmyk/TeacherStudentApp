import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/shell/app_shell.dart';
import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/features/auth/presentation/email_auth_screen.dart';
import 'package:teacher_student_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:teacher_student_app/features/admin/presentation/admin_guard.dart';
import 'package:teacher_student_app/features/admin/presentation/featured_teachers_screen.dart';
import 'package:teacher_student_app/features/admin/presentation/moderation_screen.dart';
import 'package:teacher_student_app/features/admin/presentation/teacher_verification_screen.dart';
import 'package:teacher_student_app/features/account/presentation/account_restore_screen.dart';
import 'package:teacher_student_app/features/auth/presentation/login_screen.dart';
import 'package:teacher_student_app/features/auth/presentation/role_selection_screen.dart';
import 'package:teacher_student_app/features/bookings/presentation/booking_details_screen.dart';
import 'package:teacher_student_app/features/chat/presentation/direct_chat_screen.dart';
import 'package:teacher_student_app/features/chat/presentation/direct_chats_screen.dart';
import 'package:teacher_student_app/features/design_gallery/presentation/design_gallery_screen.dart';
import 'package:teacher_student_app/features/favorites/presentation/favorites_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/featured_tutors_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/group_chat_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/group_details_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/group_form_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/group_members_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/group_timetable_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/join_requests_screen.dart';
import 'package:teacher_student_app/features/notifications/presentation/notifications_screen.dart';
import 'package:teacher_student_app/features/profile/presentation/my_data_screen.dart';
import 'package:teacher_student_app/features/profile/presentation/support_screens.dart';
import 'package:teacher_student_app/features/splash/presentation/splash_screen.dart';
import 'package:teacher_student_app/features/teacher/presentation/edit_teacher_profile_screen.dart';
import 'package:teacher_student_app/features/teacher/presentation/my_teacher_profile_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/teacher_profile_screen.dart';

/// موجّه التنقل المركزي.
///
/// كل شاشة تُسجَّل هنا فقط؛ لا يوجد `Navigator.push` بنوع شاشة مباشر في
/// الشاشات (إلا للانتقال بالاسم)، ما يسمح بتغيير التنقل لاحقًا من مكان واحد.
abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RoutePaths.splash:
        return _page(const SplashScreen(), settings);
      case RoutePaths.login:
        return _page(const LoginScreen(), settings);
      case RoutePaths.emailAuth:
        return _page(const EmailAuthScreen(), settings);
      case RoutePaths.roleSelection:
        return _page(const RoleSelectionScreen(), settings);
      case RoutePaths.shell:
        return _page(const AppShell(), settings);
      case RoutePaths.accountRestore:
        return _page(const AccountRestoreScreen(), settings);
      case RoutePaths.designGallery:
        return _page(const DesignGalleryScreen(), settings);
      case RoutePaths.teacherProfile:
        final String? teacherId = _idFrom(settings);
        if (teacherId == null) {
          return _page(const UnknownRouteScreen(), settings);
        }
        return _page(TeacherProfileScreen(teacherId: teacherId), settings);
      case RoutePaths.groupDetails:
        final String? groupId = _idFrom(settings);
        if (groupId == null) {
          return _page(const UnknownRouteScreen(), settings);
        }
        return _page(GroupDetailsScreen(groupId: groupId), settings);
      case RoutePaths.groupForm:
        // معرّف اختياري: غيابه يعني «إنشاء مجموعة جديدة».
        final Object? formArgs = settings.arguments;
        final String? editId = formArgs is String && formArgs.trim().isNotEmpty
            ? formArgs.trim()
            : null;
        return _page(GroupFormScreen(groupId: editId), settings);
      case RoutePaths.groupMembers:
        final String? membersGroupId = _idFrom(settings);
        if (membersGroupId == null) {
          return _page(const UnknownRouteScreen(), settings);
        }
        return _page(GroupMembersScreen(groupId: membersGroupId), settings);
      case RoutePaths.groupRequests:
        final String? requestsGroupId = _idFrom(settings);
        if (requestsGroupId == null) {
          return _page(const UnknownRouteScreen(), settings);
        }
        return _page(
          JoinRequestsScreen(groupId: requestsGroupId),
          settings,
        );
      case RoutePaths.groupTimetable:
        final String? timetableGroupId = _idFrom(settings);
        if (timetableGroupId == null) {
          return _page(const UnknownRouteScreen(), settings);
        }
        return _page(
          GroupTimetableScreen(groupId: timetableGroupId),
          settings,
        );
      case RoutePaths.groupChat:
        final String? chatGroupId = _idFrom(settings);
        if (chatGroupId == null) {
          return _page(const UnknownRouteScreen(), settings);
        }
        return _page(GroupChatScreen(groupId: chatGroupId), settings);
      case RoutePaths.bookingDetails:
        final String? bookingId = _idFrom(settings);
        if (bookingId == null) {
          return _page(const UnknownRouteScreen(), settings);
        }
        return _page(BookingDetailsScreen(bookingId: bookingId), settings);
      case RoutePaths.notifications:
        return _page(const NotificationsScreen(), settings);
      case RoutePaths.featuredTeachers:
        return _page(const FeaturedTutorsScreen(), settings);
      case RoutePaths.myData:
        return _page(const MyDataScreen(), settings);
      case RoutePaths.support:
        return _page(const SupportScreen(), settings);
      case RoutePaths.legal:
        return _page(const LegalScreen(), settings);
      case RoutePaths.favorites:
        return _page(const FavoritesScreen(), settings);
      case RoutePaths.directChats:
        return _page(const DirectChatsScreen(), settings);
      case RoutePaths.directChat:
        final String? chatId = _idFrom(settings);
        if (chatId == null) {
          return _page(const UnknownRouteScreen(), settings);
        }
        return _page(DirectChatScreen(chatId: chatId), settings);
      // ── لوحة الإدارة (P14) ────────────────────────────────────────────────
      // كل مسار إداري يمرّ من [AdminGuard]: الطالب/المدرس يرى «لا تملك صلاحية»
      // لا شاشة فارغة. الحماية النهائية في `firestore.rules`.
      case RoutePaths.adminDashboard:
        return _page(
          const AdminGuard(child: AdminDashboardScreen()),
          settings,
        );
      case RoutePaths.adminFeatured:
        return _page(
          const AdminGuard(
            title: 'المدرسون المميزون',
            child: FeaturedTeachersScreen(),
          ),
          settings,
        );
      case RoutePaths.adminVerification:
        return _page(
          const AdminGuard(
            title: 'طابور التوثيق',
            child: TeacherVerificationScreen(),
          ),
          settings,
        );
      case RoutePaths.adminModeration:
        return _page(
          const AdminGuard(
            title: 'المراجعة والبلاغات',
            child: ModerationScreen(),
          ),
          settings,
        );
      case RoutePaths.myTeacherProfile:
        return _page(const MyTeacherProfileScreen(), settings);
      case RoutePaths.editTeacherProfile:
        return _page(const EditTeacherProfileScreen(), settings);
      default:
        return _page(const UnknownRouteScreen(), settings);
    }
  }

  /// معرّف الكيان المطلوب من `arguments`.
  ///
  /// نرفض أي نوع آخر بهدوء ونعرض شاشة «المسار غير معروف»، بدل تمرير قيمة
  /// خاطئة إلى شاشة التفاصيل تنهار أثناء البناء.
  static String? _idFrom(RouteSettings settings) {
    final Object? arguments = settings.arguments;
    if (arguments is String && arguments.trim().isNotEmpty) {
      return arguments.trim();
    }
    return null;
  }

  static MaterialPageRoute<dynamic> _page(Widget child, RouteSettings settings) {
    return MaterialPageRoute<dynamic>(
      builder: (BuildContext context) => child,
      settings: settings,
    );
  }
}

/// شاشة احتياطية لمسار غير معروف.
class UnknownRouteScreen extends StatelessWidget {
  const UnknownRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.unknownRoute)),
      body: Center(
        child: EmptyState(
          icon: Icons.search_off,
          title: AppStrings.unknownRoute,
          message: 'المسار المطلوب غير مسجّل في التطبيق.',
          actionLabel: AppStrings.backToHome,
          onActionTap: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              RoutePaths.splash,
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
    );
  }
}
