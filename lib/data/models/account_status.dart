/// حالة الحساب (P17).
///
/// حذف الحساب في هذا التطبيق **حذف ناعم** لا فوري: الطلب يوقف الظهور العام
/// ويبدأ مهلة سماح 7 أيام يستطيع المستخدم خلالها استعادة حسابه بتسجيل الدخول.
/// الحذف النهائي (تصفير البيانات/إزالة الحساب) إجراء إداري خارج التطبيق — لا
/// نعِد المستخدم بشيء لا ينفّذه هذا الإصدار.
enum AccountStatus {
  /// حساب طبيعي.
  active,

  /// طلب صاحب الحساب حذفه، والمهلة جارية.
  pendingDeletion;

  /// القيمة المكتوبة في Firestore.
  static const String activeWire = 'active';
  static const String pendingDeletionWire = 'pending_deletion';

  /// التمثيل في القاعدة (اسم صريح لا يعتمد على `enum.name`).
  String get wire => switch (this) {
    AccountStatus.active => activeWire,
    AccountStatus.pendingDeletion => pendingDeletionWire,
  };

  /// قراءة آمنة: أي قيمة غير معروفة أو غائبة تعني حسابًا نشطًا.
  ///
  /// **لماذا الفشل إلى `active`؟** لأن غياب الحقل هو حالة كل مستند قديم، واعتبار
  /// الغياب «محذوفًا» كان سيخفي حسابات سليمة. أما الحذف فلا يُستنتج أبدًا من
  /// الغياب: يُكتب صريحًا مع موعد.
  static AccountStatus fromWire(Object? raw) =>
      raw == pendingDeletionWire ? AccountStatus.pendingDeletion : active;

  String get label => switch (this) {
    AccountStatus.active => 'نشط',
    AccountStatus.pendingDeletion => 'بانتظار الحذف',
  };
}
