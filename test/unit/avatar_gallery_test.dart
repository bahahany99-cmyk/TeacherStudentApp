import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/models/user_avatar.dart';

/// (P31) معرض الصور الرمزية: العدد، التوزيع، تفرّد المعرّفات، و**وجود الملفات
/// فعلًا**.
///
/// فحص الملفات على القرص مقصود: مسار خاطئ أو صورة نُسيت لا يظهر في التحليل ولا
/// في الترجمة، ويظهر فقط كدائرة فارغة على جهاز المستخدم. الاختبار يقطع الطريق
/// قبل البناء.
void main() {
  group('(P31) كتالوج الصور الرمزية', () {
    test('30 صورة بالضبط: عشر فئات × ثلاث صور', () {
      expect(AvatarPresets.count, 30);
      expect(AvatarPresets.all.length, 30);
      expect(AvatarPresets.perCategory, 3);
      expect(AvatarCategory.values.length, 10);
      expect(AvatarPresets.perCategory * AvatarCategory.values.length, 30);

      for (final AvatarCategory category in AvatarCategory.values) {
        expect(
          AvatarPresets.ofCategory(category).length,
          AvatarPresets.perCategory,
          reason: 'الفئة ${category.label} يجب أن تحوي 3 صور',
        );
      }
    });

    test('الفئات العشر المطلوبة موجودة بالترتيب المعلن', () {
      expect(
        AvatarCategory.values.map((AvatarCategory c) => c.label).toList(),
        <String>[
          'أولاد أطفال',
          'بنات أطفال',
          'أولاد مراهقون',
          'بنات مراهقات',
          'شباب',
          'شابات',
          'رجال بالغون',
          'نساء بالغات',
          'رجال كبار السن',
          'نساء كبيرات السن',
        ],
      );
    });

    test('معرّفات الصور القديمة ثابتة (لا تتغيّر بإضافة صور)', () {
      // القائمة الحرجة: ترتيب الملفات للمعرّفات 0..23 كما نُشرت في P31.
      // أي إعادة ترتيب هنا تعني أن مستخدمًا اختار صورة فسيَرى صورة أخرى.
      const List<String> legacyAssets = <String>[
        'assets/avatars/boy_01.jpg',
        'assets/avatars/boy_02.jpg',
        'assets/avatars/boy_03.jpg',
        'assets/avatars/boy_04.jpg',
        'assets/avatars/girl_01.jpg',
        'assets/avatars/girl_02.jpg',
        'assets/avatars/girl_03.jpg',
        'assets/avatars/girl_04.jpg',
        'assets/avatars/man_01.jpg',
        'assets/avatars/man_02.jpg',
        'assets/avatars/man_03.jpg',
        'assets/avatars/man_04.jpg',
        'assets/avatars/woman_01.jpg',
        'assets/avatars/woman_02.jpg',
        'assets/avatars/woman_03.jpg',
        'assets/avatars/woman_04.jpg',
        'assets/avatars/elder_man_01.jpg',
        'assets/avatars/elder_man_02.jpg',
        'assets/avatars/elder_man_03.jpg',
        'assets/avatars/elder_man_04.jpg',
        'assets/avatars/elder_woman_01.jpg',
        'assets/avatars/elder_woman_02.jpg',
        'assets/avatars/elder_woman_03.jpg',
        'assets/avatars/elder_woman_04.jpg',
      ];
      for (int i = 0; i < legacyAssets.length; i++) {
        expect(
          AvatarPresets.all[i].asset,
          legacyAssets[i],
          reason: 'معرّف الصورة $i تغيّر',
        );
      }
      // الصور الجديدة كلها بعد القديمة.
      expect(AvatarPresets.all[24].id, 24);
      expect(AvatarPresets.all[29].id, 29);
    });

    test('المعرّف يساوي الموضع، والمسارات فريدة ومضمَّنة', () {
      final Set<String> assets = <String>{};
      for (int i = 0; i < AvatarPresets.all.length; i++) {
        final AvatarArtwork artwork = AvatarPresets.all[i];
        expect(artwork.id, i, reason: 'الترتيب هو العقد');
        expect(artwork.asset, startsWith('assets/avatars/'));
        expect(assets.add(artwork.asset), isTrue, reason: 'مسار مكرّر');
        expect(artwork.description.trim(), isNotEmpty);
      }
    });

    test('كل ملف صورة موجود فعلًا على القرص', () {
      for (final AvatarArtwork artwork in AvatarPresets.all) {
        final File file = File(artwork.asset);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'ملف مفقود: ${artwork.asset}',
        );
        // ملف خفيف: سقف 60KB لكل صورة (المتوقع 10–25KB).
        expect(file.lengthSync(), lessThan(60 * 1024));
      }
    });

    test('البدائل اللونية كافية ولا تنكسر', () {
      expect(AvatarPresets.fallbackGradients, isNotEmpty);
      for (final (int, int) pair in AvatarPresets.fallbackGradients) {
        expect(pair.$1, isNot(pair.$2));
      }
    });
  });

  group('(P31) اختيار الصورة الرمزية وحفظها', () {
    test('الحتمية: نفس المعرّف ⇒ نفس الصورة دائمًا', () {
      final int first = AvatarPresets.forId('student-42');
      expect(AvatarPresets.forId('student-42'), first);
      expect(first, inInclusiveRange(0, AvatarPresets.count - 1));
    });

    test('المعرّفات المختلفة تتوزّع على أكثر من صورة', () {
      final Set<int> designs = <int>{
        for (int i = 0; i < 40; i++) AvatarPresets.forId('uid-$i'),
      };
      expect(designs.length, greaterThan(4));
    });

    test('المعرّف الفارغ لا ينكسر', () {
      expect(AvatarPresets.forId(''), 0);
    });

    test('الاحتياط الحتمي يبقى في نطاق الصور القديمة (24) حتى لا تتغيّر صورة أحد', () {
      for (int i = 0; i < 200; i++) {
        expect(
          AvatarPresets.forId('legacy-user-$i'),
          inInclusiveRange(0, AvatarPresets.legacyDeterministicCount - 1),
        );
      }
      expect(AvatarPresets.legacyDeterministicCount, 24);
      expect(AvatarPresets.normalize(29, 'uid'), 29);
      expect(AvatarPresets.normalize(30, 'uid'), AvatarPresets.forId('uid'));
    });

    test('تطبيع قيمة قديمة/خارجة عن المدى', () {
      expect(AvatarPresets.normalize(null, 'uid'), AvatarPresets.forId('uid'));
      expect(AvatarPresets.normalize(99, 'uid'), AvatarPresets.forId('uid'));
      expect(AvatarPresets.normalize(-1, 'uid'), AvatarPresets.forId('uid'));
      // قيم P22 القديمة (0..5) تبقى صالحة — لا ترحيل.
      for (int legacy = 0; legacy < 6; legacy++) {
        expect(AvatarPresets.normalize(legacy, 'uid'), legacy);
      }
      expect(AvatarPresets.normalize(23, 'uid'), 23);
    });

    test('artworkOf يطابق المعرّف ويطبّع غير الصالح', () {
      expect(AvatarPresets.artworkOf(11).id, 11);
      expect(
        AvatarPresets.artworkOf(500, ownerId: 'uid').id,
        AvatarPresets.forId('uid'),
      );
    });
  });

  group('(P31) أولوية الصورة: مرفوعة ← مختارة ← افتراضية', () {
    const String uid = 'uid-priority';

    test('صورة مرفوعة صالحة تتقدّم على الاختيار', () {
      final UserAvatar avatar = UserAvatar(
        ownerId: uid,
        imageBase64: base64Encode(<int>[1, 2, 3, 4]),
        mimeType: 'image/png',
        presetId: 9,
      );

      final AvatarResolution resolution = AvatarResolution.resolve(
        ownerId: uid,
        avatar: avatar,
        chosenPreset: 2,
      );

      expect(resolution.isUploaded, isTrue);
      expect(resolution.presetId, 9, reason: 'الاختيار المحفوظ في المستند');
      expect(resolution.bytes, isNotNull);
    });

    test('بلا صورة: الاختيار المحفوظ هو المعروض', () {
      final AvatarResolution resolution = AvatarResolution.resolve(
        ownerId: uid,
        avatar: const UserAvatar(ownerId: uid, presetId: 14),
      );
      expect(resolution.isUploaded, isFalse);
      expect(resolution.presetId, 14);
    });

    test('بلا مستند إطلاقًا: الرمزية الحتمية من المعرّف', () {
      final AvatarResolution resolution = AvatarResolution.resolve(
        ownerId: uid,
        chosenPreset: 3,
      );
      expect(resolution.presetId, 3);
      expect(resolution.bytes, isNull);
    });

    test('بلا مستند وبلا اختيار: الحتمية', () {
      final AvatarResolution resolution = AvatarResolution.resolve(ownerId: uid);
      expect(resolution.presetId, AvatarPresets.forId(uid));
      expect(resolution.asset, AvatarPresets.all[AvatarPresets.forId(uid)].asset);
    });

    test('بايتات تالفة (base64 غير صالح) لا تُعدّ صورة مرفوعة', () {
      final AvatarResolution resolution = AvatarResolution.resolve(
        ownerId: uid,
        avatar: const UserAvatar(
          ownerId: uid,
          imageBase64: 'not-base64!!',
          mimeType: 'image/png',
          presetId: 4,
        ),
      );
      expect(resolution.isUploaded, isFalse);
      expect(resolution.presetId, 4);
    });

    test('قيمة اختيار خارج المدى تعود إلى الحتمية', () {
      final AvatarResolution resolution = AvatarResolution.resolve(
        ownerId: uid,
        avatar: const UserAvatar(ownerId: uid, presetId: 999),
        chosenPreset: 1,
      );
      expect(resolution.presetId, AvatarPresets.forId(uid));
    });
  });

  group('(P31) مستند الصورة', () {
    test('الصورة المرفوعة تُقرأ بايتات، والتالفة تعود null', () {
      final Uint8List bytes = Uint8List.fromList(<int>[7, 7, 7]);
      final UserAvatar avatar = UserAvatar(
        ownerId: 'uid',
        imageBase64: base64Encode(bytes),
        mimeType: 'image/png',
      );
      expect(avatar.bytes, bytes);
      expect(avatar.hasCustomPhoto, isTrue);

      const UserAvatar broken = UserAvatar(
        ownerId: 'uid',
        imageBase64: '%%%',
        mimeType: 'image/png',
      );
      expect(broken.bytes, isNull);
      expect(broken.hasCustomPhoto, isTrue, reason: 'الحقل موجود لكنه تالف');
    });

    test('withPreset يحفظ البايتات ويغيّر الاختيار فقط', () {
      final UserAvatar avatar = UserAvatar(
        ownerId: 'uid',
        imageBase64: base64Encode(<int>[1]),
        mimeType: 'image/jpeg',
        presetId: 1,
      );
      final UserAvatar next = avatar.withPreset(20);
      expect(next.presetId, 20);
      expect(next.imageBase64, avatar.imageBase64);
    });

    test('حدود الصورة موثّقة وتفي بسقف القواعد', () {
      expect(AvatarLimits.maxBase64Length, greaterThan(0));
      expect(AvatarLimits.mimeTypes, contains('image/jpeg'));
    });
  });
}
