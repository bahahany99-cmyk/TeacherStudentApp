import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/models/account_status.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/data/models/user_role.dart';

/// (P22) صور الحساب: الصورة الافتراضية الحتمية، والقراءة المتسامحة للصورة
/// المرفوعة، وحدود الحجم التي تفرضها القواعد أيضًا.
void main() {
  group('AvatarPresets — الصورة الافتراضية', () {
    test('اختيار حتمي: نفس المعرّف ⇒ نفس التصميم دائمًا', () {
      final int first = AvatarPresets.forId('student-42');
      expect(AvatarPresets.forId('student-42'), first);
      expect(first, inInclusiveRange(0, AvatarPresets.count - 1));
    });

    test('المعرّفات المختلفة تتوزّع على أكثر من تصميم', () {
      final Set<int> designs = <int>{
        for (int i = 0; i < 40; i++) AvatarPresets.forId('uid-$i'),
      };
      expect(designs.length, greaterThan(1));
    });

    test('المعرّف الفارغ لا ينكسر', () {
      expect(AvatarPresets.forId(''), 0);
    });

    test('تطبيع قيمة قديمة/خارجة عن المدى إلى تصميم صالح', () {
      expect(AvatarPresets.normalize(null, 'uid'), AvatarPresets.forId('uid'));
      expect(AvatarPresets.normalize(99, 'uid'), AvatarPresets.forId('uid'));
      expect(AvatarPresets.normalize(-1, 'uid'), AvatarPresets.forId('uid'));
      expect(AvatarPresets.normalize(3, 'uid'), 3);
    });

    test('كل تصميم له تدرّج بلونين مختلفين', () {
      expect(AvatarPresets.gradients.length, AvatarPresets.count);
      for (final (int, int) pair in AvatarPresets.gradients) {
        expect(pair.$1, isNot(pair.$2));
        expect(pair.$1, inInclusiveRange(0, 0xFFFFFFFF));
        expect(pair.$2, inInclusiveRange(0, 0xFFFFFFFF));
      }
    });
  });

  group('UserAvatar — صورة مرفوعة', () {
    final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

    test('بايتات صحيحة تُفكّ وتُعرض', () {
      final UserAvatar avatar = UserAvatar(
        ownerId: 'uid-1',
        imageBase64: base64Encode(bytes),
        mimeType: 'image/png',
      );

      expect(avatar.hasCustomPhoto, isTrue);
      expect(avatar.bytes, bytes);
    });

    test('ترميز تالف لا يُسقط الشاشة: يعود null فتظهر الافتراضية', () {
      const UserAvatar broken = UserAvatar(
        ownerId: 'uid-1',
        imageBase64: '###ليس base64###',
        mimeType: 'image/jpeg',
      );

      expect(broken.hasCustomPhoto, isTrue);
      expect(broken.bytes, isNull);
      expect(broken.resolvedPresetId, AvatarPresets.forId('uid-1'));
    });

    test('لا صورة ⇒ hasCustomPhoto=false والتصميم الحتمي', () {
      const UserAvatar empty = UserAvatar(ownerId: 'uid-7');

      expect(empty.hasCustomPhoto, isFalse);
      expect(empty.bytes, isNull);
      expect(empty.resolvedPresetId, AvatarPresets.forId('uid-7'));
    });

    test('withImage يحفظ التصميم الحالي ويضيف الصورة', () {
      const UserAvatar base = UserAvatar(ownerId: 'uid-7', presetId: 4);
      final UserAvatar updated = base.withImage(
        imageBase64: base64Encode(bytes),
        mimeType: 'image/png',
      );

      expect(updated.presetId, 4);
      expect(updated.hasCustomPhoto, isTrue);
      expect(updated.resolvedPresetId, 4);
    });

    test('حدود الحجم معلنة ومتسقة مع ما تفرضه القواعد', () {
      expect(AvatarLimits.maxBase64Length, 200000);
      expect(AvatarLimits.pickMaxDimension, lessThanOrEqualTo(1024));
      expect(AvatarLimits.mimeTypes, containsAll(<String>['image/jpeg', 'image/png']));
      expect(AvatarLimits.mimeTypes, isNot(contains('image/svg+xml')));
    });
  });

  group('AppUser — التصميم كجزء من الحساب', () {
    const AppUser user = AppUser(
      id: 'uid-9',
      displayName: 'طالب',
      role: UserRole.student,
    );

    test('بلا قيمة محفوظة: التصميم الحتمي من المعرّف (الحساب ليس بلا صورة)', () {
      expect(user.avatarPreset, isNull);
      expect(user.resolvedAvatarPreset, AvatarPresets.forId('uid-9'));
    });

    test('withAvatarPreset يثبّت الاختيار ويطبّع القيم الخارجة', () {
      expect(user.withAvatarPreset(2).avatarPreset, 2);
      expect(user.withAvatarPreset(2).resolvedAvatarPreset, 2);
      // قيمة خارج المدى تُطبَّع لا تُخزَّن كما هي.
      expect(
        user.withAvatarPreset(42).resolvedAvatarPreset,
        AvatarPresets.forId('uid-9'),
      );
    });

    test('تعديل البيانات الشخصية أو حالة الحساب لا يمحو الصورة', () {
      final AppUser withPreset = user.withAvatarPreset(5);
      expect(
        withPreset
            .withPersonalInfo(displayName: 'اسم', phone: '0100', stage: null)
            .avatarPreset,
        5,
      );
      expect(
        withPreset.withAccountStatus(AccountStatus.active).avatarPreset,
        5,
      );
    });
  });
}
