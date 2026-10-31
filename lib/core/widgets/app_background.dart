import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_effects.dart';

/// مزاج شريط الحافة العلوية (لا لون الصفحة؛ الصفحة بيضاء في الحالتين).
enum AppBackgroundTone {
  /// بلاش ← أبيض: الاستخدام الافتراضي لكل صفحات المحتوى.
  cool,

  /// بلاش/خوخي ← أبيض: صفحات الحساب والملف الشخصي (أدفأ بدرجة واحدة فقط).
  warm,
}

/// خلفية الشاشة العالمية (تُركَّب مرة واحدة في `MaterialApp.builder`).
///
/// **النسخة 4.2 — قاعدة صريحة قابلة للقياس:**
/// 1. الطبقة السفلية **بيضاء صريحة** (`Colors.white`) على كامل الشاشة.
/// 2. فوقها شريط بلاش في الأعلى فقط، بارتفاع `blushHeightFactor` من الشاشة
///    (20% كحد أقصى، وبسقف مطلق 200 نقطة حتى لا يتضخّم على الشاشات الطويلة).
/// 3. الشريط ينتهي عند حافته السفلية بأبيض **معتم**، ثم لا يوجد شيء فوق
///    الأبيض — فلا يظهر أي وردي في المنتصف أو الأسفل أو خلف شريط التنقّل.
///
/// لماذا `Positioned` داخل `Stack` بدل تدرّج على ارتفاع الشاشة؟
/// - التدرّج الطويل يجعل اللون يتوزّع بصريًا على مساحة أكبر فيبدو الصف الأبيض
///   «مغبَّشًا»؛ الشريط المحدود يجعل الوردي **ينتهي** لا «يخبو».
/// - ربط الشريط بنسبة من الارتفاع (لا بالبكسل) يُبقي الشكل نفسه على كل الأجهزة.
///
/// ملاحظة أداء: لا رسوم متحركة ولا `BackdropFilter` — رسم ثابت واحد.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.tone = AppBackgroundTone.cool,
  });

  /// نسبة ارتفاع الشاشة التي يشغلها شريط البلاش.
  ///
  /// 0.20 هو الحد الذي طلبه صاحب المشروع: على الأقل 80% من الشاشة أبيض صريح.
  /// القيمة ثابتة في مكان واحد، ويحرسها اختبار (`design_v3_test`).
  static const double blushHeightFactor = 0.20;

  /// سقف مطلق لارتفاع الشريط — على الشاشات الطويلة (تابلت) تبقى النسبة لكن
  /// بلا شريط ضخم يشغل ثلث الشاشة.
  static const double blushMaxHeight = 200;

  /// مفاتيح للاختبار البصري: تثبت أن الأبيض طبقة سفلية وأن الشريط محدود.
  static const Key baseKey = ValueKey<String>('app-background-white');
  static const Key blushBandKey = ValueKey<String>('app-background-blush');

  final Widget child;
  final AppBackgroundTone tone;

  /// ارتفاع شريط البلاش لارتفاع شاشة معيّن.
  static double blushHeightFor(double screenHeight) {
    final double byFactor = screenHeight * blushHeightFactor;
    if (byFactor.isNaN || byFactor <= 0) {
      return 0;
    }
    return math.min(byFactor, blushMaxHeight);
  }

  @override
  Widget build(BuildContext context) {
    // `maybeSizeOf` حتى تعمل الخلفية داخل اختبارات بلا MediaQuery.
    final double screenHeight =
        MediaQuery.maybeSizeOf(context)?.height ?? 800;
    final double bandHeight = blushHeightFor(screenHeight);

    final LinearGradient gradient = tone == AppBackgroundTone.warm
        ? AppGradients.pageWarm
        : AppGradients.page;

    return ColoredBox(
      key: baseKey,
      color: Colors.white,
      child: Stack(
        // التمدّد ضروري: هذه الخلفية تلتف حول شجرة التطبيق كاملة (خلف
        // Navigator)، وبلا `expand` يحصل المحتوى على قيود مرخّية فينهار
        // ارتفاعه إلى صفر (فخ وقعنا فيه سابقًا).
        fit: StackFit.expand,
        children: <Widget>[
          if (bandHeight > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: bandHeight,
              child: DecoratedBox(
                key: blushBandKey,
                decoration: BoxDecoration(gradient: gradient),
                child: const SizedBox.expand(),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
