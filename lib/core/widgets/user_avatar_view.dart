import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// صورة حساب جاهزة للعرض (P22، محدَّثة في P31).
///
/// **الأولوية (P31) مطبَّقة هنا مرة واحدة:** الصورة المرفوعة الصالحة، ثم
/// الصورة الرمزية المختارة، ثم الرمزية الافتراضية الحتمية من المعرّف — عبر
/// [AvatarResolution]. كل شاشة تُظهر صورة (المحادثات، بطاقات المجموعات، طلبات
/// الحجز، ملف المدرس، بطاقة الحساب) تستخدم هذا الودجت، فلا يوجد منطق ثانٍ.
///
/// **عرض فقط، بلا إدخال/إخراج**: لا تقرأ من الشبكة ولا تخزّن حالة. لذلك يمكن
/// اختبارها مباشرة (`pumpWidget`) بلا مستودعات.
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

  /// مستند الصورة إن كان محمّلًا (يحمل البايتات والمعرّف معًا).
  final UserAvatar? image;

  /// الاختيار المحفوظ (`avatarPreset`) — يُستخدم إذا لم يصل مستند الصورة بعد.
  final int? presetId;

  /// الحرف/الحروف المعروضة في البديل عند تعذّر تحميل ملف الأصل.
  final String? initials;

  final double size;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AvatarResolution resolution = AvatarResolution.resolve(
      ownerId: userId,
      avatar: image,
      chosenPreset: presetId,
    );
    final AvatarArtwork artwork = AvatarPresets.all[resolution.presetId];
    final Uint8List? bytes = resolution.bytes;

    return Semantics(
      label: semanticLabel ?? artwork.description,
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: bytes != null
              ? Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  gaplessPlayback: true,
                  // بايتات تالفة/غير صورة: نعود إلى **الرمزية** (الأولوية
                  // الثانية) لا إلى دائرة حرف — الصورة الرمزية اختيار صريح من
                  // المستخدم، وتقديمها على البديل المرسوم هو الصحيح.
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? stack) =>
                          _bundledOrGradient(context, artwork),
                )
              // الصور المضمَّنة تُرسم من الـAPK: بلا شبكة وبلا تحميل معلّق.
              : Image.asset(
                  artwork.asset,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  gaplessPlayback: true,
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? stack) =>
                          _fallback(artwork),
                ),
        ),
      ),
    );
  }

  /// الصورة الرمزية المضمَّنة، وإن تعذّر تحميل ملفها (أصل ناقص) فالتدرّج.
  Widget _bundledOrGradient(BuildContext context, AvatarArtwork artwork) {
    return Image.asset(
      artwork.asset,
      fit: BoxFit.cover,
      width: size,
      height: size,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stack) =>
              _fallback(artwork),
    );
  }

  /// بديل أخير: دائرة بتدرّج هادئ وحرفين — لا صورة فارغة أبدًا.
  Widget _fallback(AvatarArtwork artwork) {
    final (int, int) colors =
        AvatarPresets.fallbackGradients[artwork.id %
            AvatarPresets.fallbackGradients.length];
    final String trimmed = (initials ?? '').trim();
    final String text = trimmed.isEmpty
        ? '؟'
        : (trimmed.length <= 2 ? trimmed : trimmed.substring(0, 2));

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: <Color>[Color(colors.$1), Color(colors.$2)],
        ),
      ),
      child: Center(
        child: Text(
          text,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// يحمّل صورة الحساب مرة واحدة ثم يعرضها.
///
/// **لماذا `StatefulWidget`؟** لأن `FutureBuilder` مع `getFor` داخل `build`
/// يعيد القراءة عند كل إعادة بناء (تمرير، إدخال حرف…) — قراءة Firestore لكل
/// إطار. هنا تُقرأ مرة واحدة ويُحتفظ بالمستقبل.
///
/// **`reloadToken` (P31):** بعد رفع صورة أو اختيار رمزية أو إزالتها يجب أن
/// تتحدّث البطاقة فورًا. بدل إعادة بناء الشجرة أو إدخال حالة عامة، يمرّر
/// المستدعي رقمًا يزيده بعد كل تغيير، فيُعاد التحميل.
class UserAvatarLoader extends StatefulWidget {
  const UserAvatarLoader({
    super.key,
    required this.userId,
    this.presetId,
    this.initials,
    this.size = 56,
    this.semanticLabel,
    this.reloadToken = 0,
  });

  final String userId;
  final int? presetId;
  final String? initials;
  final double size;
  final String? semanticLabel;
  final int reloadToken;

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
    if (oldWidget.userId != widget.userId ||
        oldWidget.reloadToken != widget.reloadToken) {
      _future = AppServicesScope.of(context).avatars.getFor(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserAvatar?>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<UserAvatar?> snapshot) {
        // أثناء التحميل أو عند الخطأ: الصورة الرمزية — لا مؤشر تحميل دائم
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
