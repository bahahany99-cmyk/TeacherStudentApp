/**
 * عمليات المزاد — طبقة الخدمة (بلا Firebase).
 *
 * كل دالة هنا تأخذ `store` (مستودع قابل للحقن) و`now` (ساعة الخادم)، وتُعيد
 * نتيجة موصوفة. الاختبارات تستخدم مستودعًا في الذاكرة (`test/memory_store.js`)
 * فتُثبِت السلوك كاملًا بلا محاكي: التزامن، والتكرار، والمهل، والدورة الواحدة.
 *
 * **قاعدة ذهبية:** لا يُحسب أي قرار (أهلية، حد زمني، ترتيب، فائز) في التطبيق.
 * العميل يقرأ وينادي دالة سحابية؛ والكتابة على مستندات المزاد ممنوعة في القواعد.
 */

'use strict';

const core = require('./auction_core');

const { AuctionError } = core;

/** أنواع إشعارات المزاد — يجب أن تطابق `NotificationType` في تطبيق Flutter. */
const AUCTION_NOTIFICATION_TYPES = Object.freeze({
  won: 'auctionWon',
  replacement: 'auctionReplacement',
  paymentExpired: 'auctionPaymentExpired',
});

/**
 * يضمن وجود دورتَي الأسبوع الحالي والقادم لكل فئة.
 *
 * يُستدعى من المجدول الأسبوعي وعند أول قراءة إدارية؛ والتكرار آمن لأن الإنشاء
 * مشروط بعدم الوجود (`createIfAbsent`) في نفس المعاملة.
 *
 * @param {{store:object, now:Date, config?:object, actor?:string}} input
 */
async function ensureWeeklyCycles({ store, now, config, actor }) {
  const cfg = { ...core.DEFAULT_CONFIG, ...(config ?? (await store.getConfig())) };
  const week = core.weeklySchedule(now, cfg);
  const nextWeek = core.weeklySchedule(new Date(week.opensAt.getTime() + 7 * 86400000), cfg);
  const created = [];

  for (const schedule of [week, nextWeek]) {
    for (const category of core.CATEGORIES) {
      const id = core.cycleId(schedule.cycleKey, category);
      const exists = await store.getAuction(id);
      if (exists) continue;
      const createdNow = await store.createAuction(id, {
        id,
        cycleKey: schedule.cycleKey,
        category,
        timeZone: core.TIME_ZONE,
        opensAt: schedule.opensAt,
        closesAt: schedule.closesAt,
        bidCutoffAt: schedule.bidCutoffAt,
        announcesAt: schedule.announcesAt,
        paymentDeadline: schedule.paymentDeadline,
        replacementOpensAt: schedule.replacementOpensAt,
        replacementDeadline: schedule.replacementDeadline,
        displayStartsAt: schedule.displayStartsAt,
        displayEndsAt: schedule.displayEndsAt,
        minBid: cfg.minBid,
        bidStep: cfg.bidStep,
        extraBidLimit: cfg.extraBidLimit,
        maxBid: cfg.maxBid,
        positions: cfg.positionsPerCategory,
        bidCount: 0,
        biddersCount: 0,
        highestBid: 0,
        finalizedAt: null,
        publishedAt: null,
        settledAt: null,
        replacementRound: 0,
        createdAt: now,
      });
      // `create` لا `set`: لو أنشأ مجدول آخر الدورة في اللحظة نفسها فلا نكتب
      // فوقها (ولا نُسجّلها مرتين في الأثر).
      if (createdNow) created.push(id);
    }
  }
  if (created.length > 0) {
    await store.appendAudit({
      at: now,
      actor: actor ?? 'system',
      action: 'cycles.create',
      detail: created.join(', '),
    });
  }
  return { created };
}

/**
 * مزايدة واحدة — ذرّية بالكامل.
 *
 * الحماية:
 *   - **المعاملة** تجعل «قراءة الحالة ثم الكتابة» وحدة واحدة، فلا سباق.
 *   - **معرّف الطلب** يُخزَّن في نفس المعاملة، فإعادة الإرسال تعيد النتيجة
 *     المخزّنة بلا مضاعفة الزيادة.
 *   - كل الحدود تُقرأ **من داخل المعاملة** (لا من قراءة سابقة).
 *
 * @param {{store:object, now:Date, uid:string, cycleKey:string, category:string,
 *          amount:number, requestId:string}} input
 */
async function placeBid({ store, now, uid, cycleKey, category, amount, requestId }) {
  const requestKey = core.idempotencyDocId(uid, core.assertRequestId(requestId));
  const auctionId = core.cycleId(cycleKey, category);

  return store.transaction(async (tx) => {
    const replay = await tx.getIdempotency(requestKey);
    if (replay) {
      // إعادة إرسال نفس الطلب: نفس النتيجة، بلا أي كتابة جديدة.
      return { ...replay, replayed: true };
    }

    const auction = await tx.getAuction(auctionId);
    if (!auction) {
      throw new AuctionError('no-auction', 'لا يوجد مزاد لهذا الأسبوع في هذه الفئة.');
    }
    // (1) حدّ الإغلاق والـ10 دقائق — كلها على ساعة الخادم.
    const status = core.deriveStatus(auction, now);
    const profile = await tx.getProfile(uid);
    const currentBid = await tx.getBid(auctionId, uid);

    // (البند 2) التحقق الكامل قبل أي كتابة.
    const outcome = core.validateBid({ auction, profile, currentBid, amount, now });

    const bid = {
      teacherId: uid,
      displayName: profile.displayName ?? '',
      amount: outcome.amount,
      increasesUsed: outcome.increasesUsed,
      placedAt: currentBid?.placedAt ?? now,
      lastBidAt: now,
      updatedAt: now,
      status,
    };

    const isNewBidder = !currentBid;
    await tx.setBid(auctionId, uid, bid);
    await tx.setAuction(auctionId, {
      ...auction,
      bidCount: (auction.bidCount ?? 0) + 1,
      biddersCount: (auction.biddersCount ?? 0) + (isNewBidder ? 1 : 0),
      highestBid: Math.max(auction.highestBid ?? 0, outcome.amount),
      lastBidAt: now,
      updatedAt: now,
    });

    const result = {
      auctionId,
      amount: outcome.amount,
      increasesUsed: outcome.increasesUsed,
      increasesRemaining: core.increasesRemaining(auction, bid),
      nextMinimum: core.nextMinimumBid(auction, bid),
      isFirst: outcome.isFirst,
      replayed: false,
    };
    // (2) تخزين بصمة الطلب **داخل المعاملة** ⇒ لا ازدواج مهما توالت المحاولات.
    await tx.setIdempotency(requestKey, { ...result, at: now });
    await tx.appendAudit({
      at: now,
      actor: uid,
      action: 'bid.place',
      detail: `${auctionId}: ${outcome.amount}`,
    });
    return result;
  });
}

/**
 * إغلاق المزاد وتعيين الفائزين (الخميس 09:00 أو يدويًا).
 *
 * - **حتمي:** الترتيب من `rankBids` (مبلغ ← أسبق ← معرّف).
 * - **متكرر بأمان:** إن كان `finalizedAt` موجودًا يعيد النتيجة بلا تغيير.
 * - المراكز غير المملوءة (قلة المزايدات) تبقى فارغة ولا تُوزَّع قسرًا.
 */
async function finalizeAuction({ store, now, auctionId, actor }) {
  return store.transaction(async (tx) => {
    const auction = await tx.getAuction(auctionId);
    if (!auction) {
      throw new AuctionError('no-auction', 'دورة غير موجودة.');
    }
    if (auction.finalizedAt) {
      return {
        auctionId,
        alreadyFinalized: true,
        winners: (await tx.listWinners(auctionId)).map((w) => w.teacherId),
        emptySeats: (await tx.listWinners(auctionId)).filter(
          (w) => w.status === 'unfilled',
        ).length,
      };
    }
    // لا إعلان قبل موعده: يمنع «حسم مبكر» يغيّر نتيجة مزاد جارٍ.
    if (now.getTime() < new Date(auction.closesAt).getTime() && actor !== 'admin-override') {
      throw new AuctionError('too-early', 'لا يمكن إعلان النتائج قبل إغلاق المزاد.');
    }

    const bids = await tx.listBids(auctionId);
    const selected = core.selectWinners(bids, auction.positions);
    const winners = [];
    for (let rank = 0; rank < selected.length; rank += 1) {
      const bid = selected[rank];
      const winner = {
        teacherId: bid.teacherId,
        displayName: bid.displayName ?? '',
        rank: rank + 1,
        amount: bid.amount,
        round: 1,
        status: 'pendingPayment',
        deadline: auction.paymentDeadline,
        notifiedAt: null,
        confirmedAt: null,
        confirmedBy: null,
      };
      await tx.setWinner(auctionId, bid.teacherId, winner);
      winners.push(winner);
    }

    const emptySeats = Math.max(0, auction.positions - selected.length);
    await tx.setAuction(auctionId, {
      ...auction,
      finalizedAt: now,
      finalizedBy: actor ?? 'system',
      winnersCount: selected.length,
      emptySeats,
      updatedAt: now,
    });
    await tx.appendAudit({
      at: now,
      actor: actor ?? 'system',
      action: 'auction.finalize',
      detail: `${auctionId}: ${selected.length}/${auction.positions}`,
    });

    // الإشعارات: الفائز يعرف فوزه وموعد الدفع، بلا أي معلومة عن منافسيه.
    for (const winner of winners) {
      await tx.notify({
        recipientId: winner.teacherId,
        type: AUCTION_NOTIFICATION_TYPES.won,
        actorId: 'system',
        actorName: 'درسلي',
        targetId: auctionId,
        title: 'فزت في مزاد التمييز',
        body:
          `فزت بالمركز ${winner.rank} في فئة ` +
          `${auction.category === 'online' ? 'المدرسين عن بُعد' : 'المدرسين حضوريًا'}. ` +
          'أكمل الدفع قبل انتهاء المهلة لتظهر في شريط المميزين.',
        createdAt: now,
      });
      await tx.setWinner(auctionId, winner.teacherId, { ...winner, notifiedAt: now });
    }
    return { auctionId, alreadyFinalized: false, winners, emptySeats };
  });
}

/**
 * تأكيد/رفض دفع فائز (إداري، أو بعد التحقق من وسيلة الدفع المعتمدة).
 *
 * لا بوّابة دفع: الحالة تُسجَّل بأمر إداري موثّق (من حصّل المبلغ فعلًا).
 * - لا يُقبل الدفع بعد انتهاء مهلة المرحلة الحالية.
 * - لا تتغيّر حالة `paid` بعد تثبيتها (لا استرجاع تلقائي).
 */
async function confirmWinnerPayment({ store, now, auctionId, teacherId, paid, actor, note }) {
  if (typeof actor !== 'string' || actor.length === 0) {
    throw new AuctionError('unauthorized', 'فعل إداري بلا هوية.');
  }
  return store.transaction(async (tx) => {
    const auction = await tx.getAuction(auctionId);
    if (!auction) throw new AuctionError('no-auction', 'دورة غير موجودة.');
    const winner = await tx.getWinner(auctionId, teacherId);
    if (!winner) throw new AuctionError('no-winner', 'هذا المدرس ليس فائزًا في الدورة.');

    if (winner.status === 'paid') {
      return { auctionId, teacherId, status: 'paid', alreadyPaid: true };
    }
    if (winner.status === 'unfilled') {
      throw new AuctionError('unfilled', 'مقعد غير مُسنَد.');
    }

    const deadline =
      winner.round === 2 ? auction.replacementDeadline : auction.paymentDeadline;
    if (paid && now.getTime() > new Date(deadline).getTime()) {
      throw new AuctionError('payment-late', 'انتهت مهلة الدفع لهذا المقعد.');
    }

    const nextStatus = paid ? 'paid' : 'unpaid';
    const updated = {
      ...winner,
      status: nextStatus,
      confirmedAt: now,
      confirmedBy: actor,
      note: note ?? null,
    };
    await tx.setWinner(auctionId, teacherId, updated);
    await tx.appendAudit({
      at: now,
      actor,
      action: paid ? 'payment.confirm' : 'payment.reject',
      detail: `${auctionId}/${teacherId}`,
    });
    return { auctionId, teacherId, status: nextStatus, alreadyPaid: false };
  });
}

/**
 * دورة البديل — **مرة واحدة فقط** لكل دورة.
 *
 * - تُشغَّل بعد انقضاء مهلة الدفع (الجمعة 09:00).
 * - المقاعد غير المدفوعة تُعرض على التالي في الترتيب (خارج الفائزين الأصليين).
 * - `replacementRound` يصير 1؛ أي استدعاء لاحق لا يُنشئ دورة ثانية، والمقاعد
 *   التي لا مرشّح لها تبقى **فارغة نهائيًا**.
 */
async function runReplacementRound({ store, now, auctionId, actor }) {
  return store.transaction(async (tx) => {
    const auction = await tx.getAuction(auctionId);
    if (!auction) throw new AuctionError('no-auction', 'دورة غير موجودة.');
    if (auction.replacementRound >= 1) {
      return {
        auctionId,
        alreadyRan: true,
        seats: [],
        emptySeats: (await tx.listWinners(auctionId)).filter(
          (w) => w.status === 'unfilled',
        ).length,
      };
    }
    if (now.getTime() < new Date(auction.paymentDeadline).getTime()) {
      throw new AuctionError('too-early', 'لم تنتهِ مهلة الدفع بعد.');
    }

    const winners = await tx.listWinners(auctionId);
    const bids = await tx.listBids(auctionId);

    // من لم يدفع يُثبَّت «unpaid» حتى لا يُسند إليه مقعد لاحقًا.
    const normalized = [];
    for (const winner of winners) {
      if (winner.status === 'pendingPayment') {
        const updated = { ...winner, status: 'unpaid', expiredAt: now };
        await tx.setWinner(auctionId, winner.teacherId, updated);
        normalized.push(updated);
      } else {
        normalized.push(winner);
      }
    }

    const plan = core.buildReplacement({
      bids,
      winners: normalized.map((winner) => ({
        teacherId: winner.teacherId,
        paid: winner.status === 'paid',
      })),
      positions: auction.positions,
    });

    const newWinners = [];
    for (let index = 0; index < plan.filled.length; index += 1) {
      const bid = plan.filled[index];
      const winner = {
        teacherId: bid.teacherId,
        displayName: bid.displayName ?? '',
        rank: null,
        amount: bid.amount,
        round: 2,
        status: 'pendingPayment',
        deadline: auction.replacementDeadline,
        notifiedAt: now,
        confirmedAt: null,
        confirmedBy: null,
      };
      await tx.setWinner(auctionId, bid.teacherId, winner);
      newWinners.push(winner);
      await tx.notify({
        recipientId: bid.teacherId,
        type: AUCTION_NOTIFICATION_TYPES.replacement,
        actorId: 'system',
        actorName: 'درسلي',
        targetId: auctionId,
        title: 'مقعد متاح لك في مزاد التمييز',
        body: 'توفّر مقعد في دورة البديل. أكمل الدفع قبل انتهاء مهلة البديل لتظهر في شريط المميزين.',
        createdAt: now,
      });
    }

    for (const winner of normalized.filter((w) => w.status === 'unpaid')) {
      await tx.notify({
        recipientId: winner.teacherId,
        type: AUCTION_NOTIFICATION_TYPES.paymentExpired,
        actorId: 'system',
        actorName: 'درسلي',
        targetId: auctionId,
        title: 'انتهت مهلة الدفع',
        body: 'لم يُسجَّل دفع مزايدتك الفائزة، فأُتيح المقعد لدورة البديل.',
        createdAt: now,
      });
    }

    await tx.setAuction(auctionId, {
      ...auction,
      replacementRound: 1,
      replacementRanAt: now,
      replacementFilled: newWinners.length,
      emptySeats: plan.emptySeats,
      updatedAt: now,
    });
    await tx.appendAudit({
      at: now,
      actor: actor ?? 'system',
      action: 'auction.replacement',
      detail: `${auctionId}: seats=${plan.seats}, filled=${newWinners.length}, empty=${plan.emptySeats}`,
    });
    return {
      auctionId,
      alreadyRan: false,
      seats: plan.seats,
      newWinners,
      emptySeats: plan.emptySeats,
    };
  });
}

/**
 * نشر التمييز (السبت 00:00): يُطبَّق على الملفات المدفوعة فقط.
 *
 * - يُنشر مرة واحدة (`publishedAt`).
 * - المستند العام `auctionResults/{auctionId}` يحمل الأسماء والمراكز **بلا
 *   مبالغ** — المزايدات تبقى خاصة.
 */
async function publishFeatured({ store, now, auctionId, actor }) {
  return store.transaction(async (tx) => {
    const auction = await tx.getAuction(auctionId);
    if (!auction) throw new AuctionError('no-auction', 'دورة غير موجودة.');
    if (auction.publishedAt) {
      return { auctionId, alreadyPublished: true, published: [] };
    }
    if (now.getTime() < new Date(auction.displayStartsAt).getTime()) {
      throw new AuctionError('too-early', 'لا يبدأ العرض قبل السبت 00:00.');
    }

    const winners = await tx.listWinners(auctionId);
    const paid = winners
      .filter((winner) => winner.status === 'paid')
      .sort((a, b) => (a.rank ?? 99) - (b.rank ?? 99) || (b.amount - a.amount));

    // الحمولة العامة: أسماء ومراكز فقط، بلا مبالغ ولا هويات منافسين خاسرين.
    const publicWinners = paid.map((winner, index) => ({
      teacherId: winner.teacherId,
      displayName: winner.displayName,
      rank: index + 1,
      round: winner.round,
    }));
    await tx.setResults(auctionId, {
      auctionId,
      cycleKey: auction.cycleKey,
      category: auction.category,
      published: true,
      publishedAt: now,
      winners: publicWinners,
      emptySeats: Math.max(0, auction.positions - publicWinners.length),
    });

    const assignments = core.featuredAssignments({
      [auction.category]: publicWinners.map((winner, index) => ({
        teacherId: winner.teacherId,
        featuredOrder: index,
      })),
    });
    await tx.setFeaturedFlags(assignments);
    await tx.setAuction(auctionId, {
      ...auction,
      publishedAt: now,
      publishedBy: actor ?? 'system',
      featuredCount: publicWinners.length,
      updatedAt: now,
    });
    await tx.appendAudit({
      at: now,
      actor: actor ?? 'system',
      action: 'auction.publish',
      detail: `${auctionId}: ${publicWinners.length} featured`,
    });
    return { auctionId, alreadyPublished: false, published: publicWinners };
  });
}

/**
 * إنهاء التمييز في نهاية الأسبوع (الجمعة 23:59): يرفع العلم عن **من ميّزناه**
 * فقط، ويُبقي التمييز اليدوي للإدارة كما هو.
 */
async function expireFeatured({ store, now, auctionId, actor }) {
  return store.transaction(async (tx) => {
    const auction = await tx.getAuction(auctionId);
    if (!auction) throw new AuctionError('no-auction', 'دورة غير موجودة.');
    if (auction.settledAt) {
      return { auctionId, alreadySettled: true, cleared: [] };
    }
    const results = await tx.getResults(auctionId);
    const cleared = (results?.winners ?? []).map((winner) => winner.teacherId);
    if (cleared.length > 0) {
      await tx.setFeaturedFlags(
        cleared.map((teacherId) => ({ teacherId, isFeatured: false, featuredOrder: 0 })),
      );
    }
    await tx.setAuction(auctionId, {
      ...auction,
      settledAt: now,
      settledBy: actor ?? 'system',
      updatedAt: now,
    });
    await tx.appendAudit({
      at: now,
      actor: actor ?? 'system',
      action: 'auction.expire',
      detail: `${auctionId}: cleared ${cleared.length}`,
    });
    return { auctionId, alreadySettled: false, cleared };
  });
}

/**
 * تعديل إعدادات المزاد (إداري فقط): يُتحقق من النطاقات ثم يُحفظ كاملًا.
 * التغيير يسري على **الدورات القادمة** فقط؛ الدورات القائمة تحتفظ بشروطها.
 */
async function updateConfig({ store, now, actor, patch }) {
  if (typeof actor !== 'string' || actor.length === 0) {
    throw new AuctionError('unauthorized', 'فعل إداري بلا هوية.');
  }
  const current = { ...core.DEFAULT_CONFIG, ...(await store.getConfig()) };
  const next = { ...current, ...patch };

  const intInRange = (value, min, max) =>
    Number.isInteger(value) && value >= min && value <= max;
  if (!intInRange(next.positionsPerCategory, 1, 10)) {
    throw new AuctionError('invalid-config', 'عدد المقاعد يجب أن يكون بين 1 و10.');
  }
  if (!intInRange(next.minBid, 1, 1000000)) {
    throw new AuctionError('invalid-config', 'أقل مزايدة غير صالحة.');
  }
  if (!intInRange(next.bidStep, 1, 100000)) {
    throw new AuctionError('invalid-config', 'قيمة الزيادة غير صالحة.');
  }
  if (!intInRange(next.extraBidLimit, 0, 50)) {
    throw new AuctionError('invalid-config', 'عدد الزيادات المجانية يجب أن يكون بين 0 و50.');
  }
  if (!intInRange(next.maxBid, next.minBid, 10000000)) {
    throw new AuctionError('invalid-config', 'الحد الأقصى يجب أن يكون ≥ أقل مزايدة.');
  }
  if (!intInRange(next.paymentWindowHours, 1, 168)) {
    throw new AuctionError('invalid-config', 'مهلة الدفع يجب أن تكون بين ساعة و168 ساعة.');
  }
  if (!intInRange(next.replacementWindowHours, 1, 72)) {
    throw new AuctionError('invalid-config', 'مهلة البديل يجب أن تكون بين ساعة و72 ساعة.');
  }

  await store.setConfig(next, actor, now);
  await store.appendAudit({
    at: now,
    actor,
    action: 'config.update',
    detail: JSON.stringify(patch),
  });
  return next;
}

// ─────────────────────────────────────────────────────────────────────────────
// قراءات للعرض (بلا قرار) — تُغذّي واجهة المدرّس ولوحة الإدارة
// ─────────────────────────────────────────────────────────────────────────────

/** التاريخ كما يعبر إلى العميل: ميلي ثانية UTC (لا `Timestamp` تفهمه Dart فقط). */
const ms = (value) => {
  if (value == null) return null;
  if (value instanceof Date) return value.getTime();
  if (typeof value?.toDate === 'function') return value.toDate().getTime();
  const parsed = new Date(value).getTime();
  return Number.isNaN(parsed) ? null : parsed;
};

/** الأسطر العامة من النتائج: أسماء ومراكز بلا مبالغ (نفس ما تكتبه `publishFeatured`). */
function publicResults(results) {
  if (!results || results.published !== true) return null;
  return {
    auctionId: results.auctionId ?? null,
    cycleKey: results.cycleKey ?? null,
    category: results.category ?? null,
    publishedAt: ms(results.publishedAt),
    emptySeats: results.emptySeats ?? 0,
    winners: (results.winners ?? []).map((winner) => ({
      teacherId: winner.teacherId,
      displayName: winner.displayName ?? '',
      rank: winner.rank ?? null,
      round: winner.round ?? 1,
    })),
  };
}

/**
 * حالة الأسبوع كما يراها **مدرّس واحد**.
 *
 * يُعاد فقط ما يحقّ له رؤيته:
 *   - حالة الأسبوع وحدوده (عرض العدّاد) وإعداداته العلنية (أقل مزايدة، الخطوة)،
 *   - **مزايدته هو** ورصيد زياداته وأدنى مزايدة تالية،
 *   - **مقعده هو** إن كان فائزًا (المركز، المهلة، حالة الدفع)،
 *   - النتائج المنشورة (أسماء ومراكز) — وهي بيانات عامة أصلًا.
 *
 * ولا يُعاد: `highestBid`، ولا عدد المزايدين، ولا أي مزايدة أو هوية منافس.
 *
 * @param {{store:object, now:Date, uid:string}} input
 */
async function getTeacherAuctionState({ store, now, uid }) {
  const profile = await store.getProfile(uid);
  if (!profile) {
    throw new AuctionError('not-verified', 'لا يوجد ملف مدرّس لهذا الحساب.');
  }
  // الفئة يحدّدها **الخادم** من الملف، لا العميل: لا يمكن ادّعاء فئة أخرى.
  const category = profile.isOnline === true ? 'online' : 'inPerson';
  const config = { ...core.DEFAULT_CONFIG, ...(await store.getConfig()) };

  let schedule = core.weeklySchedule(now, config);
  let auctionId = core.cycleId(schedule.cycleKey, category);
  let auction = await store.getAuction(auctionId);

  // (تكسّب تشغيلي) إن لم يكن المجدول قد أنشأ الدورة بعد، نُنشئها الآن. العملية
  // idempotent (`create` لا `set`)، فلا تُدهس دورة قائمة بمزايداتها.
  if (!auction) {
    await ensureWeeklyCycles({ store, now, config, actor: 'lazy' });
    auction = await store.getAuction(auctionId);
  }
  if (!auction) {
    throw new AuctionError('no-auction', 'لم تُفتح دورة هذا الأسبوع بعد. حاول لاحقًا.');
  }
  schedule = {
    cycleKey: auction.cycleKey,
    opensAt: auction.opensAt,
    closesAt: auction.closesAt,
    bidCutoffAt: auction.bidCutoffAt,
    announcesAt: auction.announcesAt,
    paymentDeadline: auction.paymentDeadline,
    replacementDeadline: auction.replacementDeadline,
    displayStartsAt: auction.displayStartsAt,
    displayEndsAt: auction.displayEndsAt,
  };

  const [myBid, myWinner, results] = await Promise.all([
    store.getBid(auctionId, uid),
    store.getWinner(auctionId, uid),
    store.getResults(auctionId),
  ]);

  const eligible =
    profile.status === 'verified' && profile.accountHidden !== true;

  return {
    serverNow: now.getTime(),
    timeZone: core.TIME_ZONE,
    cycleKey: auction.cycleKey,
    auctionId,
    category,
    phase: core.deriveStatus(auction, now),
    opensAt: ms(schedule.opensAt),
    closesAt: ms(schedule.closesAt),
    bidCutoffAt: ms(schedule.bidCutoffAt),
    announcesAt: ms(schedule.announcesAt),
    paymentDeadline: ms(schedule.paymentDeadline),
    replacementDeadline: ms(schedule.replacementDeadline),
    displayStartsAt: ms(schedule.displayStartsAt),
    displayEndsAt: ms(schedule.displayEndsAt),
    minBid: auction.minBid ?? config.minBid,
    bidStep: auction.bidStep ?? config.bidStep,
    extraBidLimit: auction.extraBidLimit ?? config.extraBidLimit,
    maxBid: auction.maxBid ?? config.maxBid,
    positions: auction.positions ?? config.positionsPerCategory,
    bidCutoffMinutes: config.bidCutoffMinutes ?? core.BID_CUTOFF_MINUTES,
    eligible,
    eligibility: eligible
      ? null
      : profile.accountHidden === true
        ? 'accountHidden'
        : 'notVerified',
    // مزايدتي أنا فقط.
    myBid: myBid
      ? {
          amount: myBid.amount,
          increasesUsed: myBid.increasesUsed ?? 0,
          placedAt: ms(myBid.placedAt),
          lastBidAt: ms(myBid.lastBidAt),
        }
      : null,
    increasesRemaining: core.increasesRemaining(auction, myBid),
    nextMinimum: core.nextMinimumBid(auction, myBid),
    // مقعدي أنا فقط (إن فزت).
    myWinner: myWinner
      ? {
          rank: myWinner.rank ?? null,
          status: myWinner.status,
          round: myWinner.round ?? 1,
          amount: myWinner.amount ?? null,
          deadline: ms(
            myWinner.round === 2 ? auction.replacementDeadline : auction.paymentDeadline,
          ),
          paid: myWinner.status === 'paid',
        }
      : null,
    results: publicResults(results),
  };
}

/**
 * النتائج المعروضة الآن — لكل فئة، على شاشة «المميزون» العامة.
 *
 * **بلا فهرس مركّب:** المعرّفات مشتقة (`{cycleKey}-{category}`)، فنقرأ دورتين
 * فقط: دورة هذا الأسبوع (تُنشر السبت) ودورة الأسبوع الماضي (عرضها يستمر حتى
 * الجمعة 23:59). الأولى تُقدَّم إن كانت منشورة، وإلا فالثانية.
 *
 * @param {{store:object, now:Date}} input
 */
async function getFeaturedResults({ store, now }) {
  const config = { ...core.DEFAULT_CONFIG, ...(await store.getConfig()) };
  const current = core.weeklySchedule(now, config);
  const previous = core.weeklySchedule(
    new Date(current.opensAt.getTime() - 24 * 3600 * 1000),
    config,
  );

  const categories = {};
  for (const category of core.CATEGORIES) {
    categories[category] = null;
    for (const key of [current.cycleKey, previous.cycleKey]) {
      const doc = await store.getResults(core.cycleId(key, category));
      if (doc && doc.published === true) {
        categories[category] = publicResults(doc);
        break;
      }
    }
  }

  return {
    serverNow: now.getTime(),
    timeZone: core.TIME_ZONE,
    displayCycleKey:
      categories.online?.cycleKey ?? categories.inPerson?.cycleKey ?? null,
    categories,
  };
}

/**
 * نظرة الإدارة: الفئتان + الإعدادات + الفائزون بحالات الدفع + آخر الأثر.
 *
 * تُستدعى من دالة إدارية فقط (بعد التحقق من الادعاء/الدور)، ولا تُستخدم في
 * أي شاشة عامة. هنا فقط تظهر المبالغ (الإدارة تحتاجها للمطابقة المالية).
 *
 * @param {{store:object, now:Date, cycleKey?:string}} input
 */
async function getAdminOverview({ store, now, cycleKey }) {
  const config = { ...core.DEFAULT_CONFIG, ...(await store.getConfig()) };
  const schedule = core.weeklySchedule(now, config);
  const key = cycleKey ?? schedule.cycleKey;

  // نفس تكسّب المدرّس: لو لم تكن دورة الأسبوع موجودة نُنشئها قبل عرضها.
  if (!(await store.getAuction(core.cycleId(key, 'online')))) {
    await ensureWeeklyCycles({ store, now, config, actor: 'admin' });
  }
  const categories = [];

  for (const category of core.CATEGORIES) {
    const auctionId = core.cycleId(key, category);
    const auction = await store.getAuction(auctionId);
    if (!auction) {
      categories.push({ auctionId, category, cycleKey: key, missing: true });
      continue;
    }
    const [winners, results] = await Promise.all([
      store.listWinners(auctionId),
      store.getResults(auctionId),
    ]);
    const orderedWinners = winners.slice().sort((a, b) => {
      // الفائزون الأصليون بترتيب المركز، ثم فائزو البديل (بلا مركز) بالأحدث.
      const rankA = a.rank ?? 99;
      const rankB = b.rank ?? 99;
      if (rankA !== rankB) return rankA - rankB;
      return (b.amount ?? 0) - (a.amount ?? 0);
    });
    categories.push({
      auctionId,
      category,
      cycleKey: auction.cycleKey,
      missing: false,
      phase: core.deriveStatus(auction, now),
      opensAt: ms(auction.opensAt),
      closesAt: ms(auction.closesAt),
      bidCutoffAt: ms(auction.bidCutoffAt),
      announcesAt: ms(auction.announcesAt),
      paymentDeadline: ms(auction.paymentDeadline),
      replacementDeadline: ms(auction.replacementDeadline),
      displayStartsAt: ms(auction.displayStartsAt),
      displayEndsAt: ms(auction.displayEndsAt),
      positions: auction.positions,
      minBid: auction.minBid,
      bidStep: auction.bidStep,
      extraBidLimit: auction.extraBidLimit,
      maxBid: auction.maxBid,
      bidCount: auction.bidCount ?? 0,
      biddersCount: auction.biddersCount ?? 0,
      highestBid: auction.highestBid ?? 0,
      finalizedAt: ms(auction.finalizedAt),
      publishedAt: ms(auction.publishedAt),
      settledAt: ms(auction.settledAt),
      replacementRound: auction.replacementRound ?? 0,
      emptySeats: auction.emptySeats ?? Math.max(0, auction.positions - winners.length),
      winners: orderedWinners.map((winner) => ({
        teacherId: winner.teacherId,
        displayName: winner.displayName ?? '',
        rank: winner.rank ?? null,
        amount: winner.amount ?? null,
        round: winner.round ?? 1,
        status: winner.status,
        deadline: ms(
          winner.round === 2 ? auction.replacementDeadline : auction.paymentDeadline,
        ),
        confirmedAt: ms(winner.confirmedAt),
        confirmedBy: winner.confirmedBy ?? null,
      })),
      results: publicResults(results),
    });
  }

  return {
    serverNow: now.getTime(),
    timeZone: core.TIME_ZONE,
    cycleKey: key,
    config,
    categories,
    audit: (await store.listAudit(40)).map((entry) => ({
      at: ms(entry.at),
      actor: entry.actor ?? '',
      action: entry.action ?? '',
      detail: entry.detail ?? '',
    })),
  };
}

module.exports = {
  AUCTION_NOTIFICATION_TYPES,
  ensureWeeklyCycles,
  getTeacherAuctionState,
  getFeaturedResults,
  getAdminOverview,
  placeBid,
  finalizeAuction,
  confirmWinnerPayment,
  runReplacementRound,
  publishFeatured,
  expireFeatured,
  updateConfig,
};
