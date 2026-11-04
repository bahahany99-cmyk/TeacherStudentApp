import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/data/models/chat_image.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/chat/presentation/widgets/chat_image_viewer.dart';

/// مصغّر صورة داخل فقاعة المحادثة (P24).
///
/// **قليل الضجيج بقصد:** لا نُكرّر نص التحذير على كل صورة — الصور تُرسل
/// بالعشرات، وتكرار «ستُحذف بعد خمسة أيام» تحت كل واحدة يحوّل المحادثة إلى
/// لافتة. بدلًا من ذلك: مثلث تحذير صغير شبه شفاف على حافة المصغّر مع مدة
/// قصيرة («٥ أيام»)، ومن يلمسه يقرأ التفصيل في سطر واحد.
///
/// **الصورة تُقرأ عند العرض فقط:** الطلب يحدث هنا لا في قائمة الرسائل كلها،
/// فالمحادثة الممتلئة بالصور تبقى خفيفة.
class ChatImageThumbnail extends StatefulWidget {
  const ChatImageThumbnail({
    super.key,
    required this.chatId,
    required this.imageId,
    required this.isMine,
  });

  final String chatId;
  final String imageId;

  /// فقاعتي أنا (تأخذ نفس شكل الفقاعة المحيطة).
  final bool isMine;

  /// مفتاح المصغّر — تستخدمه الاختبارات للنقر على الصورة نفسها.
  static const Key thumbnailKey = Key('chat-image-thumbnail');

  /// مفتاح شارة الانتهاء الصغيرة على الحافة.
  static const Key badgeKey = Key('chat-image-expiry-badge');

  /// مفتاح حالة «انتهت الصورة / غير متاحة».
  static const Key missingKey = Key('chat-image-missing');

  @override
  State<ChatImageThumbnail> createState() => _ChatImageThumbnailState();
}

class _ChatImageThumbnailState extends State<ChatImageThumbnail> {
  /// يُنشأ مرة واحدة لكل صورة: إعادة البناء (وصول رسالة جديدة) لا تُعيد القراءة
  /// من الشبكة.
  Future<ChatImage?>? _load;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= AppServicesScope.of(context).chatImages.findById(
      chatId: widget.chatId,
      imageId: widget.imageId,
    );
  }

  void _openViewer(ChatImage image) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext context) => ChatImageViewer(image: image),
      ),
    );
  }

  /// «لماذا المثلث؟» — التفصيل يظهر عند الطلب، لا في كل فقاعة.
  void _explainExpiry(ChatImage? image) {
    final String notice = image == null
        ? 'تُحذف صور المحادثة تلقائيًا بعد ${ChatImage.lifetimeLabel()} من '
              'إرسالها، ولم تعد هذه الصورة متاحة.'
        : 'تُحذف صور المحادثة تلقائيًا بعد ${ChatImage.lifetimeLabel()} من '
              'إرسالها. تبقى هذه الصورة ${ChatImage.remainingLabel(image.remaining())}.';

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(notice), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatImage?>(
      future: _load,
      builder: (BuildContext context, AsyncSnapshot<ChatImage?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _ThumbShell(
            key: ChatImageThumbnail.thumbnailKey,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final ChatImage? image = snapshot.data;
        if (image == null) {
          // انتهت أو حُذفت أو تعذّرت قراءتها: مربع صغير صادق بدل صورة مكسورة.
          return _MissingImage(onTap: () => _explainExpiry(null));
        }

        return GestureDetector(
          key: ChatImageThumbnail.thumbnailKey,
          onTap: () => _openViewer(image),
          child: _ThumbShell(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.memory(
                  image.bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  // الصورة تالفة؟ لا نُسقط المحادثة — المصغّر يُظهر بديلًا.
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stack,
                      ) => const _MissingImageBody(),
                ),
                PositionedDirectional(
                  bottom: 4,
                  start: 4,
                  child: _ExpiryBadge(
                    label: ChatImage.remainingLabel(image.remaining()),
                    onTap: () => _explainExpiry(image),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// إطار المصغّر الموحّد (نفس المقاس في كل الحالات فلا تقفز القائمة).
class _ThumbShell extends StatelessWidget {
  const _ThumbShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadiusDirectional.circular(AppSpacing.radiusMd),
      child: SizedBox(width: 168, height: 168, child: child),
    );
  }
}

/// شارة صغيرة: مثلث + مدة قصيرة، نصف شفافة حتى لا تعلو على الصورة.
class _ExpiryBadge extends StatelessWidget {
  const _ExpiryBadge({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'تُحذف بعد $label — اضغط للتفصيل',
      child: GestureDetector(
        key: ChatImageThumbnail.badgeKey,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xs,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(110),
            borderRadius: BorderRadiusDirectional.circular(
              AppSpacing.radiusPill,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                size: 11,
                color: Colors.white,
              ),
              const SizedBox(width: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 9,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «الصورة غير متاحة» — مقاس صغير، بلا نص طويل.
class _MissingImage extends StatelessWidget {
  const _MissingImage({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ThumbShell(
      key: ChatImageThumbnail.missingKey,
      child: GestureDetector(onTap: onTap, child: const _MissingImageBody()),
    );
  }
}

class _MissingImageBody extends StatelessWidget {
  const _MissingImageBody();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ColoredBox(
      color: AppColors.washRose,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.image_not_supported_outlined,
              size: 20,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 2),
            Text(
              'انتهت مدة الصورة',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
