import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/avatar_cropper.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/image_picker_gateway.dart';
import 'package:teacher_student_app/features/profile/presentation/avatar_crop_screen.dart';
import 'package:teacher_student_app/features/profile/presentation/avatar_gallery_screen.dart';
import 'package:teacher_student_app/features/profile/presentation/widgets/avatar_editor_controller.dart';

/// الأفعال الثلاثة لصورة الحساب (P31) — مكان واحد يربط الاختيار والقصّ والرفع.
///
/// **التسلسل ليس تفصيلًا:** اختيار ← **قصّ ومعاينة** ← رفع ← تحديث العرض.
/// ولا خطوة تكتب على التخزين قبل نجاح ما قبلها، ولذلك:
/// - إلغاء المنتقي ⇒ لا شيء.
/// - إلغاء القصّ ⇒ لا شيء.
/// - فشل الرفع ⇒ الصورة المحفوظة القديمة تبقى كما هي (لا حذف مسبق).
class AvatarActions {
  const AvatarActions._();

  /// تغيير الصورة الشخصية: منتقي النظام ← شاشة القصّ ← الرفع.
  ///
  /// يعيد `true` إذا حُفظت صورة جديدة.
  static Future<bool> changePhoto(
    BuildContext context,
    AvatarEditorController controller,
  ) async {
    if (controller.busy) {
      return false;
    }
    final AppServices services = AppServicesScope.of(context);

    final PickedImage? picked;
    try {
      picked = await services.imagePicker.pickFromGallery();
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
      return false;
    }
    // إلغاء المستخدم ليس خطأ: لا رسالة ولا تغيير.
    if (picked == null || !context.mounted) {
      return false;
    }

    final PickedImage? cropped = await _presentCrop(context, services, picked);
    if (cropped == null || !context.mounted) {
      return false;
    }

    try {
      await controller.uploadPhoto(
        services.avatars,
        bytes: cropped.bytes,
        mimeType: cropped.mimeType,
      );
      if (!context.mounted) {
        return true;
      }
      AppSnackBar.show(
        context,
        'حُدِّثت صورتك.',
        type: AppMessageType.success,
      );
      return true;
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
      return false;
    }
  }

  /// فتح المعرض واعتماد صورة رمزية. يعيد `true` عند الحفظ.
  static Future<bool> choosePreset(
    BuildContext context,
    AvatarEditorController controller,
  ) async {
    if (controller.busy) {
      return false;
    }
    final int? chosen = await AvatarGalleryScreen.show(
      context,
      currentPreset: controller.preset,
    );
    if (chosen == null ||
        (chosen == controller.preset && !controller.hasUploadedPhoto)) {
      return false;
    }
    if (!context.mounted) {
      return false;
    }
    return _savePreset(context, controller, chosen);
  }

  /// إزالة الصورة المرفوعة (يبقى الاختيار الرمزي والحساب كما هما).
  static Future<bool> removePhoto(
    BuildContext context,
    AvatarEditorController controller,
  ) async {
    if (controller.busy || !controller.hasUploadedPhoto) {
      return false;
    }
    final AppServices services = AppServicesScope.of(context);
    try {
      await controller.removePhoto(services.avatars);
      if (!context.mounted) {
        return true;
      }
      AppSnackBar.show(context, 'عُدت إلى صورتك الرمزية.');
      return true;
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
      return false;
    }
  }

  /// حفظ معرّف الرمزية — يمرّ بالجلسة إن وُجدت (فتتحدّث بطاقة الحساب فورًا)
  /// وإلا بالمستودع مباشرة.
  static Future<bool> _savePreset(
    BuildContext context,
    AvatarEditorController controller,
    int preset,
  ) async {
    final SessionController? session = SessionScope.maybeOf(context);
    final AppServices services = AppServicesScope.of(context);

    Future<void> applyOnSession(int value) async {
      if (session != null) {
        await session.updateAvatarPreset(value);
      } else {
        await services.avatars.setPreset(uid: controller.userId, preset: value);
      }
    }

    try {
      await controller.choosePreset(
        services.avatars,
        preset,
        onSessionPreset: applyOnSession,
      );
      if (!context.mounted) {
        return true;
      }
      AppSnackBar.show(
        context,
        'اعتُمدت صورتك الرمزية.',
        type: AppMessageType.success,
      );
      return true;
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
      return false;
    }
  }

  /// شاشة القصّ — قابلة للاستبدال في الاختبارات عبر `AppServices.avatarCrop`.
  static Future<PickedImage?> _presentCrop(
    BuildContext context,
    AppServices services,
    PickedImage source,
  ) {
    final AvatarCropPresenter? presenter = services.avatarCrop;
    if (presenter != null) {
      return presenter(context, source);
    }
    return AvatarCropScreen.show(context, source);
  }

  static void _showError(BuildContext context, Object error) {
    final AppException exception = error is AppException
        ? error
        : toAppException(error);
    AppSnackBar.show(
      context,
      exception.overrideMessage ?? exception.message,
      type: AppMessageType.error,
    );
  }
}
