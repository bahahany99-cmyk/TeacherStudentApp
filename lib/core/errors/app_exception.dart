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

  /// خدمة غير متاحة في هذه النسخة (مثلًا Firebase غير مُهيَّأ).
  unavailable,

  /// مدخلات المستخدم غير صالحة (بريد خاطئ، كلمة مرور ضعيفة…).
  invalidInput,

  /// ألغى المستخدم العملية بنفسه (مثل إغلاق قائمة حسابات Google).
  ///
  /// نوع مستقل حتى لا نُخيف المستخدم برسالة خطأ لأنه غيّر رأيه، ولا نعامله
  /// كنجاح كاذب.
  canceled,

  /// خطأ غير متوقع.
  unknown,
}

/// خطأ تطبيقي يحمل رسالة صالحة للعرض.
class AppException implements Exception {
  const AppException(
    this.kind, {
    this.debugMessage,
    this.overrideTitle,
    this.overrideMessage,
  });

  const AppException.network({
    String? debugMessage,
    String? overrideMessage,
    String? overrideTitle,
  }) : this(
         AppErrorKind.network,
         debugMessage: debugMessage,
         overrideMessage: overrideMessage,
         overrideTitle: overrideTitle,
       );

  const AppException.permission({
    String? debugMessage,
    String? overrideMessage,
    String? overrideTitle,
  }) : this(
         AppErrorKind.permission,
         debugMessage: debugMessage,
         overrideMessage: overrideMessage,
         overrideTitle: overrideTitle,
       );

  const AppException.notFound({
    String? debugMessage,
    String? overrideMessage,
    String? overrideTitle,
  }) : this(
         AppErrorKind.notFound,
         debugMessage: debugMessage,
         overrideMessage: overrideMessage,
         overrideTitle: overrideTitle,
       );

  const AppException.unavailable({
    String? debugMessage,
    String? overrideMessage,
    String? overrideTitle,
  }) : this(
         AppErrorKind.unavailable,
         debugMessage: debugMessage,
         overrideMessage: overrideMessage,
         overrideTitle: overrideTitle,
       );

  const AppException.invalidInput({
    String? debugMessage,
    String? overrideMessage,
    String? overrideTitle,
  }) : this(
         AppErrorKind.invalidInput,
         debugMessage: debugMessage,
         overrideMessage: overrideMessage,
         overrideTitle: overrideTitle,
       );

  final AppErrorKind kind;

  /// تفاصيل للتشخيص فقط — لا تُعرض للمستخدم.
  final String? debugMessage;

  /// عنوان خاص بالخطأ يتجاوز عنوان النوع (يُستخدم لرسائل Firebase المحددة).
  final String? overrideTitle;

  /// شرح خاص بالخطأ يتجاوز شرح النوع.
  final String? overrideMessage;

  /// عنوان قصير للمستخدم.
  String get title =>
      overrideTitle ??
      switch (kind) {
        AppErrorKind.network => 'لا يوجد اتصال بالإنترنت',
        AppErrorKind.permission => 'لا تملك صلاحية لهذا المحتوى',
        AppErrorKind.notFound => 'العنصر غير موجود',
        AppErrorKind.unavailable => 'الخدمة غير متاحة الآن',
        AppErrorKind.invalidInput => 'تحقّق من البيانات المُدخلة',
        AppErrorKind.canceled => 'أُلغي تسجيل الدخول',
        AppErrorKind.unknown => 'حدث خطأ غير متوقع',
      };

  /// شرح مختصر + ما يمكن للمستخدم فعله.
  String get message =>
      overrideMessage ??
      switch (kind) {
        AppErrorKind.network => 'تحقّق من الاتصال ثم أعد المحاولة.',
        AppErrorKind.permission => 'إذا كنت تعتقد أن هذا خطأ، تواصل مع الدعم.',
        AppErrorKind.notFound => 'ربما تم حذفه أو تغيّر الرابط.',
        AppErrorKind.unavailable =>
          'هذه الميزة تحتاج اتصالًا بالخادم غير مُهيَّأ في هذه النسخة.',
        AppErrorKind.invalidInput => 'راجع الحقول ثم أعد المحاولة.',
        AppErrorKind.canceled => 'لم يكتمل تسجيل الدخول. يمكنك المحاولة متى شئت.',
        AppErrorKind.unknown => 'أعد المحاولة، وإن تكرر الخطأ أبلغنا عنه.',
      };

  @override
  String toString() =>
      'AppException($kind)${debugMessage == null ? '' : ': $debugMessage'}';
}

/// يحوّل أي خطأ إلى [AppException] لعرضه.
AppException toAppException(Object error) {
  if (error is AppException) {
    return error;
  }
  return AppException(AppErrorKind.unknown, debugMessage: error.toString());
}
