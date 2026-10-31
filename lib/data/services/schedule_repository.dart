import 'package:teacher_student_app/data/models/group_session.dart';

/// عقد إدارة الجدول الأسبوعي للمجموعة (P9).
///
/// **القراءة** لكل عضو مقبول ولصاحب المجموعة، **والكتابة** لصاحب المجموعة فقط
/// — والفرض النهائي في `firestore.rules` لا هنا.
abstract interface class ScheduleRepository {
  /// كل مواعيد المجموعة (بما فيها الملغاة — تُعرض بوسمها).
  Future<List<GroupSession>> listForGroup(String groupId);

  /// إضافة موعد أسبوعي — يرفض التداخل مع موعد قائم برسالة عربية.
  Future<GroupSession> createSession({
    required String groupId,
    required String teacherId,
    required SessionDraft draft,
  });

  /// تعديل موعد قائم (لا يغيّر المجموعة ولا المالك).
  Future<GroupSession> updateSession({
    required GroupSession session,
    required String teacherId,
    required SessionDraft draft,
  });

  /// إلغاء/إعادة تفعيل موعد. الإلغاء لا يحذف السجل، والموعد الملغى لا يشارك
  /// في فحص التداخل.
  Future<GroupSession> setCancelled({
    required GroupSession session,
    required String teacherId,
    required bool isCancelled,
  });
}
