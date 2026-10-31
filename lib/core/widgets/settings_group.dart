import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';

/// مجموعة إعدادات: عنوان صغير + بطاقة واحدة تضم صفوفًا مفصولة بخطوط.
///
/// **لماذا مجموعة لا بطاقة لكل صف؟** لأن صفحة الإعدادات تُقرأ بالمجموعات لا
/// بالصفوف: «الحساب»، «التواصل»، «الدعم». بطاقة لكل صف تعني ظلًّا وحدًّا لكل
/// سطر، فتصير الصفحة مزدحمة بالحواف بدل المحتوى — وهو بالضبط ما كان يبدو
/// «نموذجًا غير مصقول».
///
/// الخطوط بين الصفوف تبدأ بعد الأيقونة (inset) كما في iOS/Android، فلا تقطع
/// العمود البصري للأيقونات.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    this.title,
    this.children = const <Widget>[],
    this.margin,
  });

  /// عنوان المجموعة (اختياري): نص صغير ثقيل فوق البطاقة، لا داخلها.
  final String? title;

  /// الصفوف ([SettingsTile] عادةً). تفصل بينها خطوط تلقائيًا.
  final List<Widget> children;

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: margin ?? const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null)
            Padding(
              // محاذاة العنوان مع حشوة البطاقة نفسها حتى لا يبدو معلّقًا.
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.xxs,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                title!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < children.length; i++) ...<Widget>[
                  if (i > 0)
                    // خط بادئ بعد الأيقونة: العمود البصري للأيقونات يبقى متصلًا.
                    Divider(
                      height: 0.6,
                      thickness: 0.6,
                      indent: AppSpacing.xxl + AppSpacing.xs,
                      endIndent: AppSpacing.md,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// صف إعدادات: أيقونة في مربع ملوّن هادئ + عنوان + وصف اختياري + سهم.
///
/// **الحالات:**
/// - [danger]: حمراء (خروج/حذف) — اللون وحده لا يكفي، فالوصف يشرح الأثر.
/// - [busy]: دوّارة صغيرة بدل السهم، والصف معطّل أثناء العملية.
/// - [trailing]: عنصر بديل (شارة، عدّاد…) بدل السهم.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.danger = false,
    this.busy = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  final bool busy;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = danger
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final Color foreground = danger
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.settingsTileHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs + 2,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(22),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  trailing ??
                      Icon(
                        Icons.chevron_left,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
