import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/user_avatar_view.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/profile/presentation/widgets/avatar_actions.dart';
import 'package:teacher_student_app/features/profile/presentation/widgets/avatar_editor_controller.dart';

/// ورقة إعدادات الصورة الشخصية (P31).
///
/// **لماذا ورقة سفلية لا قسم كامل داخل الصفحة؟** لأن صفحة «حسابي» كانت تحمل
/// قسمًا منفصلًا للصورة يكرّر الصورة نفسها الموجودة في البطاقة. الآن الصورة
/// تظهر **مرة واحدة** في البطاقة، وإعداداتها تُفتح من زر صغير عليها، فلا
/// تكرار ولا مساحة مهدورة.
///
/// الخيارات الثلاثة صريحة ومتساوية الأهمية: تغيير الصورة، اختيار رمزية من
/// المعرض، إزالة الصورة. إزالة تظهر معطّلة (لا مخفية) إن لم توجد صورة مرفوعة،
/// فيعرف المستخدم لماذا لا تعمل بدل أن يبحث عنها.
class AvatarSettingsSheet extends StatefulWidget {
  const AvatarSettingsSheet({super.key, required this.userId});

  /// صاحب الصورة (المستخدم الحالي).
  final String userId;

  /// يفتح الورقة ويعيد `true` إن تغيّرت الصورة.
  static Future<bool> show(BuildContext context, {required String userId}) async {
    final bool? changed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) => AvatarSettingsSheet(userId: userId),
    );
    return changed ?? false;
  }

  @override
  State<AvatarSettingsSheet> createState() => _AvatarSettingsSheetState();
}

class _AvatarSettingsSheetState extends State<AvatarSettingsSheet> {
  late final AvatarEditorController _controller;
  bool _changed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _controller = AvatarEditorController(
        userId: widget.userId,
        initialPreset:
            SessionScope.maybeOf(context)?.user?.resolvedAvatarPreset ?? 0,
      )..addListener(_onChanged);
      _controller.load(AppServicesScope.of(context).avatars);
    }
  }

  bool _initialized = false;

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<bool> Function() action,
  ) async {
    final bool ok = await action();
    if (!mounted) {
      return;
    }
    if (ok) {
      _changed = true;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                UserAvatarView(
                  key: const Key('avatar-settings-preview'),
                  userId: widget.userId,
                  image: _controller.image,
                  presetId: _controller.preset,
                  initials: SessionScope.maybeOf(context)?.user?.initials,
                  size: AppSpacing.avatarMd,
                  semanticLabel: 'صورتك الحالية',
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'الصورة الشخصية',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _controller.hasUploadedPhoto
                            ? 'تظهر بجانب اسمك في المحادثات وملفك.'
                            : 'تستخدم الآن صورة رمزية من المعرض.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_controller.busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _SheetAction(
              key: const Key('avatar-pick'),
              icon: Icons.photo_camera_outlined,
              title: 'تغيير الصورة الشخصية',
              subtitle: 'اختيار صورة من الجهاز، ثم قصّها ومعاينتها قبل الحفظ',
              enabled: !_controller.busy,
              onTap: () => _run(
                () => AvatarActions.changePhoto(context, _controller),
              ),
            ),
            _SheetAction(
              key: const Key('avatar-presets'),
              icon: Icons.face_retouching_natural_outlined,
              title: 'اختيار صورة رمزية',
              subtitle: '‏24 صورة جاهزة تعمل دون إنترنت',
              enabled: !_controller.busy,
              onTap: () => _run(
                () => AvatarActions.choosePreset(context, _controller),
              ),
            ),
            _SheetAction(
              key: const Key('avatar-remove'),
              icon: Icons.hide_image_outlined,
              title: 'إزالة الصورة',
              subtitle: _controller.hasUploadedPhoto
                  ? 'العودة إلى صورتك الرمزية دون حذف أي بيانات'
                  : 'لا توجد صورة مرفوعة الآن',
              enabled: !_controller.busy && _controller.hasUploadedPhoto,
              onTap: () => _run(
                () => AvatarActions.removePhoto(context, _controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// صف إجراء داخل الورقة: أيقونة + عنوان + شرح، ومساحة لمس كاملة.
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color foreground = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withAlpha(110);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(enabled ? 24 : 10),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(
                icon,
                size: 20,
                color: enabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withAlpha(120),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
