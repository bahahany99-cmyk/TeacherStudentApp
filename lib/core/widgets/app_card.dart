import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// سطح/بطاقة موحّدة تُستخدم في كل الشاشات.
///
/// المواصفة المعتمدة (نسخة 3 — 2026-10-27، مطابقة للمرجع البصري):
/// - سطح **أبيض صريح** (`Colors.white`) في الوضع الفاتح.
/// - نصف قطر **24**.
/// - حدّ شعري **أبيض 80% بعرض 1.2** (هو ما يعطي الإحساس الزجاجي).
/// - **ظلان** بالضبط: قريب (أسود 4% · blur 8 · 0,2) وبعيد (أسود 6% · blur 24 · 0,12).
///
/// `Material` داخلي ضروري: العناصر التي ترسم حبرها على أقرب `Material`
/// (`ListTile`، `InkWell`) تفقد التأثيرات أو تُطلق Assertion في وضع التصحيح إذا
/// وُضعت داخل `DecoratedBox` ملوّن مباشرة.
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
    this.shadows,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// سطح متدرّج ناعم (مثل `AppGradients.glow`) بدل الأبيض المسطّح.
  /// يُستخدم للبطاقات التمهيدية، ودائمًا مع نص داكن.
  final Gradient? gradient;

  /// ظل أقوى قليلًا — للبطاقة المهمة/المختارة فقط.
  final bool lifted;

  final Color? borderColor;
  final double? borderRadius;

  /// تجاوز الظل (نادرًا: البطاقة داخل حاوية لها ظلها).
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLight = theme.brightness == Brightness.light;
    final double radius = borderRadius ?? AppSpacing.radiusCard;
    final BorderRadius borderRadiusValue = BorderRadius.circular(radius);

    final Widget padded = Padding(
      padding: padding ?? AppSpacing.cardPadding,
      child: child,
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        // أبيض صريح في الوضع الفاتح — لا لون خلفية مزرق أو رمادي.
        color: gradient != null
            ? null
            : (isLight ? Colors.white : theme.colorScheme.surfaceContainerHigh),
        gradient: gradient,
        borderRadius: borderRadiusValue,
        border: AppBorders.side(
          borderColor ??
              (gradient == null ? AppBorders.onWhite : AppBorders.onTint),
        ),
        boxShadow:
            shadows ??
            (lifted ? AppShadows.cardLifted : AppShadows.card),
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
