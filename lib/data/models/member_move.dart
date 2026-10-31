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
    this.acceptedJoinRequest = false,
    this.promotedWaitlist = false,
    this.clearedSourceRecords = 0,
  });

  final GroupMember member;

  /// المجموعة المصدر بعد إنقاص المقعد.
  final StudyGroup from;

  /// المجموعة الهدف بعد زيادة المقعد.
  final StudyGroup to;

  /// كان للطالب طلب انضمام **معلّق** للمجموعة الهدف، فحُوّل إلى `accepted`
  /// في المعاملة نفسها بدل أن يبقى معلّقًا لعضو صار داخلًا فعلًا.
  final bool acceptedJoinRequest;

  /// كان للطالب صف **انتظار** في المجموعة الهدف، فحُوّل إلى `promoted`.
  final bool promotedWaitlist;

  /// عدد الصفوف القديمة التي حُذفت من المجموعة المصدر (طلب انضمام و/أو صف
  /// انتظار). تُحذف لا تُترك، لأن بقاءها يعني حالة شبح: طلب «مقبول» أو انتظار
  /// «تم قبوله» لطالب لم يعد في المجموعة.
  final int clearedSourceRecords;

  /// رسالة عربية موجزة لتنبيه المدرس بما تم — «لا شيء حدث بصمت».
  String get summary {
    final List<String> parts = <String>[
      if (acceptedJoinRequest) 'حُوّل طلب انضمامه المعلّق إلى مقبول',
      if (promotedWaitlist) 'أُغلق صف انتظاره',
      if (clearedSourceRecords > 0)
        'حُذف $clearedSourceRecords سجل قديم من المجموعة السابقة',
    ];
    return parts.isEmpty ? '' : ' — ${parts.join('، ')}.';
  }
}
