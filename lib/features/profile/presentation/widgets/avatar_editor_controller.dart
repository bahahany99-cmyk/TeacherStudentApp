import 'package:flutter/foundation.dart';

import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/data/services/avatar_repository.dart';

/// حالة صورة الحساب ومنطق حفظها (P31) — بلا واجهة وبلا `BuildContext`.
///
/// **لماذا صنف مستقل؟** لأن ثلاث واجهات تستخدم نفس المنطق: بطاقة الحساب
/// (ورقة الإعدادات)، معرض الصور الرمزية، ونموذج ملف المدرّس. نسخُ المنطق في
/// كل واحدة هو أصل التباعد الذي نتجنّبه؛ الاختبارات تغطّي هذا الصنف مباشرة
/// (رفع، إزالة، اختيار رمزية، فشل) فلا يعتمد السلوك على اختبار واجهة هشّ.
///
/// **قاعدة الأولوية** تأتي من [AvatarResolution] — مصدر واحد مشترك مع العرض.
class AvatarEditorController extends ChangeNotifier {
  AvatarEditorController({required this.userId, required int initialPreset})
    : _preset = AvatarPresets.normalize(initialPreset, userId);

  /// صاحب الصورة.
  final String userId;

  UserAvatar? _image;
  int _preset;
  bool _busy = false;
  bool _loaded = false;

  /// مستند الصورة كما قرأناه (بايتات + اختيار محفوظ).
  UserAvatar? get image => _image;

  /// الاختيار المحفوظ المعروض (بعد التطبيع).
  int get preset => _preset;

  bool get busy => _busy;

  bool get loaded => _loaded;

  /// هل توجد صورة مرفوعة صالحة تُعرض الآن؟
  bool get hasUploadedPhoto => resolution.isUploaded;

  /// القرار الكامل للعرض (أولوية: مرفوعة ← مختارة ← افتراضية).
  AvatarResolution get resolution =>
      AvatarResolution.resolve(ownerId: userId, avatar: _image, chosenPreset: _preset);

  /// بايتات الصورة المرفوعة إن وُجدت (للمعاينة الفورية).
  Uint8List? get uploadedBytes => resolution.bytes;

  /// يقرأ المستند مرة واحدة. فشل القراءة **لا يمنع** استخدام الشاشة: تظهر
  /// الرمزية الافتراضية، ويبقى بإمكان المستخدم الرفع أو الاختيار.
  Future<void> load(AvatarRepository repository) async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final UserAvatar? loaded = await repository.getFor(userId);
      _image = loaded;
      if (loaded?.presetId != null) {
        _preset = AvatarPresets.normalize(loaded!.presetId, userId);
      }
    } on Object {
      // لا شيء: الحالة الافتراضية كافية.
    }
    notifyListeners();
  }

  /// رفع الصورة المقصوصة. لا يُستبدل العرض إلا بعد نجاح الرفع.
  Future<void> uploadPhoto(
    AvatarRepository repository, {
    required Uint8List bytes,
    required String mimeType,
  }) async {
    _setBusy(true);
    try {
      final UserAvatar saved = await repository.upload(
        uid: userId,
        bytes: bytes,
        mimeType: mimeType,
      );
      _image = saved;
      if (saved.presetId != null) {
        _preset = AvatarPresets.normalize(saved.presetId, userId);
      }
    } finally {
      _setBusy(false);
    }
  }

  /// إزالة الصورة المرفوعة والعودة إلى الرمزية (المختارة إن وُجدت).
  ///
  /// **لا يُمسّ الحساب ولا الاختيار**: مستند الصورة يفقد بايتاته فقط، و
  /// `avatarPreset` يبقى كما هو — وهذا شرط P31 الصريح.
  Future<void> removePhoto(AvatarRepository repository) async {
    _setBusy(true);
    try {
      await repository.remove(userId, preset: _preset);
      // نحتفظ بالاختيار ونُسقط البايتات فقط.
      _image = UserAvatar(ownerId: userId, presetId: _preset);
    } finally {
      _setBusy(false);
    }
  }

  /// اعتماد صورة رمزية.
  ///
  /// **لماذا تزيل الصورة المرفوعة؟** لأن الأولوية تجعل المرفوعة تتفوّق دائمًا،
  /// فلو أبقيناها لما رأى المستخدم ما اختار. الإزالة هنا **مقصودة ومعلنة** في
  /// الواجهة، والصورة القديمة تُرفع من جديد إن أراد الرجوع إليها.
  Future<void> choosePreset(
    AvatarRepository repository,
    int preset, {
    Future<void> Function(int preset)? onSessionPreset,
  }) async {
    final int normalized = AvatarPresets.normalize(preset, userId);
    _setBusy(true);
    try {
      if (resolution.isUploaded) {
        await repository.remove(userId, preset: normalized);
      }
      if (onSessionPreset != null) {
        await onSessionPreset(normalized);
      } else {
        await repository.setPreset(uid: userId, preset: normalized);
      }
      _preset = normalized;
      _image = UserAvatar(ownerId: userId, presetId: normalized);
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
