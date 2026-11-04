import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';

/// شبكة الصور الرمزية (P31) — مكوّن **مشترك** بين شاشتين:
///
/// - معرض «تغيير الصورة» من بطاقة الحساب (`AvatarGalleryScreen`) حيث يُعرض
///   الاختيار الحالي ويمكن المعاينة قبل الاعتماد.
/// - شاشة الاختيار الإلزامية للحساب الجديد (`AvatarOnboardingScreen`) حيث لا
///   يوجد اختيار سابق أصلًا.
///
/// **لماذا مكوّن مشترك؟** لأن تكرار الشبكة في الشاشتين يعني نسختين من نفس
/// القواعد البصرية (ثلاثة أعمدة، دائرة، إطار التحديد، علامة الصح، شارة
/// «الحالية») — وأي تعديل مستقبلي كان سيُنسى في إحداهما. الشاشتان تختلفان في
/// السلوك فقط (ماذا يحدث عند النقر)، لا في العرض.
///
/// **ترتيب الفئات** هو ترتيب `AvatarCategory.values`: أطفال ← مراهقون ← شباب ←
/// بالغون ← كبار السن، ذكور ثم إناث في كل مستوى. لا ترتيب آخر: المستخدم يبحث
/// عن «صورة تشبهني» في مستوى عمره أولًا.
class AvatarCategorySection extends StatelessWidget {
  const AvatarCategorySection({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
    this.currentPreset,
    this.keyPrefix = 'avatar-option',
  });

  final AvatarCategory category;

  /// المعرّف المحدَّد الآن (إطار + علامة صح). `null` = لا اختيار بعد.
  final int? selected;

  /// الاختيار المحفوظ سابقًا — يُوسم بشارة «الحالية» إن لم يكن هو المحدَّد.
  final int? currentPreset;

  final ValueChanged<int> onTap;

  /// بادئة مفاتيح البلاطات، كي لا تتشابه مفاتيح شاشتين في اختبار واحد.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<AvatarArtwork> artworks = AvatarPresets.ofCategory(category);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs,
              vertical: AppSpacing.xs,
            ),
            child: Text(category.label, style: theme.textTheme.titleSmall),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final AvatarArtwork artwork in artworks)
                AvatarTile(
                  key: Key('$keyPrefix-${artwork.id}'),
                  artwork: artwork,
                  selected: artwork.id == selected,
                  isCurrent:
                      currentPreset != null && artwork.id == currentPreset,
                  onTap: () => onTap(artwork.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// صورة واحدة في الشبكة: دائرة كاملة + إطار عند الاختيار + علامة صح.
///
/// التمييز **ليس باللون وحده**: إطار سميك + علامة صح + خلفية خفيفة، فيبقى
/// واضحًا لمن لا يميّز الألوان ولقارئ الشاشة (`Semantics(selected: true)`).
class AvatarTile extends StatelessWidget {
  const AvatarTile({
    super.key,
    required this.artwork,
    required this.selected,
    required this.onTap,
    this.isCurrent = false,
  });

  final AvatarArtwork artwork;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color ring = theme.colorScheme.primary;

    return Semantics(
      button: true,
      selected: selected,
      label: '${artwork.category.label}: ${artwork.description}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Stack(
          // `StackFit.expand`: البلاطة مربّعة أصلًا في الشبكة، والتعبئة تجعل
          // الصورة تملأ الخلية ولو لم يكتمل فكّ الترميز (بدون `expand` تُقاس
          // الصورة على مقاسها الأصلي فتظهر دوائر صغيرة أو صفرية).
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? ring : Colors.transparent,
                  width: 2.5,
                ),
                color: selected ? ring.withAlpha(20) : Colors.transparent,
              ),
              child: ClipOval(
                child: Image.asset(
                  artwork.asset,
                  fit: BoxFit.cover,
                  // 56dp على شاشة 3× = 168px: نقرأ بهذا الحجم فقط.
                  cacheWidth: 192,
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stack,
                      ) => Container(color: Color(artwork.tint)),
                ),
              ),
            ),
            if (selected)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: ring,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.check,
                    size: 14,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            if (isCurrent && !selected)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    'الحالية',
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
