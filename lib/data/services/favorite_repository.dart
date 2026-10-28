import 'package:teacher_student_app/data/models/favorite.dart';

/// عقد المفضلة (P13).
///
/// **لمن؟** للطالب: يحفظ مدرسين ومجموعات ليجدهم لاحقًا. العنصر يُحفظ **لمن أضافه
/// فقط**؛ لا قائمة مشتركة ولا عدّاد عام، والقواعد تمنع قراءة مفضلة غيرك أو
/// الكتابة فيها.
///
/// **لا «إضافة» و«إزالة» منفصلتان:** [toggle] وحدها، لأن الواجهة زر واحد. إضافة
/// مكرّرة مستحيلة بنيويًا لأن معرّف المستند مشتق من (الطالب، النوع، الهدف) —
/// انظر `Favorite.idFor`.
abstract interface class FavoriteRepository {
  /// مفضلة طالب واحد — الأحدث أولًا.
  Future<List<Favorite>> listForStudent(String studentId);

  /// نفس القائمة كتدفّق حيّ (شاشة المفضلة تتحدّث بلا سحب للتحديث).
  Stream<List<Favorite>> watchForStudent(String studentId);

  /// هل هذا العنصر في مفضلة الطالب الآن؟ (تدفّق لزر واحد: نجمة أو قلب).
  Stream<bool> watchIsFavorite({
    required String studentId,
    required FavoriteKind kind,
    required String targetId,
  });

  /// يضيف العنصر إن لم يكن موجودًا، ويحذفه إن كان.
  ///
  /// يعيد الحالة **بعد** التبديل: `true` = صار في المفضلة.
  Future<bool> toggle({
    required String studentId,
    required FavoriteKind kind,
    required String targetId,
  });
}
