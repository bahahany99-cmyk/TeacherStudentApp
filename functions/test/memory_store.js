/**
 * مستودع في الذاكرة — بديل Firestore في الاختبارات.
 *
 * يحاكي ما يهمّنا بدقة:
 *   1. **الذرّية:** كل `transaction` تُنفَّذ بالتتابع (سلسلة وعود)، فاختبار
 *      «مزايدتان متزامنتان» يعطي نتيجة حتمية كما يفعل Firestore.
 *   2. **العقد نفسه:** نفس أسماء الدوال التي يتوقعها `auction_service`.
 *
 * لا يُستخدم في الإنتاج إطلاقًا.
 */

'use strict';

/**
 * نسخ عميق يحافظ على `Date` كما هي — مهم لأن جدول المزاد كله تواريخ، وFirestore
 * يعيد `Timestamp` تُحوَّل إلى `Date` في المتجر الحقيقي.
 */
function clone(value) {
  if (value === null || value === undefined) return value;
  if (value instanceof Date) return new Date(value.getTime());
  if (Array.isArray(value)) return value.map(clone);
  if (typeof value !== 'object') return value;
  const out = {};
  for (const [key, item] of Object.entries(value)) out[key] = clone(item);
  return out;
}

function createMemoryStore(seed = {}) {
  const state = {
    config: clone(seed.config) ?? {},
    auctions: new Map(Object.entries(clone(seed.auctions) ?? {})),
    bids: new Map(), // `${auctionId}/${teacherId}`
    winners: new Map(),
    results: new Map(),
    idempotency: new Map(),
    profiles: new Map(Object.entries(clone(seed.profiles) ?? {})),
    notifications: [],
    audit: [],
    featured: new Map(),
  };

  // سلسلة واحدة: تُجبر المعاملات على التنفيذ التسلسلي (ذرّية).
  let queue = Promise.resolve();

  const auctionTx = (txState) => ({
    async getAuction(auctionId) {
      return clone(txState.auctions.get(auctionId)) ?? null;
    },
    async setAuction(auctionId, data) {
      txState.auctions.set(auctionId, clone(data));
    },
    async getBid(auctionId, teacherId) {
      return clone(txState.bids.get(`${auctionId}/${teacherId}`)) ?? null;
    },
    async setBid(auctionId, teacherId, data) {
      txState.bids.set(`${auctionId}/${teacherId}`, clone(data));
    },
    async listBids(auctionId) {
      return [...txState.bids.entries()]
        .filter(([key]) => key.startsWith(`${auctionId}/`))
        .map(([, value]) => clone(value));
    },
    async getWinner(auctionId, teacherId) {
      return clone(txState.winners.get(`${auctionId}/${teacherId}`)) ?? null;
    },
    async setWinner(auctionId, teacherId, data) {
      txState.winners.set(`${auctionId}/${teacherId}`, clone(data));
    },
    async listWinners(auctionId) {
      return [...txState.winners.entries()]
        .filter(([key]) => key.startsWith(`${auctionId}/`))
        .map(([, value]) => clone(value));
    },
    async getProfile(teacherId) {
      return clone(txState.profiles.get(teacherId)) ?? null;
    },
    async setFeaturedFlags(assignments) {
      for (const assignment of assignments) {
        const current = txState.featured.get(assignment.teacherId) ?? {};
        txState.featured.set(assignment.teacherId, {
          ...current,
          isFeatured: assignment.isFeatured !== false,
          featuredOrder: assignment.featuredOrder ?? 0,
        });
      }
    },
    async getResults(auctionId) {
      return clone(txState.results.get(auctionId)) ?? null;
    },
    async setResults(auctionId, data) {
      txState.results.set(auctionId, clone(data));
    },
    async getIdempotency(key) {
      return clone(txState.idempotency.get(key)) ?? null;
    },
    async setIdempotency(key, value) {
      txState.idempotency.set(key, clone(value));
    },
    async notify(payload) {
      txState.notifications.push(clone(payload));
    },
    async appendAudit(entry) {
      txState.audit.push(clone(entry));
    },
  });

  /** نسخة قابلة للتعديل تُثبَّت في الحالة بعد نجاح المعاملة فقط. */
  const workingCopy = () => ({
    auctions: new Map(state.auctions),
    bids: new Map(state.bids),
    winners: new Map(state.winners),
    results: new Map(state.results),
    idempotency: new Map(state.idempotency),
    profiles: new Map(state.profiles),
    featured: new Map(state.featured),
    notifications: [...state.notifications],
    audit: [...state.audit],
  });

  const store = {
    state,
    seedProfile(teacherId, profile) {
      state.profiles.set(teacherId, clone(profile));
    },
    seedAuction(auctionId, data) {
      state.auctions.set(auctionId, clone(data));
    },

    async getConfig() {
      return clone(state.config);
    },
    async getProfile(teacherId) {
      return clone(state.profiles.get(teacherId)) ?? null;
    },
    async getBid(auctionId, teacherId) {
      return clone(state.bids.get(`${auctionId}/${teacherId}`)) ?? null;
    },
    async getWinner(auctionId, teacherId) {
      return clone(state.winners.get(`${auctionId}/${teacherId}`)) ?? null;
    },
    async listBids(auctionId) {
      return [...state.bids.entries()]
        .filter(([key]) => key.startsWith(`${auctionId}/`))
        .map(([, value]) => clone(value));
    },
    async getResults(auctionId) {
      return clone(state.results.get(auctionId)) ?? null;
    },
    async listAudit(limit = 50) {
      return clone(state.audit.slice(-limit).reverse());
    },
    async setConfig(config, actor) {
      state.config = { ...clone(config), updatedBy: actor };
    },

    async getAuction(auctionId) {
      return clone(state.auctions.get(auctionId)) ?? null;
    },
    /** مثل `create()` في Firestore: لا يدهس موجودًا، ويُعيد هل أُنشئ الآن. */
    async createAuction(auctionId, data) {
      if (state.auctions.has(auctionId)) return false;
      state.auctions.set(auctionId, clone(data));
      return true;
    },
    async setAuction(auctionId, data) {
      state.auctions.set(auctionId, clone(data));
    },

    transaction(work) {
      const run = queue.then(async () => {
        const working = workingCopy();
        const tx = auctionTx(working);
        const result = await work(tx);
        // تثبيت الكتابات بعد النجاح فقط (سلوك المعاملة).
        state.auctions = working.auctions;
        state.bids = working.bids;
        state.winners = working.winners;
        state.results = working.results;
        state.idempotency = working.idempotency;
        state.featured = working.featured;
        state.notifications = working.notifications;
        state.audit = working.audit;
        return result;
      });
      // نُبقي السلسلة حيّة حتى لو فشلت المعاملة.
      queue = run.then(
        () => undefined,
        () => undefined,
      );
      return run;
    },

    async appendAudit(entry) {
      state.audit.push(clone(entry));
    },

    // مساعدات للتحقق في الاختبارات.
    getBid(auctionId, teacherId) {
      return clone(state.bids.get(`${auctionId}/${teacherId}`)) ?? null;
    },
    listWinners(auctionId) {
      return [...state.winners.entries()]
        .filter(([key]) => key.startsWith(`${auctionId}/`))
        .map(([, value]) => clone(value));
    },
    notificationsFor(teacherId) {
      return state.notifications.filter((item) => item.recipientId === teacherId);
    },
    featuredOf(teacherId) {
      return clone(state.featured.get(teacherId)) ?? null;
    },
    auditEntries() {
      return clone(state.audit);
    },
  };

  return store;
}

module.exports = { createMemoryStore };
