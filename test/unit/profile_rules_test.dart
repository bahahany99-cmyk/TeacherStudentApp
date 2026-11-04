import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/validation/profile_rules.dart';

/// (P18) قواعد الحقول الشخصية — تُختبر وحدها لأنها المصدر الوحيد للحدود التي
/// يراها المستخدم، ويجب أن تطابق `validContactFields` في `firestore.rules`.
void main() {
  group('اسم العرض', () {
    test('الفراغ مرفوض', () {
      expect(ProfileRules.nameProblem(''), isNotNull);
      expect(ProfileRules.nameProblem('   '), isNotNull);
      expect(ProfileRules.nameProblem(null), isNotNull);
    });

    test('أقصر من الحد مرفوض، والحد نفسه مقبول', () {
      expect(ProfileRules.nameProblem('مح'), isNotNull);
      expect(ProfileRules.nameProblem('مح1'), isNull);
    });

    test('أطول من 80 مرفوض', () {
      expect(ProfileRules.nameProblem('ا' * 80), isNull);
      expect(ProfileRules.nameProblem('ا' * 81), isNotNull);
    });
  });

  group('الهاتف', () {
    test('اختياري: الفراغ صالح', () {
      expect(ProfileRules.phoneProblem(''), isNull);
      expect(ProfileRules.phoneProblem(null), isNull);
    });

    test('الصيغ المصرية/الدولية المقبولة', () {
      expect(ProfileRules.phoneProblem('01012345678'), isNull);
      expect(ProfileRules.phoneProblem('+20 100 123 4567'), isNull);
      expect(ProfileRules.phoneProblem('0101-234-5678'), isNull);
    });

    test('الحروف مرفوضة حتى لو كان الطول مناسبًا', () {
      expect(ProfileRules.phoneProblem('010ABCDEFG'), isNotNull);
    });

    test('أقل من 8 أرقام مرفوض', () {
      expect(ProfileRules.phoneProblem('0101'), isNotNull);
    });

    test('رموز بلا أرقام كافية مرفوضة (لا يمرّ فحص الطول وحده)', () {
      // عشرة رموز مسموحة لكن صفر أرقام: يمرّ من فحص الطول ولا يفيد شيئًا.
      expect(ProfileRules.phoneProblem('+---------'), isNotNull);
    });

    test('أطول من 20 مرفوض', () {
      expect(ProfileRules.phoneProblem('1' * 21), isNotNull);
    });
  });

  group('المرحلة', () {
    test('اختيارية: الفراغ صالح', () {
      expect(ProfileRules.stageProblem(''), isNull);
      expect(ProfileRules.stageProblem(null), isNull);
    });

    test('حرف واحد مرفوض، والحدّ الأقصى محترم', () {
      expect(ProfileRules.stageProblem('ث'), isNotNull);
      expect(ProfileRules.stageProblem('الثانوية العامة'), isNull);
      expect(ProfileRules.stageProblem('ا' * 41), isNotNull);
    });
  });

  test('التحقق المجمّع يرفض أي حقل خاطئ', () {
    expect(
      ProfileRules.isValid(
        displayName: 'أحمد',
        phone: '01012345678',
        stage: 'الثانوية العامة',
      ),
      isTrue,
    );
    expect(
      ProfileRules.isValid(
        displayName: 'أحمد',
        phone: 'abc',
        stage: null,
      ),
      isFalse,
    );
  });
}
