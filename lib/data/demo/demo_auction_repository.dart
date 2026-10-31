import 'package:teacher_student_app/data/models/weekly_auction.dart';
import 'package:teacher_student_app/data/services/auction_repository.dart';

/// محاكاة المزاد في **وضع بلا خادم** (Firebase غير مُهيَّأ).
///
/// ⚠️ هذه ليست سلوكًا إنتاجيًا: لا مزايدة حقيقية ولا دفع ولا تمييز. الغرض أن
/// تبقى الشاشة قابلة للمعاينة والاختبار بلا مشروع Firebase، وأن تشرح للمستخدم
/// ما سيحدث عند الاتصال — لا أن تتظاهر بمزاد حقيقي.
///
/// القواعد المطبَّقة هنا **نسخة مبسّطة** من قواعد الخادم (الحد الأدنى، الخطوة،
/// عدد الزيادات، آخر 10 دقائق) حتى يكون التدفق قابلًا للتجربة، لكن المرجع
/// النهائي يبقى `functions/lib/auction_core.js`؛ ولذلك كل ما يخصّ الإدارة
/// (الحسم، الدفع، البديل، النشر) **غير متاح** هنا بدل تزييفه.
class DemoAuctionRepository implements AuctionRepository {
  DemoAuctionRepository({
    DateTime Function()? clock,
    this.isOnline = true,
    this.eligible = true,
    this.positions = 5,
    this.minBid = 100,
    this.bidStep = 25,
    this.extraBidLimit = 10,
    this.maxBid = 50000,
  }) : _clock = clock ?? DateTime.now;

  /// ساعة قابلة للحقن: الاختبار يحتاج أسبوعًا ثابتًا.
  final DateTime Function() _clock;

  /// فئة المدرّس في الحزمة التجريبية (يحدّدها الملف عادةً).
  final bool isOnline;
  final bool eligible;

  final int positions;
  final int minBid;
  final int bidStep;
  final int extraBidLimit;
  final int maxBid;

  /// مزايدات الجلسة: `cycleKey` ← (المبلغ، عدد الزيادات، وقت أول مزايدة).
  final Map<String, ({int amount, int increases, DateTime placedAt})> _bids =
      <String, ({int amount, int increases, DateTime placedAt})>{};

  AuctionCategory get _category =>
      isOnline ? AuctionCategory.online : AuctionCategory.inPerson;

  @override
  Future<AuctionState> loadMyState() async {
    final DateTime now = _clock();
    final _DemoWeek week = _DemoWeek.of(now);
    final ({int amount, int increases, DateTime placedAt})? bid =
        _bids[week.cycleKey];

    return AuctionState(
      serverNow: now,
      timeZone: 'Africa/Cairo',
      cycleKey: week.cycleKey,
      auctionId: '${week.cycleKey}-${_category.wireName}',
      category: _category,
      phase: week.phaseAt(now),
      opensAt: week.opensAt,
      closesAt: week.closesAt,
      bidCutoffAt: week.bidCutoffAt,
      announcesAt: week.announcesAt,
      paymentDeadline: week.paymentDeadline,
      replacementDeadline: week.replacementDeadline,
      displayStartsAt: week.displayStartsAt,
      displayEndsAt: week.displayEndsAt,
      minBid: minBid,
      bidStep: bidStep,
      maxBid: maxBid,
      extraBidLimit: extraBidLimit,
      positions: positions,
      eligible: eligible,
      eligibility: eligible ? null : 'notVerified',
      myBid: bid == null
          ? null
          : AuctionBidSummary(
              amount: bid.amount,
              increasesUsed: bid.increases,
              placedAt: bid.placedAt,
              lastBidAt: bid.placedAt,
            ),
      increasesRemaining: bid == null ? extraBidLimit : extraBidLimit - bid.increases,
      nextMinimum: bid == null ? minBid : bid.amount + bidStep,
      // لا نتائج ولا مقاعد في المحاكاة: لا نتظاهر بفائز أو دفع.
      myWinner: null,
      results: null,
    );
  }

  @override
  Future<AuctionBidOutcome> placeBid({
    required AuctionCategory category,
    required int amount,
    required String requestId,
  }) async {
    final DateTime now = _clock();
    final _DemoWeek week = _DemoWeek.of(now);
    final AuctionPhase phase = week.phaseAt(now);
    if (!eligible ||
        !phase.canBid ||
        category != _category ||
        amount <= 0 ||
        amount > maxBid) {
      throw const AuctionUnavailable();
    }

    final ({int amount, int increases, DateTime placedAt})? current =
        _bids[week.cycleKey];
    if (current == null) {
      if (amount < minBid) throw const AuctionUnavailable();
    } else {
      if (current.increases >= extraBidLimit) throw const AuctionUnavailable();
      if (amount < current.amount + bidStep) throw const AuctionUnavailable();
    }
    final bool isFirst = current == null;

    final int increases = current == null ? 0 : current.increases + 1;
    _bids[week.cycleKey] = (
      amount: amount,
      increases: increases,
      placedAt: current?.placedAt ?? now,
    );

    return AuctionBidOutcome(
      amount: amount,
      increasesUsed: increases,
      increasesRemaining: extraBidLimit - increases,
      nextMinimum: amount + bidStep,
      isFirst: isFirst,
      replayed: false,
    );
  }

  /// لا نتائج منشورة في المحاكاة: العرض الفعلي يأتي من الخادم بعد السبت.
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

/// أسبوع المزاد في المحاكاة — نفس حدود الجدول المعتمد، بتوقيت الجهاز المحلي.
///
/// **الخادم هو المصدر الحقيقي:** هذه النسخة موجودة فقط ليُعرَض للعميل عدّاد
/// منطقي في حزمة بلا Firebase، وهي مكتوبة بتوقيت محلي لا بمنطقة `Africa/Cairo`
/// (لا توجد قاعدة بيانات توقيت في Dart بلا حزم خارجية).
class _DemoWeek {
  _DemoWeek({
    required this.cycleKey,
    required this.opensAt,
    required this.closesAt,
    required this.bidCutoffAt,
    required this.announcesAt,
    required this.paymentDeadline,
    required this.replacementDeadline,
    required this.displayStartsAt,
    required this.displayEndsAt,
  });

  factory _DemoWeek.of(DateTime now) {
    final DateTime monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    final DateTime closesAt = monday.add(
      const Duration(days: 2, hours: 23, minutes: 59, seconds: 59),
    );
    final DateTime announcesAt = monday.add(const Duration(days: 3, hours: 9));
    final DateTime paymentDeadline = announcesAt.add(const Duration(hours: 24));
    final DateTime displayStartsAt = monday.add(const Duration(days: 5));
    return _DemoWeek(
      cycleKey: 'demo-${monday.year}-${_weekOfYear(monday)}',
      opensAt: monday,
      closesAt: closesAt,
      bidCutoffAt: closesAt.subtract(const Duration(minutes: 10)),
      announcesAt: announcesAt,
      paymentDeadline: paymentDeadline,
      replacementDeadline: paymentDeadline.add(const Duration(hours: 12)),
      displayStartsAt: displayStartsAt,
      displayEndsAt: displayStartsAt.add(const Duration(days: 7)).subtract(
        const Duration(minutes: 1),
      ),
    );
  }

  final String cycleKey;
  final DateTime opensAt;
  final DateTime closesAt;
  final DateTime bidCutoffAt;
  final DateTime announcesAt;
  final DateTime paymentDeadline;
  final DateTime replacementDeadline;
  final DateTime displayStartsAt;
  final DateTime displayEndsAt;

  /// نفس ترتيب المراحل في الخادم (`deriveStatus`).
  AuctionPhase phaseAt(DateTime now) {
    if (now.isBefore(opensAt)) return AuctionPhase.scheduled;
    if (now.isBefore(bidCutoffAt)) return AuctionPhase.open;
    if (now.isBefore(closesAt)) return AuctionPhase.gracePeriod;
    if (now.isBefore(announcesAt)) return AuctionPhase.awaitingFinalize;
    if (now.isBefore(paymentDeadline)) return AuctionPhase.paymentWindow;
    if (now.isBefore(replacementDeadline)) return AuctionPhase.replacement;
    // العرض نفسه لا يغيّر المرحلة (كما في الخادم): تبقى `awaitingPublish` حتى
    // يُنهى التمييز نهاية الأسبوع.
    if (now.isBefore(displayEndsAt)) return AuctionPhase.awaitingPublish;
    return AuctionPhase.ended;
  }

  static int _weekOfYear(DateTime monday) {
    final DateTime firstThursday = DateTime(monday.year, 1, 4);
    final DateTime firstMonday = firstThursday.subtract(
      Duration(days: firstThursday.weekday - DateTime.monday),
    );
    final int weeks = monday.difference(firstMonday).inDays ~/ 7;
    return weeks + 1;
  }
}
