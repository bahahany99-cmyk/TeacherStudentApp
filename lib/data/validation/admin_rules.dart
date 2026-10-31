import 'package:teacher_student_app/data/models/content_report.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// قواعد جودة قرارات الإدارة (P14) — نفس الترتيب الذي تفرضه القواعد لاحقًا.
///
/// **لماذا ملف منفصل؟** لأن سبب الرفض يُكتب مرة ويُقرأ مرات (المدرس، وسجل
/// المراجعة). سبب من حرف واحد لا يشرح شيئًا، وسبب طويل جدًا لا يُقرأ في
/// الواجهة. والقاعدة نفسها مطبَّقة في `firestore.rules` (طول 5..200).
abstract final class AdminRules {
  static const int minReasonLength = 5;
  static const int maxReasonLength = 200;

  /// يعيد رسالة عربية عند سبب غير صالح، أو `null` إن كان مقبولًا.
  static String? reasonProblem(String raw) {
    final String reason = raw.trim();
    if (reason.length < minReasonLength) {
      return 'اكتب سببًا واضحًا (٥ أحرف على الأقل) قبل حفظ القرار.';
    }
    if (reason.length > maxReasonLength) {
      return 'السبب أطول من المسموح ($maxReasonLength حرفًا).';
    }
    return null;
  }

  /// ترتيب طابور التوثيق: **قيد المراجعة أولًا** (معلّق ينتظر قرارًا) ثم
  /// المسودات، وداخل كل حالة الأقدم معرّفًا أولًا لتثبيت الترتيب بين القراءات.
  static List<TeacherProfile> verificationQueue(List<TeacherProfile> source) {
    final List<TeacherProfile> queue = source
        .where((TeacherProfile profile) => profile.status.awaitsReview)
        .toList(growable: false);
    return List<TeacherProfile>.unmodifiable(
      <TeacherProfile>[...queue]..sort((
        TeacherProfile a,
        TeacherProfile b,
      ) {
        if (a.status != b.status) {
          return a.status == TeacherProfileStatus.pendingReview ? -1 : 1;
        }
        return a.id.compareTo(b.id);
      }),
    );
  }

  /// ترتيب البلاغات المفتوحة: الأحدث أولًا.
  static List<ContentReport> newestReportsFirst(List<ContentReport> source) {
    final List<ContentReport> items = source
        .where((ContentReport report) => report.isOpen)
        .toList(growable: false);
    return List<ContentReport>.unmodifiable(
      <ContentReport>[...items]
        ..sort((ContentReport a, ContentReport b) => b.createdAt.compareTo(a.createdAt)),
    );
  }
}
