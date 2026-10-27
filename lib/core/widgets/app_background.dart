import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_effects.dart';

/// مزاج الخلفية.
enum AppBackgroundTone {
  /// بلاش ← أبيض: الاستخدام الافتراضي لكل صفحات المحتوى.
  cool,

  /// بلاش/خوخي ← أبيض: صفحات الحساب والملف الشخصي (أدفأ بدرجة واحدة فقط).
  warm,
}

/// خلفية الشاشة العالمية (تُركَّب مرة واحدة في `MaterialApp.builder`).
///
/// **نسخة 4.1:** تخلّت عن الهالات الملوّنة (orbs) وعن الغسيل السفلي. السبب أن
/// الخلفية كانت تُضفي ورديًا على كامل الشاشة، وصار المحتوى يبدو «مصبوغًا» بدل
/// أن تبدو البطاقات بيضاء صريحة فوق بياض. الآن:
/// - الحافة العلوية فقط تحمل بلاش رقيقًا يتلاشى إلى الأبيض.
/// - بقية الشاشة **بيضاء صريحة** (`AppGradients.page`).
///
/// لماذا `DecoratedBox` مباشرة بلا `Stack`؟ بعد حذف الهالات لم يبقَ ما يحتاج
/// تراكبًا؛ و`DecoratedBox` يمرّر القيود كما هي (لا يفقد المحتوى ارتفاعه، وهو
/// الخطأ الذي وقع سابقًا مع `Stack` بقيود مرخّية).
///
/// ملاحظة أداء: كل شيء ثابت (`const`) — بلا رسوم متحركة ولا `BackdropFilter`،
/// فيبقى التمرير سلسًا على الأجهزة الضعيفة.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.tone = AppBackgroundTone.cool});

  final Widget child;
  final AppBackgroundTone tone;

  @override
  Widget build(BuildContext context) {
    final LinearGradient gradient = tone == AppBackgroundTone.warm
        ? AppGradients.pageWarm
        : AppGradients.page;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: child,
    );
  }
}
