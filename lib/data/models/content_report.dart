/// بلاغ عن محتوى مخالف يرفعه مستخدم، وتنظره الإدارة (P14).
///
/// **لماذا مستند مستقل لا حقل على المحتوى نفسه؟** لأن البلاغ إجراء مستخدم
/// (قد يكون كيديًا أو مكررًا)، بينما المحتوى ملك صاحبه. فصلُه يحفظ الأصل
/// ويترك للإدارة سجلًا لما وردها ومتى حُسم (A-88).
///
/// **الكتابة:** المستخدم يُنشئ بلاغًا بحالة [ReportStatus.open] فقط، والقواعد
/// ترفض أي حالة أخرى عند الإنشاء. تغيير الحالة إلى `resolved`/`dismissed`
/// **إداري فقط** (`request.auth.token.admin == true`).
class ContentReport {
  const ContentReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reporterId,
    required this.reason,
    required this.createdAt,
    this.targetLabel,
    this.details,
    this.status = ReportStatus.open,
    this.resolvedAt,
    this.resolutionNote,
  });

  final String id;

  /// نوع الهدف المُبلَّغ عنه (تقييم/مدرس/مجموعة).
  final ReportTargetType targetType;

  /// معرّف الهدف — يُفحص في القواعد أن المستند **قائم** فعلًا.
  final String targetId;

  /// وصف قصير للهدف للعرض في الطابور (لا يُعتمد عليه في القرار).
  final String? targetLabel;

  /// صاحب البلاغ — وهو من يقرأ بلاغه وحده (مع الإدارة).
  final String? reporterId;

  /// سبب البلاغ كما اختاره المُبلِّغ (نص قصير).
  final String? reason;

  /// تفاصيل حرة اختيارية.
  final String? details;

  final ReportStatus status;
  final DateTime createdAt;

  /// قرار الإدارة: وقت الحسم وملاحظته.
  final DateTime? resolvedAt;
  final String? resolutionNote;

  bool get isOpen => status == ReportStatus.open;

  /// خريطة الإنشاء — الحقول المسموح بها في القواعد فقط.
  Map<String, Object?> toCreateMap() => <String, Object?>{
    'targetType': targetType.wireValue,
    'targetId': targetId,
    if (reporterId != null) 'reporterId': reporterId,
    if (reason != null) 'reason': reason,
    if (details != null) 'details': details,
    'status': ReportStatus.open.wireValue,
    'createdAt': createdAt,
  };
}

/// نوع المحتوى المُبلَّغ عنه.
enum ReportTargetType {
  review('review', 'تقييم'),
  teacher('teacher', 'ملف مدرس'),
  group('group', 'مجموعة');

  const ReportTargetType(this.wireValue, this.label);

  /// القيمة المخزّنة في Firestore (تقارنها القواعد حرفيًا).
  final String wireValue;

  final String label;

  /// يحوّل نصًا من الخادم؛ `null` لنوع غير معروف (لا نخمّن).
  static ReportTargetType? parse(Object? raw) {
    for (final ReportTargetType type in ReportTargetType.values) {
      if (type.wireValue == raw) {
        return type;
      }
    }
    return null;
  }
}

/// حالة البلاغ.
enum ReportStatus {
  open('open', 'مفتوح'),
  resolved('resolved', 'حُسم'),
  dismissed('dismissed', 'مُستبعَد');

  const ReportStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ReportStatus parse(Object? raw) {
    return switch (raw) {
      'resolved' => ReportStatus.resolved,
      'dismissed' => ReportStatus.dismissed,
      _ => ReportStatus.open,
    };
  }
}

/// قرار الإدارة على بلاغ واحد.
enum ReportResolution {
  /// أُزيل المحتوى المخالف (حُذف التقييم مثلًا).
  resolved('resolved', 'حُسم البلاغ'),

  /// البلاغ غير صحيح — أُغلق بلا إجراء على المحتوى.
  dismissed('dismissed', 'استُبعد البلاغ');

  const ReportResolution(this.wireValue, this.label);

  final String wireValue;
  final String label;
}
