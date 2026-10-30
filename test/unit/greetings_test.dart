import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/utils/greetings.dart';

void main() {
  group('P25 — تحيّة الرئيسية حسب الساعة', () {
    DateTime at(int hour) => DateTime(2026, 10, 20, hour);

    test('الفترات الخمس بنصوصها', () {
      expect(Greetings.lineFor(at(4)), 'صباح الخير');
      expect(Greetings.lineFor(at(10)), 'صباح الخير');
      expect(Greetings.lineFor(at(11)), 'يومك سعيد');
      expect(Greetings.lineFor(at(15)), 'يومك سعيد');
      expect(Greetings.lineFor(at(16)), 'مساء الخير');
      expect(Greetings.lineFor(at(19)), 'مساء الخير');
      expect(Greetings.lineFor(at(20)), 'سهرة موفّقة');
      expect(Greetings.lineFor(at(23)), 'سهرة موفّقة');
      expect(Greetings.lineFor(at(0)), 'سهرة موفّقة');
      expect(Greetings.lineFor(at(3)), 'سهرة موفّقة');
    });

    test('كل ساعة من اليوم لها تحيّة وسطر غير فارغين', () {
      for (int hour = 0; hour < 24; hour++) {
        expect(Greetings.lineFor(at(hour)).trim(), isNotEmpty);
        expect(Greetings.subtitleFor(at(hour)).trim(), isNotEmpty);
      }
    });

    test('السطر التحفيزي يتبع الفترة نفسها', () {
      expect(Greetings.subtitleFor(at(6)), contains('يومك'));
      // «ليلة هادئة للمراجعة» — نطابق الكلمة لا تعريفها بـ«ال»، لأن الصياغة
      // الطبيعية تستخدم «للمراجعة» وهي لا تحتوي «المراجعة» حرفيًا.
      expect(Greetings.subtitleFor(at(22)), contains('مراجعة'));
    });
  });
}
