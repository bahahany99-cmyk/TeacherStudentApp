import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/user_avatar_view.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/profile/presentation/widgets/avatar_actions.dart';
import 'package:teacher_student_app/features/profile/presentation/widgets/avatar_editor_controller.dart';

/// حالة الصورة المختارة — يقرأها نموذج ملف المدرس ليعرف هل توجد صورة.
class AvatarSelection {
  const AvatarSelection({required this.preset, this.image});

  /// الصورة الرمزية المختارة (بعد التطبيع).
  final int preset;

  /// مستند الصورة المرفوعة (`null` = لا صورة).
  final UserAvatar? image;

  /// هل توجد صورة مخصّصة فعلًا؟ (شرط حفظ ملف المدرس)
  bool get hasCustomPhoto => image?.hasCustomPhoto ?? false;
}

/// محرّر صورة الحساب المضمَّن (P22، محدَّث في P31).
///
/// **أين يُستخدم الآن؟** في نموذج ملف المدرّس وحده، لأن الصورة جزء من بيانات
/// الملف هناك. صفحة «حسابي» لم تعد تحتويه: صورتها في بطاقة الملف نفسها،
/// وإعداداتها في ورقة سفلية ([AvatarSettingsSheet]).
///
/// **ما الذي توحّده P31؟** المنطق نفسه في الحالتين: [AvatarEditorController]
/// للحالة، و[AvatarActions] للاختيار والقصّ والرفع والإزالة. لا نسخة ثانية من
/// أي خطوة، ولا كتابة تعتمد على `BuildContext` في طبقة البيانات.
class AccountAvatarEditor extends StatefulWidget {
  const AccountAvatarEditor({
    super.key,
    required this.userId,
    required this.initialPreset,
    this.initials,
    this.enabled = true,
    this.size = 72,
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

  /// إظهار زر اختيار الصورة الرمزية.
  final bool showPresets;

  /// تُستدعى عند كل تغيير (تحميل، رفع، اختيار رمزية، إزالة).
  final ValueChanged<AvatarSelection>? onChanged;

  final String? helperText;

  @override
  State<AccountAvatarEditor> createState() => _AccountAvatarEditorState();
}

class _AccountAvatarEditorState extends State<AccountAvatarEditor> {
  AvatarEditorController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AvatarEditorController? existing = _controller;
    if (existing == null) {
      _controller = AvatarEditorController(
        userId: widget.userId,
        initialPreset: widget.initialPreset,
      )..addListener(_onControllerChanged);
      // **لا `_report()` هنا:** هذه الدالة تُستدعى أثناء بناء الأب، والإبلاغ
      // الفوري كان يستدعي `setState` على الأب في منتصف البناء (خطأ حقيقي ظهر
      // في `edit_teacher_profile_screen`: «setState() called during build»).
      // التحميل غير متزامن، فيصل الإبلاغ الأول بعد انتهاء البناء من
      // `_onControllerChanged`.
      _controller!.load(AppServicesScope.of(context).avatars);
    }
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    _report();
  }

  void _report() {
    final AvatarEditorController? controller = _controller;
    if (controller == null) {
      return;
    }
    widget.onChanged?.call(
      AvatarSelection(preset: controller.preset, image: controller.image),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  /// نمط موحّد للأزرار الصغيرة: ارتفاع 38dp وحشوة أفقية 12، فيصطفّ ثلاثة
  /// أزرار في سطر واحد على شاشة 360dp.
  static ButtonStyle _compactButton(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 38)),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      textStyle: WidgetStatePropertyAll<TextStyle?>(
        theme.textTheme.labelMedium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AvatarEditorController? controller = _controller;
    final bool hasCustom = controller?.hasUploadedPhoto ?? false;
    final bool busy = controller?.busy ?? false;
    final bool enabled = widget.enabled && !busy;

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
                  image: controller?.image,
                  presetId: controller?.preset ?? widget.initialPreset,
                  initials: widget.initials,
                  size: widget.size,
                  semanticLabel: 'صورتك',
                ),
                if (busy)
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
              // (P27) أزرار مضغوطة: الثيم يفرض ارتفاع 52dp و«حبة دواء»
              // لكل زر، فكانت ثلاثة أزرار تُشبه شرائح ضخمة داخل بطاقة صغيرة.
              OutlinedButton.icon(
                key: const Key('avatar-pick'),
                onPressed: enabled
                    ? () => AvatarActions.changePhoto(context, controller!)
                    : null,
                style: _compactButton(context),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('اختيار صورة'),
              ),
              if (widget.showPresets)
                TextButton.icon(
                  key: const Key('avatar-presets'),
                  onPressed: enabled
                      ? () => AvatarActions.choosePreset(context, controller!)
                      : null,
                  style: _compactButton(context),
                  icon: const Icon(Icons.palette_outlined, size: 18),
                  label: const Text('صورة رمزية'),
                ),
              if (hasCustom)
                TextButton.icon(
                  key: const Key('avatar-remove'),
                  onPressed: enabled
                      ? () => AvatarActions.removePhoto(context, controller!)
                      : null,
                  style: _compactButton(context),
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
