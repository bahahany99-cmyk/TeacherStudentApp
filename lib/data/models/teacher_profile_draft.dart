import 'package:teacher_student_app/data/constants/academic_options.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// الحقول التي يحرّرها **صاحب الملف** فقط (P18).
///
/// لماذا نموذج منفصل بدل `TeacherProfile`؟ لأن `TeacherProfile` يحمل حقولًا
/// إدارية (`isFeatured`, `featuredOrder`, `reviewNote`, `status`, `rating`…)
/// لا يجوز أن تصل من النموذج إلى الكتابة. حصرها في كائن أصغر يجعل الخطأ
/// **مستحيل التعبير**، لا مجرد «ممنوع بالاتفاق».
///
/// القيم الفارغة تُطبَّع إلى `null` (لا سلسلة فارغة) لمطابقة
/// `validOptionalText` في `firestore.rules`.
class TeacherProfileDraft {
  const TeacherProfileDraft({
    required this.displayName,
    required this.subject,
    required this.stage,
    required this.area,
    required this.bio,
    this.isOnline = false,
    this.priceHint,
    this.governorate,
    this.district,
    this.photoPath,
  });

  final String displayName;
  final String subject;
  final String stage;
  final String area;
  final String bio;
  final bool isOnline;
  final String? priceHint;
  final String? governorate;
  final String? district;

  /// مسار صورة الملف (P22) — إلزامي، والشكل `avatars/{uid}`.
  ///
  /// يُملأ من الصورة المرفوعة، ويُتحقق منه في النموذج **قبل** أي كتابة:
  /// الطلب بلا صورة يُرفض محليًا برسالة عربية، ثم ترفضه القواعد أيضًا.
  final String? photoPath;

  /// هل الصورة موجودة؟ (شرط الحفظ)
  bool get hasPhoto => (photoPath ?? '').trim().isNotEmpty;

  /// مشكلة في المادة أو المرحلة — `null` يعني أن الحقلين صالحان.
  ///
  /// (P23) نفس شرط `firestore.rules` حرفيًا (`academicFieldsSatisfiedFor`):
  /// نص من حرفين إلى أربعين. الفحص هنا يعطي رسالة عربية قبل أي كتابة،
  /// والقاعدة ترفض الحمولة الناقصة حتى لو جاءت من مسار آخر.
  String? get academicProblem {
    final String? subjectProblem = AcademicOptions.customTextProblem(
      subject,
      'المادة',
    );
    if (subjectProblem != null) {
      return subjectProblem;
    }
    return AcademicOptions.customTextProblem(stage, 'المرحلة الدراسية');
  }

  /// الحقول الوصفية بصيغة الخريطة التي تُكتب في Firestore.
  ///
  /// **لا تشمل** `status` ولا `ownerId` ولا `createdAt`: الإنشاء يضيفها في
  /// المستودع، والتحديث يُبقيها (merge).
  Map<String, Object?> toWriteMap() {
    return <String, Object?>{
      'displayName': displayName.trim(),
      'subject': subject.trim(),
      'stage': stage.trim(),
      'area': area.trim(),
      'bio': bio.trim(),
      'isOnline': isOnline,
      if (_clean(priceHint) != null) 'priceHint': _clean(priceHint),
      if (_clean(governorate) != null) 'governorate': _clean(governorate),
      if (_clean(district) != null) 'district': _clean(district),
      if (_clean(photoPath) != null) 'photoPath': _clean(photoPath),
    };
  }

  static String? _clean(String? value) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }

  /// نموذج جاهز من ملف موجود (لتعبئة النموذج عند التعديل).
  factory TeacherProfileDraft.fromProfile(TeacherProfile profile) {
    return TeacherProfileDraft(
      displayName: profile.displayName,
      subject: profile.subject,
      stage: profile.stage,
      area: profile.area,
      bio: profile.bio,
      isOnline: profile.isOnline,
      priceHint: profile.priceHint,
      governorate: profile.governorate,
      district: profile.district,
      photoPath: profile.photoPath,
    );
  }
}
