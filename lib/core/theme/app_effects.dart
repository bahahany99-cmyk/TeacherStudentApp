import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';

/// التدرّجات اللونية الناعمة.
///
/// القاعدة: **لا تُكتب تدرّجات داخل الشاشات**. أي شاشة تحتاج خلفية أو سطحًا
/// متدرّجًا تطلب واحدًا من هنا، حتى يبقى المظهر موحّدًا ويسهل تغييره من مكان
/// واحد (A-43).
///
/// مبدأ التصميم: التدرّجات في هذه النسخة **باهتة جدًا** (فرق لون قليل بين
/// الأطراف). الغرض إحساس بالعمق لا زخرفة؛ وأي لون قوي هنا سيصعب قراءة النص.
abstract final class AppGradients {
  /// خلفية الصفحات: نعناعي باهت ← أبيض ← لافندر/وردي باهت.
  ///
  /// تُرسم خلف محتوى الشاشة، وكل البطاقات فوقها بلون أبيض صريح.
  static const LinearGradient page = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      AppColors.mistMint,
      Color(0xFFFFFFFF),
      AppColors.mistLavender,
    ],
    stops: <double>[0.0, 0.42, 1.0],
  );

  /// خلفية بديلة أدفأ (صفحات الحساب/الملف الشخصي).
  static const LinearGradient pageWarm = LinearGradient(
    begin: AlignmentDirectional.topEnd,
    end: AlignmentDirectional.bottomStart,
    colors: <Color>[
      AppColors.mistBlush,
      Color(0xFFFFFFFF),
      AppColors.mistMint,
    ],
    stops: <double>[0.0, 0.5, 1.0],
  );

  /// سطح البطاقة المميّزة (Hero) — التدرّج الوحيد المشبع في النظام.
  static const LinearGradient hero = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: <Color>[AppColors.heroFrom, AppColors.heroTo],
  );

  /// تدرّج شفاف للون واحد — يُستخدم للفلاتر المختارة والشرائح النشطة.
  static LinearGradient tint(Color color) {
    return LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: <Color>[color.withAlpha(38), color.withAlpha(14)],
    );
  }
}

/// الظلال.
///
/// نستخدم ظلين رقيقين بدل ظل واحد قوي: الأول قريب يحدّ الحافة، والثاني بعيد
/// ناعم يعطي إحساس «الطفو» الموجود في المرجع. الظل الواحد القوي يبدو ثقيلًا
/// على شاشات OLED.
abstract final class AppShadows {
  /// بطاقة عائمة عادية.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F0E1F1B),
      blurRadius: 24,
      offset: Offset(0, 10),
      spreadRadius: -4,
    ),
    BoxShadow(color: Color(0x0A0E1F1B), blurRadius: 4, offset: Offset(0, 2)),
  ];

  /// بطاقة مرفوعة (مختارة/مهمة).
  static const List<BoxShadow> cardLifted = <BoxShadow>[
    BoxShadow(
      color: Color(0x1F0E7C66),
      blurRadius: 30,
      offset: Offset(0, 14),
      spreadRadius: -6,
    ),
    BoxShadow(color: Color(0x0D0E1F1B), blurRadius: 6, offset: Offset(0, 3)),
  ];

  /// ظل البطاقة المميّزة (ملوّن بلون الهوية).
  static const List<BoxShadow> hero = <BoxShadow>[
    BoxShadow(
      color: Color(0x33107A63),
      blurRadius: 28,
      offset: Offset(0, 14),
      spreadRadius: -8,
    ),
  ];
}
