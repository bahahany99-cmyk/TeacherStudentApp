import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/features/profile/presentation/widgets/avatar_gallery_grid.dart';

/// معرض الصور الرمزية (P31) — 30 صورة مضمَّنة في عشرة أقسام متساوية.
///
/// ## القرارات التصميمية
/// - **شبكة 3 أعمدة** على الهاتف: 30 صورة في عشرة أقسام (3 لكل قسم)، فالقسم
///   الواحد يُرى كاملًا في صف واحد، والدائرة كبيرة بما يكفي للنقر الصحيح.
/// - **أقسام معنونة** (أطفال/مراهقون/شباب/بالغون/كبار سن × ذكور وإناث) بدل شبكة
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
                  AvatarCategorySection(
                    category: category,
                    selected: _highlighted,
                    currentPreset: widget.currentPreset,
                    onTap: (int id) => setState(() => _highlighted = id),
                  ),
              ],
            ),
          ),
          // شريط سفلي ثابت: معاينة + زر اعتماد بعرض كامل.
          //
          // **لماذا الزر بعرض كامل أسفل المعاينة لا بجانبها؟** لأن الزر داخل
          // `Row` يأخذ عرضًا غير محدود من الأب (الأشقّاء غير المرنين يُقاسون
          // بعرض لا نهائي)، وهذا أنتج في الاختبارات `RenderBox was not laid
          // out` داخل `_InputPadding`. العرض الكامل = قيود محدودة دائمًا،
          // وأكبر هدف لمس للإجراء الأساسي، وأسلم على الشاشات الضيقة.
          Material(
            color: theme.colorScheme.surface,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant.withAlpha(120),
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
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
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('avatar-adopt'),
                        onPressed: () =>
                            Navigator.of(context).pop(_highlighted),
                        child: const Text('اعتماد'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
