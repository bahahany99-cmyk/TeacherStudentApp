import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/data/validation/booking_rules.dart';

/// اختيار موعد حصة: يوم + ساعة، بلا تقويم نظام ولا قوائم منسدلة.
///
/// **لماذا حبات لا `showDatePicker`؟** لأن التطبيق عربي RTL، وتجربة اختيار
/// موعد داخل ورقة واحدة أوضح وأسرع من ثلاث نوافذ متتابعة، ولأن الحبات قابلة
/// للاختبار بلا ضغط شبكة معقّدة (نفس أسلوب فلاتر الاستكشاف).
///
/// تُعيد [DateTime] مختارة أو `null` عند الإلغاء.
Future<DateTime?> showSlotPickerSheet(
  BuildContext context, {
  required int durationMinutes,
  DateTime? initial,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) =>
        _SlotPickerSheet(durationMinutes: durationMinutes, initial: initial),
  );
}

class _SlotPickerSheet extends StatefulWidget {
  const _SlotPickerSheet({required this.durationMinutes, this.initial});

  final int durationMinutes;
  final DateTime? initial;

  @override
  State<_SlotPickerSheet> createState() => _SlotPickerSheetState();
}

class _SlotPickerSheetState extends State<_SlotPickerSheet> {
  /// الأيام المعروضة: من الغد ولمدة أسبوعين (المدرسة تحجز مسبقًا).
  static const int _days = 14;

  late DateTime _day;
  late int _minutes;

  List<DateTime> get _dayOptions => <DateTime>[
    for (int i = 0; i < _days; i++)
      DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day + i,
      ),
  ];

  /// ساعات معروضة كل نصف ساعة داخل نافذة اليوم الدراسي، وتُستبعد التي تنتهي
  /// بعد الإغلاق.
  List<int> get _slots {
    final List<int> result = <int>[];
    for (
      int minute = BookingRules.openMinute;
      minute + widget.durationMinutes <= BookingRules.closeMinute;
      minute += 30
    ) {
      result.add(minute);
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    final DateTime initial = widget.initial ?? _defaultSlot();
    _day = DateTime(initial.year, initial.month, initial.day);
    _minutes = initial.hour * 60 + initial.minute;
    if (!_slots.contains(_minutes)) {
      _minutes = _slots.first;
    }
  }

  /// أول موعد مسموح: بعد المهلة الدنيا، على رأس نصف ساعة.
  ///
  /// ⚠️ عيب حقيقي كُشف في P17 (اختبار الرحلة كان يسقط ليلًا): `clamp` وحدها كانت
  /// تُعيد الموعد **إلى الخلف** حين تتجاوز المهلة الدنيا ساعة الإغلاق. مثال:
  /// الساعة 20:40 والمهلة ساعة ⇒ 21:40، وبعد التقريب 22:00، فيُقصّ إلى 21:00
  /// وهو موعد **مرفوض** (أقل من المهلة) — فيفتح النموذج على وقت غير صالح ويرى
  /// المستخدم خطأً قبل أن يلمس شيئًا. الصواب: إن لم يبقَ متسع اليوم انتقل إلى
  /// الغد عند ساعة الفتح.
  DateTime _defaultSlot() {
    final DateTime earliest = DateTime.now().add(BookingRules.minimumLeadTime);
    DateTime day = DateTime(earliest.year, earliest.month, earliest.day);
    int minutes = ((earliest.hour * 60 + earliest.minute) ~/ 30 + 1) * 30;

    if (minutes + widget.durationMinutes > BookingRules.closeMinute) {
      // لا متسع اليوم لهذه المدة: أول موعد غدًا عند الفتح.
      day = day.add(const Duration(days: 1));
      minutes = BookingRules.openMinute;
    } else if (minutes < BookingRules.openMinute) {
      minutes = BookingRules.openMinute;
    }

    return DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime selected = DateTime(
      _day.year,
      _day.month,
      _day.day,
      _minutes ~/ 60,
      _minutes % 60,
    );
    final String? blocked = BookingRules.slotBlockReason(
      startsAt: selected,
      durationMinutes: widget.durationMinutes,
      now: DateTime.now(),
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.pageGutter,
        AppSpacing.md,
        AppSpacing.pageGutter,
        AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('اختر موعد الحصة', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'مدة الحصة ${BookingRules.durationLabel(widget.durationMinutes)} · '
              'المواعيد من '
              '${BookingRules.timeLabel(DateTime(2026, 1, 1, 8))} إلى '
              '${BookingRules.timeLabel(DateTime(2026, 1, 1, 22))}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _dayOptions.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.xxs),
                itemBuilder: (BuildContext context, int index) {
                  final DateTime day = _dayOptions[index];
                  final bool isSelected =
                      day.year == _day.year &&
                      day.month == _day.month &&
                      day.day == _day.day;
                  return PillChip(
                    label: BookingRules.dateLabel(day),
                    selected: isSelected,
                    onTap: () => setState(() => _day = day),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _slots.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.xxs),
                itemBuilder: (BuildContext context, int index) {
                  final int minutes = _slots[index];
                  return PillChip(
                    label: BookingRules.timeLabel(
                      DateTime(2026, 1, 1, minutes ~/ 60, minutes % 60),
                    ),
                    selected: minutes == _minutes,
                    onTap: () => setState(() => _minutes = minutes),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (blocked != null)
              Text(
                blocked,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: blocked != null
                  ? null
                  : () {
                      if (selected.isBefore(
                        DateTime.now().add(BookingRules.minimumLeadTime),
                      )) {
                        AppSnackBar.show(
                          context,
                          'اختر موعدًا بعد ${BookingRules.minimumLeadTime.inHours} ساعة على الأقل.',
                          type: AppMessageType.warning,
                        );
                        return;
                      }
                      Navigator.of(context).pop(selected);
                    },
              child: const Text('تأكيد الموعد'),
            ),
          ],
        ),
      ),
    );
  }
}
