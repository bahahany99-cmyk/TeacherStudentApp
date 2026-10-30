import 'dart:convert';
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

/// كتالوج الصور الافتراضية المرسومة (P22).
///
/// **لماذا مرسومة لا ملفات PNG؟** لأنها تُرسم بـFlutter (`CustomPainter`)
/// فتبقى حادّة على أي كثافة بكسل، ولا تضيف أصولًا للـAPK، ولا تحتاج شبكة —
/// أي أن «صورة الحساب ليست فارغة أبدًا» تظل صحيحة بلا اتصال.
abstract final class AvatarPresets {
  /// عدد التصاميم المتاحة.
  static const int count = 6;

  /// خيارات ألوان الخلفية (تدرّجات) — تُطابق `AppColors` ولا تخالفه.
  static const List<(int, int)> gradients = <(int, int)>[
    (0xFF6C5CE7, 0xFFA29BFE), // بنفسجي
    (0xFF00897B, 0xFF4DB6AC), // أخضر مزرق
    (0xFFB04A5E, 0xFFE39AA6), // وردي داكن
    (0xFF4A6C8C, 0xFF90AFC5), // أزرق هادئ
    (0xFFA9762F, 0xFFE0BC7C), // كهرماني
    (0xFF5D4E8C, 0xFFB0A6D6), // بنفسجي فاتح
  ];

  /// معرّف افتراضي **حتمي** من معرّف المستخدم.
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

/// حدود الصورة — مصدر واحد للواجهة والقواعد.
abstract final class AvatarLimits {
  /// أقصى طول لنص base64 المحفوظ (≈ 150KB صورة).
  ///
  /// الصورة تُصغَّر إلى 512px بجودة 80% قبل الترميز، فالناتج المعتاد 20–60KB.
  /// السقف هنا للحالات الشاذة (صورة معقّدة جدًا) وللرفض على الخادم.
  static const int maxBase64Length = 200000;

  /// أقصى أبعاد يطلبها المختار من المنصّة.
  static const int pickMaxDimension = 512;

  /// جودة الضغط المطلوبة من المنصّة (0–100).
  static const int pickQuality = 80;

  /// أنواع الصور المقبولة (القواعد تتحقق من نفس القيمتين).
  static const List<String> mimeTypes = <String>['image/jpeg', 'image/png'];
}
