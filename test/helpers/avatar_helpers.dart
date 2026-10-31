import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/image_picker_gateway.dart';

/// صورة PNG صغيرة **صالحة فعلًا** (4×4 بكسل).
///
/// لماذا صورة حقيقية لا بايتات عشوائية؟ لأن `Image.memory` يفكّ الترميز في
/// الاختبار؛ البايتات العشوائية تُظهر خطأ فك ترميز (يُبتلع بـ`errorBuilder`
/// لكنه يضجّ في سجل الاختبار) ولا تُثبت أن الصورة تُعرض.
const String kTinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEElEQVR42mM4UREF'
    'RwzEcQChchmhDx/bcgAAAABJRU5ErkJggg==';

Uint8List tinyPngBytes() => base64Decode(kTinyPngBase64);

/// منتقي صور اصطناعي: يعيد ما نحدده، أو يلغي، أو يفشل — بلا منصّة.
class FakeImagePickerGateway implements ImagePickerGateway {
  FakeImagePickerGateway({this.result, this.error});

  /// ما يعيده عند الاختيار (`null` = ألغى المستخدم).
  PickedImage? result;

  /// خطأ يُرمى بدل الاختيار (لمسار الفشل).
  AppException? error;

  int pickCalls = 0;

  /// (P24) آخر غرض اختيار طُلب — يتحقق الاختبار منه أن صور المحادثة تُطلب
  /// بأبعاد أكبر من صور الحساب.
  ImagePickPreset? lastPreset;

  @override
  Future<PickedImage?> pickFromGallery({
    ImagePickPreset preset = ImagePickPreset.avatar,
  }) async {
    pickCalls++;
    lastPreset = preset;
    final AppException? failure = error;
    if (failure != null) {
      throw failure;
    }
    return result;
  }
}

/// حزمة جاهزة لاختبار الصور في الوضع التجريبي (ذاكرة، بلا Firestore).
AppServices avatarTestServices({
  PickedImage? picked,
  FakeImagePickerGateway? picker,
}) {
  return AppServices.demo(imagePicker: picker ?? FakeImagePickerGateway(result: picked));
}

/// يرفع صورة جاهزة لحساب معيّن (تهيئة اختبار: المدرس يحتاج صورة قبل الحفظ).
Future<void> seedAvatar(AppServices services, String uid) async {
  await services.avatars.upload(
    uid: uid,
    bytes: tinyPngBytes(),
    mimeType: 'image/png',
  );
}

/// يضغط زر حفظ ملف المدرس، ويمرّ بحوار إعادة التحقق إن ظهر.
///
/// (P22) تعديل ملف موثّق يعرض تأكيدًا قبل الحفظ؛ الاختبار الذي يقيس «الحفظ
/// نجح» يجب أن يمرّ بنفس المسار الذي يمرّ به المستخدم، لا أن يتخطاه.
Future<void> pressProfileSave(WidgetTester tester) async {
  final FilledButton save = tester.widget<FilledButton>(
    find.byKey(const Key('profile-save')),
  );
  save.onPressed!();
  await tester.pumpAndSettle();

  final Finder confirm = find.byKey(const Key('profile-reverify-confirm'));
  if (confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm);
    await tester.pumpAndSettle();
  }
}
