/**
 * Cloud Functions — مزاد التمييز الأسبوعي (P30).
 *
 * ## لماذا كل شيء هنا؟
 *
 * القرارات التي تمسّ المال والتمييز (أهلية المزايد، الحد الزمني، الترتيب،
 * الفائز، تعليم الدفع، نشر التمييز) **لا تُحسب في التطبيق إطلاقًا**. التطبيق
 * يقرأ حالة عامة وينادي دالة، والقواعد تمنع أي كتابة مباشرة على مستندات
 * المزاد. لذلك لا يستطيع عميل معدَّل أن يزايد بعد الإغلاق، أو يرفع نفسه في
 * الترتيب، أو يعلّم دفعًا لم يحدث.
 *
 * ## الأنواع
 *
 * - `onCall` إدارية: تتطلب Custom Claim `admin` أو دور مستند `users.role == 'admin'`
 *   (نفس سياسة القواعد). الهوية تُقرأ من رمز Firebase لا من معاملات الطلب.
 * - `onSchedule`: توقيت **Africa/Cairo** صريحًا، فتغيير ساعة الجهاز لا يغيّر شيئًا.
 *
 * ## التكرار (idempotency)
 *
 * كل عملية مالية/حسمية محمية بحالة في المستند نفسه (`finalizedAt`,
 * `replacementRound`, `publishedAt`, `settledAt`) أو بمعرّف طلب مخزَّن في
 * معاملة (`auctionIdempotency`). إعادة تشغيل المجدول أو تكرار الطلب لا يضاعف أثرًا.
 */

'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const core = require('./lib/auction_core');
const service = require('./lib/auction_service');
const { createFirestoreStore } = require('./lib/firestore_store');

initializeApp();
setGlobalOptions({ region: 'europe-west1', maxInstances: 10 });

const store = createFirestoreStore();

/** يحوّل خطأ المزاد إلى خطأ HTTPS برمز مفهوم، وبلا تفاصيل داخلية. */
function rethrow(error) {
  if (error instanceof core.AuctionError) {
    const code =
      error.code === 'unauthorized'
        ? 'permission-denied'
        : ['not-verified', 'wrong-category', 'no-auction'].includes(error.code)
          ? 'failed-precondition'
          : 'invalid-argument';
    throw new HttpsError(code, error.message, { auctionCode: error.code });
  }
  // لا نكشف تفاصيل داخلية للمستخدم، لكن نُبقيها في السجل.
  console.error('auction failure', error);
  throw new HttpsError('internal', 'تعذّر إتمام العملية. أعد المحاولة لاحقًا.');
}

/** هل الطلب من مسؤول؟ الادعاء أولًا، ثم دور المستند (كما في القواعد). */
async function assertAdmin(request) {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'سجّل الدخول أولًا.');
  }
  if (auth.token?.admin === true) return auth.uid;

  const snap = await getFirestore().collection('users').doc(auth.uid).get();
  if (!snap.exists || snap.data().role !== 'admin') {
    throw new HttpsError('permission-denied', 'هذه العملية للإدارة فقط.');
  }
  return auth.uid;
}

function assertSignedIn(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'سجّل الدخول أولًا.');
  }
  return request.auth.uid;
}

// ─────────────────────────────────────────────────────────────────────────────
// قراءة للعميل
// ─────────────────────────────────────────────────────────────────────────────

/**
 * ساعة الخادم — للعرض فقط (عدّاد تنازلي).
 *
 * **ليست مصدر قرار:** كل تحقق زمني يقع على الخادم بساعته. هذا الرقم يمنع
 * العدّاد من الاعتماد على ساعة الجهاز التي قد تكون مغيّرة قصدًا.
 */
exports.auctionClock = onCall({ enforceAppCheck: false }, () => ({
  now: Date.now(),
  timeZone: core.TIME_ZONE,
}));

/**
 * حالة الأسبوع للمدرّس الحالي — تُغذّي شاشة المزاد كاملة.
 *
 * الفئة (أونلاين/حضوري) تُشتق من **ملفه على الخادم** لا من الطلب، والمزايدة
 * المعروضة هي مزايدته وحدها. التفاصيل في `getTeacherAuctionState`.
 */
exports.myAuctionState = onCall(async (request) => {
  const uid = assertSignedIn(request);
  try {
    return await service.getTeacherAuctionState({ store, now: new Date(), uid });
  } catch (error) {
    rethrow(error);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// مزايدة المدرّس
// ─────────────────────────────────────────────────────────────────────────────

/**
 * مزايدة أو زيادة.
 * @param {{cycleKey:string, category:'online'|'inPerson', amount:number, requestId:string}} data
 */
exports.placeBid = onCall(async (request) => {
  const uid = assertSignedIn(request);
  const { cycleKey, category, amount, requestId } = request.data ?? {};
  try {
    return await service.placeBid({
      store,
      now: new Date(),
      uid,
      cycleKey: String(cycleKey ?? ''),
      category: String(category ?? ''),
      amount: Number(amount),
      requestId: String(requestId ?? ''),
    });
  } catch (error) {
    rethrow(error);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// إدارة
// ─────────────────────────────────────────────────────────────────────────────

/**
 * نظرة الإدارة على الدورتين (الفائزون بحالات الدفع، الأرقام، آخر الأثر).
 *
 * @param {{cycleKey?:string}} data اختياري: أسبوع بعينه للمراجعة التاريخية.
 */
exports.adminAuctionOverview = onCall(async (request) => {
  await assertAdmin(request);
  const { cycleKey } = request.data ?? {};
  try {
    return await service.getAdminOverview({
      store,
      now: new Date(),
      cycleKey: cycleKey ? String(cycleKey) : undefined,
    });
  } catch (error) {
    rethrow(error);
  }
});

/** تعديل إعدادات المزاد (مقاعد، أقل مزايدة، الزيادة، المهل). */
exports.adminUpdateAuctionConfig = onCall(async (request) => {
  const actor = await assertAdmin(request);
  try {
    return await service.updateConfig({
      store,
      now: new Date(),
      actor,
      patch: request.data ?? {},
    });
  } catch (error) {
    rethrow(error);
  }
});

/** إنشاء دورات الأسبوع الحالي والقادم يدويًا (استثناء تشغيلي). */
exports.adminEnsureWeeklyCycles = onCall(async (request) => {
  const actor = await assertAdmin(request);
  try {
    return await service.ensureWeeklyCycles({ store, now: new Date(), actor });
  } catch (error) {
    rethrow(error);
  }
});

/** حسم المزاد وتعيين الفائزين (يدويًا لمعالجة استثناء). */
exports.adminFinalizeAuction = onCall(async (request) => {
  const actor = await assertAdmin(request);
  const { cycleKey, category } = request.data ?? {};
  try {
    const auctionId = core.cycleId(String(cycleKey), String(category));
    return await service.finalizeAuction({
      store,
      now: new Date(),
      auctionId,
      actor: 'admin-override',
    });
  } catch (error) {
    rethrow(error);
  }
});

/** تأكيد أو رفض دفع فائز — بعد التحصيل الفعلي بالوسيلة المعتمدة. */
exports.adminConfirmWinnerPayment = onCall(async (request) => {
  const actor = await assertAdmin(request);
  const { cycleKey, category, teacherId, paid, note } = request.data ?? {};
  try {
    const auctionId = core.cycleId(String(cycleKey), String(category));
    return await service.confirmWinnerPayment({
      store,
      now: new Date(),
      auctionId,
      teacherId: String(teacherId),
      paid: paid === true,
      actor,
      note: note ?? null,
    });
  } catch (error) {
    rethrow(error);
  }
});

/** تشغيل دورة البديل يدويًا (مرة واحدة فقط؛ الاستدعاء الثاني لا يفعل شيئًا). */
exports.adminRunReplacement = onCall(async (request) => {
  const actor = await assertAdmin(request);
  const { cycleKey, category } = request.data ?? {};
  try {
    const auctionId = core.cycleId(String(cycleKey), String(category));
    return await service.runReplacementRound({ store, now: new Date(), auctionId, actor });
  } catch (error) {
    rethrow(error);
  }
});

/** نشر التمييز في شريط المميزين (يُطبَّق على المدفوعين فقط). */
exports.adminPublishFeatured = onCall(async (request) => {
  const actor = await assertAdmin(request);
  const { cycleKey, category } = request.data ?? {};
  try {
    const auctionId = core.cycleId(String(cycleKey), String(category));
    return await service.publishFeatured({ store, now: new Date(), auctionId, actor });
  } catch (error) {
    rethrow(error);
  }
});

/** إنهاء تمييز دورة منتهية. */
exports.adminExpireFeatured = onCall(async (request) => {
  const actor = await assertAdmin(request);
  const { cycleKey, category } = request.data ?? {};
  try {
    const auctionId = core.cycleId(String(cycleKey), String(category));
    return await service.expireFeatured({ store, now: new Date(), auctionId, actor });
  } catch (error) {
    rethrow(error);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// المجدول الأسبوعي — توقيت القاهرة، وكل مهمة متكررة بأمان
// ─────────────────────────────────────────────────────────────────────────────

/** الاثنين 00:05: إنشاء دورات الأسبوع. */
exports.weeklyOpenAuctions = onSchedule(
  { schedule: '5 0 * * 1', timeZone: core.TIME_ZONE },
  async () => {
    await service.ensureWeeklyCycles({ store, now: new Date(), actor: 'scheduler' });
  },
);

/** الخميس 09:05: حسم النتائج وإشعار الفائزين. */
exports.weeklyFinalizeAuctions = onSchedule(
  { schedule: '5 9 * * 4', timeZone: core.TIME_ZONE },
  async () => {
    const now = new Date();
    const { cycleKey } = core.weeklySchedule(now);
    for (const category of core.CATEGORIES) {
      const auctionId = core.cycleId(cycleKey, category);
      try {
        await service.finalizeAuction({
          store,
          now,
          auctionId,
          actor: 'scheduler',
        });
      } catch (error) {
        // مهمة فئة لا تُسقط الأخرى، والخطأ يبقى في السجل.
        console.error('finalize failed', auctionId, error);
      }
    }
  },
);

/** الجمعة 09:05: انقضاء الدفع ثم دورة البديل الواحدة. */
exports.weeklyReplacementRound = onSchedule(
  { schedule: '5 9 * * 5', timeZone: core.TIME_ZONE },
  async () => {
    const now = new Date();
    const { cycleKey } = core.weeklySchedule(now);
    for (const category of core.CATEGORIES) {
      const auctionId = core.cycleId(cycleKey, category);
      try {
        await service.runReplacementRound({
          store,
          now,
          auctionId,
          actor: 'scheduler',
        });
      } catch (error) {
        console.error('replacement failed', auctionId, error);
      }
    }
  },
);

/**
 * السبت 00:05: إنهاء تمييز الدورات المنتهية **ثم** نشر الدورات الجديدة.
 *
 * الترتيب مقصود: لو نُشر قبل الإنهاء لبقي علم `isFeatured` على مدرّس قديم لم
 * يُعَد تمييزه هذا الأسبوع (لأن الكتابة لا تمسّ إلا الفائزين الجدد).
 */
exports.weeklyPublishFeatured = onSchedule(
  { schedule: '5 0 * * 6', timeZone: core.TIME_ZONE },
  async () => {
    const now = new Date();
    const due = core.weeklySchedule(now);

    // (1) إنهاء كل دورة منشورة سابقًا انتهى عرضها ولم تُنهَ بعد.
    try {
      const snapshot = await getFirestore()
        .collection('auctions')
        .where('publishedAt', '!=', null)
        .get();
      for (const doc of snapshot.docs) {
        const data = doc.data();
        if (data.settledAt) continue;
        if (new Date(data.displayEndsAt.toDate?.() ?? data.displayEndsAt) >= now) continue;
        try {
          await service.expireFeatured({
            store,
            now,
            auctionId: doc.id,
            actor: 'scheduler',
          });
        } catch (error) {
          console.error('expire failed', doc.id, error);
        }
      }
    } catch (error) {
      console.error('expire scan failed', error);
    }

    // (2) نشر الدورات التي بدأ عرضها (السبت 00:00).
    for (const category of core.CATEGORIES) {
      const auctionId = core.cycleId(due.cycleKey, category);
      try {
        await service.publishFeatured({
          store,
          now,
          auctionId,
          actor: 'scheduler',
        });
      } catch (error) {
        console.error('publish failed', auctionId, error);
      }
    }
  },
);
