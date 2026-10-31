import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/data/models/chat_image.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// عارض صورة المحادثة بملء الشاشة (P24).
///
/// **تكبير ناعم:** `InteractiveViewer` يعطي قرصة الأصابع، وزرّا `+`/`−`
/// يعطيان نفس النتيجة بلمسة واحدة (بعض المستخدمين لا يعرفون القرصة، وآخرون
/// يفتحون الصورة بيد واحدة). كل تكبير/تصغير يتحرك حول مركز الشاشة، فتظل
/// الصورة تحت الإصبع بدل أن تقفز إلى الزاوية.
///
/// **تنزيل مباشر:** الزر يضع الصورة في معرض الجهاز فعلًا (عبر عقد
/// `ChatImageSaver`) ويؤكد بالنتيجة — لا يكتفي برسالة «تم».
class ChatImageViewer extends StatefulWidget {
  const ChatImageViewer({super.key, required this.image, this.onDownload});

  final ChatImage image;

  /// (اختبارات) تجاوز التنزيل الافتراضي — يمرَّر عادةً من `AppServices`.
  final Future<void> Function()? onDownload;

  static const Key viewerKey = Key('chat-image-viewer');
  static const Key zoomInKey = Key('chat-image-zoom-in');
  static const Key zoomOutKey = Key('chat-image-zoom-out');
  static const Key downloadKey = Key('chat-image-download');

  /// أقل وأقصى تكبير لزرّي `+`/`−` (القرصة تسمح حتى `maxScale` أيضًا).
  static const double minScale = 1;
  static const double maxScale = 4;

  @override
  State<ChatImageViewer> createState() => _ChatImageViewerState();
}

class _ChatImageViewerState extends State<ChatImageViewer> {
  final TransformationController _transform = TransformationController();
  bool _downloading = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  double get _scale => _transform.value.getMaxScaleOnAxis();

  /// تكبير/تصغير حول مركز الشاشة بمصفوفة صريحة (تُكتب خاناتها مباشرة).
  void _zoomBy(double factor) {
    final double target = (_scale * factor).clamp(
      ChatImageViewer.minScale,
      ChatImageViewer.maxScale,
    );
    if (target == _scale) {
      return;
    }
    final Size size = MediaQuery.sizeOf(context);
    final double dx = size.width / 2 * (1 - target);
    final double dy = size.height / 2 * (1 - target);

    final Matrix4 next = Matrix4.identity()
      ..setEntry(0, 0, target)
      ..setEntry(1, 1, target)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);
    setState(() => _transform.value = next);
  }

  Future<void> _download() async {
    if (_downloading) {
      return;
    }
    setState(() => _downloading = true);
    try {
      final Future<void> Function()? customDownload = widget.onDownload;
      if (customDownload != null) {
        await customDownload();
      } else {
        await AppServicesScope.of(context).imageSaver.saveToGallery(
          bytes: widget.image.bytes,
          mimeType: widget.image.mimeType,
          fileName: _fileNameFor(widget.image),
        );
      }
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        'حُفظت الصورة في معرض الجهاز.',
        type: AppMessageType.success,
      );
    } catch (error) {
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
        setState(() => _downloading = false);
      }
    }
  }

  /// اسم الملف بلا محارف غير صالحة: معرّف الصورة ورقمي فقط.
  static String _fileNameFor(ChatImage image) {
    final String safeId = image.id.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
    return 'chat-image-${safeId.isEmpty ? image.createdAt.millisecondsSinceEpoch : safeId}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Uint8List bytes = widget.image.bytes;

    return Scaffold(
      key: ChatImageViewer.viewerKey,
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: ChatImageViewer.minScale,
                maxScale: ChatImageViewer.maxScale,
                // الصورة كاملة داخل الشاشة أولًا (`contain`)، ثم يكبّرها المستخدم.
                child: Center(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stack,
                        ) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white70,
                          size: 40,
                        ),
                  ),
                ),
              ),
            ),

            // شريط علوي شفاف: إغلاق + تفصيل الانتهاء (سطر واحد، لا لافتة).
            PositionedDirectional(
              top: AppSpacing.xs,
              start: AppSpacing.xs,
              end: AppSpacing.xs,
              child: Row(
                children: <Widget>[
                  _RoundButton(
                    icon: Icons.close,
                    tooltip: 'إغلاق',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(120),
                        borderRadius: BorderRadiusDirectional.circular(
                          AppSpacing.radiusPill,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 13,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Flexible(
                            child: Text(
                              'تُحذف بعد '
                              '${ChatImage.remainingLabel(widget.image.remaining())}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // شريط سفلي: تصغير، تكبير، تنزيل.
            PositionedDirectional(
              bottom: AppSpacing.md,
              start: AppSpacing.md,
              end: AppSpacing.md,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _RoundButton(
                    key: ChatImageViewer.zoomOutKey,
                    icon: Icons.zoom_out,
                    tooltip: 'تصغير',
                    onTap: () => _zoomBy(1 / 1.6),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _RoundButton(
                    key: ChatImageViewer.zoomInKey,
                    icon: Icons.zoom_in,
                    tooltip: 'تكبير',
                    onTap: () => _zoomBy(1.6),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _RoundButton(
                    key: ChatImageViewer.downloadKey,
                    icon: Icons.download_rounded,
                    tooltip: 'تنزيل',
                    onTap: _downloading ? null : _download,
                    busy: _downloading,
                    filled: true,
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

/// زر دائري موحّد على خلفية داكنة.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.busy = false,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool busy;

  /// الزر الأساسي (التنزيل) بلون العلامة، والبقية شفافة.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: filled
          ? theme.colorScheme.primary
          : Colors.black.withAlpha(120),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, color: Colors.white),
      ),
    );
  }
}
