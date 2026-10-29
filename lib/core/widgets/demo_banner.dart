import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/session_scope.dart';
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
/// ## (P18) الويدجت صار **متحققًا ذاتيًا** — وهذه إصلاح جذري لعطل حقيقي
///
/// **العطل:** كان `const DemoBanner()` يُكتب في 20 شاشة **بلا أي شرط**، فتظهر
/// شريحة «وضع الزائر · بيانات تجريبية» لكل مستخدم — حتى من سجّل الدخول بحساب
/// Google حقيقي. الشريحة كانت تُقرأ خطأً كدليل على أن الجلسة تجريبية، مع أن
/// الجلسة سليمة تمامًا. (التشخيص الكامل:
/// `docs/diagnostics/P18_demo_banner_diagnosis.md`.)
///
/// **لماذا التحقق هنا لا في الشاشات؟** لأن الشرط في كل شاشة قابل للنسيان —
/// وقد نُسي فعلًا في 20 موضعًا وبقي صحيحًا في 3. القراءة من الجلسة داخل
/// الويدجت تجعل **المصدر واحدًا**، فلا يمكن أن تظهر الشريحة لحساب حقيقي مهما
/// كتبها مستدعٍ مستقبلًا.
///
/// ## قواعد السلوك
/// 1. **بلا `SessionScope`** (اختبار مكوّن منفرد، أو معرض): تُعامَل الجلسة
///    كغير معروفة ⇒ `isDemoSession == false` ⇒ تُخفى الشريحة. **لا انهيار**،
///    لأننا نستخدم [SessionScope.maybeOf] لا `of` (التي فيها `assert`).
/// 2. **جلسة حقيقية**: تُخفى تمامًا (`SizedBox.shrink()`) بلا حجز مساحة.
/// 3. **جلسة تجريبية**: تُعرض كما هي.
/// 4. **نص مخصّص** (`message != null`): يُعرض **دائمًا** بغض النظر عن الجلسة،
///    لأنه إفصاح صريح من المستدعي (معرض المكونات) لا مؤشر جلسة.
///
/// لا نحتفظ بحالة داخلية: التحديث يجيء من `InheritedNotifier` في
/// [SessionScope] الذي يسجّل `maybeOf` الاعتماد عليه تلقائيًا.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, this.message});

  /// نص مخصّص (المعرض يستخدمه لتنبيه مختلف).
  ///
  /// وجوده يعني «اعرضني دائمًا»: الحالات التي لا تتعلق بالجلسة لا يجوز
  /// أن تُخفى بسببها.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final bool isCustom = message != null;

    // النص المخصّص لا علاقة له بالجلسة ⇒ يُعرض بلا فحص.
    // لغير المخصّص: غياب النطاق يعني «جلسة غير معروفة» وليس انهيارًا.
    if (!isCustom) {
      final bool isDemo = SessionScope.maybeOf(context)?.isDemoSession ?? false;
      if (!isDemo) {
        // حساب حقيقي: لا شريحة ولا مساحة محجوزة (لا Padding ولا SizedBox).
        return const SizedBox.shrink();
      }
    }

    final ThemeData theme = Theme.of(context);
    final String shortText = message ?? AppStrings.demoBannerShort;

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
