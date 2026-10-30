import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// صورة حساب جاهزة للعرض (P22): صورة مخصّصة إن وُجدت، وإلا الافتراضية المرسومة.
///
/// **عرض فقط، بلا إدخال/إخراج**: لا تقرأ من الشبكة ولا تخزّن حالة. لذلك يمكن
/// اختبارها مباشرة (`pumpWidget`) بلا مستودعات، ويمكن استخدامها في أي مكان
/// (ملف مدرس، تعليق، قائمة) بنفس الشكل.
///
/// لماذا الرسم لا ملفات PNG؟ لأن الصورة الافتراضية يجب أن تظهر **فورًا وبلا
/// شبكة** وبأي كثافة بكسل، ولأنها «لا تكون فارغة أبدًا» شرطٌ في الحساب الجديد.
class UserAvatarView extends StatelessWidget {
  const UserAvatarView({
    super.key,
    required this.userId,
    this.image,
    this.presetId,
    this.initials,
    this.size = 56,
    this.semanticLabel,
  });

  /// صاحب الصورة — يُشتق منه التصميم الافتراضي الحتمي.
  final String userId;

  /// الصورة المخصّصة إن كانت محمّلة.
  final UserAvatar? image;

  /// التصميم الافتراضي المختار (`null` ⇒ الحتمي من [userId]).
  final int? presetId;

  /// الحرف/الحروف المعروضة داخل الصورة الافتراضية.
  final String? initials;

  final double size;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final int preset = AvatarPresets.normalize(presetId, userId);
    final (int, int) colors = AvatarPresets.gradients[preset];
    final Color start = Color(colors.$1);
    final Color end = Color(colors.$2);
    final Uint8List? bytes = image?.bytes;

    final Widget fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: <Color>[start, end],
        ),
      ),
      child: Center(
        child: Text(
          _initialsText,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );

    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: bytes == null
              ? fallback
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  gaplessPlayback: true,
                  // بايتات تالفة/غير صورة: نعود للافتراضية بدل مربع خطأ.
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? stack) =>
                          fallback,
                ),
        ),
      ),
    );
  }

  /// حرفان كحد أقصى: العربية بلا تشكيل تُقرأ أفضل داخل دائرة صغيرة.
  String get _initialsText {
    final String trimmed = (initials ?? '').trim();
    if (trimmed.isEmpty) {
      return '؟';
    }
    return trimmed.length <= 2 ? trimmed : trimmed.substring(0, 2);
  }
}

/// يحمّل صورة الحساب مرة واحدة ثم يعرضها.
///
/// **لماذا `StatefulWidget`؟** لأن `FutureBuilder` مع `getFor` داخل `build`
/// يعيد القراءة عند كل إعادة بناء (تمرير، إدخال حرف…) — قراءة Firestore لكل
/// إطار. هنا تُقرأ مرة واحدة ويُحتفظ بالمستقبل.
class UserAvatarLoader extends StatefulWidget {
  const UserAvatarLoader({
    super.key,
    required this.userId,
    this.presetId,
    this.initials,
    this.size = 56,
    this.semanticLabel,
  });

  final String userId;
  final int? presetId;
  final String? initials;
  final double size;
  final String? semanticLabel;

  @override
  State<UserAvatarLoader> createState() => _UserAvatarLoaderState();
}

class _UserAvatarLoaderState extends State<UserAvatarLoader> {
  Future<UserAvatar?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppServicesScope.of(context).avatars.getFor(widget.userId);
  }

  @override
  void didUpdateWidget(UserAvatarLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _future = AppServicesScope.of(context).avatars.getFor(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserAvatar?>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<UserAvatar?> snapshot) {
        // أثناء التحميل أو عند الخطأ: الصورة الافتراضية — لا مؤشر تحميل دائم
        // ولا مربع فارغ، فالصورة ليست محتوى حرجًا يستحق حجب الشاشة.
        return UserAvatarView(
          userId: widget.userId,
          image: snapshot.data,
          presetId: widget.presetId,
          initials: widget.initials,
          size: widget.size,
          semanticLabel: widget.semanticLabel,
        );
      },
    );
  }
}
