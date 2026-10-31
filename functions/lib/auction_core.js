/**
 * منطق المزاد الأسبوعي للمدرسين المميزين — **نواة نقية بلا Firebase**.
 *
 * هذا الملف هو مصدر الحقيقة الوحيد لِـ:
 *   - جدول الأسبوع (توقيت القاهرة) وحساب حدوده،
 *   - آلة الحالات لدورة المزاد،
 *   - التحقق من المزايدات،
 *   - الترتيب الحتمي واختيار الفائزين،
 *   - دورة البديل الواحدة،
 *   - مفاتيح التكرار (idempotency).
 *
 * لماذا نواة منفصلة؟ لأن كل قرار مالي/تمييزي يجب أن يكون **قابلًا للاختبار
 * بلا محاكي ولا شبكة**: الاختبارات تُشغَّل بـ`node --test` في CI، والطبقة
 * النحيفة فوقها (`auction_service.js`) تتعامل مع Firestore فقط.
 *
 * المبادئ الملزمة:
 *   1. كل الحدود الزمنية تُحسب **من ساعة الخادم** (`now` يُمرَّر دائمًا).
 *      لا يُقرأ `Date.now()` داخل هذا الملف، فساعة جهاز المستخدم لا تعني شيئًا.
 *   2. الترتيب حتمي بالكامل: لا يعتمد على ترتيب وصول المستندات.
 *   3. كل عملية قابلة للتكرار (idempotent): تكرار الطلب يعطي النتيجة نفسها.
 */

'use strict';

/** المنطقة الزمنية المعتمدة في كل الجدول. لا تُغيَّر إلا بقرار موثّق. */
const TIME_ZONE = 'Africa/Cairo';

/** دقائق حظر المزايدة قبل الإغلاق. */
const BID_CUTOFF_MINUTES = 10;

/** الفئات: فئتان مستقلتان تمامًا، لكل منهما 5 مقاعد. */
const CATEGORIES = Object.freeze(['online', 'inPerson']);

/** ترجمة الفئة إلى القيمة المحفوظة في `teacherProfiles.isOnline`. */
const CATEGORY_IS_ONLINE = Object.freeze({ online: true, inPerson: false });

const DEFAULT_CONFIG = Object.freeze({
  positionsPerCategory: 5,
  minBid: 100,
  bidStep: 25,
  extraBidLimit: 10,
  maxBid: 50000,
  // نوافذ الأسبوع (توقيت القاهرة). تُقرأ الساعة/الدقيقة من الإعداد.
  paymentWindowHours: 24,
  replacementWindowHours: 12,
  bidCutoffMinutes: BID_CUTOFF_MINUTES,
});

// ─────────────────────────────────────────────────────────────────────────────
// التوقيت: تحويل UTC ↔ توقيت القاهرة بلا مكتبات خارجية
// ─────────────────────────────────────────────────────────────────────────────

const partsFormatter = new Intl.DateTimeFormat('en-GB', {
  timeZone: TIME_ZONE,
  hour12: false,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  weekday: 'short',
});

/**
 * أجزاء التاريخ في توقيت القاهرة لِلحظة UTC معيّنة.
 * @param {Date} instant
 * @returns {{year:number, month:number, day:number, hour:number, minute:number, second:number, weekday:string}}
 */
function cairoParts(instant) {
  const parts = {};
  for (const { type, value } of partsFormatter.formatToParts(instant)) {
    if (type !== 'literal') parts[type] = value;
  }
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    // `hour12: false` يُعيد 24 لِمنتصف الليل في بعض إصدارات ICU.
    hour: Number(parts.hour) % 24,
    minute: Number(parts.minute),
    second: Number(parts.second),
    weekday: parts.weekday,
  };
}

/**
 * فارق توقيت القاهرة عن UTC بالدقائق عند لحظة معيّنة (+120 صيفًا، +180 شتاءً).
 * يُحسب من التنسيق نفسه فلا نضيف مكتبة تواريخ.
 * @param {Date} instant
 */
function cairoOffsetMinutes(instant) {
  const parts = cairoParts(instant);
  const asUtc = Date.UTC(
    parts.year,
    parts.month - 1,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
  );
  const truncated = Math.floor(instant.getTime() / 1000) * 1000;
  return Math.round((asUtc - truncated) / 60000);
}

/**
 * يبني لحظة UTC من تاريخ/وقت **محلي في القاهرة**.
 *
 * الحل بخطوتين: تخمين أولي بفارق معروف، ثم تصحيح إذا تغيّر الفارق عند اللحظة
 * الناتجة (حالة تغيير التوقيت الصيفي — مصر تُعيد العمل به في أبريل حتى 2027
 * على الأقل، فالاختبارات تغطي الحدود).
 * @param {{year:number, month:number, day:number, hour?:number, minute?:number, second?:number}} local
 * @returns {Date}
 */
function cairoTimeToUtc(local) {
  const { year, month, day } = local;
  const hour = local.hour ?? 0;
  const minute = local.minute ?? 0;
  const second = local.second ?? 0;
  const naive = Date.UTC(year, month - 1, day, hour, minute, second);
  let guess = new Date(naive - 120 * 60000);
  for (let i = 0; i < 2; i += 1) {
    const offset = cairoOffsetMinutes(guess);
    guess = new Date(naive - offset * 60000);
  }
  return guess;
}

/** هل اللحظة يوم في القاهرة؟ (0=الأحد … 6=السبت) */
function cairoWeekdayIndex(instant) {
  const map = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };
  return map[cairoParts(instant).weekday];
}

/** الاثنين 00:00 (توقيت القاهرة) لأسبوع اللحظة المعطاة. */
function cairoMondayStart(instant) {
  const parts = cairoParts(instant);
  const index = cairoWeekdayIndex(instant);
  const daysSinceMonday = (index + 6) % 7;
  return cairoTimeToUtc({
    year: parts.year,
    month: parts.month,
    day: parts.day - daysSinceMonday,
    hour: 0,
    minute: 0,
    second: 0,
  });
}

/** رقم أسبوع ISO 8601 (الاثنين بداية الأسبوع) — منه يُشتق `cycleKey`. */
function isoWeekKey(instant) {
  // نعمل على منتصف نهار الاثنين المحلي لتجنّب مشاكل الحدود.
  const monday = cairoMondayStart(instant);
  const thursday = new Date(monday.getTime() + 3 * 24 * 3600 * 1000);
  const parts = cairoParts(thursday);
  const year = parts.year;
  // أسبوع ISO 1 هو الأسبوع الذي يحتوي 4 يناير. نأخذ اثنين ذلك الأسبوع بدلًا
  // من «أول اثنين بعد 1 يناير» لأن الأخير يُخطئ سنةً كاملة حين يبدأ 1 يناير
  // يوم خميس (مثال 2026: الأسبوع 1 يبدأ 29 ديسمبر 2025).
  const jan4 = cairoTimeToUtc({ year, month: 1, day: 4 });
  const jan4Index = cairoWeekdayIndex(jan4);
  const firstMonday = new Date(
    jan4.getTime() - ((jan4Index + 6) % 7) * 24 * 3600 * 1000,
  );
  const week = 1 + Math.round((monday.getTime() - firstMonday.getTime()) / (7 * 24 * 3600 * 1000));
  return `${year}-W${String(week).padStart(2, '0')}`;
}

/**
 * جدول دورة أسبوعية كاملة من لحظة داخل الأسبوع.
 *
 * الحدود (كلها توقيت القاهرة):
 *   - فتح المزايدة: الاثنين 00:00 … إغلاقها: الأربعاء 23:59:59
 *   - آخر مزايدة مقبولة: الإغلاق − 10 دقائق
 *   - الإعلان والاعتماد: الخميس 09:00
 *   - آخر موعد لدفع الفائز: الجمعة 09:00 (24 ساعة)
 *   - دورة البديل: الجمعة 09:00 → 21:00 (12 ساعة، مرة واحدة)
 *   - العرض: السبت 00:00 → الجمعة القادمة 23:59:59
 *
 * @param {Date} instant
 * @param {Partial<typeof DEFAULT_CONFIG>} [config]
 */
function weeklySchedule(instant, config = {}) {
  const cfg = { ...DEFAULT_CONFIG, ...config };
  const parts = cairoParts(instant);
  const monday = cairoMondayStart(instant);
  const at = (dayOffset, hour, minute = 0) =>
    cairoTimeToUtc({
      year: parts.year,
      month: parts.month,
      day: parts.day - ((cairoWeekdayIndex(instant) + 6) % 7) + dayOffset,
      hour,
      minute,
    });

  const opensAt = monday;
  const closesAt = new Date(at(2, 23, 59).getTime() + 59 * 1000); // الأربعاء 23:59:59
  const bidCutoffAt = new Date(closesAt.getTime() - cfg.bidCutoffMinutes * 60000);
  const announcesAt = at(3, 9); // الخميس 09:00
  const paymentDeadline = new Date(announcesAt.getTime() + cfg.paymentWindowHours * 3600 * 1000);
  const replacementOpensAt = paymentDeadline;
  const replacementDeadline = new Date(
    replacementOpensAt.getTime() + cfg.replacementWindowHours * 3600 * 1000,
  );
  const displayStartsAt = at(5, 0); // السبت 00:00
  const displayEndsAt = new Date(at(11, 23, 59).getTime() + 59 * 1000); // الجمعة القادمة

  return {
    cycleKey: isoWeekKey(instant),
    timeZone: TIME_ZONE,
    opensAt,
    closesAt,
    bidCutoffAt,
    announcesAt,
    paymentDeadline,
    replacementOpensAt,
    replacementDeadline,
    displayStartsAt,
    displayEndsAt,
  };
}

/** مُعرّف مستند دورة فئة واحدة: `2026-W45-online`. */
function cycleId(cycleKey, category) {
  if (!CATEGORIES.includes(category)) {
    throw new AuctionError('invalid-category', 'فئة غير معروفة.');
  }
  return `${cycleKey}-${category}`;
}

// ─────────────────────────────────────────────────────────────────────────────
// الأخطاء
// ─────────────────────────────────────────────────────────────────────────────

/** خطأ مزاد يحمل رمزًا ثابتًا ورسالة عربية جاهزة للعرض. */
class AuctionError extends Error {
  /**
   * @param {string} code رمز ثابت للاختبار (لا يُعرض للمستخدم).
   * @param {string} message رسالة عربية مفهومة.
   */
  constructor(code, message) {
    super(message);
    this.name = 'AuctionError';
    this.code = code;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// الحالة المشتقة
// ─────────────────────────────────────────────────────────────────────────────

/**
 * الحالة المنطقية للدورة عند لحظة معيّنة — **محسوبة** لا مخزَّنة، فلا يمكن أن
 * تنحرف عن الساعة أو أن تُعدَّل من العميل.
 *
 * @param {object} auction مستند الدورة
 * @param {Date} now
 * @returns {'scheduled'|'open'|'gracePeriod'|'awaitingFinalize'|'paymentWindow'|'replacement'|'awaitingPublish'|'live'|'ended'}
 */
function deriveStatus(auction, now) {
  const t = now.getTime();
  const time = (value) => (value instanceof Date ? value.getTime() : new Date(value).getTime());
  if (auction.settledAt) return 'ended';
  if (t < time(auction.opensAt)) return 'scheduled';
  if (t < time(auction.bidCutoffAt)) return 'open';
  if (t < time(auction.closesAt)) return 'gracePeriod'; // آخر 10 دقائق: عرض فقط
  if (t < time(auction.announcesAt)) return 'awaitingFinalize';
  if (t < time(auction.paymentDeadline)) return 'paymentWindow';
  if (t < time(auction.replacementDeadline)) return 'replacement';
  return 'awaitingPublish';
}

/** هل المزايدة مسموحة الآن؟ (لا استثناءات إدارية: حتى المسؤول لا يزايد متأخرًا) */
function biddingOpen(auction, now) {
  return deriveStatus(auction, now) === 'open';
}

/** الثواني المتبقية للمزايدة (0 إن أُغلقت). */
function secondsToCutoff(auction, now) {
  const left = new Date(auction.bidCutoffAt).getTime() - now.getTime();
  return left > 0 ? Math.floor(left / 1000) : 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// المزايدة
// ─────────────────────────────────────────────────────────────────────────────

/**
 * يتحقق من مزايدة ويعيد الحالة الناتجة. لا يكتب شيئًا — القرار للخادم، والحفظ
 * في المعاملة يقع في الطبقة الأعلى.
 *
 * @param {object} input
 * @param {object} input.auction مستند الدورة (بحدوده الزمنية وإعداداته)
 * @param {{teacherId:string, isOnline:boolean, status:string, accountHidden?:boolean}} input.profile
 * @param {object|null} input.currentBid المزايدة الحالية للمدرّس أو null
 * @param {number} input.amount المبلغ المطلوب (جنيه مصري، عدد صحيح)
 * @param {Date} input.now ساعة الخادم
 * @returns {{amount:number, increasesUsed:number, isFirst:boolean}}
 * @throws {AuctionError}
 */
function validateBid({ auction, profile, currentBid, amount, now }) {
  if (!profile || profile.status !== 'verified') {
    throw new AuctionError('not-verified', 'المزاد متاح للمدرسين الموثّقين فقط.');
  }
  if (profile.accountHidden === true) {
    throw new AuctionError('account-hidden', 'ملفك مخفي، فلا يمكنك المشاركة في المزاد.');
  }
  const wantsOnline = CATEGORY_IS_ONLINE[auction.category];
  if (profile.isOnline !== wantsOnline) {
    throw new AuctionError('wrong-category', 'هذه الفئة لا تطابق طريقة تقديمك.');
  }

  const status = deriveStatus(auction, now);
  if (status === 'scheduled') {
    throw new AuctionError('not-open', 'لم يبدأ المزاد بعد.');
  }
  if (status === 'gracePeriod') {
    throw new AuctionError(
      'closed-last-minutes',
      'أُغلقت المزايدة: لا تُقبل مزايدات في آخر 10 دقائق.',
    );
  }
  if (status !== 'open') {
    throw new AuctionError('closed', 'انتهى وقت المزاد لهذا الأسبوع.');
  }

  if (!Number.isInteger(amount) || amount <= 0) {
    throw new AuctionError('invalid-amount', 'أدخل مبلغًا صحيحًا بالجنيه.');
  }
  const maxBid = auction.maxBid ?? DEFAULT_CONFIG.maxBid;
  if (amount > maxBid) {
    throw new AuctionError('amount-too-high', `الحد الأقصى للمزايدة ${maxBid} جنيهًا.`);
  }

  const step = auction.bidStep ?? DEFAULT_CONFIG.bidStep;
  const limit = auction.extraBidLimit ?? DEFAULT_CONFIG.extraBidLimit;

  if (!currentBid) {
    if (amount < auction.minBid) {
      throw new AuctionError(
        'below-min',
        `أقل مزايدة في هذه الفئة ${auction.minBid} جنيهًا.`,
      );
    }
    return { amount, increasesUsed: 0, isFirst: true };
  }

  if ((currentBid.increasesUsed ?? 0) >= limit) {
    throw new AuctionError(
      'no-increases-left',
      `استنفدت ${limit} زيادات مجانية. مزايدتك الحالية هي الأخيرة.`,
    );
  }
  if (amount < currentBid.amount + step) {
    throw new AuctionError(
      'below-step',
      `أقل زيادة مقبولة ${step} جنيهًا فوق مزايدتك الحالية.`,
    );
  }
  return {
    amount,
    increasesUsed: (currentBid.increasesUsed ?? 0) + 1,
    isFirst: false,
  };
}

/** أقل مبلغ مسموح للمزايدة التالية (للعرض في الواجهة؛ الخادم يتحقق بنفسه). */
function nextMinimumBid(auction, currentBid) {
  const step = auction.bidStep ?? DEFAULT_CONFIG.bidStep;
  return currentBid ? currentBid.amount + step : auction.minBid;
}

/** هل استنفد المدرّس زياداته المجانية؟ */
function increasesRemaining(auction, currentBid) {
  const limit = auction.extraBidLimit ?? DEFAULT_CONFIG.extraBidLimit;
  const used = currentBid?.increasesUsed ?? 0;
  return Math.max(0, limit - used);
}

// ─────────────────────────────────────────────────────────────────────────────
// الترتيب واختيار الفائزين
// ─────────────────────────────────────────────────────────────────────────────

/**
 * ترتيب حتمي للمزايدات:
 *   1) المبلغ تنازليًا.
 *   2) الأسبق مزايدةً أولًا (من قدّم المبلغ أولًا يفوز عند التعادل).
 *   3) معرّف المدرّس تصاعديًا (فاصل نهائي لا يعتمد على ترتيب القراءة).
 *
 * @param {Array<{teacherId:string, amount:number, placedAt:(Date|string|number), lastBidAt?:any}>} bids
 */
function rankBids(bids) {
  const at = (value) => (value instanceof Date ? value.getTime() : new Date(value).getTime());
  return [...bids].sort((a, b) => {
    if (b.amount !== a.amount) return b.amount - a.amount;
    const firstA = at(a.placedAt);
    const firstB = at(b.placedAt);
    if (firstA !== firstB) return firstA - firstB;
    return a.teacherId < b.teacherId ? -1 : a.teacherId > b.teacherId ? 1 : 0;
  });
}

/**
 * الفائزون: أعلى `positions` مزايدة بعد الترتيب.
 *
 * @param {Array} bids
 * @param {number} positions
 * @param {{exclude?: Set<string>}} [options] مستبعدون (فائزون سابقون لم يدفعوا)
 */
function selectWinners(bids, positions, options = {}) {
  const exclude = options.exclude ?? new Set();
  return rankBids(bids)
    .filter((bid) => !exclude.has(bid.teacherId))
    .slice(0, Math.max(0, positions));
}

/**
 * دورة البديل **الواحدة**: عند انقضاء مهلة الدفع، كل مقعد لم يُدفع يُعرض على
 * التالي في الترتيب (خارج الفائزين الأصليين ومن لم يدفع).
 *
 * - لا تُستدعى إلا إذا `replacementRound === 0` (مرة واحدة لكل دورة).
 * - تُعيد المقاعد الجديدة؛ وإن لم يوجد مرشّح يبقى المقعد فارغًا نهائيًا.
 *
 * @param {object} input
 * @param {Array} input.bids كل المزايدات
 * @param {Array<{teacherId:string, paid:boolean}>} input.winners الفائزون الأصليون
 * @param {number} input.positions
 */
function buildReplacement({ bids, winners, positions }) {
  const unpaid = winners.filter((winner) => !winner.paid);
  const emptySeats = unpaid.length + Math.max(0, positions - winners.length);
  if (emptySeats === 0) {
    return { seats: 0, filled: [], emptySeats: 0 };
  }
  const taken = new Set(winners.map((winner) => winner.teacherId));
  const candidates = rankBids(bids).filter((bid) => !taken.has(bid.teacherId));
  const filled = candidates.slice(0, emptySeats);
  return {
    seats: emptySeats,
    filled,
    emptySeats: emptySeats - filled.length,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// التكرار (idempotency) والحماية من إعادة الإرسال
// ─────────────────────────────────────────────────────────────────────────────

/** تحقق من معرّف طلب صالح للتكرار. */
function assertRequestId(requestId) {
  if (typeof requestId !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(requestId)) {
    throw new AuctionError('invalid-request-id', 'طلب غير صالح. أعد المحاولة.');
  }
  return requestId;
}

/** معرّف مستند التكرار: مقصور على المستخدم والطلب معًا. */
function idempotencyDocId(uid, requestId) {
  return `${uid}_${requestId}`;
}

// ─────────────────────────────────────────────────────────────────────────────
// التمييز (العرض العام)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * الحمولة التي تُطبَّق على `teacherProfiles` للفائزين المدفوعين.
 *
 * الترتيب في الشريط: ترتيب الفائز في فئته (0..4)، والفئتان تتشاركان الشريط
 * بترتيب ثابت (online أولًا). يُعيد قائمة جاهزة للكتابة الدفعية.
 *
 * @param {{online:Array, inPerson:Array}} winnersByCategory
 */
function featuredAssignments(winnersByCategory) {
  const assignments = [];
  for (const category of CATEGORIES) {
    const list = winnersByCategory[category] ?? [];
    list.forEach((winner, index) => {
      assignments.push({
        teacherId: winner.teacherId,
        category,
        featuredOrder: (category === 'online' ? 0 : 5) + index,
      });
    });
  }
  return assignments;
}

// ─────────────────────────────────────────────────────────────────────────────
// التصدير
// ─────────────────────────────────────────────────────────────────────────────

module.exports = {
  TIME_ZONE,
  BID_CUTOFF_MINUTES,
  CATEGORIES,
  CATEGORY_IS_ONLINE,
  DEFAULT_CONFIG,
  AuctionError,
  cairoParts,
  cairoOffsetMinutes,
  cairoTimeToUtc,
  cairoWeekdayIndex,
  cairoMondayStart,
  isoWeekKey,
  weeklySchedule,
  cycleId,
  deriveStatus,
  biddingOpen,
  secondsToCutoff,
  validateBid,
  nextMinimumBid,
  increasesRemaining,
  rankBids,
  selectWinners,
  buildReplacement,
  assertRequestId,
  idempotencyDocId,
  featuredAssignments,
};
