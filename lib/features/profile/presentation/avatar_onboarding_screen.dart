import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/features/profile/presentation/widgets/avatar_gallery_grid.dart';

/// شاشة **اختيار الصورة الرمزية الإلزامية** للحساب الجديد.
///
/// ## القاعدة الأساسية: لا دخول بلا اختيار فعلي
/// - عند الفتح تُعرض في الدائرة الكبيرة صورة **محايدة**
///   ([AvatarPresets.neutralPlaceholderAsset]): ليست فارغة ولا رمادية ولا
///   تبدو كصورة فشل
///   تحميل، لكنها **ليست اختيارًا** ولا تُحفظ أبدًا.
/// - زر «تأكيد الصورة والمتابعة» **معطّل** حتى ينقر المستخدم إحدى الصور
///   الثلاثين بنفسه. الضغط على زر معطّل لا ينقل إلى أي شاشة (السلوك الأصلي
///   لـ`FilledButton` بلا `onPressed`).
/// - الاختيار الفعلي يغيّر المعاينة فورًا، ويُظهر إطارًا وعلامة صح على الصورة
///   المختارة، ويُفعّل الزر.
///
/// ## الحفظ
/// عند التأكيد نكتب `avatarPreset` عبر
/// [SessionController.completeAvatarSelection] الذي **يكتب على الخادم أولًا**
/// ثم يُحدّث الجلسة:
/// فلا تُغلق الشاشة ويُسمح بالدخول إذا فشلت الكتابة (وإلا لأصبح لدينا مستخدم
/// دخل بحساب لم يُحفظ اختياره). والشاشة نفسها ليست مسارًا يمكن تجاوزه: يعرضها
/// الهيكل الرئيسي بدلًا من محتواه، فتختفي كل التبويبات حتى يتم الاختيار.
///
/// ## لماذا لا تُعرض للحسابات القديمة؟
/// الشرط في [AvatarOnboardingPolicy] لا هنا — مكان واحد للحقيقة.
class AvatarOnboardingScreen extends StatefulWidget {
  const AvatarOnboardingScreen({super.key});

  @override
  State<AvatarOnboardingScreen> createState() => _AvatarOnboardingScreenState();
}

class _AvatarOnboardingScreenState extends State<AvatarOnboardingScreen> {
  /// `null` = لم يختر المستخدم بعد (الحالة الابتدائية **دائمًا**).
  int? _selected;

  bool _saving = false;
  String? _error;

  Future<void> _confirm() async {
    final int? chosen = _selected;
    if (chosen == null || _saving) {
      return;
    }
    final SessionController session = SessionScope.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await session.completeAvatarSelection(chosen);
      // النجاح يغيّر حالة الجلسة، فيعيد الهيكل الرئيسي بناء نفسه بالواجهة
      // العادية. لا `Navigator.push` هنا: الشاشة ليست مسارًا مستقلًا.
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final AppException exception = error is AppException
          ? error
          : toAppException(error);
      final String message =
          exception.overrideMessage ?? exception.message;
      setState(() => _error = message);
      AppSnackBar.show(context, message, type: AppMessageType.error);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppUser? user = SessionScope.of(context).user;
    final String asset = _selected == null
        ? AvatarPresets.neutralPlaceholderAsset
        : AvatarPresets.all[_selected!].asset;

    return PopScope(
      // لا رجوع: الحساب الجديد لا يدخل الرئيسية قبل الاختيار، والرجوع من
      // الشاشة الأولى كان سيعني الخروج من التطبيق بلا صورة محفوظة.
      canPop: false,
      child: Scaffold(
        key: const Key('avatar-onboarding'),
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  children: <Widget>[
                    Text(
                      'اختر صورتك',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      user == null
                          ? 'ستظهر صورتك في ملفك ومحادثاتك، ويمكنك تغييرها '
                                'لاحقًا من «حسابي».'
                          : 'أهلًا ${user.displayName}، اختر صورة تظهر في ملفك '
                                'ومحادثاتك. يمكنك تغييرها لاحقًا من «حسابي».',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _PreviewCircle(asset: asset, hasSelection: _selected != null),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _selected == null
                          ? 'لم تختر بعد'
                          : AvatarPresets.all[_selected!].description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: _selected == null
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // كل الصور الثلاثين، مرتّبة بالفئات العمرية والجنس، بلا
                    // تفضيل فئة للطالب أو للمدرّس.
                    for (final AvatarCategory category
                        in AvatarCategory.values)
                      AvatarCategorySection(
                        category: category,
                        selected: _selected,
                        currentPreset: null,
                        keyPrefix: 'onboarding-avatar',
                        onTap: (int id) => setState(() => _selected = id),
                      ),
                  ],
                ),
              ),
              Material(
                color: theme.colorScheme.surface,
                elevation: 8,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (_error != null) ...<Widget>[
                          Text(
                            _error!,
                            key: const Key('avatar-onboarding-error'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const Key('avatar-onboarding-confirm'),
                            // `null` = معطّل فعلًا: لا انتقال ولا حفظ.
                            onPressed: _selected == null || _saving
                                ? null
                                : _confirm,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('تأكيد الصورة والمتابعة'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// دائرة المعاينة الكبيرة: محايدة قبل الاختيار، وصورة المستخدم بعده.
class _PreviewCircle extends StatelessWidget {
  const _PreviewCircle({required this.asset, required this.hasSelection});

  final String asset;
  final bool hasSelection;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Semantics(
        label: hasSelection
            ? 'معاينة الصورة المختارة'
            : 'معاينة محايدة — لم تختر صورة بعد',
        image: true,
        child: Container(
          width: 132,
          height: 132,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: hasSelection
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: 3,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              // مفتاح ثابت: الاختبار يقرأ الأصل المعروض من هذا الـ`Image`.
              key: const Key('avatar-onboarding-preview'),
              asset,
              fit: BoxFit.cover,
              width: 126,
              height: 126,
              cacheWidth: 384,
            ),
          ),
        ),
      ),
    );
  }
}
