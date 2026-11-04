import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/validation/model_validators.dart';

String longText(int length) => List<String>.filled(length, 'ا').join();

void main() {
  group('اسم العرض', () {
    test('الاسم الصالح يمرّ، والمسافات الطرفية تُحذف', () {
      expect(validateDisplayName('أ. سارة').isValid, isTrue);
      expect(normalizeText('  سارة  '), 'سارة');
      expect(normalizeText('   '), isNull);
      expect(normalizeText(null), isNull);
    });

    test('الفارغ مطلوب، والطويل مرفوض', () {
      expect(
        validateDisplayName('   ').problems.single.issue,
        FieldIssue.missing,
      );
      expect(
        validateDisplayName(longText(ModelLimits.displayName + 1))
            .problems
            .single
            .issue,
        FieldIssue.tooLong,
      );
      // الحد نفسه مسموح (مطابقة للقواعد: ≤ 80).
      expect(
        validateDisplayName(longText(ModelLimits.displayName)).isValid,
        isTrue,
      );
    });

    test('رسالة المشكلة عربية وقابلة للعرض', () {
      expect(validateDisplayName('').firstMessage, FieldIssue.missing.message);
    });
  });

  group('مسودة الملف التعريفي', () {
    test('الاسم وحده يكفي في البداية (الملف يُكمل لاحقًا)', () {
      final ValidationResult result = validateTeacherProfileDraft(
        displayName: 'أ. أحمد الشناوي',
      );

      expect(result.isValid, isTrue);
      expect(result.firstMessage, isNull);
    });

    test('الاسم مفقود ⇒ مشكلة واحدة فقط', () {
      final ValidationResult result = validateTeacherProfileDraft(
        displayName: null,
        subject: 'الرياضيات',
      );

      expect(result.problems.length, 1);
      expect(result.problems.single.field, 'displayName');
    });

    test('كل حقل يتجاوز حده يُبلَّغ باسمه', () {
      final ValidationResult result = validateTeacherProfileDraft(
        displayName: 'أ. سارة',
        subject: longText(ModelLimits.subject + 1),
        bio: longText(ModelLimits.bio + 1),
      );

      expect(result.isValid, isFalse);
      expect(
        result.problems.map((ValidationProblem p) => p.field),
        containsAll(<String>['subject', 'bio']),
      );
    });
  });

  group('مسودة المجموعة', () {
    test('مسودة صالحة كاملة', () {
      expect(
        validateGroupDraft(
          title: 'التفاضل والتكامل',
          subject: 'الرياضيات',
          stage: 'الثانوية العامة',
          seatsTotal: 12,
        ).isValid,
        isTrue,
      );
    });

    test('عنوان قصير جدًا مرفوض', () {
      final ValidationResult result = validateGroupDraft(
        title: 'ري',
        subject: 'الرياضيات',
        stage: 'الثانوية',
        seatsTotal: 10,
      );

      expect(
        result.problems.first.issue,
        FieldIssue.tooShort,
      );
    });

    test('السعة خارج النطاق مرفوضة (أقل من 2 أو أكثر من 40)', () {
      for (final int seats in <int>[0, 1, ModelLimits.seatsMax + 1]) {
        final ValidationResult result = validateGroupDraft(
          title: 'مجموعة',
          subject: 'الفيزياء',
          stage: 'الثانوية',
          seatsTotal: seats,
        );
        expect(result.isValid, isFalse, reason: 'السعة $seats');
        expect(
          result.problems
              .where((ValidationProblem p) => p.field == 'seatsTotal')
              .length,
          1,
        );
      }

      expect(
        validateGroupDraft(
          title: 'مجموعة',
          subject: 'الفيزياء',
          stage: 'الثانوية',
          seatsTotal: ModelLimits.seatsMax,
        ).isValid,
        isTrue,
      );
    });

    test('عنوان فيه مسافات فقط = مفقود', () {
      final ValidationResult result = validateGroupDraft(
        title: '    ',
        subject: 'الرياضيات',
        stage: 'الثانوية',
        seatsTotal: 8,
      );

      expect(result.problems.first.issue, FieldIssue.missing);
    });
  });

  group('ملاحظة الحجز', () {
    test('اختيارية بطول محدود', () {
      expect(validateBookingNote(null).isValid, isTrue);
      expect(validateBookingNote('  ').isValid, isTrue);
      expect(validateBookingNote('أرغب في حصة تجريبية').isValid, isTrue);
      expect(
        validateBookingNote(longText(ModelLimits.bookingNote + 1))
            .problems
            .single
            .issue,
        FieldIssue.tooLong,
      );
    });
  });
}
