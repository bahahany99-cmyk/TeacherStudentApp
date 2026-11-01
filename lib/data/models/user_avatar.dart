import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:teacher_student_app/data/models/user_role.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';

/// صور الحساب (P22): صورة مخصّصة رفعها المستخدم، أو صورة افتراضية مرسومة.
///
/// ## لماذا تخزين في Firestore لا في Storage؟
///
/// المشروع لا يستخدم Firebase Storage (لا حزمة ولا قواعد Storage)، وإضافة
/// مسار تخزين كامل لا يمكن اختباره في هذا المستودع (المحاكي هنا Firestore
/// فقط) كان سيعني ميزة **غير مُختبرة** بدل ميزة مُختبرة. فالخيار المتعمّد:
///
/// - الصورة تُصغَّر وتُضغط **على الجهاز** (`image_picker` بـ`maxWidth` و
///   `imageQuality`) قبل الرفع، فلا تُخزَّن صور كاميرات 4MB.
/// - تُحفظ base64 في مستند مستقل `avatars/{uid}` — **لا** في `users/{uid}`
///   ولا في `teacherProfiles/{uid}`: تلك مستندات تُقرأ في كل تسجيل دخول وفي
///   كل نتيجة بحث، ووضع ~30KB في كل واحد منها يضخّم كل استعلام.
/// - القواعد تفرض سقف الحجم (`maxBase64Length`) ونوع الصورة، فالرفض يحدث على
///   الخادم لا بالاتفاق.
///
/// ## ما لا يقدّمه هذا المسار (بصراحة)
///
/// لا CDN ولا تحسين تلقائي ولا صور بأحجام متعددة. لعشرات الآلاف من المستخدمين
/// يصبح Storage هو الخيار الصحيح، والانتقال إليه لا يغيّر الواجهة: كل الشاشات
/// تقرأ عبر [AvatarRepository] لا من Firestore مباشرة.
class UserAvatar {
  const UserAvatar({
    required this.ownerId,
    this.imageBase64,
    this.mimeType,
    this.presetId,
    this.updatedAt,
  });

  /// صاحب الصورة — معرّف المستخدم (`uid`).
  final String ownerId;

  /// بايتات الصورة مُرمَّزة base64 (`null` = لا صورة مخصّصة).
  final String? imageBase64;

  /// نوع الصورة ('image/jpeg' أو 'image/png').
  final String? mimeType;

  /// معرّف الصورة الافتراضية المرسومة (يُثبَّت عند أول دخول).
  final int? presetId;

  final DateTime? updatedAt;

  /// هل يملك صاحبها صورة مخصّصة صالحة للعرض؟
  bool get hasCustomPhoto {
    final String? data = imageBase64;
    return data != null && data.isNotEmpty;
  }

  /// بايتات الصورة جاهزة للعرض (`null` إن لم توجد أو كانت تالفة).
  ///
  /// الترميز التالف لا يُسقط الشاشة: نعيد `null` فتظهر الصورة الافتراضية.
  /// صورة مكسورة في الشاشة أسوأ من صورة افتراضية سليمة.
  Uint8List? get bytes {
    final String? data = imageBase64;
    if (data == null || data.isEmpty) {
      return null;
    }
    try {
      return base64Decode(data);
    } on FormatException {
      return null;
    }
  }

  /// الصورة الافتراضية المستخدمة عند غياب الصورة المخصّصة.
  int get resolvedPresetId => presetId ?? AvatarPresets.forId(ownerId);

  /// نسخة بصورة رمزية مختارة (بلا حاجة لإعادة قراءة المستند كاملًا).
  UserAvatar withPreset(int preset) {
    return UserAvatar(
      ownerId: ownerId,
      imageBase64: imageBase64,
      mimeType: mimeType,
      presetId: preset,
      updatedAt: updatedAt,
    );
  }

  /// نسخة بصورة مخصّصة جديدة (بلا حاجة لإعادة قراءة المستند كاملًا).
  UserAvatar withImage({
    required String imageBase64,
    required String mimeType,
    DateTime? updatedAt,
  }) {
    return UserAvatar(
      ownerId: ownerId,
      imageBase64: imageBase64,
      mimeType: mimeType,
      presetId: presetId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// فئة الصورة الرمزية — توزيع المعرض بالتساوي (P31): أربع صور لكل فئة.
enum AvatarCategory {
  boyChild('أولاد أطفال'),
  girlChild('بنات أطفال'),
  boyTeen('أولاد مراهقون'),
  girlTeen('بنات مراهقات'),
  youngMan('شباب'),
  youngWoman('شابات'),
  adultMan('رجال بالغون'),
  adultWoman('نساء بالغات'),
  olderMan('رجال كبار السن'),
  olderWoman('نساء كبيرات السن');

  const AvatarCategory(this.label);

  /// عنوان القسم في المعرض (عربي، بلا رموز تقنية).
  final String label;
}

/// لمن تُخصَّص الحصيلة التلقائية عند التسجيل (P31).
///
/// **لماذا هذا التصنيف؟** لأن التطبيق يعرف **الدور** فقط عند إنشاء الحساب (ولا
/// يعرف العمر ولا الجنس، ولا يجوز أن يسألهما). لذلك لا يجوز سحب صورة عشوائية
/// من المعرض كله: طفل/طفلة لمدرّس غير مناسب، ومظهر مسنّ لطالب في العاشرة غير
/// مناسب أيضًا. هذا التصنيف يحصر الاختيار في نطاق **مناسب للمعلومة المتاحة**،
/// وعند غياب المعلومة تُستخدم فئة محايدة (بالغون).
enum AvatarAudience {
  /// طالب: أطفال ومراهقون وشباب — لا كبار سن.
  student('طالب'),

  /// مدرّس: بالغون وكبار سن — لا أطفال ولا مراهقون.
  teacher('مدرّس'),

  /// معلومة غير كافية: صور محايدة من فئة البالغين.
  unspecified('غير محدّد');

  const AvatarAudience(this.label);

  final String label;
}

/// صورة رمزية واحدة من المعرض المضمَّن.
class AvatarArtwork {
  const AvatarArtwork({
    required this.id,
    required this.category,
    required this.asset,
    required this.description,
    required this.tint,
  });

  /// المعرّف المحفوظ في `avatarPreset` (0..29) — لا يتغيّر بعد النشر.
  final int id;

  final AvatarCategory category;

  /// مسار الأصل المضمَّن داخل التطبيق (يعمل بلا إنترنت).
  final String asset;

  /// وصف قصير يُقرأ لقارئ الشاشة.
  final String description;

  /// لون هادئ مشتق من خلفية الرسم — يُستخدم للهالة/الإطار فقط.
  final int tint;
}

/// كتالوج الصور الرمزية المضمَّنة (P31).
///
/// **ما تغيّر عن P22؟** كانت الصور الافتراضية ستة **تدرّجات مرسومة** بداخلها
/// حرفان. الآن هي **30 صورة كرتونية فعلية** مضمَّنة في `assets/avatars/`،
/// موزّعة بالتساوي على عشر فئات (أطفال، مراهقون، شباب، بالغون، كبار سن ×
/// ذكور/إناث)، بأسلوب بصري واحد وخلفيات دائرية هادئة.
///
/// **لماذا أصول مضمَّنة لا شبكة؟** ليبقى اختيار الصورة متاحًا بلا اتصال، ولأن
/// طلب «الصورة الافتراضية ليست فارغة أبدًا» يجب أن يظل صحيحًا على جهاز بلا
/// شبكة. الملفات مضغوطة (‎256×256 JPEG‎ ≈ 9–13KB) فمجموعها ≈0.38MB.
///
/// **ثبات المعرّفات (قرار ملزم):** `all[i].id == i`، والصور الجديدة تُضاف في
/// **نهاية** القائمة دائمًا. المعرّفات 0..23 لم تتغيّر عند توسيع المعرض من 24
/// إلى 30، فلا تتغيّر صورة أي مستخدم اختار رمزية سابقًا. **لا يُعاد ترتيب
/// القائمة ولا تُحذف صورة** بعد النشر.
///
/// **التوافق مع الحسابات القديمة:** المعرّف المخزَّن يظل رقمًا في `avatarPreset`
/// (0..29). القيم القديمة 0..5 تبقى صالحة وتُعرض بالرسم الجديد نفسه (المعرّف
/// لم يتغيّر، تغيّر شكل الصورة) — لا ترحيل بيانات ولا كتابة إجبارية.
abstract final class AvatarPresets {
  /// عدد الصور المتاحة (10 فئات × 3).
  static const int count = 30;

  /// صور كل فئة — ثلاث لكل فئة، بالتساوي.
  static const int perCategory = 3;

  /// عدد الصور **القديمة** التي كانت موجودة قبل توسيع المعرض إلى 30 (P31).
  ///
  /// **لماذا ثابت مستقل؟** لأن `forId` هي الاحتياط الحتمي للحسابات التي لا تحمل
  /// `avatarPreset` إطلاقًا. لو غيّرنا باقي القسمة من 24 إلى 30 لتغيّرت صورة
  /// **كل** حساب قديم من هذه الفئة بلا أن يطلب — وهو ما نرفضه. فالسقف هنا
  /// يبقى 24، وأي صورة جديدة لا تدخل في الاحتياط الحتمي.
  static const int legacyDeterministicCount = 24;

  /// صورة **محايدة تمامًا** تُعرض في دائرة المعاينة قبل أن يختار المستخدم.
  ///
  /// **لماذا وصف صامت لا صورة من الثلاثين؟** لأن عرض إحدى الصور الثلاثين
  /// سيجعلها تبدو وكأنها اختيار مسبق (أو تعيين تلقائي)، وهو ما تمنعه شاشة
  /// الاختيار الإلزامية. هذه صورة رمزية بحتة: بلا جنس ولا عمر (رأس وكتفان
  /// بلا ملامح) على خلفية هادئة من ألوان التطبيق، ولا تُحفظ أبدًا باعتبارها
  /// `avatarPreset` — الملف خارج كتالوج الثلاثين (`assets/images/`)، فهو غير
  /// قابل للاختيار أساسًا لأن الاختيار يتم بمعرّف من [all] فقط.
  static const String neutralPlaceholderAsset =
      'assets/images/avatar_placeholder.jpg';

  /// الكتالوج كاملًا، مرتّبًا بترتيب الفئات أعلاه ثم بترتيب الصور داخلها.
  ///
  /// **الترتيب هو العقد**: `id` يساوي موضع الصورة في هذه القائمة، فلا يُعاد
  /// ترتيب القائمة بعد النشر وإلا تغيّرت صورة كل مستخدم اختار رمزية.
  static const List<AvatarArtwork> all = <AvatarArtwork>[
    // ── أولاد أطفال (0..2) ───────────────────────────────────────────────────
    AvatarArtwork(
      id: 0,
      category: AvatarCategory.boyChild,
      asset: 'assets/avatars/boy_01.jpg',
      description: 'ولد بشعر أسود مجعّد وقميص أصفر',
      tint: AppColors.avatarMint,
    ),
    AvatarArtwork(
      id: 1,
      category: AvatarCategory.boyChild,
      asset: 'assets/avatars/boy_02.jpg',
      description: 'ولد بشعر بني فاتح وقميص أزرق',
      tint: AppColors.avatarLilac,
    ),
    AvatarArtwork(
      id: 2,
      category: AvatarCategory.boyChild,
      asset: 'assets/avatars/boy_03.jpg',
      description: 'ولد ببشرة داكنة وقميص مخطط أخضر',
      tint: AppColors.avatarSand,
    ),
    AvatarArtwork(
      id: 3,
      category: AvatarCategory.boyTeen,
      asset: 'assets/avatars/boy_04.jpg',
      description: 'مراهق بنظارة وهودي أحمر',
      tint: AppColors.avatarSky,
    ),
    // ── بنات أطفال (4..6) ────────────────────────────────────────────────────
    AvatarArtwork(
      id: 4,
      category: AvatarCategory.girlChild,
      asset: 'assets/avatars/girl_01.jpg',
      description: 'بنت بشعر مموّج طويل ومشبك وردي',
      tint: AppColors.avatarMint,
    ),
    AvatarArtwork(
      id: 5,
      category: AvatarCategory.girlChild,
      asset: 'assets/avatars/girl_02.jpg',
      description: 'بنت بضفيرتين كرويتين وقميص بنفسجي',
      tint: AppColors.avatarSand,
    ),
    AvatarArtwork(
      id: 6,
      category: AvatarCategory.girlChild,
      asset: 'assets/avatars/girl_03.jpg',
      description: 'بنت بذيل حصان وسويتر فيروزي',
      tint: AppColors.avatarCream,
    ),
    AvatarArtwork(
      id: 7,
      category: AvatarCategory.girlTeen,
      asset: 'assets/avatars/girl_04.jpg',
      description: 'مراهقة بشعر كاريه كستنائي وفستان أصفر',
      tint: AppColors.avatarLilac,
    ),
    // ── شباب (8..10) ─────────────────────────────────────────────────────────
    AvatarArtwork(
      id: 8,
      category: AvatarCategory.youngMan,
      asset: 'assets/avatars/man_01.jpg',
      description: 'شاب بشعر قصير وقميص كحلي',
      tint: AppColors.avatarMint,
    ),
    AvatarArtwork(
      id: 9,
      category: AvatarCategory.youngMan,
      asset: 'assets/avatars/man_02.jpg',
      description: 'شاب بشعر مجعّد ولحية قصيرة وسويتر رمادي',
      tint: AppColors.avatarSand,
    ),
    AvatarArtwork(
      id: 10,
      category: AvatarCategory.youngMan,
      asset: 'assets/avatars/man_03.jpg',
      description: 'شاب بشعر مموّج مربوط ونظارة رقيقة',
      tint: AppColors.avatarCream,
    ),
    AvatarArtwork(
      id: 11,
      category: AvatarCategory.adultMan,
      asset: 'assets/avatars/man_04.jpg',
      description: 'رجل بالغ بقميص قطني أخضر داكن',
      tint: AppColors.avatarSky,
    ),
    // ── شابات (12..14) ───────────────────────────────────────────────────────
    AvatarArtwork(
      id: 12,
      category: AvatarCategory.youngWoman,
      asset: 'assets/avatars/woman_01.jpg',
      description: 'شابة بشعر طويل مستقيم وبلوزة وردية',
      tint: AppColors.avatarMint,
    ),
    AvatarArtwork(
      id: 13,
      category: AvatarCategory.youngWoman,
      asset: 'assets/avatars/woman_02.jpg',
      description: 'شابة بحجاب بلون هادئ وسترة كريمية',
      tint: AppColors.avatarLilac,
    ),
    AvatarArtwork(
      id: 14,
      category: AvatarCategory.youngWoman,
      asset: 'assets/avatars/woman_03.jpg',
      description: 'شابة بشعر مجعّد وقميص سماوي',
      tint: AppColors.avatarSand,
    ),
    AvatarArtwork(
      id: 15,
      category: AvatarCategory.adultWoman,
      asset: 'assets/avatars/woman_04.jpg',
      description: 'امرأة بالغة بكعكة شعر عالية وبليزر رمادي',
      tint: AppColors.avatarCream,
    ),
    // ── رجال كبار السن (16..18) ──────────────────────────────────────────────
    AvatarArtwork(
      id: 16,
      category: AvatarCategory.olderMan,
      asset: 'assets/avatars/elder_man_01.jpg',
      description: 'رجل كبير السن بشعر أبيض ولحية خفيفة وقميص أزرق',
      tint: AppColors.avatarMint,
    ),
    AvatarArtwork(
      id: 17,
      category: AvatarCategory.olderMan,
      asset: 'assets/avatars/elder_man_02.jpg',
      description: 'رجل كبير السن بنظارة وشعر رمادي وقميص بيج',
      tint: AppColors.avatarSand,
    ),
    AvatarArtwork(
      id: 18,
      category: AvatarCategory.olderMan,
      asset: 'assets/avatars/elder_man_03.jpg',
      description: 'رجل كبير السن ببشرة داكنة وسترة رمادية',
      tint: AppColors.avatarLilac,
    ),
    AvatarArtwork(
      id: 19,
      category: AvatarCategory.adultMan,
      asset: 'assets/avatars/elder_man_04.jpg',
      description: 'رجل بالغ بشعر خفيف وقميص عنّابي',
      tint: AppColors.avatarSky,
    ),
    // ── نساء كبيرات السن (20..22) ────────────────────────────────────────────
    AvatarArtwork(
      id: 20,
      category: AvatarCategory.olderWoman,
      asset: 'assets/avatars/elder_woman_01.jpg',
      description: 'سيدة كبيرة السن بشعر فضي قصير وسترة خضراء',
      tint: AppColors.avatarMint,
    ),
    AvatarArtwork(
      id: 21,
      category: AvatarCategory.olderWoman,
      asset: 'assets/avatars/elder_woman_02.jpg',
      description: 'سيدة كبيرة السن بحجاب رمادي ونظارة',
      tint: AppColors.avatarLilac,
    ),
    AvatarArtwork(
      id: 22,
      category: AvatarCategory.olderWoman,
      asset: 'assets/avatars/elder_woman_03.jpg',
      description: 'سيدة كبيرة السن بشعر مجعّد فضي وسترة زرقاء',
      tint: AppColors.avatarSand,
    ),
    AvatarArtwork(
      id: 23,
      category: AvatarCategory.adultWoman,
      asset: 'assets/avatars/elder_woman_04.jpg',
      description: 'امرأة بالغة بحجاب وردي هادئ وعباءة بيج',
      tint: AppColors.avatarCream,
    ),
    // ── (P31-توسيع) الصور الست الجديدة: 24..29 ───────────────────────────────
    // تُضاف **بعد** المعرّفات القديمة دائمًا، فمعرّف كل صورة قائمة لا يتغيّر
    // ولا تتغيّر صورة أي مستخدم اختارها سابقًا.
    AvatarArtwork(
      id: 24,
      category: AvatarCategory.boyTeen,
      asset: 'assets/avatars/teen_boy_01.jpg',
      description: 'مراهق بشعر أسود كثيف وهودي رمادي',
      tint: AppColors.avatarMint,
    ),
    AvatarArtwork(
      id: 25,
      category: AvatarCategory.boyTeen,
      asset: 'assets/avatars/teen_boy_02.jpg',
      description: 'مراهق بشعر بني مموّج ونظارة وقميص زيتي',
      tint: AppColors.avatarLilac,
    ),
    AvatarArtwork(
      id: 26,
      category: AvatarCategory.girlTeen,
      asset: 'assets/avatars/teen_girl_01.jpg',
      description: 'مراهقة بشعر أسود مستقيم وبلوزة نعناعية',
      tint: AppColors.avatarSand,
    ),
    AvatarArtwork(
      id: 27,
      category: AvatarCategory.girlTeen,
      asset: 'assets/avatars/teen_girl_02.jpg',
      description: 'مراهقة بضفيرة بنية وجاكيت جينز',
      tint: AppColors.avatarCream,
    ),
    AvatarArtwork(
      id: 28,
      category: AvatarCategory.adultMan,
      asset: 'assets/avatars/adult_man_01.jpg',
      description: 'رجل بالغ بلحية قصيرة وبليزر كحلي',
      tint: AppColors.avatarSky,
    ),
    AvatarArtwork(
      id: 29,
      category: AvatarCategory.adultWoman,
      asset: 'assets/avatars/adult_woman_01.jpg',
      description: 'امرأة بالغة بشعر مموّج وبلوزة فيروزية',
      tint: AppColors.avatarLilac,
    ),
  ];

  /// صور فئة بعينها (بترتيب المعرض).
  static List<AvatarArtwork> ofCategory(AvatarCategory category) {
    return <AvatarArtwork>[
      for (final AvatarArtwork artwork in all)
        if (artwork.category == category) artwork,
    ];
  }

  /// الصورة ذات المعرّف (مع تطبيع القيم القديمة/الخارجة).
  static AvatarArtwork artworkOf(int? id, {String ownerId = ''}) {
    return all[normalize(id, ownerId)];
  }

  /// ألوان بديلة تُستخدم فقط إذا تعذّر تحميل ملف الأصل (ملف تالف/ناقص).
  ///
  /// **لماذا نُبقي بديلًا أصلًا؟** لأن صورة حساب مكسورة في قائمة محادثات أسوأ
  /// من دائرة ملوّنة بحرفين؛ البديل يضمن ألا تكون الصورة فارغة أبدًا.
  static const List<(int, int)> fallbackGradients = <(int, int)>[
    (0xFF6C5CE7, 0xFFA29BFE),
    (0xFF32406B, 0xFF8C9BC9),
    (0xFFB04A5E, 0xFFE39AA6),
    (0xFF4A6C8C, 0xFF90AFC5),
    (0xFFA9762F, 0xFFE0BC7C),
    (0xFF5D4E8C, 0xFFB0A6D6),
  ];

  /// صورة رمزية **عشوائية** تُعيَّن للحساب الجديد (P31).
  ///
  /// **لماذا لا [forId] وحدها؟** لأن `forId` حتمية من المعرّف: توزيعها جيد لكنها
  /// ليست «اختيارًا عند الإنشاء»، وكان مطلوبًا تعيين صورة عشوائية **تُحفظ** في
  /// بيانات المستخدم فتبقى كما هي.
  ///
  /// **التوزيع:** البذرة تخلط `uid` مع [entropy] (قيمة عشوائية تُقرأ مرة واحدة
  /// عند الإنشاء)، فالنتيجة شبه عشوائية ومتوزّعة على حصيلة [audience] بأقرب ما
  /// يمكن: خوارزمية `Random` موحّدة، ولا مجموعة عالمية تُدار ولا عدّاد مركزي.
  /// تكرار الصورة بين حسابين أمر متوقع (طلب صريح بألّا نفرض ضمانًا عالميًا
  /// لعدم التكرار)، ولا أثر لذلك على أي منطق.
  ///
  /// **[audience]** يمنع سحب صورة من فئة غير مناسبة (طفل لمدرّس مثلًا).
  ///
  /// **لماذا تُمرَّر [entropy]؟** لتكون الدالة **قابلة للاختبار** بحتمية كاملة:
  /// نفس البذرة ⇒ نفس النتيجة، ومدى مختلف من البذور ⇒ تغطية كل الصور.
  static int randomIndexFor(
    String uid, {
    int? entropy,
    AvatarAudience audience = AvatarAudience.unspecified,
  }) {
    final List<int> pool = assignmentPool(audience);
    if (pool.isEmpty) {
      return 0;
    }
    int mixed = 0x811c9dc5; // FNV-1a 32-bit
    for (final int unit in uid.codeUnits) {
      mixed ^= unit;
      mixed = (mixed * 0x01000193) & 0x7fffffff;
    }
    final int salt = entropy ?? Random.secure().nextInt(1 << 31);
    mixed = (mixed ^ salt) & 0x7fffffff;
    return pool[Random(mixed).nextInt(pool.length)];
  }

  /// الفئات التي يجوز السحب منها تلقائيًا لكل جمهور.
  ///
  /// **قاعدة صريحة:** لا تُسحب صورة طفل/مراهق لمدرّس، ولا صورة مسنّ لطالب.
  /// الدور هو المعلومة الوحيدة المتاحة عند التسجيل، وهي كافية لاستبعاد ما لا
  /// يناسب. وعند غياب الدور ([AvatarAudience.unspecified]) النطاق **محايد**:
  /// بالغون فقط، فهم صالحون لأي معلومة ناقصة.
  static const Map<AvatarAudience, List<AvatarCategory>> assignmentCategories =
      <AvatarAudience, List<AvatarCategory>>{
        AvatarAudience.student: <AvatarCategory>[
          AvatarCategory.boyChild,
          AvatarCategory.girlChild,
          AvatarCategory.boyTeen,
          AvatarCategory.girlTeen,
          AvatarCategory.youngMan,
          AvatarCategory.youngWoman,
        ],
        AvatarAudience.teacher: <AvatarCategory>[
          AvatarCategory.adultMan,
          AvatarCategory.adultWoman,
          AvatarCategory.olderMan,
          AvatarCategory.olderWoman,
        ],
        AvatarAudience.unspecified: <AvatarCategory>[
          AvatarCategory.adultMan,
          AvatarCategory.adultWoman,
        ],
      };

  /// يترجم دور المستخدم إلى جمهور التعيين.
  ///
  /// **مكانه هنا** لا في الخدمة: قاعدة «من يستحق أي صور» قاعدة بيانات عرض،
  /// ووجودها في الكيان يجعلها قابلة للاختبار مباشرة بلا Firebase. ولا تُسأل عن
  /// العمر ولا الجنس — الدور المعلوم وحده يكفي.
  static AvatarAudience audienceForRole(UserRole? role) {
    return switch (role) {
      UserRole.teacher => AvatarAudience.teacher,
      UserRole.student => AvatarAudience.student,
      _ => AvatarAudience.unspecified,
    };
  }

  /// كل معرّفات الصور المسموح بها لجمهور بعينه (بترتيب الكتالوج).
  static List<int> assignmentPool(AvatarAudience audience) {
    final List<AvatarCategory> categories =
        assignmentCategories[audience] ?? const <AvatarCategory>[];
    return <int>[
      for (final AvatarArtwork artwork in all)
        if (categories.contains(artwork.category)) artwork.id,
    ];
  }

  /// معرّف الصورة الافتراضية **الحتمي** من معرّف المستخدم.
  ///
  /// الحتمية مقصودة: نفس المستخدم يرى نفس الصورة على كل جهاز وقبل أن يُكتب
  /// أي مستند، فلا «تتغيّر صورته» عند إعادة تثبيت أو تسجيل دخول.
  ///
  /// **الباقي ثابت على [legacyDeterministicCount] (24) وليس [count]:** توسيع
  /// المعرض إلى 30 يجب ألّا يغيّر صورة أي حساب قديم بلا `avatarPreset`.
  static int forId(String id) {
    if (id.isEmpty) {
      return 0;
    }
    int hash = 0;
    for (final int unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash % legacyDeterministicCount;
  }

  /// تطبيع معرّف قادم من الخادم (قد يكون `null` أو خارج المدى).
  static int normalize(int? raw, String id) {
    if (raw == null || raw < 0 || raw >= count) {
      return forId(id);
    }
    return raw;
  }
}

/// أولوية الصورة المعروضة (P31) — **مصدر واحد** لكل الشاشات.
///
/// 1. الصورة المرفوعة إن كانت موجودة **وصالحة** (base64 يفكّ إلى بايتات).
/// 2. الصورة الرمزية التي اختارها المستخدم (`avatarPreset`).
/// 3. صورة رمزية افتراضية حتمية من المعرّف.
///
/// كانت الشاشات قبل P31 تختار بين (1) و(3) فقط، فالطالب الذي اختار رمزية كان
/// يراها في بطاقة حسابه ولا يراها في المحادثات وبطاقات المجموعات. الآن كل من
/// يعرض صورة يمرّ من هنا: [UserAvatarView] و[UserAvatarLoader] هما التنفيذ
/// الوحيد، ولا يوجد مكان يبني صورة حساب بمنطق مختلف.
class AvatarResolution {
  const AvatarResolution({required this.presetId, required this.bytes});

  /// الصورة الرمزية المعروضة (بعد التطبيع).
  final int presetId;

  /// بايتات الصورة المرفوعة إن كانت صالحة — وإلا `null`.
  final Uint8List? bytes;

  /// هل المعروض صورة مرفوعة؟
  bool get isUploaded => bytes != null;

  /// المسار المضمَّن للصورة الرمزية المعروضة.
  String get asset => AvatarPresets.all[presetId].asset;

  /// يحسم الأولوية من (معرّف المستخدم، مستنده إن وُجد).
  ///
  /// لا يقرأ شيئًا ولا يعرف الشبكة: دالة نقية قابلة للاختبار مباشرة.
  static AvatarResolution resolve({
    required String ownerId,
    UserAvatar? avatar,
    int? chosenPreset,
  }) {
    final Uint8List? valid = avatar?.bytes;
    final int preset = AvatarPresets.normalize(
      avatar?.presetId ?? chosenPreset,
      ownerId,
    );
    return AvatarResolution(presetId: preset, bytes: valid);
  }
}

/// حدود الصورة — **مصدر واحد** للواجهة والقواعد.
///
/// (P31) الصورة تُقصّ في التطبيق إلى 512×512 ثم تُرمَّز JPEG بسلّم جودة، فيبقى
/// الناتج المعتاد 40–80KB؛ والسقف هنا للحالات الشاذة، وتفرضه القواعد أيضًا
/// (`imageBase64.size() <= 200000`).
abstract final class AvatarLimits {
  /// أقصى طول لنص base64 المحفوظ (≈ 150KB صورة).
  static const int maxBase64Length = 200000;

  /// أقصى أبعاد يطلبها المختار من المنصّة، ودقة تصدير القصّ.
  static const int pickMaxDimension = 512;

  /// جودة الضغط المطلوبة من المنصّة (0–100).
  static const int pickQuality = 80;

  /// أنواع الصور المقبولة (القواعد تتحقق من نفس القيمتين).
  static const List<String> mimeTypes = <String>['image/jpeg', 'image/png'];
}
