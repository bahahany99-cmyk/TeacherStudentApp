import 'dart:async';

import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/data/models/teacher_filter.dart';

/// شريط فلاتر استكشاف المدرسين (P15): بحث + طريقة تقديم + محافظة.
///
/// **قاعدة بصرية من v3:** كل فلتر «حبة» في صف أفقي قابل للتمرير، بلا قوائم
/// منسدلة. الحبة المختارة تُلوَّن، فتُقرأ الحالة بنظرة.
///
/// المكوّن عرض فقط: يستقبل الفلتر الحالي ويعيد الجديد عبر [onChanged]، فلا
/// يعرف مستودعًا ولا حالة — ما يجعله قابلًا للاختبار وحده.
class TeacherFilterBar extends StatefulWidget {
  const TeacherFilterBar({
    super.key,
    required this.filter,
    required this.governorates,
    required this.resultLabel,
    required this.onChanged,
  });

  final TeacherFilter filter;

  /// المحافظات الموجودة فعلًا في البيانات (لا قائمة نظرية).
  final List<String> governorates;

  /// سطر عدد النتائج — يُعرض تحت الشريط.
  final String resultLabel;

  final ValueChanged<TeacherFilter> onChanged;

  @override
  State<TeacherFilterBar> createState() => _TeacherFilterBarState();
}

class _TeacherFilterBarState extends State<TeacherFilterBar> {
  late final TextEditingController _query = TextEditingController(
    text: widget.filter.query,
  );

  /// تأجيل قراءة البحث 250 مللي ثانية بعد آخر حرف.
  ///
  /// الحبات تُطلق القراءة فورًا (نقرة واحدة = نيّة واضحة)، أما الكتابة فحرف
  /// واحد ليس نيّة — بلا هذا التأجيل يُطلق اسم من ستة أحرف ستّ قراءات، وعلى
  /// Firestore ستّ رحلات شبكة.
  static const Duration _typingDelay = Duration(milliseconds: 250);
  Timer? _debounce;

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_typingDelay, () {
      if (mounted) {
        widget.onChanged(widget.filter.copyWith(query: value));
      }
    });
  }

  @override
  void didUpdateWidget(TeacherFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // «تفريغ الفلاتر» من الخارج يجب أن يفرّغ الحقل أيضًا.
    if (widget.filter.query != _query.text &&
        widget.filter.query != oldWidget.filter.query) {
      _query.text = widget.filter.query;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _setDelivery(TeacherDeliveryFilter next) {
    // «عن بُعد» تُلغي المحافظة المختارة: محافظة مع «عن بُعد» نتيجة فارغة في
    // أكثر الحالات، والسلوك المتوقع أن يتكيّف الشريط مع الاختيار.
    widget.onChanged(
      next == TeacherDeliveryFilter.online
          ? widget.filter.copyWith(delivery: next, governorate: null)
          : widget.filter.copyWith(delivery: next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TeacherFilter filter = widget.filter;
    final bool showsGovernorates =
        widget.governorates.isNotEmpty &&
        (filter.delivery != TeacherDeliveryFilter.online ||
            filter.governorate != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'ابحث باسم المدرس أو المادة أو المكان',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح البحث',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _debounce?.cancel();
                      _query.clear();
                      widget.onChanged(filter.copyWith(query: ''));
                    },
                  ),
          ),
          onChanged: _onQueryChanged,
        ),
        const SizedBox(height: AppSpacing.xs),
        PillRow(
          children: <Widget>[
            for (final TeacherDeliveryFilter option
                in TeacherDeliveryFilter.values)
              PillChip(
                label: option.label,
                icon: switch (option) {
                  TeacherDeliveryFilter.any => Icons.apps_rounded,
                  TeacherDeliveryFilter.online => Icons.public_rounded,
                  TeacherDeliveryFilter.inPerson => Icons.place_outlined,
                },
                selected: filter.delivery == option,
                onTap: () => _setDelivery(option),
              ),
          ],
        ),
        if (showsGovernorates) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          PillRow(
            children: <Widget>[
              PillChip(
                label: 'كل المحافظات',
                selected: filter.governorate == null,
                onTap: () =>
                    widget.onChanged(filter.copyWith(governorate: null)),
              ),
              for (final String governorate in widget.governorates)
                PillChip(
                  label: governorate,
                  selected: filter.governorate == governorate,
                  onTap: () =>
                      widget.onChanged(filter.copyWith(governorate: governorate)),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                widget.resultLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (filter.isActive)
              PillChip(
                label: 'تفريغ الفلاتر',
                icon: Icons.filter_alt_off_outlined,
                dense: true,
                onTap: () {
                  _debounce?.cancel();
                  _query.clear();
                  widget.onChanged(filter.cleared());
                },
              ),
          ],
        ),
      ],
    );
  }
}
