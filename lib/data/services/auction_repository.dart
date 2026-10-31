import 'package:teacher_student_app/data/models/weekly_auction.dart';

/// عقد مزاد التمييز الأسبوعي (P30) أمام الواجهات.
///
/// **حدود صريحة:** لا يوجد في هذا العقد ما يسمح للعميل بتقرير شيء. كل كتابة
/// تمرّ بدالة سحابية، والقواعد تمنع أي كتابة مباشرة على مستندات المزاد:
///
/// | العملية | من ينفّذها | التحقق |
/// |---|---|---|
/// | مزايدة | مدرس | الخادم: الأهلية، الفئة، الحدود، آخر 10 دقائق، الزيادات |
/// | حسم/بديل/نشر/إعداد | مسؤول | الخادم: الادعاء + نافذة زمنية + تكرار آمن |
/// | دفع | مسؤول | الخادم: المهلة + أن الطلب لفائز فعلي |
///
/// الشاشات تتعامل مع [AppException] فقط؛ لا استيراد Firebase هنا.
abstract interface class AuctionRepository {
  /// حالة الأسبوع للمدرّس الحالي (فئته من ملفه، ومزايدته هو فقط).
  Future<AuctionState> loadMyState();

  /// مزايدة أو زيادة.
  ///
  /// [requestId] مفتاح منع الازدواج: يُولَّد مرة عند الضغط ويُعاد إرساله في
  /// المحاولات، فيضمن الخادم ألّا تُحتسب الزيادة مرتين.
  Future<AuctionBidOutcome> placeBid({
    required AuctionCategory category,
    required int amount,
    required String requestId,
  });

  /// النتائج المنشورة الآن لكل فئة (نداء واحد يُعيد الفئتين).
  ///
  /// القيمة `null` لفئة تعني «لم تُنشر بعد» — لا نتائج تقديرية ولا أسماء
  /// مخمّنة. والفئة الغائبة من الخريطة تُقرأ كـ`null` أيضًا.
  Future<Map<AuctionCategory, AuctionResultsView?>> loadPublishedResults();

  /// نظرة الإدارة: الفئتان، الفائزون بمبالغهم وحالات الدفع، والإعدادات.
  Future<AuctionAdminOverview> loadAdminOverview({String? cycleKey});

  /// تعديل الإعدادات (تسري على الدورات القادمة فقط).
  Future<void> updateConfig(AuctionConfig config);

  /// إنشاء دورات الأسبوع يدويًا (استثناء تشغيلي إن تأخّر المجدول).
  Future<void> ensureCycles();

  /// حسم المزاد الآن (تجاوز إداري موثّق — يُسجَّل في الأثر).
  Future<void> finalizeAuction({
    required String cycleKey,
    required AuctionCategory category,
  });

  /// تعليم دفع فائز (بعد التحصيل فعليًا). لا بوّابة دفع في التطبيق.
  Future<void> confirmWinnerPayment({
    required String cycleKey,
    required AuctionCategory category,
    required String teacherId,
    required bool paid,
    String? note,
  });

  /// تشغيل دورة البديل (مرة واحدة؛ الاستدعاء الثاني لا يفعل شيئًا).
  Future<void> runReplacement({
    required String cycleKey,
    required AuctionCategory category,
  });

  /// نشر التمييز على المدفوعين (يبدأ السبت 00:00).
  Future<void> publishFeatured({
    required String cycleKey,
    required AuctionCategory category,
  });

  /// إنهاء تمييز دورة انتهى عرضها.
  Future<void> expireFeatured({
    required String cycleKey,
    required AuctionCategory category,
  });
}

/// تنفيذ فارغ للبيئات الاختبارية التي لا تختبر المزاد.
///
/// يعيد حالة «غير متاح» واضحة بدل الانفجار، مثل بقية عقود المشروع
/// (`EmptyAvatarRepository`). لا يُستخدم في الإنتاج: الحزمتان الحقيقيتان
/// (`AppServices.firebase` و`AppServices.demo`) تحقنان تنفيذًا فعليًا.
class EmptyAuctionRepository implements AuctionRepository {
  const EmptyAuctionRepository();

  @override
  Future<AuctionState> loadMyState() async =>
      throw const AuctionUnavailable();

  @override
  Future<AuctionBidOutcome> placeBid({
    required AuctionCategory category,
    required int amount,
    required String requestId,
  }) async => throw const AuctionUnavailable();

  @override
  Future<Map<AuctionCategory, AuctionResultsView?>> loadPublishedResults() async =>
      const <AuctionCategory, AuctionResultsView?>{};

  @override
  Future<AuctionAdminOverview> loadAdminOverview({String? cycleKey}) async =>
      throw const AuctionUnavailable();

  @override
  Future<void> updateConfig(AuctionConfig config) async =>
      throw const AuctionUnavailable();

  @override
  Future<void> ensureCycles() async => throw const AuctionUnavailable();

  @override
  Future<void> finalizeAuction({
    required String cycleKey,
    required AuctionCategory category,
  }) async => throw const AuctionUnavailable();

  @override
  Future<void> confirmWinnerPayment({
    required String cycleKey,
    required AuctionCategory category,
    required String teacherId,
    required bool paid,
    String? note,
  }) async => throw const AuctionUnavailable();

  @override
  Future<void> runReplacement({
    required String cycleKey,
    required AuctionCategory category,
  }) async => throw const AuctionUnavailable();

  @override
  Future<void> publishFeatured({
    required String cycleKey,
    required AuctionCategory category,
  }) async => throw const AuctionUnavailable();

  @override
  Future<void> expireFeatured({
    required String cycleKey,
    required AuctionCategory category,
  }) async => throw const AuctionUnavailable();
}

/// يُرمى حين لا تكون الدوال السحابية متاحة في هذه الحزمة (وضع بلا خادم).
///
/// الشاشة تُترجمه إلى رسالة «المزاد يحتاج اتصالًا بالخادم» بلا انفجار.
class AuctionUnavailable implements Exception {
  const AuctionUnavailable();

  @override
  String toString() => 'AuctionUnavailable';
}
