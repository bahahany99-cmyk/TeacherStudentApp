import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/config/app_identity.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/theme/app_typography.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';

/// معرض المكونات (للمراجعة البصرية فقط — لا يُستخدم في مسار المستخدم).
///
/// الغرض: مراجعة نظام التصميم كله في شاشة واحدة على جهاز حقيقي، بدلًا من
/// التنقل بين كل الشاشات لفحص الخط والألوان والمسافات وRTL.
///
/// الوصول: «حسابي» → قسم «معاينة الواجهات» → «معرض المكونات» (وضع المعاينة فقط).
class DesignGalleryScreen extends StatelessWidget {
  const DesignGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('معرض المكونات (v3)')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const DemoBanner(
                  message: 'شاشة تطوير للمراجعة البصرية فقط، وليست جزءًا من تجربة المستخدم.',
                ),

                // ---------- الهوية والخط ----------
                const SectionHeader(
                  title: 'الهوية والخط',
                  subtitle: 'Cairo 400 / 600 / 700 — العرض من اليمين لليسار',
                ),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(AppIdentity.displayName, style: theme.textTheme.displaySmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        AppIdentity.tagline,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(),
                      const SizedBox(height: AppSpacing.xs),
                      const _Specimen('Regular 400', FontWeight.w400),
                      const _Specimen('SemiBold 600', FontWeight.w600),
                      const _Specimen('Bold 700', FontWeight.w700),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'أرقام عربية ومصرية: ١٢٣٤٥٦٧٨٩٠ — 0123456789 — '
                        'السعر 150 ج.م / حصة',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'تشكيل: مَدْرَسَةٌ، طُلَّابٌ، دَرْسٌ — رموز: ! ؟ ، . «»',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ---------- مقياس النصوص ----------
                const SectionHeader(title: 'مقياس النصوص'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _TypeRow('displaySmall', theme.textTheme.displaySmall),
                      _TypeRow('headlineMedium', theme.textTheme.headlineMedium),
                      _TypeRow('headlineSmall', theme.textTheme.headlineSmall),
                      _TypeRow('titleLarge', theme.textTheme.titleLarge),
                      _TypeRow('titleMedium', theme.textTheme.titleMedium),
                      _TypeRow('bodyLarge', theme.textTheme.bodyLarge),
                      _TypeRow('bodyMedium', theme.textTheme.bodyMedium),
                      _TypeRow('labelLarge', theme.textTheme.labelLarge),
                      _TypeRow('labelSmall', theme.textTheme.labelSmall),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ---------- الألوان ----------
                const SectionHeader(
                  title: 'الألوان',
                  subtitle: 'كل القيم من AppColors وColorScheme',
                ),
                AppCard(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      _Swatch('primary', theme.colorScheme.primary),
                      _Swatch('primaryContainer', theme.colorScheme.primaryContainer),
                      _Swatch('secondary', theme.colorScheme.secondary),
                      _Swatch('surface', theme.colorScheme.surface, border: true),
                      _Swatch('outline', theme.colorScheme.outline),
                      const _Swatch('accent', AppColors.accent),
                      const _Swatch('pending', AppColors.statusPending),
                      const _Swatch('accepted', AppColors.statusAccepted),
                      const _Swatch('rejected', AppColors.statusRejected),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ---------- المسافات ----------
                const SectionHeader(
                  title: 'مقياس المسافات',
                  subtitle: 'xxs 4 · xs 8 · sm 12 · md 16 · lg 24 · xl 32 · xxl 48',
                ),
                const AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _SpaceBar('xxs', AppSpacing.xxs),
                      _SpaceBar('xs', AppSpacing.xs),
                      _SpaceBar('sm', AppSpacing.sm),
                      _SpaceBar('md', AppSpacing.md),
                      _SpaceBar('lg', AppSpacing.lg),
                      _SpaceBar('xl', AppSpacing.xl),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ---------- الأزرار ----------
                const SectionHeader(title: 'الأزرار'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      FilledButton(onPressed: () {}, child: const Text('زر أساسي')),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton(onPressed: () {}, child: const Text('زر ثانوي')),
                      const SizedBox(height: AppSpacing.xs),
                      TextButton(onPressed: () {}, child: const Text('زر نصي')),
                      const SizedBox(height: AppSpacing.xs),
                      const FilledButton(onPressed: null, child: Text('زر معطّل')),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('بحث'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ---------- الحقول ----------
                const SectionHeader(title: 'الحقول'),
                const AppCard(
                  child: Column(
                    children: <Widget>[
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'الاسم',
                          hintText: 'اكتب اسمك',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'حقل معطّل',
                          hintText: 'غير متاح الآن',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'بريد إلكتروني',
                          errorText: 'صيغة البريد غير صحيحة',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ---------- نظام v2: التدرّجات والظلال ----------
                const SectionHeader(
                  title: 'v2 — التدرّجات والظلال',
                  subtitle: 'خلفيات ناعمة وسطوح عائمة بدل الألوان المسطّحة',
                  icon: Icons.gradient_outlined,
                ),
                const AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _GradientPreview(
                        label: 'page',
                        gradient: AppGradients.page,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      _GradientPreview(
                        label: 'pageWarm',
                        gradient: AppGradients.pageWarm,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const _GradientPreview(
                        label: 'hero',
                        gradient: AppGradients.hero,
                        onDark: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: <Widget>[
                            Text('ظل عادي', style: theme.textTheme.labelMedium),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'AppShadows.card',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppCard(
                        lifted: true,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: <Widget>[
                            Text('ظل مرفوع', style: theme.textTheme.labelMedium),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'cardLifted',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // ---------- نظام v2: الشرائح (Pills) ----------
                const SectionHeader(
                  title: 'v2 — الشرائح والفلاتر',
                  subtitle: 'حبة دواء: فلتر / وسم / عداد',
                  icon: Icons.tune,
                ),
                SizedBox(
                  height: 44,
                  child: PillRow(
                    children: <Widget>[
                      PillChip(
                        label: 'الكل',
                        selected: true,
                        onTap: () {},
                      ),
                      PillChip(label: 'الرياضيات', onTap: () {}),
                      PillChip(label: 'الفيزياء', onTap: () {}),
                      PillChip(
                        label: 'المعادي',
                        icon: Icons.place_outlined,
                        onTap: () {},
                      ),
                      PillChip(
                        label: 'مميز',
                        icon: Icons.workspace_premium_outlined,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const AppCard(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      const PillChip(label: 'وسم ثابت', dense: true),
                      PillBadge(label: 'مدرس مميز', icon: Icons.workspace_premium),
                      PillBadge(
                        label: 'متاح',
                        icon: Icons.check_circle_outline,
                        color: AppColors.statusAccepted,
                      ),
                      PillBadge(
                        label: 'مكتمل',
                        color: AppColors.statusRejected,
                      ),
                      PillChip(
                        label: '7 مقاعد',
                        dense: true,
                        icon: Icons.groups_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ---------- البطاقات والشرائح ----------
                const SectionHeader(title: 'البطاقات والشرائح'),
                AppCard(
                  child: Row(
                    children: <Widget>[
                      const CircleAvatar(
                        radius: AppSpacing.avatarSm / 2,
                        child: Text('س'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('بطاقة قابلة للضغط', style: theme.textTheme.titleMedium),
                            Text(
                              'اضغط لرؤية تأثير الحبر (Ink)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_left),
                    ],
                  ),
                  onTap: () => AppSnackBar.show(
                    context,
                    'تم الضغط على البطاقة',
                    type: AppMessageType.success,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const AppCard(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      StatusChip(
                        label: 'قيد الانتظار',
                        color: AppColors.statusPending,
                      ),
                      StatusChip(label: 'مقبول', color: AppColors.statusAccepted),
                      StatusChip(label: 'مرفوض', color: AppColors.statusRejected),
                      StatusChip(label: 'مسودة', color: AppColors.statusNeutral),
                      StatusChip(
                        label: 'نص طويل جدًا لاختبار القص والاختصار',
                        color: AppColors.statusNeutral,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ---------- الحالات ----------
                const SectionHeader(title: 'حالات الفراغ والتنبيهات'),
                AppCard(
                  child: Column(
                    children: <Widget>[
                      const EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'لا توجد طلبات',
                        message: 'ستظهر هنا الطلبات الجديدة عند وصولها.',
                      ),
                      const Divider(),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () => AppSnackBar.show(context, 'رسالة معلومات'),
                            child: const Text('info'),
                          ),
                          OutlinedButton(
                            onPressed: () => AppSnackBar.show(
                              context,
                              'تم الحفظ بنجاح',
                              type: AppMessageType.success,
                            ),
                            child: const Text('success'),
                          ),
                          OutlinedButton(
                            onPressed: () => AppSnackBar.show(
                              context,
                              'هذه الميزة غير مفعّلة بعد',
                              type: AppMessageType.warning,
                            ),
                            child: const Text('warning'),
                          ),
                          OutlinedButton(
                            onPressed: () => AppSnackBar.show(
                              context,
                              'تعذّر تحميل البيانات',
                              type: AppMessageType.error,
                            ),
                            child: const Text('error'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ---------- RTL ----------
                const SectionHeader(
                  title: 'اختبار الاتجاه (RTL)',
                  subtitle: 'كل الأسهم والمحاذاة يجب أن تنعكس تلقائيًا',
                ),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Row(
                        children: <Widget>[
                          Icon(Icons.arrow_back),
                          SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text('سهم للخلف (يجب أن يشير لليمين)'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Row(
                        children: <Widget>[
                          Icon(Icons.arrow_forward),
                          SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text('سهم للأمام (يجب أن يشير لليسار)'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'هذا نص يبدأ من اليمين',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.start,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_left),
                          Text('١ / ٣', style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                AppCard(
                  child: Text(
                    'الخط: ${AppTypography.fontFamily} · '
                    'أقل ارتفاع سطر: ${AppTypography.minLineHeight} · '
                    'نصف قطر البطاقة: ${AppSpacing.radiusXl}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
        ),
      );
  }
}

class _Specimen extends StatelessWidget {
  const _Specimen(this.label, this.weight);

  final String label;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'درسلي — نموذج للخط العربي',
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: weight),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow(this.name, this.style);

  final String name;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          SizedBox(
            width: 118,
            child: Text(
              name,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text('دَرْسُ الرياضيات', style: style)),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color, {this.border = false});

  final String label;
  final Color color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 72,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: border ? Border.all(color: theme.colorScheme.outline) : null,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        SizedBox(
          width: 76,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SpaceBar extends StatelessWidget {
  const _SpaceBar(this.label, this.value);

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 44,
            child: Text(label, style: theme.textTheme.labelSmall),
          ),
          Container(
            width: value,
            height: 12,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(90),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${value.toInt()}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// معاينة تدرّج: مستطيل بحواف كبيرة + تسمية.
class _GradientPreview extends StatelessWidget {
  const _GradientPreview({
    required this.label,
    required this.gradient,
    this.onDark = false,
  });

  final String label;
  final Gradient gradient;

  /// التدرّجات المشبعة تحتاج نصًا أبيض.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      height: 60,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: onDark ? Colors.white : theme.colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
