import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';

/// التدرّجات اللونية الناعمة.
///
/// النسخة 4.2 (2026-10-27): **صفحة بيضاء صريحة**، وشريط بلاش قصير في أعلى
/// الشاشة فقط.
///
/// لماذا تغيّر البنية؟ في 4.1 كان البلاش متدرّجًا على ارتفاع الشاشة كلها؛
/// ومع أن الأبيض يبدأ عند 30% إلا أن التدرّج الطويل يجعل الوردي «يتسرّب» بصريًا
/// إلى ما وراء البطاقات، فتُقرأ الصفحة مصبوغة. القاعدة الآن صريحة ومحسوبة:
/// - طبقة سفلية **بيضاء صريحة** (`Colors.white`) على كامل الشاشة.
/// - شريط علوي بارتفاع **20% كحد أقصى** من الشاشة، ينتهي عند حافته السفلية
///   بأبيض صريح **معتم** ⇒ لا يوجد خط فاصل ولا تسرّب لون تحته إطلاقًا.
/// - ما تحت الشريط (80% من الشاشة) أبيض `#FFFFFF` لا غير.
///
/// القاعدة الحاكمة: **لا يُكتب تدرّج داخل شاشة**. كل خلفية أو سطح متدرّج يأتي
/// من هنا، حتى يبقى المظهر موحّدًا وقابلًا للتعديل من نقطة واحدة (A-44).
abstract final class AppGradients {
  /// شريط الحافة العلوية: بلاش ← أبيض صريح.
  ///
  /// يُرسم داخل شريط بارتفاع محدود ([AppBackground.blushHeightFactor]) لا
  /// على ارتفاع الشاشة، والمحطة الأخيرة **بيضاء معتمة** حتى يلتحم الشريط
  /// بالخلفية البيضاء بلا حافة مرئية.
  static const LinearGradient page = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      AppColors.blushTop,
      AppColors.blushSoft,
      Color(0xFFFFFFFF),
    ],
    stops: <double>[0.0, 0.48, 1.0],
  );

  /// نفس الشريط بمزاج خوخي دافئ (صفحات الحساب/الملف الشخصي).
  /// الفرق «مزاج» لا «لون»: كلاهما ينتهي بالأبيض الصريح.
  static const LinearGradient pageWarm = LinearGradient(
    begin: AlignmentDirectional.topEnd,
    end: AlignmentDirectional.bottomStart,
    colors: <Color>[
      AppColors.blushTop,
      AppColors.washPeach,
      Color(0xFFFFFFFF),
    ],
    stops: <double>[0.0, 0.45, 1.0],
  );

  /// سطح «لمعة» للبطاقات التمهيدية (بديل الكتلة المشبعة).
  ///
  /// أبيض في معظمه مع لمسة وردية في الركن العلوي — يُستخدم مع نص داكن،
  /// فلا حاجة لقيم تباين خاصة.
  static const LinearGradient glow = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: <Color>[
      AppColors.blushSoft,
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
    ],
    stops: <double>[0.0, 0.42, 1.0],
  );

  /// التدرّج الوحيد المشبع — محصور في شعار صغير (84 نقطة) على شاشة الدخول.
  static const LinearGradient hero = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: <Color>[AppColors.heroFrom, AppColors.heroTo],
  );

  /// تدرّج شفاف للون واحد — للشرائح المختارة.
  static LinearGradient tint(Color color) {
    return LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: <Color>[color.withAlpha(30), color.withAlpha(10)],
    );
  }
}

/// الظلال.
///
/// مواصفة صاحب المشروع (2026-10-27) — ظلان بالضبط، لا أكثر:
/// 1. ظل قريب: `black 4%` · blur 8 · offset (0, 2).
/// 2. ظل محيطي بعيد: `black 6%` · blur 24 · offset (0, 12).
///
/// الحساب بالنسب: 4% = `withAlpha(10)`، 6% = `withAlpha(15)`.
/// سبب التقارب القصير/البعيد: القريب يحدّ الحافة، والبعيد يعطي الطفو؛ ظل واحد
/// قوي يبدو ثقيلًا و«مسطّحًا» على شاشات OLED.
abstract final class AppShadows {
  /// ظل البطاقة القياسي (المطلوب حرفيًا).
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x0A000000), // أسود 4%
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0F000000), // أسود 6%
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  /// نفس النمط بقوة أعلى قليلًا — للبطاقات المختارة/المهمة فقط.
  static const List<BoxShadow> cardLifted = <BoxShadow>[
    BoxShadow(
      color: Color(0x14000000), // أسود 8%
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
    BoxShadow(
      color: Color(0x1A000000), // أسود 10%
      blurRadius: 30,
      offset: Offset(0, 16),
    ),
  ];

  /// ظل ملطّف للشريحة العائمة (أخف من البطاقة).
  static const List<BoxShadow> pill = <BoxShadow>[
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  /// ظل الشعار الملوّن (يُستخدم مرة واحدة على شاشة الدخول).
  static const List<BoxShadow> hero = <BoxShadow>[
    BoxShadow(
      color: Color(0x2E9E4C6C),
      blurRadius: 26,
      offset: Offset(0, 12),
      spreadRadius: -8,
    ),
  ];
}

/// الحدود الشعرية.
///
/// الحد الأبيض الشفاف هو ما يجعل البطاقة تبدو «زجاجية/عائمة» على خلفية ملونة،
/// بينما حد رمادي يجعلها تبدو صندوقًا مرسومًا. القيمة 0.8 مواصفة صاحب المشروع.
abstract final class AppBorders {
  static const double hairlineWidth = 1.2;

  /// حد أبيض شفاف على أسطح بيضاء (بطاقات على خلفية ملوّنة).
  static const Color onWhite = Color(0xCCFFFFFF); // أبيض 80%

  /// حد أخف على الأسطح المصبوغة بلون الهوية.
  static const Color onTint = Color(0x66FFFFFF); // أبيض 40%

  static Border side(Color color) => Border.all(
    color: color,
    width: hairlineWidth,
  );
}
