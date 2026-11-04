import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/validation/message_rules.dart';

void main() {
  group('MessageRules — من يشارك', () {
    test('المالك والعضو يشاركان، والغريب لا', () {
      expect(
        MessageRules.canParticipate(
          viewerId: 'teacher-1',
          isOwner: true,
          isMember: false,
        ),
        isTrue,
      );
      expect(
        MessageRules.canParticipate(
          viewerId: 'student-1',
          isOwner: false,
          isMember: true,
        ),
        isTrue,
      );
      expect(
        MessageRules.canParticipate(
          viewerId: 'student-2',
          isOwner: false,
          isMember: false,
        ),
        isFalse,
      );
    });

    test('بلا معرّف مستخدم لا مشاركة، والرسالة تشرح السبب', () {
      expect(
        MessageRules.canParticipate(
          viewerId: null,
          isOwner: false,
          isMember: true,
        ),
        isFalse,
      );

      final String? blocked = MessageRules.blockedReason(
        viewerId: 'student-2',
        isOwner: false,
        isMember: false,
      );
      expect(blocked, contains('أعضاء المجموعة'));
      expect(
        MessageRules.blockedReason(
          viewerId: 'student-1',
          isOwner: false,
          isMember: true,
        ),
        isNull,
      );
    });
  });

  group('MessageRules — النص', () {
    test('التطبيع يوحّد المسافات ويقصّ الأطراف', () {
      expect(MessageRules.normalize('  مرحبا   بالجميع \n'), 'مرحبا بالجميع');
      expect(MessageRules.normalize(null), '');
      expect(MessageRules.normalize(' \n\t '), '');
    });

    test('الرسالة الفارغة أو الفراغات مرفوضة', () {
      expect(MessageRules.validate('').isValid, isFalse);
      expect(MessageRules.validate('    ').isValid, isFalse);
      expect(MessageRules.validate(null).isValid, isFalse);
    });

    test('حد الطول 500 حرف بالضبط', () {
      expect(MessageRules.validate('ا' * 500).isValid, isTrue);
      final result = MessageRules.validate('ا' * 501);
      expect(result.isValid, isFalse);
      expect(result.problems.first.field, 'text');
    });

    test('عدّاد الأحرف يعدّ النص المطبَّع', () {
      expect(MessageRules.characterCounter('  مرحبا '), '5 / 500');
      expect(MessageRules.characterCounter(null), '0 / 500');
    });
  });
}
