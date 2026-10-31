/// نماذج مزاد التمييز الأسبوعي (P30) — **قراءة فقط**.
///
/// كل ما هنا يعكس ما يُعيده الخادم (Cloud Functions) بعد تنقيته:
///   - [AuctionState] للمدرّس: حالته هو، ومزايدته هو، ولا شيء عن منافسيه.
///   - [AuctionResultsView] للجميع: أسماء الفائزين المدفوعين ومراكزهم بلا مبالغ.
///   - [AuctionAdminOverview] للإدارة وحدها: الفائزون بمبالغهم وحالات دفعهم.
///
/// **لا يوجد في هذه النماذج أي قرار:** لا ترتيب، ولا أهلية، ولا حدّ زمني
/// يُحسب في التطبيق ليُعتمد. الخادم يقصّ (`bidCutoffAt`، `phase`) والتطبيق
/// يعرض ويقترح فقط، ثم يُرسل الطلب ليُحكم على الخادم.
library;

/// فئة المزاد: فئتان مستقلتان تمامًا، لكل منهما خمسة مقاعد.
enum AuctionCategory {
  /// مدرس يقدّم عن بُعد (`teacherProfiles.isOnline == true`).
  online('online', 'أونلاين'),

  /// مدرس يستقبل الطالب حضوريًا (`isOnline == false`).
  inPerson('inPerson', 'حضوري');

  const AuctionCategory(this.wireName, this.label);

  /// القيمة في Firestore/الدوال — تغييرها يوجب تغييره في الخادم.
  final String wireName;

  /// الاسم المعروض.
  final String label;

  /// قراءة آمنة: قيمة غير معروفة تُعيد `null` بدل الانفجار.
  static AuctionCategory? tryParse(Object? value) => switch (value) {
    'online' => AuctionCategory.online,
    'inPerson' => AuctionCategory.inPerson,
    _ => null,
  };
}

/// مرحلة الأسبوع — **مشتقة على الخادم** من الطوابع الزمنية وساعته.
///
/// لا تُخزَّن في Firestore كحقل متغيّر: حقل قابل للتعديل يعني حالة قابلة
/// للتزوير. هنا مجرد عرض للعميل.
enum AuctionPhase {
  /// قبل فتح المزايدة (قبل الاثنين 00:00).
  scheduled('لم يبدأ المزاد', false),

  /// المزايدة مفتوحة.
  open('المزايدة مفتوحة', true),

  /// آخر 10 دقائق قبل الإغلاق: عرض النتائج الجارية فقط، وبلا مزايدة.
  gracePeriod('أُغلقت المزايدة — جارٍ الاحتساب', false),

  /// بعد الإغلاق وقبل إعلان الخميس 09:00.
  awaitingFinalize('جارٍ احتساب الفائزين', false),

  /// أُعلن الفائزون، ومهلة الدفع سارية (24 ساعة).
  paymentWindow('مهلة دفع الفائزين', false),

  /// دورة البديل الواحدة (12 ساعة).
  replacement('دورة البديل', false),

  /// انتهت مهل الدفع والبديل، وقبل بدء العرض السبت 00:00.
  awaitingPublish('استعدادًا للعرض', false),

  /// الدورة منتهية (رُفع التمييز بعد أسبوع العرض).
  ended('انتهى هذا الأسبوع', false);

  const AuctionPhase(this.label, this.canBid);

  /// نص عربي مختصر للعرض.
  final String label;

  /// هل تُقبل مزايدة في هذه المرحلة؟ (الخادم هو من يحكم نهائيًا)
  final bool canBid;

  /// قراءة آمنة: مرحلة غير معروفة تُقرأ كـ[scheduled] لا كـ«مفتوح».
  static AuctionPhase parse(Object? value) => switch (value) {
    'open' => AuctionPhase.open,
    'gracePeriod' => AuctionPhase.gracePeriod,
    'awaitingFinalize' => AuctionPhase.awaitingFinalize,
    'paymentWindow' => AuctionPhase.paymentWindow,
    'replacement' => AuctionPhase.replacement,
    'awaitingPublish' => AuctionPhase.awaitingPublish,
    'ended' => AuctionPhase.ended,
    _ => AuctionPhase.scheduled,
  };
}

/// مزايدة المدرّس نفسه (مبلغه وعدد زياداته وتوقيت أول مزايدة).
class AuctionBidSummary {
  const AuctionBidSummary({
    required this.amount,
    required this.increasesUsed,
    this.placedAt,
    this.lastBidAt,
  });

  final int amount;
  final int increasesUsed;
  final DateTime? placedAt;
  final DateTime? lastBidAt;

  static AuctionBidSummary? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final Object? amount = raw['amount'];
    if (amount is! num) return null;
    return AuctionBidSummary(
      amount: amount.toInt(),
      increasesUsed: (raw['increasesUsed'] as num?)?.toInt() ?? 0,
      placedAt: _date(raw['placedAt']),
      lastBidAt: _date(raw['lastBidAt']),
    );
  }
}

/// مقعد المدرّس نفسه إن فاز — المركز والمهلة وحالة الدفع.
class AuctionSeat {
  const AuctionSeat({
    required this.status,
    required this.round,
    required this.paid,
    required this.deadline,
    this.rank,
    this.amount,
  });

  /// `pendingPayment` / `paid` / `unpaid` / `unfilled`.
  final String status;

  /// 1 = الفائزون الأصليون، 2 = دورة البديل.
  final int round;
  final bool paid;
  final DateTime? deadline;

  /// المركز في الفئة؛ `null` لفائز البديل (يأخذ مقعدًا لا ترتيبًا).
  final int? rank;
  final int? amount;

  /// هل ما زال بانتظار دفع؟ (للعرض فقط؛ التحقق على الخادم)
  bool get isPendingPayment => status == 'pendingPayment';

  static AuctionSeat? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final Object? status = raw['status'];
    if (status is! String) return null;
    return AuctionSeat(
      status: status,
      round: (raw['round'] as num?)?.toInt() ?? 1,
      paid: raw['paid'] == true,
      deadline: _date(raw['deadline']),
      rank: (raw['rank'] as num?)?.toInt(),
      amount: (raw['amount'] as num?)?.toInt(),
    );
  }
}

/// سطر في النتائج العامة: اسم ومركز فقط — **بلا مبلغ**.
class AuctionResultEntry {
  const AuctionResultEntry({
    required this.teacherId,
    required this.displayName,
    required this.round,
    this.rank,
  });

  final String teacherId;
  final String displayName;
  final int round;
  final int? rank;

  static AuctionResultEntry? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final Object? teacherId = raw['teacherId'];
    if (teacherId is! String || teacherId.isEmpty) return null;
    return AuctionResultEntry(
      teacherId: teacherId,
      displayName: (raw['displayName'] as String?) ?? '',
      round: (raw['round'] as num?)?.toInt() ?? 1,
      rank: (raw['rank'] as num?)?.toInt(),
    );
  }
}

/// النتائج المنشورة لفئة واحدة بعد السبت 00:00.
class AuctionResultsView {
  const AuctionResultsView({
    required this.cycleKey,
    required this.category,
    required this.winners,
    this.publishedAt,
    this.emptySeats = 0,
  });

  final String cycleKey;
  final AuctionCategory? category;
  final List<AuctionResultEntry> winners;
  final DateTime? publishedAt;

  /// مقاعد لم تُشغَل (لم تُدفع أو لم يجد البديل مرشّحًا) — تبقى فارغة بقصد.
  final int emptySeats;

  static AuctionResultsView? fromMap(Object? raw) {
    if (raw is! Map || raw['published'] == false) return null;
    final List<AuctionResultEntry> winners = <AuctionResultEntry>[
      for (final Object? item in (raw['winners'] as List<Object?>?) ?? const <Object?>[])
        if (AuctionResultEntry.fromMap(item) case final AuctionResultEntry entry) entry,
    ];
    return AuctionResultsView(
      cycleKey: (raw['cycleKey'] as String?) ?? '',
      category: AuctionCategory.tryParse(raw['category']),
      winners: winners,
      publishedAt: _date(raw['publishedAt']),
      emptySeats: (raw['emptySeats'] as num?)?.toInt() ?? 0,
    );
  }
}

/// **حالة المزاد كما يراها مدرّس واحد** — من دالة `myAuctionState`.
///
/// لا تحتوي `highestBid` ولا عدد المزايدين ولا أي مزايدة لغير صاحبها.
class AuctionState {
  const AuctionState({
    required this.serverNow,
    required this.timeZone,
    required this.cycleKey,
    required this.auctionId,
    required this.category,
    required this.phase,
    required this.opensAt,
    required this.closesAt,
    required this.bidCutoffAt,
    required this.announcesAt,
    required this.paymentDeadline,
    required this.displayStartsAt,
    required this.displayEndsAt,
    required this.minBid,
    required this.bidStep,
    required this.maxBid,
    required this.extraBidLimit,
    required this.positions,
    required this.eligible,
    required this.increasesRemaining,
    required this.nextMinimum,
    this.bidCutoffMinutes = 10,
    this.replacementDeadline,
    this.eligibility,
    this.myBid,
    this.myWinner,
    this.results,
  });

  /// ساعة الخادم لحظة القراءة — منها يُحسب فرق التوقيت للعدّاد التنازلي.
  final DateTime serverNow;

  /// المنطقة الزمنية المعلنة للجدول (`Africa/Cairo`).
  final String timeZone;

  final String cycleKey;
  final String auctionId;
  final AuctionCategory? category;
  final AuctionPhase phase;

  final DateTime opensAt;
  final DateTime closesAt;

  /// آخر لحظة تُقبل فيها مزايدة (= الإغلاق − 10 دقائق).
  final DateTime bidCutoffAt;
  final DateTime announcesAt;
  final DateTime paymentDeadline;
  final DateTime displayStartsAt;

  /// نهاية العرض (الجمعة 23:59 من الأسبوع التالي).
  final DateTime displayEndsAt;

  final DateTime? replacementDeadline;

  final int minBid;
  final int bidStep;
  final int maxBid;
  final int extraBidLimit;
  final int positions;
  final int bidCutoffMinutes;

  /// هل يملك صاحب الجلسة أهلية المزايدة؟ (الخادم يقيّم ملفه هو)
  final bool eligible;

  /// `accountHidden` أو `notVerified` إن كان غير مؤهل.
  final String? eligibility;

  final AuctionBidSummary? myBid;
  final int increasesRemaining;
  final int nextMinimum;
  final AuctionSeat? myWinner;
  final AuctionResultsView? results;

  /// هل هذه فئة «عن بُعد»؟
  bool get isOnline => category == AuctionCategory.online;

  /// ترجمة سبب عدم الأهلية إلى نص عربي.
  String? get ineligibilityMessage => switch (eligibility) {
    'accountHidden' => 'ملفك مخفي (حساب مجدول للحذف)، فلا يمكنك المشاركة في المزاد.',
    'notVerified' => 'المزاد متاح للمدرسين الموثّقين فقط. أكمل توثيق ملفك أولًا.',
    _ => null,
  };

  static AuctionState fromMap(Map<Object?, Object?> raw) {
    final DateTime now = _date(raw['serverNow']) ?? DateTime.now();
    return AuctionState(
      serverNow: now,
      timeZone: (raw['timeZone'] as String?) ?? 'Africa/Cairo',
      cycleKey: (raw['cycleKey'] as String?) ?? '',
      auctionId: (raw['auctionId'] as String?) ?? '',
      category: AuctionCategory.tryParse(raw['category']),
      phase: AuctionPhase.parse(raw['phase']),
      opensAt: _date(raw['opensAt']) ?? now,
      closesAt: _date(raw['closesAt']) ?? now,
      bidCutoffAt: _date(raw['bidCutoffAt']) ?? now,
      announcesAt: _date(raw['announcesAt']) ?? now,
      paymentDeadline: _date(raw['paymentDeadline']) ?? now,
      replacementDeadline: _date(raw['replacementDeadline']),
      displayStartsAt: _date(raw['displayStartsAt']) ?? now,
      displayEndsAt: _date(raw['displayEndsAt']) ?? now,
      minBid: (raw['minBid'] as num?)?.toInt() ?? 100,
      bidStep: (raw['bidStep'] as num?)?.toInt() ?? 25,
      maxBid: (raw['maxBid'] as num?)?.toInt() ?? 50000,
      extraBidLimit: (raw['extraBidLimit'] as num?)?.toInt() ?? 10,
      positions: (raw['positions'] as num?)?.toInt() ?? 5,
      bidCutoffMinutes: (raw['bidCutoffMinutes'] as num?)?.toInt() ?? 10,
      eligible: raw['eligible'] == true,
      eligibility: raw['eligibility'] as String?,
      myBid: AuctionBidSummary.fromMap(raw['myBid']),
      increasesRemaining: (raw['increasesRemaining'] as num?)?.toInt() ?? 0,
      nextMinimum: (raw['nextMinimum'] as num?)?.toInt() ?? 0,
      myWinner: AuctionSeat.fromMap(raw['myWinner']),
      results: AuctionResultsView.fromMap(raw['results']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// الإدارة
// ─────────────────────────────────────────────────────────────────────────────

/// إعدادات المزاد — يكتبها المسؤول، وتسري على الدورات القادمة وحدها.
class AuctionConfig {
  const AuctionConfig({
    this.positionsPerCategory = 5,
    this.minBid = 100,
    this.bidStep = 25,
    this.extraBidLimit = 10,
    this.maxBid = 50000,
    this.announceHour = 9,
    this.paymentWindowHours = 24,
    this.replacementWindowHours = 12,
    this.bidCutoffMinutes = 10,
  });

  final int positionsPerCategory;
  final int minBid;
  final int bidStep;
  final int extraBidLimit;
  final int maxBid;

  /// ساعة إعلان النتائج (0–23) بتوقيت القاهرة — الافتراضي 9 صباحًا.
  final int announceHour;
  final int paymentWindowHours;
  final int replacementWindowHours;

  /// دقائق حظر المزايدة قبل الإغلاق (1–120) — الافتراضي 10.
  final int bidCutoffMinutes;

  AuctionConfig copyWith({
    int? positionsPerCategory,
    int? minBid,
    int? bidStep,
    int? extraBidLimit,
    int? maxBid,
    int? announceHour,
    int? paymentWindowHours,
    int? replacementWindowHours,
    int? bidCutoffMinutes,
  }) => AuctionConfig(
    positionsPerCategory: positionsPerCategory ?? this.positionsPerCategory,
    minBid: minBid ?? this.minBid,
    bidStep: bidStep ?? this.bidStep,
    extraBidLimit: extraBidLimit ?? this.extraBidLimit,
    maxBid: maxBid ?? this.maxBid,
    announceHour: announceHour ?? this.announceHour,
    paymentWindowHours: paymentWindowHours ?? this.paymentWindowHours,
    replacementWindowHours: replacementWindowHours ?? this.replacementWindowHours,
    bidCutoffMinutes: bidCutoffMinutes ?? this.bidCutoffMinutes,
  );

  /// تُرسل كاملة: الخادم يتحقق من النطاقات ثم يحفظ المستند كاملًا.
  Map<String, Object?> toMap() => <String, Object?>{
    'positionsPerCategory': positionsPerCategory,
    'minBid': minBid,
    'bidStep': bidStep,
    'extraBidLimit': extraBidLimit,
    'maxBid': maxBid,
    'announceHour': announceHour,
    'paymentWindowHours': paymentWindowHours,
    'replacementWindowHours': replacementWindowHours,
    'bidCutoffMinutes': bidCutoffMinutes,
  };

  static AuctionConfig fromMap(Object? raw) {
    if (raw is! Map) return const AuctionConfig();
    return AuctionConfig(
      positionsPerCategory: (raw['positionsPerCategory'] as num?)?.toInt() ?? 5,
      minBid: (raw['minBid'] as num?)?.toInt() ?? 100,
      bidStep: (raw['bidStep'] as num?)?.toInt() ?? 25,
      extraBidLimit: (raw['extraBidLimit'] as num?)?.toInt() ?? 10,
      maxBid: (raw['maxBid'] as num?)?.toInt() ?? 50000,
      announceHour: (raw['announceHour'] as num?)?.toInt() ?? 9,
      paymentWindowHours: (raw['paymentWindowHours'] as num?)?.toInt() ?? 24,
      replacementWindowHours:
          (raw['replacementWindowHours'] as num?)?.toInt() ?? 12,
      bidCutoffMinutes: (raw['bidCutoffMinutes'] as num?)?.toInt() ?? 10,
    );
  }
}

/// فائز كما تراه الإدارة: بالمركز والمبلغ وحالة الدفع ومن اعتمدها.
class AuctionAdminWinner {
  const AuctionAdminWinner({
    required this.teacherId,
    required this.displayName,
    required this.status,
    required this.round,
    this.rank,
    this.amount,
    this.deadline,
    this.confirmedAt,
    this.confirmedBy,
  });

  final String teacherId;
  final String displayName;

  /// `pendingPayment` / `paid` / `unpaid` / `unfilled`.
  final String status;
  final int round;
  final int? rank;
  final int? amount;
  final DateTime? deadline;
  final DateTime? confirmedAt;
  final String? confirmedBy;

  static AuctionAdminWinner? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final Object? teacherId = raw['teacherId'];
    if (teacherId is! String || teacherId.isEmpty) return null;
    return AuctionAdminWinner(
      teacherId: teacherId,
      displayName: (raw['displayName'] as String?) ?? '',
      status: (raw['status'] as String?) ?? 'pendingPayment',
      round: (raw['round'] as num?)?.toInt() ?? 1,
      rank: (raw['rank'] as num?)?.toInt(),
      amount: (raw['amount'] as num?)?.toInt(),
      deadline: _date(raw['deadline']),
      confirmedAt: _date(raw['confirmedAt']),
      confirmedBy: raw['confirmedBy'] as String?,
    );
  }
}

/// دورة فئة واحدة كما تراها الإدارة.
class AuctionAdminCategory {
  const AuctionAdminCategory({
    required this.auctionId,
    required this.category,
    required this.missing,
    required this.phase,
    required this.winners,
    this.positions = 0,
    this.minBid = 0,
    this.bidStep = 0,
    this.extraBidLimit = 0,
    this.maxBid = 0,
    this.bidCount = 0,
    this.biddersCount = 0,
    this.highestBid = 0,
    this.emptySeats = 0,
    this.replacementRound = 0,
    this.closesAt,
    this.paymentDeadline,
    this.replacementDeadline,
    this.displayStartsAt,
    this.finalizedAt,
    this.publishedAt,
    this.settledAt,
    this.results,
  });

  final String auctionId;
  final AuctionCategory? category;

  /// هل الدورة غير موجودة أصلًا (المجدول لم يعمل بعد)؟
  final bool missing;
  final AuctionPhase phase;
  final List<AuctionAdminWinner> winners;

  final int positions;
  final int minBid;
  final int bidStep;
  final int extraBidLimit;
  final int maxBid;
  final int bidCount;
  final int biddersCount;
  final int highestBid;
  final int emptySeats;
  final int replacementRound;

  final DateTime? closesAt;
  final DateTime? paymentDeadline;
  final DateTime? replacementDeadline;
  final DateTime? displayStartsAt;
  final DateTime? finalizedAt;
  final DateTime? publishedAt;
  final DateTime? settledAt;
  final AuctionResultsView? results;

  /// عدد المدفوعين — ما يُطابق ماليًا فعليًا.
  int get paidCount => winners.where((AuctionAdminWinner w) => w.status == 'paid').length;

  /// عدد من انتهت مهلته بلا دفع.
  int get unpaidCount => winners.where((AuctionAdminWinner w) => w.status == 'unpaid').length;

  static AuctionAdminCategory? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final Object? auctionId = raw['auctionId'];
    if (auctionId is! String || auctionId.isEmpty) return null;
    return AuctionAdminCategory(
      auctionId: auctionId,
      category: AuctionCategory.tryParse(raw['category']),
      missing: raw['missing'] == true,
      phase: AuctionPhase.parse(raw['phase']),
      winners: <AuctionAdminWinner>[
        for (final Object? item in (raw['winners'] as List<Object?>?) ?? const <Object?>[])
          if (AuctionAdminWinner.fromMap(item) case final AuctionAdminWinner winner) winner,
      ],
      positions: (raw['positions'] as num?)?.toInt() ?? 0,
      minBid: (raw['minBid'] as num?)?.toInt() ?? 0,
      bidStep: (raw['bidStep'] as num?)?.toInt() ?? 0,
      extraBidLimit: (raw['extraBidLimit'] as num?)?.toInt() ?? 0,
      maxBid: (raw['maxBid'] as num?)?.toInt() ?? 0,
      bidCount: (raw['bidCount'] as num?)?.toInt() ?? 0,
      biddersCount: (raw['biddersCount'] as num?)?.toInt() ?? 0,
      highestBid: (raw['highestBid'] as num?)?.toInt() ?? 0,
      emptySeats: (raw['emptySeats'] as num?)?.toInt() ?? 0,
      replacementRound: (raw['replacementRound'] as num?)?.toInt() ?? 0,
      closesAt: _date(raw['closesAt']),
      paymentDeadline: _date(raw['paymentDeadline']),
      replacementDeadline: _date(raw['replacementDeadline']),
      displayStartsAt: _date(raw['displayStartsAt']),
      finalizedAt: _date(raw['finalizedAt']),
      publishedAt: _date(raw['publishedAt']),
      settledAt: _date(raw['settledAt']),
      results: AuctionResultsView.fromMap(raw['results']),
    );
  }
}

/// سطر في سجل الأثر — من فعل ماذا ومتى.
class AuctionAuditEntry {
  const AuctionAuditEntry({
    required this.action,
    required this.actor,
    required this.detail,
    this.at,
  });

  final String action;
  final String actor;
  final String detail;
  final DateTime? at;

  /// شرح عربي مختصر للفعل (الرمز يأتي من الخادم).
  String get label => switch (action) {
    'bid.place' => 'مزايدة',
    'auction.finalize' => 'حسم المزاد',
    'payment.confirm' => 'تأكيد دفع',
    'payment.reject' => 'رفض دفع',
    'auction.replacement' => 'دورة البديل',
    'auction.publish' => 'نشر التمييز',
    'auction.expire' => 'إنهاء التمييز',
    'config.update' => 'تعديل الإعدادات',
    'cycles.create' => 'إنشاء دورات',
    _ => action,
  };

  static AuctionAuditEntry? fromMap(Object? raw) {
    if (raw is! Map) return null;
    return AuctionAuditEntry(
      action: (raw['action'] as String?) ?? '',
      actor: (raw['actor'] as String?) ?? '',
      detail: (raw['detail'] as String?) ?? '',
      at: _date(raw['at']),
    );
  }
}

/// نظرة الإدارة الكاملة: الفئتان + الإعدادات + آخر الأثر.
class AuctionAdminOverview {
  const AuctionAdminOverview({
    required this.cycleKey,
    required this.config,
    required this.categories,
    required this.audit,
    required this.serverNow,
    this.timeZone = 'Africa/Cairo',
  });

  final String cycleKey;
  final AuctionConfig config;
  final List<AuctionAdminCategory> categories;
  final List<AuctionAuditEntry> audit;
  final DateTime serverNow;
  final String timeZone;

  static AuctionAdminOverview fromMap(Map<Object?, Object?> raw) {
    return AuctionAdminOverview(
      cycleKey: (raw['cycleKey'] as String?) ?? '',
      config: AuctionConfig.fromMap(raw['config']),
      categories: <AuctionAdminCategory>[
        for (final Object? item
            in (raw['categories'] as List<Object?>?) ?? const <Object?>[])
          if (AuctionAdminCategory.fromMap(item)
              case final AuctionAdminCategory category)
            category,
      ],
      audit: <AuctionAuditEntry>[
        for (final Object? item in (raw['audit'] as List<Object?>?) ?? const <Object?>[])
          if (AuctionAuditEntry.fromMap(item) case final AuctionAuditEntry entry) entry,
      ],
      serverNow: _date(raw['serverNow']) ?? DateTime.now(),
      timeZone: (raw['timeZone'] as String?) ?? 'Africa/Cairo',
    );
  }
}

/// نتيجة عملية مزايدة — كما يعيدها الخادم (منها `replayed`).
class AuctionBidOutcome {
  const AuctionBidOutcome({
    required this.amount,
    required this.increasesUsed,
    required this.increasesRemaining,
    required this.nextMinimum,
    required this.isFirst,
    required this.replayed,
  });

  final int amount;
  final int increasesUsed;
  final int increasesRemaining;
  final int nextMinimum;
  final bool isFirst;

  /// `true` إن كان هذا الطلب مكررًا (أُعيد إرساله) — نتيجته نفسها بلا زيادة جديدة.
  final bool replayed;

  static AuctionBidOutcome fromMap(Object? raw) {
    final Map<Object?, Object?> map = raw is Map ? raw : const <Object?, Object?>{};
    return AuctionBidOutcome(
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      increasesUsed: (map['increasesUsed'] as num?)?.toInt() ?? 0,
      increasesRemaining: (map['increasesRemaining'] as num?)?.toInt() ?? 0,
      nextMinimum: (map['nextMinimum'] as num?)?.toInt() ?? 0,
      isFirst: map['isFirst'] == true,
      replayed: map['replayed'] == true,
    );
  }
}

/// تحويل قيمة الخادم إلى تاريخ.
///
/// الخادم يُرسل **ميلي ثانية UTC** (رقم) لا كائنًا زمنيًا، فالقيمة نفسها لا
/// تتأثر بمنطقة جهاز المستخدم. نقبل النص أيضًا (بيانات قديمة أو يدوية).
DateTime? _date(Object? raw) {
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true).toLocal();
  }
  if (raw is String) return DateTime.tryParse(raw)?.toLocal();
  return null;
}

/// تُستخدم في الاختبارات وفي الشاشات التي تُحقن الوقت.
DateTime? auctionDateFrom(Object? raw) => _date(raw);
