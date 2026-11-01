import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

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
  boy('أولاد صغار'),
  girl('بنات صغيرات'),
  youngMan('شباب'),
  youngWoman('شابات'),
  olderMan('رجال أكبر سنًا'),
  olderWoman('سيدات أكبر سنًا');

  const AvatarCategory(this.label);

  /// عنوان القسم في المعرض (عربي، بلا رموز تقنية).
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

  /// المعرّف المحفوظ في `avatarPreset` (0..23) — لا يتغيّر بعد النشر.
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
/// حرفان. الآن هي **24 صورة كرتونية فعلية** مضمَّنة في `assets/avatars/`،
/// موزّعة بالتساوي على ست فئات (أولاد/بنات/شباب/شابات/رجال أكبر/سيدات أكبر)،
/// بأسلوب بصري واحد وخلفيات هادئة.
///
/// **لماذا أصول مضمَّنة لا شبكة؟** ليبقى اختيار الصورة متاحًا بلا اتصال، ولأن
/// طلب «الصورة الافتراضية ليست فارغة أبدًا» يجب أن يظل صحيحًا على جهاز بلا
/// شبكة. الملفات مضغوطة (‎256×256 JPEG‎ ≈ 15–25KB) فمجموعها أقل من 0.6MB.
///
/// **التوافق مع الحسابات القديمة:** المعرّف المخزَّن يظل رقمًا في `avatarPreset`
/// (0..23). القيم القديمة 0..5 تبقى صالحة وتُعرض الآن بالرسم الجديد نفسه
/// (المعرّف لم يتغيّر، تغيّر شكل الصورة) — لا ترحيل بيانات ولا كتابة إجبارية.
abstract final class AvatarPresets {
  /// عدد الصور المتاحة (6 فئات × 4).
  static const int count = 24;

  /// صور كل فئة — أربع لكل فئة، بالتساوي.
  static const int perCategory = 4;

  /// الكتالوج كاملًا، مرتّبًا بترتيب الفئات أعلاه ثم بترتيب الصور داخلها.
  ///
  /// **الترتيب هو العقد**: `id` يساوي موضع الصورة في هذه القائمة، فلا يُعاد
  /// ترتيب القائمة بعد النشر وإلا تغيّرت صورة كل مستخدم اختار رمزية.
  static const List<AvatarArtwork> all = <AvatarArtwork>[
    AvatarArtwork(
      id: 0,
      category: AvatarCategory.boy,
      asset: 'assets/avatars/boy_01.jpg',
      description: 'ولد بشعر أسود مجعّد وقميص أصفر',
      tint: 0xFFBFE0CB,
    ),
    AvatarArtwork(
      id: 1,
      category: AvatarCategory.boy,
      asset: 'assets/avatars/boy_02.jpg',
      description: 'ولد بشعر بني فاتح وقميص أزرق',
      tint: 0xFFD8D2EE,
    ),
    AvatarArtwork(
      id: 2,
      category: AvatarCategory.boy,
      asset: 'assets/avatars/boy_03.jpg',
      description: 'ولد ببشرة داكنة وقميص مخطط أخضر',
      tint: 0xFFF3D7BF,
    ),
    AvatarArtwork(
      id: 3,
      category: AvatarCategory.boy,
      asset: 'assets/avatars/boy_04.jpg',
      description: 'ولد بنظارة وهودي أحمر',
      tint: 0xFFCFE3F3,
    ),
    AvatarArtwork(
      id: 4,
      category: AvatarCategory.girl,
      asset: 'assets/avatars/girl_01.jpg',
      description: 'بنت بشعر مموّج طويل ومشبك وردي',
      tint: 0xFFBFE0CB,
    ),
    AvatarArtwork(
      id: 5,
      category: AvatarCategory.girl,
      asset: 'assets/avatars/girl_02.jpg',
      description: 'بنت بضفيرتين كرويتين وقميص بنفسجي',
      tint: 0xFFF3D7BF,
    ),
    AvatarArtwork(
      id: 6,
      category: AvatarCategory.girl,
      asset: 'assets/avatars/girl_03.jpg',
      description: 'بنت بذيل حصان وسويتر فيروزي',
      tint: 0xFFEDE0C8,
    ),
    AvatarArtwork(
      id: 7,
      category: AvatarCategory.girl,
      asset: 'assets/avatars/girl_04.jpg',
      description: 'بنت بشعر كاريه كستنائي وفستان أصفر',
      tint: 0xFFD8D2EE,
    ),
    AvatarArtwork(
      id: 8,
      category: AvatarCategory.youngMan,
      asset: 'assets/avatars/man_01.jpg',
      description: 'شاب بشعر قصير وقميص كحلي',
      tint: 0xFFBFE0CB,
    ),
    AvatarArtwork(
      id: 9,
      category: AvatarCategory.youngMan,
      asset: 'assets/avatars/man_02.jpg',
      description: 'شاب بشعر مجعّد ولحية قصيرة وسويتر رمادي',
      tint: 0xFFF3D7BF,
    ),
    AvatarArtwork(
      id: 10,
      category: AvatarCategory.youngMan,
      asset: 'assets/avatars/man_03.jpg',
      description: 'شاب بشعر مموّج مربوط ونظارة رقيقة',
      tint: 0xFFEDE0C8,
    ),
    AvatarArtwork(
      id: 11,
      category: AvatarCategory.youngMan,
      asset: 'assets/avatars/man_04.jpg',
      description: 'شاب بقميص قطني أخضر داكن',
      tint: 0xFFCFE3F3,
    ),
    AvatarArtwork(
      id: 12,
      category: AvatarCategory.youngWoman,
      asset: 'assets/avatars/woman_01.jpg',
      description: 'شابة بشعر طويل مستقيم وبلوزة وردية',
      tint: 0xFFBFE0CB,
    ),
    AvatarArtwork(
      id: 13,
      category: AvatarCategory.youngWoman,
      asset: 'assets/avatars/woman_02.jpg',
      description: 'شابة بحجاب بلون هادئ وسترة كريمية',
      tint: 0xFFD8D2EE,
    ),
    AvatarArtwork(
      id: 14,
      category: AvatarCategory.youngWoman,
      asset: 'assets/avatars/woman_03.jpg',
      description: 'شابة بشعر مجعّد وقميص سماوي',
      tint: 0xFFF3D7BF,
    ),
    AvatarArtwork(
      id: 15,
      category: AvatarCategory.youngWoman,
      asset: 'assets/avatars/woman_04.jpg',
      description: 'شابة بكعكة شعر عالية وبليزر رمادي',
      tint: 0xFFEDE0C8,
    ),
    AvatarArtwork(
      id: 16,
      category: AvatarCategory.olderMan,
      asset: 'assets/avatars/elder_man_01.jpg',
      description: 'رجل أكبر سنًا بشعر أبيض ولحية خفيفة وقميص أزرق',
      tint: 0xFFBFE0CB,
    ),
    AvatarArtwork(
      id: 17,
      category: AvatarCategory.olderMan,
      asset: 'assets/avatars/elder_man_02.jpg',
      description: 'رجل أكبر سنًا بنظارة وشعر رمادي وقميص بيج',
      tint: 0xFFF3D7BF,
    ),
    AvatarArtwork(
      id: 18,
      category: AvatarCategory.olderMan,
      asset: 'assets/avatars/elder_man_03.jpg',
      description: 'رجل أكبر سنًا ببشرة داكنة وسترة رمادية',
      tint: 0xFFD8D2EE,
    ),
    AvatarArtwork(
      id: 19,
      category: AvatarCategory.olderMan,
      asset: 'assets/avatars/elder_man_04.jpg',
      description: 'رجل أكبر سنًا بشعر أصلع جزئيًا وقميص عنّابي',
      tint: 0xFFCFE3F3,
    ),
    AvatarArtwork(
      id: 20,
      category: AvatarCategory.olderWoman,
      asset: 'assets/avatars/elder_woman_01.jpg',
      description: 'سيدة أكبر سنًا بشعر فضي قصير وسترة خضراء',
      tint: 0xFFBFE0CB,
    ),
    AvatarArtwork(
      id: 21,
      category: AvatarCategory.olderWoman,
      asset: 'assets/avatars/elder_woman_02.jpg',
      description: 'سيدة أكبر سنًا بحجاب رمادي ونظارة',
      tint: 0xFFD8D2EE,
    ),
    AvatarArtwork(
      id: 22,
      category: AvatarCategory.olderWoman,
      asset: 'assets/avatars/elder_woman_03.jpg',
      description: 'سيدة أكبر سنًا بشعر مجعّد فضي وسترة زرقاء',
      tint: 0xFFF3D7BF,
    ),
    AvatarArtwork(
      id: 23,
      category: AvatarCategory.olderWoman,
      asset: 'assets/avatars/elder_woman_04.jpg',
      description: 'سيدة أكبر سنًا بحجاب وردي هادئ وعباءة بيج',
      tint: 0xFFEDE0C8,
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
  /// عند الإنشاء)، فالنتيجة شبه عشوائية ومتوزّعة على 24 صورة بأقرب ما يمكن:
  /// خوارزمية `Random` موحّدة، ولا مجموعة عالمية تُدار ولا عدّاد مركزي.
  /// تكرار الصورة بين حسابين أمر متوقع (طلبا صراحةً ألّا نفرض ضمانًا عالميًا
  /// لعدم التكرار)، ولا أثر لذلك على أي منطق.
  ///
  /// **لماذا تُمرَّر [entropy]؟** لتكون الدالة **قابلة للاختبار** بحتمية كاملة:
  /// نفس البذرة ⇒ نفس النتيجة، ومدى مختلف من البذور ⇒ تغطية كل الصور.
  static int randomIndexFor(String uid, {int? entropy}) {
    if (all.isEmpty) {
      return 0;
    }
    int mixed = 0x811c9dc5; // FNV-1a 32-bit
    for (final int unit in uid.codeUnits) {
      mixed ^= unit;
      mixed = (mixed * 0x01000193) & 0x7fffffff;
    }
    final int salt = entropy ?? Random.secure().nextInt(1 << 31);
    mixed = (mixed ^ salt) & 0x7fffffff;
    return Random(mixed).nextInt(all.length);
  }

  /// معرّف الصورة الافتراضية **الحتمي** من معرّف المستخدم.
  ///
  /// الحتمية مقصودة: نفس المستخدم يرى نفس الصورة على كل جهاز وقبل أن يُكتب
  /// أي مستند، فلا «تتغيّر صورته» عند إعادة تثبيت أو تسجيل دخول.
  static int forId(String id) {
    if (id.isEmpty) {
      return 0;
    }
    int hash = 0;
    for (final int unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash % count;
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
