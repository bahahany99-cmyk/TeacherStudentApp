import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';

/// حارس المسارات الإدارية (P14).
///
/// **ماذا يفعل بالضبط؟** يمنع *الوصول إلى الواجهة* من حساب طالب أو مدرس، حتى
/// لو عرف المسار وكتبه يدويًا أو وصل عبر رابط قديم. الحماية الحقيقية تبقى في
/// `firestore.rules`؛ هذا الحارس يمنع رؤية الشاشة لا قراءة البيانات.
///
/// المصدر: `SessionController.isAdmin` الذي يجمع بين الادعاء المقروء من الخادم
/// (`request.auth.token.admin`) والدور التجريبي. **لا يوجد** أي مسار يمنح
/// الصلاحية من داخل التطبيق.
class AdminGuard extends StatelessWidget {
  const AdminGuard({super.key, required this.child, this.title = 'لوحة الإدارة'});

  /// الشاشة المحمية.
  final Widget child;

  /// عنوان الشاشة في حالة الرفض (ليس سرًّا: المسار معروف أصلًا).
  final String title;

  @override
  Widget build(BuildContext context) {
    final SessionController session = SessionScope.of(context);

    if (!session.isAdmin) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: EmptyState(
                icon: Icons.lock_outline,
                title: 'لا تملك صلاحية',
                message:
                    'هذه الشاشة للإدارة فقط. الوصول يُمنح بادعاء إداري على '
                    'الخادم، ولا يُختار من التطبيق.',
                actionLabel: 'العودة إلى التطبيق',
                onActionTap: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    RoutePaths.shell,
                    (Route<dynamic> route) => false,
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    return child;
  }
}
