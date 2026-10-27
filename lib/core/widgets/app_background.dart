import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_effects.dart';

/// نوع الخلفية المتدرّجة.
enum AppBackgroundTone {
  /// نعناعي ← أبيض ← لافندر: الاستخدام الافتراضي لصفحات المحتوى.
  cool,

  /// وردي ← أبيض ← نعناعي: صفحات الحساب/الملف الشخصي (أدفأ).
  warm,
}

/// خلفية الشاشة المتدرّجة + هالات لونية شفافة.
///
/// لماذا واجهة واحدة لكل الشاشات؟
/// - التدرّج المكرّر في كل شاشة يعني نسخًا لأرقام الألوان، وأول تعديل يصبح
///   غير متّسق (نفس سبب A-25 في الخط).
/// - الهالات الثلاث محسوبة بنسب من عرض الشاشة، فلا تفيض على أحجام مختلفة ولا
///   تسبب overflow لأنها داخل `Stack` بـ`clipBehavior: Clip.hardEdge`.
///
/// ملاحظة أداء: كل شيء ثابت (`const`) — لا رسوم متحركة ولا `BackdropFilter`،
/// حتى يبقى التمرير سلسًا على الأجهزة الضعيفة.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.tone = AppBackgroundTone.cool,
    this.showOrbs = true,
  });

  final Widget child;
  final AppBackgroundTone tone;

  /// الهالات الناعمة خلف المحتوى. تُطفأ في الشاشات المزدحمة بالبطاقات.
  final bool showOrbs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinearGradient gradient = tone == AppBackgroundTone.warm
        ? AppGradients.pageWarm
        : AppGradients.page;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        // التمدّد ضروري: هذه الخلفية تلتف حول شجرة التطبيق كاملة (خلف
        // Navigator)، وبلا `expand` يحصل المحتوى على قيود مرخّية فينهار
        // ارتفاعه إلى صفر ولا يظهر أي شيء.
        fit: StackFit.expand,
        children: <Widget>[
          if (showOrbs)
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double width = constraints.maxWidth;
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: <Widget>[
                        _Orb(
                          color: theme.colorScheme.primary,
                          diameter: width * 0.72,
                          opacity: 0.10,
                          top: -width * 0.34,
                          start: -width * 0.24,
                        ),
                        _Orb(
                          color: theme.colorScheme.tertiary,
                          diameter: width * 0.62,
                          opacity: 0.10,
                          top: width * 0.18,
                          end: -width * 0.26,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// هالة دائرية شفافة توضع بإحداثيات نسبية.
class _Orb extends StatelessWidget {
  const _Orb({
    required this.color,
    required this.diameter,
    required this.opacity,
    required this.top,
    this.start,
    this.end,
  });

  final Color color;
  final double diameter;
  final double opacity;
  final double top;
  final double? start;
  final double? end;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: start,
      right: end,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color.withAlpha((opacity * 255).round()), color.withAlpha(0)],
          ),
        ),
      ),
    );
  }
}
