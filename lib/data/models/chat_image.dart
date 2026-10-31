import 'dart:convert';
import 'dart:typed_data';

/// حدود صور المحادثة (P24) — **مصدر واحد** تستخدمه الواجهة والقواعد معًا.
///
/// الصور لا تُخزَّن في مستند الرسالة: الرسالة سطر صغير يُقرأ في كل فتح
/// للمحادثة، ووضع 300KB من الصور فيه يعني قراءة ملايين البايتات لعرض «مرحبا».
/// لذلك لكل صورة مستند مستقل في مجموعة فرعية، ويُقرأ فقط عند عرضها.
abstract final class ChatImageLimits {
  /// سقف طول base64 — يُضبط في `firestore.rules` بالقيمة نفسها.
  ///
  /// 400,000 حرف ≈ 300KB صورة، وهو سقف عملي لصورة دردشة مُصغَّرة على الجهاز
  /// (`maxWidth` صغير + ضغط JPEG) لا لصورة كاميرا خام.
  static const int maxBase64Length = 400000;

  /// أقل طول مقبول (صورة أصغر من ذلك ليست صورة).
  static const int minBase64Length = 64;

  /// الأنواع المسموح بها — قيمتان فقط، كما في `avatars`.
  static const List<String> mimeTypes = <String>['image/jpeg', 'image/png'];

  /// (P24) عمر الصورة: **5 أيام** ثم تُحذف تلقائيًا.
  ///
  /// الغرض مساحة التخزين: صور الدردشة أثقل محتوى في التطبيق وأقلّه قيمة على
  /// المدى الطويل. الحد مفروض من جهتين: القواعد تمنع **قراءتها** بعد
  /// `expiresAt` (فلا تظهر ولو بقي المستند)، والعميل يحذف المنتهي عند فتح
  /// المحادثة (تنظيف تدريجي بلا دالة سحابية).
  static const Duration lifetime = Duration(days: 5);

  /// هامش التسامح لفرق ساعة الجهاز/الخادم (يُستخدم في الفحص المحلي فقط).
  static const Duration clockTolerance = Duration(minutes: 2);
}

/// صورة أُرسلت داخل محادثة مباشرة (P24).
///
/// **مؤقتة بالتصميم:** تحمل موعد انتهاء صريحًا لا يُحسب في الواجهة، فيمكن
/// للقواعد مقارنته بـ`request.time` ولا يمكن للعميل تمديده.
class ChatImage {
  const ChatImage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.bytes,
    required this.mimeType,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String chatId;
  final String senderId;

  /// البايتات الفعلية (مفكوكة من base64 عند القراءة).
  final Uint8List bytes;

  final String mimeType;
  final DateTime createdAt;

  /// بعد هذا الموعد: القواعد ترفض القراءة، والعميل يحذف المستند.
  final DateTime expiresAt;

  /// هل انتهت صلاحية الصورة الآن؟
  ///
  /// الهامش [ChatImageLimits.clockTolerance] يمنع «انتهت» كاذبة لصورة أُنشئت
  /// للتوّ على جهاز ساعته متأخرة قليلًا. القرار النهائي للخادم دائمًا.
  bool isExpired({DateTime? now}) {
    final DateTime moment = now ?? DateTime.now();
    return !moment.isBefore(expiresAt.subtract(ChatImageLimits.clockTolerance));
  }

  /// المدة المتبقية قبل الحذف (صفر إن انتهت).
  Duration remaining({DateTime? now}) {
    final Duration left = expiresAt.difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// «٥ أيام» — عمر الصورة من لحظة إنشائها (للشارة الدقيقة على المصغّر).
  static String lifetimeLabel() => '${ChatImageLimits.lifetime.inDays} أيام';

  /// المتبقي بصيغة قصيرة للعرض: «٣ أيام»، «٢٢ ساعة»، «١٥ دقيقة».
  static String remainingLabel(Duration left) {
    if (left.inDays >= 1) {
      final int days = left.inDays;
      return days == 1 ? 'يوم واحد' : '$days ${days == 2 ? 'يومين' : 'أيام'}';
    }
    if (left.inHours >= 1) {
      final int hours = left.inHours;
      return hours == 1 ? 'ساعة' : '$hours ساعة';
    }
    final int minutes = left.inMinutes < 1 ? 1 : left.inMinutes;
    return '$minutes دقيقة';
  }

  /// خريطة الكتابة في `directChats/{chatId}/images/{imageId}`.
  ///
  /// `chatId` منسوخ داخل المستند بقصد: يجعل القراءة/الكتابة فحصًا على المستند
  /// نفسه ويسمح للاستعلام بالتحقق دون قراءة الأب لكل صف.
  Map<String, Object?> toCreateMap() {
    return <String, Object?>{
      'chatId': chatId,
      'senderId': senderId,
      'imageBase64': base64Encode(bytes),
      'mimeType': mimeType,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
    };
  }

  /// معرّف فريد للصورة داخل المحادثة.
  static String newId(DateTime now, {required String senderId}) =>
      '${now.microsecondsSinceEpoch}_$senderId';
}
