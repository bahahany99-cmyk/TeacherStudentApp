import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/data/services/image_picker_gateway.dart';
import 'package:teacher_student_app/features/profile/presentation/avatar_crop_encoder.dart';
import 'package:teacher_student_app/features/profile/presentation/avatar_crop_geometry.dart';

/// شاشة قصّ الصورة الشخصية (P31).
///
/// ## القرار التصميمي: الإطار ثابت والصورة تتحرّك
/// أغلب المنتقي «يقصّ الإطار» — هنا العكس: الإطار ثابت في المنتصف، والصورة
/// تُسحب وتُكبَّر خلفه. السبب أن المستخدم يرى **النتيجة النهائية** طوال الوقت
/// (ما داخل الدائرة) بدل أن يتخيّل ماذا سيقتطع.
///
/// ## الإيماءات
/// - سحب بإصبع واحد: تحريك الصورة.
/// - قرصة بإصبعين: تكبير/تصغير بين 1× و4×.
/// - كل حركة مقيّدة بـ[CropMath] فلا يظهر فراغ داخل الإطار أبدًا.
///
/// ## عند الإلغاء أو الفشل
/// الشاشة تعيد `null` فقط؛ ولا تلمس التخزين. الرفع يحدث بعد التأكيد في
/// `AvatarActions`، وفشله لا يمسّ الصورة الحالية المحفوظة.
class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({super.key, required this.source});

  final PickedImage source;

  /// يعرض الشاشة ويعيد الصورة المقصوصة، أو `null` عند الإلغاء/الفشل.
  static Future<PickedImage?> show(
    BuildContext context,
    PickedImage source,
  ) {
    return Navigator.of(context).push<PickedImage>(
      MaterialPageRoute<PickedImage>(
        builder: (BuildContext context) => AvatarCropScreen(source: source),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  ui.Image? _image;
  bool _failed = false;
  bool _exporting = false;

  double _zoom = CropMath.minZoom;
  Offset _pan = Offset.zero;

  double _zoomAtStart = CropMath.minZoom;
  Offset _panAtStart = Offset.zero;
  Offset _focalStart = Offset.zero;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(widget.source.bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } on Object {
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAtStart = _zoom;
    _panAtStart = _pan;
    _focalStart = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double cropSide) {
    final ui.Image? image = _image;
    if (image == null) {
      return;
    }
    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final double zoom = CropMath.clampZoom(_zoomAtStart * details.scale);
    final Size displayed = CropMath.displayedSize(
      imageSize: imageSize,
      cropSide: cropSide,
      zoom: zoom,
    );
    final Offset rawPan =
        _panAtStart + (details.focalPoint - _focalStart);
    setState(() {
      _zoom = zoom;
      _pan = CropMath.clampPan(
        rawPan,
        displayed: displayed,
        cropSide: cropSide,
      );
    });
  }

  Future<void> _confirm(double cropSide) async {
    final ui.Image? image = _image;
    if (image == null || _exporting) {
      return;
    }
    setState(() => _exporting = true);
    try {
      final PickedImage? cropped = await AvatarCropEncoder.encode(
        image: image,
        cropSide: cropSide,
        zoom: _zoom,
        pan: _pan,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(cropped);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تجهيز الصورة. جرّب صورة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      key: const Key('avatar-crop-screen'),
      backgroundColor: const Color(0xFF12172B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('قص الصورة'),
        leading: IconButton(
          key: const Key('crop-cancel-icon'),
          icon: const Icon(Icons.close),
          tooltip: 'إلغاء',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // إطار مربّع يتّسع للشاشة مع هامش، ويترك مكان الأزرار أسفلًا.
            final double side = (constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth
                    : constraints.maxHeight) -
                AppSpacing.xxl;
            final double cropSide = side.clamp(160.0, 420.0);

            return Column(
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: _failed
                        ? const _CropFailure()
                        : _image == null
                            ? const CircularProgressIndicator(color: Colors.white)
                            : _CropStage(
                                image: _image!,
                                cropSide: cropSide,
                                zoom: _zoom,
                                pan: _pan,
                                onScaleStart: _onScaleStart,
                                onScaleUpdate: (ScaleUpdateDetails details) =>
                                    _onScaleUpdate(details, cropSide),
                              ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Text(
                    'اسحب الصورة بإصبع، وكبّرها بإصبعين. ما داخل الدائرة هو ما '
                    'سيُحفظ.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('crop-cancel'),
                          onPressed: _exporting
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                          ),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FilledButton(
                          key: const Key('crop-confirm'),
                          onPressed: (_image == null || _exporting)
                              ? null
                              : () => _confirm(cropSide),
                          child: _exporting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('تأكيد'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// مسرح القصّ: صورة متحرّكة + إطار ثابت + تعتيم خارج الدائرة.
class _CropStage extends StatelessWidget {
  const _CropStage({
    required this.image,
    required this.cropSide,
    required this.zoom,
    required this.pan,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  final ui.Image image;
  final double cropSide;
  final double zoom;
  final Offset pan;
  final ValueChanged<ScaleStartDetails> onScaleStart;
  final ValueChanged<ScaleUpdateDetails> onScaleUpdate;

  @override
  Widget build(BuildContext context) {
    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final Size displayed = CropMath.displayedSize(
      imageSize: imageSize,
      cropSide: cropSide,
      zoom: zoom,
    );

    return GestureDetector(
      key: const Key('crop-gesture-area'),
      onScaleStart: onScaleStart,
      onScaleUpdate: onScaleUpdate,
      child: SizedBox.square(
        dimension: cropSide,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ClipOval(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: Transform.translate(
                  offset: pan,
                  child: SizedBox(
                    width: displayed.width,
                    height: displayed.height,
                    child: RawImage(
                      image: image,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _CropFramePainter(
                  side: cropSide,
                  strokeColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// حلقة الإطار + تعتيم ما حولها داخل المربّع (بلا صور ولا حزم).
class _CropFramePainter extends CustomPainter {
  const _CropFramePainter({required this.side, required this.strokeColor});

  final double side;
  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double radius = side / 2;

    // تعتيم خفيف خارج الدائرة فقط (القصّ دائري في التطبيق).
    final Path dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()..addOval(Rect.fromCircle(center: rect.center, radius: radius)),
    );
    canvas.drawPath(dim, Paint()..color = const Color(0x66000000));

    canvas.drawCircle(
      rect.center,
      radius - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = strokeColor,
    );
  }

  @override
  bool shouldRepaint(_CropFramePainter oldDelegate) =>
      oldDelegate.side != side || oldDelegate.strokeColor != strokeColor;
}

/// رسالة صريحة عند تعذّر فكّ ترميز الصورة (ملف تالف).
class _CropFailure extends StatelessWidget {
  const _CropFailure();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 40),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'تعذّر قراءة هذه الصورة. اختر صورة أخرى.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
