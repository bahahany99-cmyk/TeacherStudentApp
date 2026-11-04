import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// شريحة/فلتر بشكل «حبة الدواء» — العنصر المميّز في النظام البصري v2.
///
/// تُستخدم لثلاث حالات مختلفة بنفس الشكل (كما في المرجع المعتمد):
/// 1. فلتر قابل للضغط (`onTap`) — مثل: المادة، المنطقة.
/// 2. وسم تصنيف ثابت (`selected` بلا `onTap`) — مثل: «مدرس مميز».
/// 3. عداد معلومة (بأيقونة) — مثل: «12 مجموعة».
///
/// الحالة المختارة: خلفية بلون الهوية الشفاف + حدّ أوضح + خط أثقل، بلا تغيير
/// في الحجم (حتى لا «يقفز» الصف عند الاختيار).
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.color,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  /// لون مخصّص (للحالات: مقبول/مرفوض…). الافتراضي لون الهوية.
  final Color? color;

  /// ارتفاع أقل — للاستخدام داخل البطاقات.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = color ?? theme.colorScheme.primary;

    // نسخة 3: تعبئة محايدة فاتحة جدًا (شبه بيضاء) وحدّ رقيق — لا ألوان قوية
    // ولا ظل ثقيل. المختارة تأخذ باستيل من لون الهوية فقط.
    final bool isLight = theme.brightness == Brightness.light;
    final Color background = selected
        ? accent.withAlpha(22)
        : (isLight ? Colors.white : theme.colorScheme.surfaceContainerHigh);
    final Color foreground = selected
        ? accent
        : (isLight ? const Color(0xFF4B5563) : theme.colorScheme.onSurfaceVariant);

    final Widget content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md + 2,
        vertical: dense ? 5 : AppSpacing.xs + 1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 14 : 16, color: foreground),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    final BoxDecoration decoration = BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      border: Border.all(
        color: selected
            ? accent.withAlpha(90)
            : theme.colorScheme.outlineVariant.withAlpha(90),
        width: 1,
      ),
      // ظل شعري خفيف جدًا: يرفع الشريحة عن الخلفية بلا أن تصبح «زرًّا ثقيلًا».
      boxShadow: AppShadows.pill,
    );

    final Widget surface = Container(decoration: decoration, child: content);

    if (onTap == null) {
      return surface;
    }

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          onTap: onTap,
          child: surface,
        ),
      ),
    );
  }
}

/// صف أفقي من الشرائح مع تمرير أفقي عند الضيق.
///
/// استخدام `Wrap` في مكان يحتاج تمريرًا يسبب طيّة تدفع المحتوى لأسفل؛ وهنا
/// نريد صفًا واحدًا بتمرير أفقي كما في المرجع.
class PillRow extends StatelessWidget {
  const PillRow({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // RTL: البداية على اليمين تلقائيًا لأن الاتجاه موروث.
      padding: padding,
      child: Row(
        children: <Widget>[
          for (int index = 0; index < children.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: AppSpacing.xs),
            children[index],
          ],
        ],
      ),
    );
  }
}

/// شارة صغيرة جدًا (نقطة/عدّاد) على حافة بطاقة.
class PillBadge extends StatelessWidget {
  const PillBadge({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: accent.withAlpha(26),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: accent.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// تدرّج شفاف جاهز — يُستخدم لتلوين أسطح الشرائح المختارة.
LinearGradient pillTint(Color color) => AppGradients.tint(color);
