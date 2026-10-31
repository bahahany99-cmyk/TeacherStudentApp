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
///
/// ## ثبات التخطيط (P18 — إصلاح «الفلاتر تختفي وتقفز»)
///
/// الشكوى كانت: اختيار «عن بُعد» يُخفي صف المحافظات كله، فيقفز صف
/// «تفريغ الفلاتر» وقائمة النتائج لأعلى، وتبدو الخيارات وكأنها «اختلّت».
/// السبب كان شرط عرض محسوبًا في البناء:
///
/// ```dart
/// showsGovernorates = governorates.isNotEmpty &&
///     (delivery != online || governorate != null);   // ← يحذف صفًا كاملًا
/// ```
///
/// الإصلاح بنيوي لا تجميلي: **ارتفاع الشريط ثابت في كل الحالات**. كل الخيارات
/// تبقى ظاهرة دائمًا، وتتغيّر صلاحيتها فقط:
///
/// | الحالة | صف المحافظات |
/// | --- | --- |
/// | «الكل» / «حضوري فقط» | حبات مفعّلة + «كل المحافظات» |
/// | «عن بُعد» | نفس الحبات **ظاهرة لكن غير مفعّلة** + تنبيه داخل الصف |
/// | قبل وصول المحافظات | سطر انتظار بنفس ارتفاع الحبة (لا قفزة عند الوصول) |
///
/// و«تفريغ الفلاتر» انتقل إلى **آخر صف طريقة التقديم** (صف أفقي قابل للتمرير)
/// بدل صف مستقل يظهر ويختفي — فظهوره لا يحرّك شيئًا رأسيًا.
class TeacherFilterBar extends StatefulWidget {
  const TeacherFilterBar({
    super.key,
    required this.filter,
    required this.governorates,
    required this.onChanged,
    this.governoratesLoading = false,
    this.governoratesFailed = false,
    this.onRetryGovernorates,
  });

  final TeacherFilter filter;

  /// المحافظات الموجودة فعلًا في البيانات (لا قائمة نظرية).
  final List<String> governorates;

  /// هل ما زالت قراءة المحافظات جارية؟ يُستخدم لعرض سطر انتظار **بنفس
  /// الارتفاع** بدل صف فارغ يقفز حين تصل البيانات.
  final bool governoratesLoading;

  /// (P29) فشل تحميل بيانات المدرسين — أي أن الصف **لا يعرف** المحافظات، ولا
  /// يجوز أن يقول «لا توجد محافظات مسجّلة بعد» (تلك معلومة عن البيانات، لا عن
  /// الشبكة). الفشل هنا يُعرض كحبة قابلة للضغط تُعيد المحاولة.
  final bool governoratesFailed;

  /// إعادة محاولة تحميل الخيارات (تُمرَّر من الشاشة).
  final VoidCallback? onRetryGovernorates;

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
    // إعادة بناء محلية فقط: أيقونة المسح تعتمد على وجود نص، ولو انتظرنا الأب
    // (الذي يتحدّث بعد المهلة) لما ظهرت الأيقونة أثناء الكتابة.
    setState(() {});
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
    // «تفريغ الفلاتر» أو أي تغيير خارجي للنص يجب أن يفرّغ الحقل أيضًا.
    if (widget.filter.query != oldWidget.filter.query &&
        widget.filter.query != _query.text) {
      _debounce?.cancel();
      _query.text = widget.filter.query;
      _query.selection = TextSelection.collapsed(
        offset: _query.text.length,
      );
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
    // أكثر الحالات، والسلوك المتوقع أن يتكيّف الشريط مع الاختيار. الصف لا
    // يُحذف (فلا قفزة) — خيارات المحافظة تبقى ظاهرة لكن غير مفعّلة.
    widget.onChanged(
      next == TeacherDeliveryFilter.online
          ? widget.filter.copyWith(delivery: next, governorate: null)
          : widget.filter.copyWith(delivery: next),
    );
  }

  /// حبة ثابتة (بلا فعل) بنفس ارتفاع بقية الحبات.
  ///
  /// الغرض: تشغل مكانًا مرئيًا بدل إخفاء الصف، فلا يقفز التخطيط عند تغيّر
  /// الحالة أو عند وصول البيانات.
  Widget _placeholderChip(String label, {IconData? icon}) {
    return PillChip(label: label, icon: icon);
  }

  Widget _governoratesRow(TeacherFilter filter) {
    final bool onlineOnly = filter.delivery == TeacherDeliveryFilter.online;

    // الترتيب مقصود: الفشل أولًا (لا نعرف)، ثم الانتظار، ثم «لا توجد» —
    // فالأخيرة **خبر عن البيانات** لا تُقال إلا بعد نجاح القراءة فعلًا.
    if (widget.governoratesFailed) {
      return PillRow(
        children: <Widget>[
          PillChip(
            key: const Key('governorates-failed'),
            label: 'تعذّر تحميل المحافظات — إعادة',
            icon: Icons.refresh,
            onTap: widget.onRetryGovernorates,
          ),
        ],
      );
    }

    if (widget.governorates.isEmpty) {
      return PillRow(
        children: <Widget>[
          widget.governoratesLoading
              ? _placeholderChip('جارٍ تحميل المحافظات…', icon: Icons.sync)
              : _placeholderChip(
                  'لا توجد محافظات مسجّلة بعد',
                  icon: Icons.map_outlined,
                ),
        ],
      );
    }

    return PillRow(
      children: <Widget>[
        // تنبيه **داخل الصف** لا فوقه: لا يزيد الارتفاع ولا يزيح شيئًا.
        // وهو قابل للضغط: نقرة تكفي للانتقال إلى «حضوري فقط».
        if (onlineOnly)
          PillChip(
            label: 'المحافظة تخصّ الحضوري',
            icon: Icons.info_outline,
            onTap: () => _setDelivery(TeacherDeliveryFilter.inPerson),
          ),
        PillChip(
          label: 'كل المحافظات',
          selected: filter.governorate == null,
          onTap: onlineOnly
              ? null
              : () => widget.onChanged(filter.copyWith(governorate: null)),
        ),
        for (final String governorate in widget.governorates)
          PillChip(
            label: governorate,
            selected: filter.governorate == governorate,
            // «عن بُعد» يجعل المحافظة غير ذات معنى: الحبة تبقى **ظاهرة** لكن
            // معطّلة، بدل أن تُحذف من الصف.
            onTap: onlineOnly
                ? null
                : () => widget.onChanged(
                    filter.copyWith(governorate: governorate),
                  ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final TeacherFilter filter = widget.filter;

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
            // «تفريغ الفلاتر» داخل صف أفقي (لا صف مستقل يظهر ويختفي)، فلا
            // يتحرك شيء رأسيًا عند تفعيل أول فلتر أو تفريغه.
            if (filter.isActive)
              PillChip(
                label: 'تفريغ الفلاتر',
                icon: Icons.filter_alt_off_outlined,
                onTap: () {
                  _debounce?.cancel();
                  _query.clear();
                  widget.onChanged(filter.cleared());
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // صف المحافظات: **موجود دائمًا** (بارتفاع ثابت) بعد اكتمال أو بدء
        // تحميل البيانات، فلا يقفز ما تحته عند تغيير طريقة التقديم.
        _governoratesRow(filter),
      ],
    );
  }
}
