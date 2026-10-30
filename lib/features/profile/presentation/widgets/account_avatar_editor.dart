import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/user_avatar_view.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/image_picker_gateway.dart';

/// حالة الصورة المختارة — يقرأها نموذج ملف المدرس ليعرف هل توجد صورة.
class AvatarSelection {
  const AvatarSelection({required this.preset, this.image});

  /// التصميم الافتراضي المختار.
  final int preset;

  /// الصورة المخصّصة المرفوعة (`null` = افتراضية).
  final UserAvatar? image;

  /// هل توجد صورة مخصّصة فعلًا؟ (شرط حفظ ملف المدرس)
  bool get hasCustomPhoto => image?.hasCustomPhoto ?? false;
}

/// محرّر صورة الحساب (P22) — يستخدمه الطالب والمدرس بنفس السلوك.
///
/// يعرض الصورة الحالية، ويتيح: اختيار صورة من الجهاز، أو تصميم افتراضي، أو
/// إزالة الصورة المخصّصة. كل الكتابة تمرّ عبر `AvatarRepository`، فالشاشة لا
/// تعرف Firestore ولا `image_picker`.
///
/// **لماذا هذا الودجت مشترك؟** لأن قاعدة «الحساب ليس بلا صورة» واحدة: الطالب
/// يغيّر صورته من «بياناتي»، والمدرس يضيف صورته من نموذج ملفه. نسختان من نفس
/// المنطق تعنيان اختلافًا في السلوك — وهذا ما نتجنّبه عمدًا.
class AccountAvatarEditor extends StatefulWidget {
  const AccountAvatarEditor({
    super.key,
    required this.userId,
    required this.initialPreset,
    this.initials,
    this.enabled = true,
    this.size = 88,
    this.showPresets = true,
    this.onChanged,
    this.helperText,
  });

  final String userId;
  final int initialPreset;
  final String? initials;

  /// `false` ⇒ عرض فقط (مثلًا: الملف مقفل أثناء المراجعة).
  final bool enabled;

  final double size;

  /// إظهار شبكة التصاميم الافتراضية.
  final bool showPresets;

  /// تُستدعى عند كل تغيير (تحميل، رفع، اختيار تصميم، إزالة).
  final ValueChanged<AvatarSelection>? onChanged;

  final String? helperText;

  @override
  State<AccountAvatarEditor> createState() => _AccountAvatarEditorState();
}

class _AccountAvatarEditorState extends State<AccountAvatarEditor> {
  late int _preset = widget.initialPreset;
  UserAvatar? _image;
  bool _busy = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  void _report() {
    widget.onChanged?.call(AvatarSelection(preset: _preset, image: _image));
  }

  Future<void> _load() async {
    try {
      final UserAvatar? image = await AppServicesScope.of(
        context,
      ).avatars.getFor(widget.userId);
      if (!mounted) {
        return;
      }
      setState(() => _image = image);
      _report();
    } on Object {
      // فشل قراءة الصورة لا يمنع استخدام الشاشة: تظهر الافتراضية.
      if (mounted) {
        _report();
      }
    }
  }

  /// اختيار صورة من الجهاز ← ضغط على المنصّة ← رفع ← معاينة فورية.
  Future<void> _pick() async {
    if (_busy || !widget.enabled) {
      return;
    }
    setState(() => _busy = true);
    final AppServices services = AppServicesScope.of(context);
    try {
      final PickedImage? picked = await services.imagePicker.pickFromGallery();
      if (picked == null) {
        // إلغاء المستخدم ليس خطأ: لا رسالة، لا تغيير.
        return;
      }
      final UserAvatar uploaded = await services.avatars.upload(
        uid: widget.userId,
        bytes: picked.bytes,
        mimeType: picked.mimeType,
      );
      if (!mounted) {
        return;
      }
      setState(() => _image = uploaded);
      _report();
      AppSnackBar.show(context, 'حُدِّثت صورتك.', type: AppMessageType.success);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        error.overrideMessage ?? error.message,
        type: AppMessageType.error,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        toAppException(error).message,
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _removeCustom() async {
    if (_busy || !widget.enabled) {
      return;
    }
    setState(() => _busy = true);
    try {
      await AppServicesScope.of(context).avatars.remove(widget.userId);
      if (!mounted) {
        return;
      }
      setState(() => _image = null);
      _report();
      AppSnackBar.show(context, 'عُدت إلى الصورة الافتراضية.');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        toAppException(error).message,
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _selectPreset(int preset) async {
    if (_busy || !widget.enabled) {
      return;
    }
    setState(() {
      _preset = preset;
      _image = null; // التصميم الافتراضي يحلّ محل الصورة المخصّصة للمعاينة.
    });
    _report();
    try {
      // الجلسة تكتب في `users/{uid}` وتحدّث الحالة المعروضة، والمستودع يعرف
      // المسار الحقيقي (Firestore أو ذاكرة الجولة).
      final SessionController? session = SessionScope.maybeOf(context);
      if (session != null) {
        await session.updateAvatarPreset(preset);
      } else {
        await AppServicesScope.of(
          context,
        ).avatars.setPreset(uid: widget.userId, preset: preset);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        toAppException(error).message,
        type: AppMessageType.error,
      );
    }
  }

  Future<void> _openPresetSheet() async {
    if (!widget.enabled) {
      return;
    }
    final int? chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'اختر تصميمًا افتراضيًا',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    for (int index = 0; index < AvatarPresets.count; index++)
                      InkWell(
                        key: Key('avatar-preset-$index'),
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(sheetContext).pop(index),
                        child: UserAvatarView(
                          userId: widget.userId,
                          presetId: index,
                          initials: widget.initials,
                          size: 56,
                          semanticLabel: 'تصميم ${index + 1}',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null) {
      await _selectPreset(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasCustom = _image?.hasCustomPhoto ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Stack(
              alignment: AlignmentDirectional.bottomEnd,
              children: <Widget>[
                UserAvatarView(
                  key: const Key('avatar-preview'),
                  userId: widget.userId,
                  image: _image,
                  presetId: _preset,
                  initials: widget.initials,
                  size: widget.size,
                  semanticLabel: 'صورتك',
                ),
                if (_busy)
                  SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    hasCustom ? 'صورتك الشخصية' : 'صورتك الافتراضية',
                    style: theme.textTheme.titleSmall,
                  ),
                  if (widget.helperText != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      widget.helperText!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (widget.enabled) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              OutlinedButton.icon(
                key: const Key('avatar-pick'),
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('اختيار صورة'),
              ),
              if (widget.showPresets)
                TextButton.icon(
                  key: const Key('avatar-presets'),
                  onPressed: _busy ? null : _openPresetSheet,
                  icon: const Icon(Icons.palette_outlined, size: 18),
                  label: const Text('تصميم افتراضي'),
                ),
              if (hasCustom)
                TextButton.icon(
                  key: const Key('avatar-remove'),
                  onPressed: _busy ? null : _removeCustom,
                  icon: const Icon(Icons.hide_image_outlined, size: 18),
                  label: const Text('إزالة الصورة'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
