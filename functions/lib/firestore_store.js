/**
 * مستودع Firestore لعمليات المزاد (Admin SDK).
 *
 * الطبقة رقيقة عمدًا: لا منطق قرار هنا — فقط قراءة/كتابة مسارات معروفة. كل
 * المنطق في `auction_core.js` و`auction_service.js` (مُختبَرَين بلا Firebase).
 *
 * **تجاوز القواعد:** Admin SDK يتجاوز Firestore Security Rules، وهذا هو مصدر
 * القدرة على كتابة المزايدات والنتائج. لذلك كل كتابة عميل في `firestore.rules`
 * ممنوعة على هذه المجموعات — لا يوجد مسار بديل للعميل يعدّل مزادًا.
 */

'use strict';

const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

/** الثوابت المشتركة مع التطبيق. */
const COLLECTIONS = Object.freeze({
  auctionConfig: 'auctionConfig',
  auctions: 'auctions',
  bids: 'bids',
  winners: 'winners',
  results: 'auctionResults',
  audit: 'auctionAudit',
  idempotency: 'auctionIdempotency',
  teacherProfiles: 'teacherProfiles',
  notifications: 'notifications',
});

/**
 * يبني مستودعًا على Firestore.
 * @param {{db?: FirebaseFirestore.Firestore}} [options]
 */
function createFirestoreStore(options = {}) {
  const db = options.db ?? getFirestore();

  const toDate = (value) => (value instanceof Date ? value : value?.toDate?.() ?? value);

  return {
    /** إعدادات المزاد (مستند واحد). */
    async getConfig() {
      const snap = await db.collection(COLLECTIONS.auctionConfig).doc('current').get();
      return snap.exists ? snap.data() : {};
    },
    async setConfig(config, actor, now) {
      await db
        .collection(COLLECTIONS.auctionConfig)
        .doc('current')
        .set({ ...config, updatedAt: now, updatedBy: actor }, { merge: true });
    },

    async getAuction(auctionId) {
      const snap = await db.collection(COLLECTIONS.auctions).doc(auctionId).get();
      return snap.exists ? { id: snap.id, ...snap.data() } : null;
    },
    /**
     * إنشاء الدورة **بشرط عدم الوجود** (`create` لا `set`).
     *
     * السبب: مجدولان قد يتشغّلا معًا (إعادة محاولة أو فتح الشاشة في نفس
     * اللحظة). `set` كان سيدهس مستندًا قائمًا بمزايداته. `create` يفشل بـ
     * `ALREADY_EXISTS` فنعتبره «موجود أصلًا» ونُكمل بلا ضرر (idempotent).
     *
     * @returns {Promise<boolean>} هل أُنشئت الآن؟
     */
    async createAuction(auctionId, data) {
      try {
        await db.collection(COLLECTIONS.auctions).doc(auctionId).create(data);
        return true;
      } catch (error) {
        if (error?.code === 6 || error?.code === 'already-exists') return false;
        throw error;
      }
    },
    async setAuction(auctionId, data) {
      await db.collection(COLLECTIONS.auctions).doc(auctionId).set(data, { merge: false });
    },

    /**
     * معاملة ذرّية: كل ما يُقرأ ويُكتب داخلها وحدة واحدة. عقود `tx` مطابقة
     * تمامًا لما يتوقعه `auction_service` (ومستودع الذاكرة في الاختبارات).
     */
    async transaction(work) {
      return db.runTransaction(async (transaction) => {
        const auctionRef = (auctionId) =>
          db.collection(COLLECTIONS.auctions).doc(auctionId);

        const tx = {
          async getAuction(auctionId) {
            const snap = await transaction.get(auctionRef(auctionId));
            return snap.exists ? { id: snap.id, ...snap.data() } : null;
          },
          async setAuction(auctionId, data) {
            transaction.set(auctionRef(auctionId), data);
          },
          async getBid(auctionId, teacherId) {
            const snap = await transaction.get(
              auctionRef(auctionId).collection(COLLECTIONS.bids).doc(teacherId),
            );
            return snap.exists ? { id: snap.id, ...snap.data() } : null;
          },
          async setBid(auctionId, teacherId, data) {
            transaction.set(
              auctionRef(auctionId).collection(COLLECTIONS.bids).doc(teacherId),
              data,
            );
          },
          async listBids(auctionId) {
            // استعلام داخل معاملة: ممنوع الاستعلام على مجموعة فرعية مع دالة
            // تجميع هنا؛ النتائج صغيرة (مدرسون مصريون في فئة واحدة).
            const snap = await transaction.get(
              auctionRef(auctionId).collection(COLLECTIONS.bids),
            );
            return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
          },
          async getWinner(auctionId, teacherId) {
            const snap = await transaction.get(
              auctionRef(auctionId).collection(COLLECTIONS.winners).doc(teacherId),
            );
            return snap.exists ? { id: snap.id, ...snap.data() } : null;
          },
          async setWinner(auctionId, teacherId, data) {
            transaction.set(
              auctionRef(auctionId).collection(COLLECTIONS.winners).doc(teacherId),
              data,
            );
          },
          async listWinners(auctionId) {
            const snap = await transaction.get(
              auctionRef(auctionId).collection(COLLECTIONS.winners),
            );
            return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
          },
          async getProfile(teacherId) {
            const snap = await transaction.get(
              db.collection(COLLECTIONS.teacherProfiles).doc(teacherId),
            );
            return snap.exists ? { id: snap.id, ...snap.data() } : null;
          },
          async setFeaturedFlags(assignments) {
            for (const assignment of assignments) {
              transaction.set(
                db.collection(COLLECTIONS.teacherProfiles).doc(assignment.teacherId),
                {
                  isFeatured: assignment.isFeatured !== false,
                  featuredOrder: assignment.featuredOrder ?? 0,
                },
                { merge: true },
              );
            }
          },
          async getResults(auctionId) {
            const snap = await transaction.get(
              db.collection(COLLECTIONS.results).doc(auctionId),
            );
            return snap.exists ? { id: snap.id, ...snap.data() } : null;
          },
          async setResults(auctionId, data) {
            transaction.set(db.collection(COLLECTIONS.results).doc(auctionId), data);
          },
          async getIdempotency(key) {
            const snap = await transaction.get(
              db.collection(COLLECTIONS.idempotency).doc(key),
            );
            return snap.exists ? { ...snap.data(), at: toDate(snap.data().at) } : null;
          },
          async setIdempotency(key, value) {
            transaction.set(db.collection(COLLECTIONS.idempotency).doc(key), {
              ...value,
              createdAt: FieldValue.serverTimestamp(),
            });
          },
          async notify(payload) {
            const ref = db.collection(COLLECTIONS.notifications).doc();
            transaction.set(ref, {
              ...payload,
              createdAt: Timestamp.fromDate(payload.createdAt ?? new Date()),
              readAt: null,
            });
          },
          async appendAudit(entry) {
            const ref = db.collection(COLLECTIONS.audit).doc();
            transaction.set(ref, {
              ...entry,
              at: Timestamp.fromDate(entry.at ?? new Date()),
            });
          },
        };
        return work(tx);
      });
    },

    // ── قراءات للعرض (بلا قرار) ────────────────────────────────────────────

    async getProfile(teacherId) {
      const snap = await db.collection(COLLECTIONS.teacherProfiles).doc(teacherId).get();
      return snap.exists ? { id: snap.id, ...snap.data() } : null;
    },
    async getBid(auctionId, teacherId) {
      const snap = await db
        .collection(COLLECTIONS.auctions)
        .doc(auctionId)
        .collection(COLLECTIONS.bids)
        .doc(teacherId)
        .get();
      return snap.exists ? { id: snap.id, ...snap.data() } : null;
    },
    async getWinner(auctionId, teacherId) {
      const snap = await db
        .collection(COLLECTIONS.auctions)
        .doc(auctionId)
        .collection(COLLECTIONS.winners)
        .doc(teacherId)
        .get();
      return snap.exists ? { id: snap.id, ...snap.data() } : null;
    },
    async listWinners(auctionId) {
      const snap = await db
        .collection(COLLECTIONS.auctions)
        .doc(auctionId)
        .collection(COLLECTIONS.winners)
        .get();
      return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    },
    async listBids(auctionId) {
      const snap = await db
        .collection(COLLECTIONS.auctions)
        .doc(auctionId)
        .collection(COLLECTIONS.bids)
        .get();
      return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    },
    async getResults(auctionId) {
      const snap = await db.collection(COLLECTIONS.results).doc(auctionId).get();
      return snap.exists ? { id: snap.id, ...snap.data() } : null;
    },
    /** آخر [limit] سطرًا في سجل التدقيق — الأحدث أولًا. */
    async listAudit(limit = 50) {
      const snap = await db
        .collection(COLLECTIONS.audit)
        .orderBy('at', 'desc')
        .limit(limit)
        .get();
      return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    },

    /** إضافة سجل تدقيق خارج المعاملة (للمسارات التي لا تكتب مستندات مزاد). */
    async appendAudit(entry) {
      await db.collection(COLLECTIONS.audit).add({
        ...entry,
        at: Timestamp.fromDate(entry.at ?? new Date()),
      });
    },
  };
}

module.exports = { COLLECTIONS, createFirestoreStore };
