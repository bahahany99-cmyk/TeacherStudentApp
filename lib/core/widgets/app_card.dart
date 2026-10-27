import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// سطح/بطاقة موحّدة تُستخدم في كل الشاشات.
///
/// نسخة 2 (2026-10-27) — الطابع «العائم»:
/// - حواف 24 نقطة (بدل 18) وحدّ شعري فاتح بدل حد رمادي واضح.
/// - ظل مزدوج رقيق: قريب يحدّ الحافة، وبعيد يعطي إحساس الطفو.
/// - لا يُستخدم `Card` لتقليل الارتباط بتغيّرات `CardTheme` بين إصدارات Flutter.
///
/// `Material` داخلي ضروري: العناصر التي ترسم حبرها على أقرب `Material`
/// (مثل `ListTile` و`InkWell`) تفقد التأثيرات وتُطلق Assertion في وضع التصحيح
/// إذا وُضعت داخل `DecoratedBox` ملوّن مباشرة.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.margin,
    this.gradient,
    this.lifted = false,
    this.borderColor,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// تدرّج السطح. إن مُرّر، يُستخدم بدل اللون الأبيض (مثل بطاقة Hero).
  final Gradient? gradient;

  /// ظل أقوى/ملوّن — للبطاقات المهمة أو المختارة.
  final bool lifted;

  final Color? borderColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double radius = borderRadius ?? AppSpacing.radiusXl;
    final BorderRadius borderRadiusValue = BorderRadius.circular(radius);

    final Widget padded = Padding(
      padding: padding ?? AppSpacing.cardPadding,
      child: child,
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null
            ? (theme.brightness == Brightness.light
                  ? Colors.white
                  : theme.colorScheme.surfaceContainerHigh)
            : null,
        gradient: gradient,
        borderRadius: borderRadiusValue,
        border: Border.all(
          color: borderColor ?? Colors.white.withAlpha(gradient == null ? 200 : 40),
          width: 1,
        ),
        boxShadow: lifted ? AppShadows.cardLifted : AppShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null
            ? padded
            : InkWell(
                borderRadius: borderRadiusValue,
                onTap: onTap,
                child: padded,
              ),
      ),
    );
  }
}
