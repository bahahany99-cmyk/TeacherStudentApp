import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// حشوة أفقية متجاوبة حسب عرض الشاشة.
///
/// يمكن استخدامها كعنصر داخل `ListView` (لا تُفرض ارتفاعات لا نهائية).
/// عند الحاجة لتخطيط أجهزة لوحية أوسع (NavigationRail + عمودين) لاحقًا،
/// يكفي تعديل هذا الملف.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= AppSpacing.tabletBreakpoint;
        final double horizontal = isWide ? AppSpacing.xl : AppSpacing.md;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontal,
            vertical: AppSpacing.sm,
          ),
          child: child,
        );
      },
    );
  }
}
