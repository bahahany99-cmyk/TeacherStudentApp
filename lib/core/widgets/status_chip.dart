import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// وسم صغير يعرض حالة (طلب حجز، ملف مدرس، …).
///
/// نسخة 2: شكل «حبة دواء» بخلفية ناعمة وحدّ شفاف، بلا ظل — لأنه غالبًا يظهر
/// داخل بطاقة لها ظلها، وتكديس الظلال يجعل الشاشة ثقيلة.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: color.withAlpha(70), width: 1),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}
