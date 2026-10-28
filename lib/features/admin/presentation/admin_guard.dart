import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';

/// حارس الشاشات الإدارية (P14).
///
/// **لماذا حارس واجهة وهو ليس أمانًا؟** لأن الأمان في القواعد وحدها
/// (`request.auth.token.admin == true`). الحارس هنا يمنع حالة سيئة فقط: طالب
/// يصل إلى مسار إداري بالخطأ فيرى شاشة فارغة أو أزرارًا لا تعمل. الأفضل أن
/// يقرأ «لا تملك صلاحية» ويعود.
///
/// القرار A-88 يوضّح أن الادعاء يُضبط بمفتاح خدمة خارج التطبيق، ولا يمكن
/// للتطبيق منح نفسه صلاحية إدارة.
class AdminGuard extends StatelessWidget {
  const AdminGuard({super.key, required this.child, this.title = 'لوحة الإدارة'});

  /// الشاشة الإدارية بعد اجتياز الفحص.
  final Widget child;

  /// عنوان شاشة الرفض — يخبر المستخدم أي قسم حُجب عنه.
  final String title;

  @override
  Widget build(BuildContext context) {
    final bool allowed = SessionScope.of(context).isAdmin;
    if (allowed) {
      return child;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'لا تملك صلاحية',
              message: 'هذه الشاشة للإدارة فقط. لو كنت مسؤولًا فسجّل الدخول '
                  'بحساب إداري معتمد.',
              actionLabel: 'العودة',
              onActionTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                RoutePaths.shell,
                (Route<dynamic> route) => false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
