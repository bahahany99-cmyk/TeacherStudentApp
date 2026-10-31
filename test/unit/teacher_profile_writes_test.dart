import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/firebase/teacher_profile_writes.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// (P29) حمولات الكتابة على `teacherProfiles` — قواعد الظهور والإخفاء.
///
/// هذا الاختبار يحرس القرار الإداري: **التوثيق يُصلح الملف الناقص ولا يُظهر
/// حسابًا أخفاه أحد**.
const String _deleteMarker = '__DELETE__';
const String _timestampMarker = '__SERVER_TS__';

Map<String, Object?> _decision({
  required bool hasFlag,
  TeacherProfileStatus status = TeacherProfileStatus.verified,
  String? note,
}) {
  return TeacherProfileWrites.adminDecision(
    status: status,
    reviewNote: note,
    deletedValue: _deleteMarker,
    serverTimestamp: _timestampMarker,
    accountHiddenFlagPresent: hasFlag,
    adminUid: 'admin-1',
  );
}

void main() {
  group('قرار الإدارة — حقل الظهور', () {
    test('ملف بلا accountHidden: التوثيق يضيف false (فيصبح قابلًا للاكتشاف)', () {
      final Map<String, Object?> payload = _decision(hasFlag: false);

      expect(payload['accountHidden'], false);
      expect(payload['status'], 'verified');
      expect(payload['reviewedBy'], 'admin-1');
      expect(payload['reviewedAt'], _timestampMarker);
      expect(payload['reviewNote'], _deleteMarker);
    });

    test('حساب مخفي (true): لا يُكتب الحقل إطلاقًا فلا يعود للظهور', () {
      final Map<String, Object?> payload = _decision(hasFlag: true);

      expect(
        payload.containsKey('accountHidden'),
        isFalse,
        reason: 'قرار التوثيق لا يجوز أن يُظهر حسابًا أخفاه المسؤول',
      );
      expect(payload['status'], 'verified');
    });

    test('ملف ظاهر أصلًا (false): لا يُعاد كتابة الحقل (لا تغيير بلا داعٍ)', () {
      final Map<String, Object?> payload = _decision(hasFlag: true);

      expect(payload.containsKey('accountHidden'), isFalse);
    });

    test('الرفض يكتب السبب ولا يحذفه، ويضيف الحقل عند غيابه', () {
      final Map<String, Object?> payload = _decision(
        hasFlag: false,
        status: TeacherProfileStatus.rejected,
        note: 'النبذة تحتوي بيانات تواصل خارج التطبيق.',
      );

      expect(payload['status'], 'rejected');
      expect(payload['reviewNote'], 'النبذة تحتوي بيانات تواصل خارج التطبيق.');
      expect(payload['accountHidden'], false);
    });

    test('بلا هوية مراجع: لا يُكتب reviewedBy', () {
      final Map<String, Object?> payload = TeacherProfileWrites.adminDecision(
        status: TeacherProfileStatus.verified,
        reviewNote: null,
        deletedValue: _deleteMarker,
        serverTimestamp: _timestampMarker,
        accountHiddenFlagPresent: true,
      );

      expect(payload.containsKey('reviewedBy'), isFalse);
    });
  });

  group('حفظ صاحب الملف — ترقيع آمن', () {
    test('ملف ناقص الحقل: يُضاف false', () {
      expect(
        TeacherProfileWrites.ownerSaveBackfill(accountHiddenFlagPresent: false),
        <String, Object?>{'accountHidden': false},
      );
    });

    test('ملف يحمل الحقل: لا شيء يُضاف (حتى لو كان مخفيًا)', () {
      expect(
        TeacherProfileWrites.ownerSaveBackfill(accountHiddenFlagPresent: true),
        isEmpty,
      );
    });
  });
}
