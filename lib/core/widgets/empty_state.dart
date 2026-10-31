import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// حالة فراغ/خطأ موحّدة — بنسخة «مقنعة» لا سطر نص.
///
/// المكوّن يقدّم ثلاث طبقات، بالترتيب الذي يقرأه المستخدم:
/// 1. **هالة أيقونة**: دائرة بتدرّج خفيف من لون الهوية حول أيقونة كبيرة —
///    تعطي الفراغ «شكلًا» بدل بياض موحش، بلا صور تُثقل حزمة التطبيق.
/// 2. **عنوان + شرح**: ماذا يحدث الآن، وماذا يفعل المستخدم.
/// 3. **إجراء أساسي** ([primaryActionLabel]) بشكل `FilledButton` — لا نص
///    عائم. الفراغ بلا مخرج هو ما يجعل الشاشة تبدو ميتة؛ الإجراء هو الفرق
///    بين «لا يوجد شيء» و«هذا ما تفعله الآن».
///
/// الإجراء الثانوي ([actionLabel]) يبقى `TextButton` للتوافق: مئات المواضع
/// تستخدمه، وبعضها إجراء خفيف لا يستحق زرًا ممتلئًا.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onActionTap,
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// إجراء ثانوي (نص).
  final String? actionLabel;
  final VoidCallback? onActionTap;

  /// إجراء أساسي (زر ممتلئ) — المخرج الواضح من الحالة الفارغة.
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  /// مفتاح زر الإجراء الأساسي — تثبته الاختبارات بلا الاعتماد على نص.
  static const Key primaryActionKey = Key('empty-primary-action');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.xs,
      ),
      // بلا `Center`: المكوّن يُستضاف داخل أعمدة ذات ارتفاع غير محدود، و`Center`
      // هناك يتوسّع إلى ما لا نهاية. `ConstrainedBox` وحده يكفي لعرض مقروء.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // هالة الأيقونة: تدرّج خفيف جدًا، بلا حدود — عنصر بصري واحد لا
              // «بطاقة داخل بطاقة».
              Container(
                width: AppSpacing.emptyHalo,
                height: AppSpacing.emptyHalo,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: <Color>[primary.withAlpha(30), primary.withAlpha(8)],
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 38, color: primary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (primaryActionLabel != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  key: primaryActionKey,
                  onPressed: onPrimaryAction,
                  style: FilledButton.styleFrom(
                    // ليس بعرض الشاشة: زر الفراغ إجراء مقترح لا نموذج إرسال.
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                  ),
                  child: Text(primaryActionLabel!),
                ),
              ],
              if (actionLabel != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                TextButton(onPressed: onActionTap, child: Text(actionLabel!)),
              ],
            ],
          ),
      ),
    );
  }
}
