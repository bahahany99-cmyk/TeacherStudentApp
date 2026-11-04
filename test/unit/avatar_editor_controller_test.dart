import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/data/services/avatar_repository.dart';
import 'package:teacher_student_app/features/profile/presentation/widgets/avatar_editor_controller.dart';

/// (P31) منطق الصورة: التحميل، الرفع، الإزالة، واختيار الرمزية — بلا واجهة.
///
/// **لماذا اختبار على وحدة مستقلة؟** لأن هذا هو المنطق الذي يُخطئ بصمت: رفع
/// فاشل يُبقي الصورة القديمة؟ إزالة تُفقد الاختيار؟ اختيار رمزية يترك صورة
/// مرفوعة تُخفيها؟ كلها حالات لا تظهر في لقطة شاشة.
class _FailingAvatarRepository implements AvatarRepository {
  _FailingAvatarRepository(this.delegate);

  final AvatarRepository delegate;
  bool failUpload = false;
  bool failRemove = false;
  bool failPreset = false;

  AppException get _error => const AppException(
    AppErrorKind.unavailable,
    overrideMessage: 'فشل متعمّد',
  );

  @override
  Future<UserAvatar?> getFor(String uid) => delegate.getFor(uid);

  @override
  Future<UserAvatar> upload({
    required String uid,
    required Uint8List bytes,
    required String mimeType,
  }) {
    if (failUpload) {
      throw _error;
    }
    return delegate.upload(uid: uid, bytes: bytes, mimeType: mimeType);
  }

  @override
  Future<void> remove(String uid, {int? preset}) {
    if (failRemove) {
      throw _error;
    }
    return delegate.remove(uid, preset: preset);
  }

  @override
  Future<void> ensureDefault(String uid) => delegate.ensureDefault(uid);

  @override
  Future<void> setPreset({required String uid, required int preset}) {
    if (failPreset) {
      throw _error;
    }
    return delegate.setPreset(uid: uid, preset: preset);
  }
}

Uint8List _tinyBytes() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEElEQVR42mM4UREF'
  'RwzEcQChchmhDx/bcgAAAABJRU5ErkJggg==',
);

void main() {
  late DemoAvatarRepository store;
  late _FailingAvatarRepository repository;
  late AvatarEditorController controller;

  setUp(() {
    store = DemoAvatarRepository();
    repository = _FailingAvatarRepository(store);
    controller = AvatarEditorController(userId: 'uid-1', initialPreset: 5);
  });

  group('(P31) التحميل والافتراضي', () {
    test('قبل أي شيء: الاختيار الأولي هو المعروض', () {
      expect(controller.preset, 5);
      expect(controller.hasUploadedPhoto, isFalse);
      expect(controller.resolution.asset, AvatarPresets.all[5].asset);
    });

    test('تحميل مستند فيه اختيار ⇒ الاختيار المحفوظ يتغلّب على الأولي', () async {
      await store.setPreset(uid: 'uid-1', preset: 17);
      await controller.load(repository);
      expect(controller.preset, 17);
      expect(controller.loaded, isTrue);
    });

    test('تحميل مستند فيه صورة ⇒ صورتان مرفوعة ومختارة معًا', () async {
      await store.upload(
        uid: 'uid-1',
        bytes: _tinyBytes(),
        mimeType: 'image/png',
      );
      await store.setPreset(uid: 'uid-1', preset: 9);

      await controller.load(repository);
      expect(controller.hasUploadedPhoto, isTrue);
      expect(controller.preset, 9);
      expect(controller.uploadedBytes, isNotNull);
    });

    test('فشل التحميل لا يمنع الاستخدام', () async {
      // مستودع يرمي من getFor.
      final AvatarEditorController other = AvatarEditorController(
        userId: 'uid-2',
        initialPreset: 2,
      );
      await other.load(_ThrowingRepository(store));
      expect(other.preset, 2);
      expect(other.hasUploadedPhoto, isFalse);
    });
  });

  group('(P31) الرفع والإزالة', () {
    test('الرفع يحفظ الصورة ويغيّر المعروض', () async {
      await controller.uploadPhoto(
        repository,
        bytes: _tinyBytes(),
        mimeType: 'image/png',
      );
      expect(controller.hasUploadedPhoto, isTrue);
      expect(controller.busy, isFalse);
      final UserAvatar? stored = await store.getFor('uid-1');
      expect(stored?.hasCustomPhoto, isTrue);
    });

    test('فشل الرفع لا يستبدل الصورة الحالية', () async {
      await controller.uploadPhoto(
        repository,
        bytes: _tinyBytes(),
        mimeType: 'image/png',
      );
      final Uint8List before = controller.uploadedBytes!;

      repository.failUpload = true;
      await expectLater(
        controller.uploadPhoto(
          repository,
          bytes: _tinyBytes(),
          mimeType: 'image/png',
        ),
        throwsA(isA<AppException>()),
      );

      expect(controller.hasUploadedPhoto, isTrue);
      expect(controller.uploadedBytes, before, reason: 'الصورة القديمة تبقى');
      expect(controller.busy, isFalse, reason: 'لا يبقى الزر معطّلًا');
    });

    test('الإزالة تُسقط الصورة وتُبقي الاختيار', () async {
      await store.setPreset(uid: 'uid-1', preset: 8);
      await controller.load(repository);
      await controller.uploadPhoto(
        repository,
        bytes: _tinyBytes(),
        mimeType: 'image/png',
      );

      await controller.removePhoto(repository);

      expect(controller.hasUploadedPhoto, isFalse);
      expect(controller.preset, 8);
      final UserAvatar? stored = await store.getFor('uid-1');
      expect(stored?.hasCustomPhoto, isFalse);
      expect(stored?.presetId, 8);
    });

    test('إزالة بلا صورة لا تُنشئ حالة غريبة', () async {
      await controller.removePhoto(repository);
      expect(controller.hasUploadedPhoto, isFalse);
      expect(controller.preset, 5);
    });

    test('فشل الإزالة يُبقي الصورة معروضة', () async {
      await controller.uploadPhoto(
        repository,
        bytes: _tinyBytes(),
        mimeType: 'image/png',
      );
      repository.failRemove = true;

      await expectLater(
        controller.removePhoto(repository),
        throwsA(isA<AppException>()),
      );
      expect(controller.hasUploadedPhoto, isTrue);
      expect(controller.busy, isFalse);
    });
  });

  group('(P31) اختيار الصورة الرمزية', () {
    test('اختيار الرمزية يزيل الصورة المرفوعة ويحفظ المعرّف', () async {
      await controller.uploadPhoto(
        repository,
        bytes: _tinyBytes(),
        mimeType: 'image/png',
      );

      await controller.choosePreset(repository, 21);

      expect(controller.hasUploadedPhoto, isFalse, reason: 'الرمزية هي المعروضة');
      expect(controller.preset, 21);
      final UserAvatar? stored = await store.getFor('uid-1');
      expect(stored?.hasCustomPhoto, isFalse);
      expect(stored?.presetId, 21);
    });

    test('الاختيار يمرّ بالجلسة عند توفّرها', () async {
      int? savedOnSession;
      await controller.choosePreset(
        repository,
        12,
        onSessionPreset: (int preset) async {
          savedOnSession = preset;
          await store.setPreset(uid: 'uid-1', preset: preset);
        },
      );
      expect(savedOnSession, 12);
      expect((await store.getFor('uid-1'))?.presetId, 12);
    });

    test('قيمة خارج المدى تُطبَّع قبل الحفظ', () async {
      await controller.choosePreset(repository, 999);
      expect(controller.preset, AvatarPresets.forId('uid-1'));
    });

    test('فشل حفظ الاختيار لا يُظهر اختيارًا لم يُحفظ', () async {
      repository.failPreset = true;
      await expectLater(
        controller.choosePreset(repository, 15),
        throwsA(isA<AppException>()),
      );
      expect(controller.preset, 5, reason: 'تبقى الحالة السابقة');
      expect(controller.busy, isFalse);
    });
  });
}

/// مستودع يرمي من `getFor` وحده — لاختبار متانة التحميل.
class _ThrowingRepository implements AvatarRepository {
  _ThrowingRepository(this.delegate);

  final AvatarRepository delegate;

  @override
  Future<UserAvatar?> getFor(String uid) async {
    throw const AppException(
      AppErrorKind.unavailable,
      overrideMessage: 'تعذّرت القراءة',
    );
  }

  @override
  Future<UserAvatar> upload({
    required String uid,
    required Uint8List bytes,
    required String mimeType,
  }) => delegate.upload(uid: uid, bytes: bytes, mimeType: mimeType);

  @override
  Future<void> remove(String uid, {int? preset}) =>
      delegate.remove(uid, preset: preset);

  @override
  Future<void> ensureDefault(String uid) => delegate.ensureDefault(uid);

  @override
  Future<void> setPreset({required String uid, required int preset}) =>
      delegate.setPreset(uid: uid, preset: preset);
}
