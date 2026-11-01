import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';

/// معرض الصور الرمزية (P31) — 24 صورة مضمَّنة في ستة أقسام متساوية.
///
/// ## القرارات التصميمية
/// - **شبكة 4 أعمدة** على الهاتف: 24 صورة تُرى بتمريرة واحدة تقريبًا، ودائرة
///   56dp قابلة للنقر بلا خطأ (هدف اللمس ≥ 48dp).
/// - **أقسام معنونة** (أولاد/بنات/شباب/شابات/رجال أكبر/سيدات أكبر) بدل شبكة
///   مسطّحة، لأن المستخدم يبحث عن «صورة تشبهني» فالتقسيم يقلّص البحث.
/// - **معاينة قبل الاعتماد**: النقر يختار ويعاين في شريط ثابت أسفل الشاشة، ولا
///   يُحفظ إلا بزر «اعتماد». هذا يمنع تغييرًا غير مقصود بضغطة عابرة.
/// - **تمييز المختار**: إطار بلون التطبيق + علامة صح + خلفية مميّزة، فلا يعتمد
///   التمييز على اللون وحده (فرق واضح لمن لا يميّز الألوان).
class AvatarGalleryScreen extends StatefulWidget {
  const AvatarGalleryScreen({super.key, required this.currentPreset});

  /// الاختيار المحفوظ حاليًا (يُعرض محدَّدًا عند الفتح).
  final int currentPreset;

  static Future<int?> show(
    BuildContext context, {
    required int currentPreset,
  }) {
    return Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (BuildContext context) =>
            AvatarGalleryScreen(currentPreset: currentPreset),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<AvatarGalleryScreen> createState() => _AvatarGalleryScreenState();
}

class _AvatarGalleryScreenState extends State<AvatarGalleryScreen> {
  late int _highlighted = widget.currentPreset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AvatarArtwork highlighted = AvatarPresets.all[_highlighted];

    return Scaffold(
      key: const Key('avatar-gallery'),
      appBar: AppBar(title: const Text('الصور الرمزية')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: <Widget>[
                for (final AvatarCategory category in AvatarCategory.values)
                  _CategorySection(
                    category: category,
                    highlighted: _highlighted,
                    currentPreset: widget.currentPreset,
                    onTap: (int id) => setState(() => _highlighted = id),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(120),
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  ClipOval(
                    child: Image.asset(
                      highlighted.asset,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'معاينة اختيارك',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${highlighted.category.label} · '
                          '${highlighted.description}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton(
                    key: const Key('avatar-adopt'),
                    onPressed: () => Navigator.of(context).pop(_highlighted),
                    child: const Text('اعتماد'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// قسم فئة واحدة: عنوان + شبكة صورها.
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.highlighted,
    required this.currentPreset,
    required this.onTap,
  });

  final AvatarCategory category;
  final int highlighted;
  final int currentPreset;
  final ValueChanged<int> onTap;

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
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final AvatarArtwork artwork in artworks)
                _AvatarTile(
                  artwork: artwork,
                  selected: artwork.id == highlighted,
                  isCurrent: artwork.id == currentPreset,
                  onTap: () => onTap(artwork.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// صورة واحدة في الشبكة: إطار عند الاختيار + علامة صح + شارة «الحالية».
class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.artwork,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
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
        key: Key('avatar-option-${artwork.id}'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Stack(
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
                  errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                      Container(color: Color(artwork.tint)),
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
