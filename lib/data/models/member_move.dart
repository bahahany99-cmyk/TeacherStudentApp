import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/study_group.dart';

/// نتيجة نقل عضو من مجموعة إلى أخرى.
///
/// تُعيد المجموعتين بعد التعديل **كما كتبهما الخادم** (لا نسخة محسوبة في
/// الواجهة)، لأن الشاشة تعرض السعة مباشرةً بعد النقل.
class MemberMove {
  const MemberMove({
    required this.member,
    required this.from,
    required this.to,
  });

  final GroupMember member;

  /// المجموعة المصدر بعد إنقاص المقعد.
  final StudyGroup from;

  /// المجموعة الهدف بعد زيادة المقعد.
  final StudyGroup to;
}
