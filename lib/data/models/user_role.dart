/// أدوار المستخدمين.
///
/// ⚠️ مهم: وجود هذا الـ enum في التطبيق لا يعني أن التطبيق يملك سلطة تحديد
/// الدور. في الإنتاج يُقرأ الدور من مستند المستخدم في Firestore، وتُفرض
/// الصلاحيات عبر قواعد Firestore وCloud Functions (انظر
/// `docs/ARCHITECTURE_DECISIONS.md` → قسم الأمان).
enum UserRole {
  student,
  teacher,
  admin;

  String get label => switch (this) {
    UserRole.student => 'طالب',
    UserRole.teacher => 'مدرس',
    UserRole.admin => 'إدارة',
  };

  /// هل الدور يخص واجهة مستخدم عادية (لا إدارية)؟
  bool get isEndUser => this == UserRole.student || this == UserRole.teacher;
}
