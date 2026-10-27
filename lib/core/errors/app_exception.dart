/// أنواع الأخطاء التي يمكن أن تصل إلى الواجهة.
///
/// الغرض: فصل "ماذا حدث تقنيًا" عن "ماذا نعرض للمستخدم"، حتى تبقى الرسائل
/// العربية موحّدة في كل الشاشات، ولا تتسرّب تفاصيل تقنية إلى الواجهة.
enum AppErrorKind {
  /// لا اتصال بالشبكة أو انتهت المهلة.
  network,

  /// المستخدم لا يملك صلاحية (قاعدة Firestore/Storage رفضت العملية).
  permission,

  /// العنصر غير موجود أو حُذف.
  notFound,

  /// خطأ غير متوقع.
  unknown,
}

/// خطأ تطبيقي يحمل رسالة صالحة للعرض.
class AppException implements Exception {
  const AppException(this.kind, {this.debugMessage});

  const AppException.network({String? debugMessage})
    : this(AppErrorKind.network, debugMessage: debugMessage);

  const AppException.permission({String? debugMessage})
    : this(AppErrorKind.permission, debugMessage: debugMessage);

  const AppException.notFound({String? debugMessage})
    : this(AppErrorKind.notFound, debugMessage: debugMessage);

  final AppErrorKind kind;

  /// تفاصيل للتشخيص فقط — لا تُعرض للمستخدم.
  final String? debugMessage;

  /// عنوان قصير للمستخدم.
  String get title => switch (kind) {
    AppErrorKind.network => 'لا يوجد اتصال بالإنترنت',
    AppErrorKind.permission => 'لا تملك صلاحية لهذا المحتوى',
    AppErrorKind.notFound => 'العنصر غير موجود',
    AppErrorKind.unknown => 'حدث خطأ غير متوقع',
  };

  /// شرح مختصر + ما يمكن للمستخدم فعله.
  String get message => switch (kind) {
    AppErrorKind.network => 'تحقّق من الاتصال ثم أعد المحاولة.',
    AppErrorKind.permission => 'إذا كنت تعتقد أن هذا خطأ، تواصل مع الدعم.',
    AppErrorKind.notFound => 'ربما تم حذفه أو تغيّر الرابط.',
    AppErrorKind.unknown => 'أعد المحاولة، وإن تكرر الخطأ أبلغنا عنه.',
  };

  @override
  String toString() => 'AppException($kind)${debugMessage == null ? '' : ': $debugMessage'}';
}

/// يحوّل أي خطأ إلى [AppException] لعرضه.
AppException toAppException(Object error) {
  if (error is AppException) {
    return error;
  }
  return AppException(AppErrorKind.unknown, debugMessage: error.toString());
}
