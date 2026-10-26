import 'package:teacher_student_app/data/models/user_role.dart';

/// مستخدم التطبيق كما يحتاجه الواجهة.
///
/// الحقول هنا للعرض فقط. أي بيانات حسّاسة (صلاحية الإدارة، حالة اعتماد المدرس)
/// تُقرأ من الخادم ولا يعتمد التطبيق على قيمتها المحلية في أي قرار أمني.
class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.role,
    this.email,
    this.isDemoAccount = false,
  });

  final String id;
  final String displayName;
  final UserRole role;
  final String? email;

  /// `true` عندما يكون الحساب مُصطنعًا محليًا للعرض فقط (لا Firebase).
  ///
  /// تُستخدم لعرض شريط "وضع تجريبي" ومنع أي كود من التعامل معه كحساب حقيقي.
  final bool isDemoAccount;

  String get initials {
    final String trimmed = displayName.trim();
    return trimmed.isEmpty ? '؟' : trimmed.substring(0, 1);
  }
}
