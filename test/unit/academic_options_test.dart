import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/constants/academic_options.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/teacher_profile_draft.dart';

/// (P19) القوائم الأكاديمية المعتمدة.
///
/// **لماذا نختبر الثوابت؟** لأن هذه القوائم صارت جزءًا من عقد البيانات: ما
/// يختاره المدرس يُكتب في `teacherProfiles/{uid}`، وما يفلتر به الطالب يُقارن
/// به نصًا. أي انحراف (قيمة مكرّرة، محافظة ناقصة، مرحلة بصياغة مختلفة عن
/// البيانات القائمة) يظهر كملف «لا يظهر في أي فلتر» بلا رسالة خطأ.
void main() {
  group('قوائم المواد والمراحل والمحافظات', () {
    test('المواد: 18 مادة، بلا تكرار ولا فراغ', () {
      expect(AcademicOptions.subjects.length, 18);
      expect(
        AcademicOptions.subjects.toSet().length,
        AcademicOptions.subjects.length,
      );
      for (final String subject in AcademicOptions.subjects) {
        expect(subject.trim(), subject);
        expect(subject, isNotEmpty);
      }
    });

    test('المحافظات: 27 محافظة بالضبط (عدد محافظات مصر)', () {
      expect(AcademicOptions.governorates.length, 27);
      expect(
        AcademicOptions.governorates.toSet().length,
        AcademicOptions.governorates.length,
      );
      // القاهرة والجيزة أولًا (الترتيب الجغرافي المعتاد)، وأسوان في الآخر.
      expect(AcademicOptions.governorates.first, 'القاهرة');
      expect(AcademicOptions.governorates, contains('الفيوم'));
      expect(AcademicOptions.governorates, contains('أسوان'));
    });

    test('المراحل: أربع مراحل بترتيب تصاعدي', () {
      expect(AcademicOptions.stages, <String>[
        'الابتدائية',
        'الإعدادية',
        'الثانوية العامة',
        'الجامعة',
      ]);
    });

    test('مراحل البيانات التجريبية كلها معتمدة (لا «قيمة غير معروفة» عند التحرير)',
        () {
      for (final TeacherProfile profile in DemoData.teachers) {
        // المسودات والمرفوضة أيضًا — كلها تُفتح في نفس النموذج.
        expect(
          AcademicOptions.isKnownStage(profile.stage),
          isTrue,
          reason: 'مرحلة غير معتمدة في ${profile.displayName}: ${profile.stage}',
        );
      }
    });

    test('كل مادة في البيانات التجريبية إما معتمدة أو تُحفظ كقيمة قديمة', () {
      for (final TeacherProfile profile in DemoData.teachers) {
        final bool known = AcademicOptions.isKnownSubject(profile.subject);
        if (!known) {
          // القيم المركّبة القديمة («الرياضيات — التفاضل») مسموحة، لكن يجب أن
          // تبقى قابلة للعرض: النموذج يضيفها كخيار إضافي. الشرط الوحيد أن
          // تكون نصًا غير فارغ، لا أن تُحذف بصمت.
          expect(profile.subject.trim(), isNotEmpty);
        }
      }
    });

    test('كل محافظة محفوظة في البيانات التجريبية معتمدة', () {
      for (final TeacherProfile profile in DemoData.teachers) {
        final String? governorate = profile.governorate;
        if (governorate == null || governorate.trim().isEmpty) {
          continue;
        }
        expect(
          AcademicOptions.isKnownGovernorate(governorate),
          isTrue,
          reason: 'محافظة غير معتمدة: $governorate',
        );
      }
    });
  });

  group('الدوال المساعدة isKnown*', () {
    test('تقبل القيم المعتمدة وتتجاهل الفراغات الطرفية', () {
      expect(AcademicOptions.isKnownSubject('الرياضيات'), isTrue);
      expect(AcademicOptions.isKnownSubject('  الرياضيات  '), isTrue);
      expect(AcademicOptions.isKnownStage('الثانوية العامة'), isTrue);
      expect(AcademicOptions.isKnownGovernorate('القاهرة'), isTrue);
    });

    test('ترفض القيم المشابهة حرفيًا لا غير (وهذا سبب وجود القوائم)', () {
      // «رياضيات» بلا أل التعريف، و«الرياضه» بالهاء: ليستا القيمة المعتمدة.
      expect(AcademicOptions.isKnownSubject('رياضيات'), isFalse);
      expect(AcademicOptions.isKnownSubject('الرياضه'), isFalse);
      expect(AcademicOptions.isKnownStage('ثانوية عامة'), isFalse);
      expect(AcademicOptions.isKnownGovernorate('الفيوم '), isTrue);
      expect(AcademicOptions.isKnownGovernorate('فيوم'), isFalse);
    });

    test('null والنص الفارغ ليستا مادة ولا مرحلة ولا محافظة', () {
      expect(AcademicOptions.isKnownSubject(null), isFalse);
      expect(AcademicOptions.isKnownSubject(''), isFalse);
      expect(AcademicOptions.isKnownSubject('   '), isFalse);
      expect(AcademicOptions.isKnownStage(null), isFalse);
      expect(AcademicOptions.isKnownGovernorate(''), isFalse);
    });

    test('«بياناتي» تقرأ المراحل من نفس المصدر لا من نسخة ثانية', () {
      expect(AcademicOptions.stageSuggestions, same(AcademicOptions.stages));
    });
  });


  // ═══════════════════════════════════════════════════════════════════════════
  // (P22) القيم المخصّصة: «أخرى» + كتابة يدوية
  group('(P22) المادة والمرحلة المخصّصتان', () {
    test('خيار «أخرى» قيمة حارسة لا تُحفظ كقيمة معتمدة', () {
      expect(AcademicOptions.customOption, '__custom__');
      expect(AcademicOptions.customOptionLabel, contains('أخرى'));
      // ليست مادة ولا مرحلة: لو حُفظت لظهرت في البحث بلا معنى.
      expect(AcademicOptions.isKnownSubject(AcademicOptions.customOption), isFalse);
      expect(AcademicOptions.isKnownStage(AcademicOptions.customOption), isFalse);
    });

    test('نص مخصّص صالح يُقبل: «العلوم المتكاملة» و«رياض الأطفال»', () {
      expect(AcademicOptions.customTextProblem('العلوم المتكاملة', 'المادة'), isNull);
      expect(AcademicOptions.customTextProblem('رياض الأطفال', 'المرحلة'), isNull);
      // وحدود الطول مطابقة لـ`validAcademicField` في القواعد: 2..40.
      expect(AcademicOptions.customTextProblem('رك', 'المادة'), isNull);
      expect(AcademicOptions.customTextProblem('ر'.padRight(39, 'ك'), 'المادة'), isNull);
    });

    test('الفراغ والحرف الواحد والزائد عن 40 مرفوضة برسالة عربية', () {
      expect(AcademicOptions.customTextProblem('   ', 'المادة'), 'أدخل المادة');
      expect(AcademicOptions.customTextProblem('ر', 'المادة'), contains('قصير'));
      expect(
        AcademicOptions.customTextProblem('ر'.padRight(41, 'س'), 'المرحلة'),
        contains('طويل'),
      );
      expect(AcademicOptions.customTextProblem(null, 'المرحلة'), isNotNull);
    });

    test('isCustomSubject/isCustomStage يميّزان المحفوظ غير المعتمد', () {
      expect(AcademicOptions.isCustomSubject('الرياضيات'), isFalse);
      expect(AcademicOptions.isCustomSubject('العلوم المتكاملة'), isTrue);
      expect(AcademicOptions.isCustomSubject(null), isFalse);
      expect(AcademicOptions.isCustomSubject('  '), isFalse);
      expect(AcademicOptions.isCustomStage('الجامعة'), isFalse);
      expect(AcademicOptions.isCustomStage('رياض الأطفال'), isTrue);
    });

    test('القيمة المخصّصة تُحفظ في الخريطة كما هي بلا تحويل', () {
      const TeacherProfileDraft draft = TeacherProfileDraft(
        displayName: 'أ. منى',
        subject: 'العلوم المتكاملة',
        stage: 'رياض الأطفال',
        area: 'الفيوم',
        bio: 'نبذة كافية للاختبار هنا بلا مشاكل.',
        photoPath: 'avatars/uid-1',
      );

      final Map<String, Object?> map = draft.toWriteMap();
      expect(map['subject'], 'العلوم المتكاملة');
      expect(map['stage'], 'رياض الأطفال');
      expect(map['photoPath'], 'avatars/uid-1');
      expect(map.containsKey('status'), isFalse);
      // ولا تُكتب القيمة الحارسة مكان النص أبدًا.
      expect(map.values, isNot(contains(AcademicOptions.customOption)));
    });
  });
}
