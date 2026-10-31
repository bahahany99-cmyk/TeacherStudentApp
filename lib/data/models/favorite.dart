/// نوع العنصر الذي يحفظه الطالب في المفضلة (P13).
///
/// القيمة النصية ([wireName]) هي **نفس** القيمة في `firestore.rules`، وتدخل في
/// تركيب معرّف المستند — تغييرها يوجب تغييرهما معًا.
enum FavoriteKind {
  teacher('teacher', 'مدرس'),
  group('group', 'مجموعة');

  const FavoriteKind(this.wireName, this.label);

  final String wireName;
  final String label;

  static FavoriteKind parse(Object? raw) =>
      raw == 'group' ? FavoriteKind.group : FavoriteKind.teacher;
}

/// عنصر في مفضلة الطالب: مدرس أو مجموعة.
///
/// **المعرّف مشتق لا حر:** `‎{studentId}_{kind}_{targetId}` (A-86). به تصبح
/// «إضافة مكررة» مستحيلة بنيويًا (مستند واحد لكل عنصر)، ويستطيع المستخدم حذف
/// ما أضافه فقط بلا بحث.
class Favorite {
  const Favorite({
    required this.studentId,
    required this.kind,
    required this.targetId,
    required this.createdAt,
  });

  /// صاحب المفضلة — القواعد تفرض أنه المستخدم الحالي نفسه.
  final String studentId;

  final FavoriteKind kind;

  /// معرّف المدرس أو المجموعة.
  final String targetId;

  final DateTime createdAt;

  /// معرّف المستند المشتق.
  String get id => idFor(
    studentId: studentId,
    kind: kind,
    targetId: targetId,
  );

  static String idFor({
    required String studentId,
    required FavoriteKind kind,
    required String targetId,
  }) => '${studentId}_${kind.wireName}_$targetId';

  /// خريطة الإنشاء — الحقول المسموح بها في `firestore.rules` فقط.
  Map<String, Object?> toCreateMap() => <String, Object?>{
    'studentId': studentId,
    'kind': kind.wireName,
    'targetId': targetId,
    'createdAt': createdAt,
  };
}
