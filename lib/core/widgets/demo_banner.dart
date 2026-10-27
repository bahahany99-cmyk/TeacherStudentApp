import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// تنبيه «وضع الزائر» — **شريحة دقيقة** لا صندوق تحذيري.
///
/// التغيير (نسخة 3، 2026-10-27): الصندوق الأصفر الكبير كان يقطع بداية كل شاشة
/// ويشوّه المظهر. البديل: شريحة بسطر واحد، بحدّ دافئ خفيف وظل شعري، تُقرأ عند
/// الحاجة ولا تنافس المحتوى.
///
/// لماذا ما زلنا نعرضها؟ لأن إخفاءها قد يُفهم أن البيانات حقيقية من الخادم —
/// وهي بيانات تجريبية محلية. الوضوح هنا متطلب صدق لا اختيار تصميمي.
///
/// قارئ الشاشة يسمع النص الكامل (`Semantics.label`)، بينما يظهر على الشاشة نص
/// أقصر يوفّر المساحة.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, this.message});

  /// نص مخصّص (المعرض يستخدمه لتنبيه مختلف).
  final String? message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String shortText = message ?? AppStrings.demoBannerShort;
    final bool isCustom = message != null;

    // المسافة السفلية خارج الشريحة، فيبقى ارتفاع الشريحة نفسها دقيقًا.
    return Semantics(
      label: message ?? AppStrings.demoBanner,
      container: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.demoBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  border: Border.all(color: AppColors.demoBorder, width: 1),
                  boxShadow: AppShadows.pill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // نقطة صغيرة بدل أيقونة: أقل إزعاجًا وأسرع قراءة.
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.demoForeground,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs + 2),
                    Flexible(
                      child: Text(
                        shortText,
                        // النص المخصّص (المعرض) أطول، فيُسمح بسطرين له فقط.
                        maxLines: isCustom ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.demoForeground,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
