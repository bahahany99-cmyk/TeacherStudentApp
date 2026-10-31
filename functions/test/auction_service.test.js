/**
 * اختبارات طبقة خدمة المزاد — على مستودع في الذاكرة.
 *
 * تُغطّي ما لا تستطيع النواة وحدها إثباته:
 *   - التزامن (مزايدتان في اللحظة نفسها على مقعد واحد)،
 *   - التكرار (نفس `requestId` مرتين، ونفس المستخدم بطلبات مختلفة)،
 *   - إعادة تشغيل العمليات المجدولة (finalize/publish/replacement مرتين)،
 *   - المهلات، ودورة البديل الواحدة، والمقاعد الفارغة، والصلاحيات.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const core = require('../lib/auction_core');
const service = require('../lib/auction_service');
const { createMemoryStore } = require('./memory_store');

const cairo = (year, month, day, hour = 0, minute = 0) =>
  core.cairoTimeToUtc({ year, month, day, hour, minute });

const NOW_MONDAY = cairo(2026, 10, 12, 10); // داخل أسبوع المزايدة
const CYCLE = core.weeklySchedule(NOW_MONDAY);
const AUCTION_ONLINE = core.cycleId(CYCLE.cycleKey, 'online');
const AUCTION_IN_PERSON = core.cycleId(CYCLE.cycleKey, 'inPerson');

const teacher = (id, overrides = {}) => ({
  status: 'verified',
  isOnline: true,
  accountHidden: false,
  displayName: `مدرس ${id}`,
  ...overrides,
});

/** متجر جاهز بدورة الأسبوع + مدرسين موثّقين في الفئتين. */
async function setup({ online = 6, inPerson = 2, config } = {}) {
  const store = createMemoryStore();
  await service.ensureWeeklyCycles({ store, now: NOW_MONDAY, config });
  const onlineIds = Array.from({ length: online }, (_, i) => `on${i + 1}`);
  const inPersonIds = Array.from({ length: inPerson }, (_, i) => `in${i + 1}`);
  for (const id of onlineIds) store.seedProfile(id, teacher(id));
  for (const id of inPersonIds) store.seedProfile(id, teacher(id, { isOnline: false }));
  return { store, onlineIds, inPersonIds };
}

let requestCounter = 0;
const requestId = () => `req-${String((requestCounter += 1)).padStart(8, '0')}`;

const bid = (store, uid, amount, { now = NOW_MONDAY, category = 'online', rid } = {}) =>
  service.placeBid({
    store,
    now,
    uid,
    category,
    cycleKey: CYCLE.cycleKey,
    amount,
    requestId: rid ?? requestId(),
  });

// ─────────────────────────────────────────────────────────────────────────────
// 1) إنشاء الدورات
// ─────────────────────────────────────────────────────────────────────────────

test('ensureWeeklyCycles ينشئ دورتين × فئتين، ولا يكرّر عند إعادة التشغيل', async () => {
  const store = createMemoryStore();
  const first = await service.ensureWeeklyCycles({ store, now: NOW_MONDAY });
  assert.equal(first.created.length, 4); // هذا الأسبوع + القادم × فئتان
  const again = await service.ensureWeeklyCycles({ store, now: NOW_MONDAY });
  assert.deepEqual(again.created, []);
});

test('كل فئة لها مستند مستقل وإعدادات منسوخة لحظة الإنشاء', async () => {
  const { store } = await setup({ config: { minBid: 200, bidStep: 50 } });
  const online = await store.getAuction(AUCTION_ONLINE);
  const inPerson = await store.getAuction(AUCTION_IN_PERSON);
  assert.notEqual(online.id, inPerson.id);
  assert.equal(online.category, 'online');
  assert.equal(inPerson.category, 'inPerson');
  assert.equal(online.minBid, 200);
  assert.equal(online.positions, 5);
});

// ─────────────────────────────────────────────────────────────────────────────
// 2) المزايدات: القواعد والتكرار والتزامن
// ─────────────────────────────────────────────────────────────────────────────

test('مزايدة أولى صحيحة تُحفظ وتُحدّث عدّادات الدورة', async () => {
  const { store } = await setup();
  const result = await bid(store, 'on1', 100);
  assert.equal(result.isFirst, true);
  assert.equal(result.increasesRemaining, 10);
  assert.equal(result.nextMinimum, 125);

  const auction = await store.getAuction(AUCTION_ONLINE);
  assert.equal(auction.bidCount, 1);
  assert.equal(auction.biddersCount, 1);
  assert.equal(auction.highestBid, 100);
});

test('الزيادة تستهلك من الرصيد، والـ11 ترفض بلا كتابة', async () => {
  const { store } = await setup();
  await bid(store, 'on1', 100);
  for (let i = 1; i <= 10; i += 1) {
    const result = await bid(store, 'on1', 100 + i * 25);
    assert.equal(result.increasesUsed, i);
    assert.equal(result.increasesRemaining, 10 - i);
  }
  const before = await store.getBid(AUCTION_ONLINE, 'on1');
  await assert.rejects(
    () => bid(store, 'on1', 100 + 11 * 25),
    (error) => error.code === 'no-increases-left',
  );
  const after = await store.getBid(AUCTION_ONLINE, 'on1');
  assert.deepEqual(after, before); // لا كتابة جزئية
  assert.equal(store.notificationsFor('on1').length, 0);
});

test('نفس requestId مرتين ⇒ نتيجة واحدة، وزيادة واحدة فقط', async () => {
  const { store } = await setup();
  const rid = 'request-abc-123';
  const first = await bid(store, 'on1', 100, { rid });
  const second = await bid(store, 'on1', 100, { rid });
  assert.equal(first.replayed, false);
  assert.equal(second.replayed, true);
  assert.equal(second.amount, first.amount);
  assert.equal(second.increasesUsed, 0);

  const auction = await store.getAuction(AUCTION_ONLINE);
  assert.equal(auction.bidCount, 1);
  assert.equal((await store.getBid(AUCTION_ONLINE, 'on1')).increasesUsed, 0);
});

test('نفس requestId بعد زيادة حقيقية يعيد النتيجة القديمة لا الحالية', async () => {
  const { store } = await setup();
  const first = await bid(store, 'on1', 100, { rid: 'request-first-1' });
  await bid(store, 'on1', 200);
  const replay = await bid(store, 'on1', 300, { rid: 'request-first-1' });
  assert.equal(replay.replayed, true);
  assert.equal(replay.amount, first.amount);
  assert.equal((await store.getBid(AUCTION_ONLINE, 'on1')).amount, 200);
});

test('التزامن: طلبان متوازيان بنفس المبلغ ⇒ واحد فقط يُقبل', async () => {
  const { store } = await setup();
  await bid(store, 'on1', 100);
  // القاعدة: كل زيادة ≥ الحالي + الخطوة، فلا يمكن «تجاوز» الزيادة نفسها مرتين.
  const results = await Promise.allSettled([
    bid(store, 'on1', 125),
    bid(store, 'on1', 125),
  ]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  const stored = await store.getBid(AUCTION_ONLINE, 'on1');
  assert.equal(stored.amount, 125);
  assert.equal(stored.increasesUsed, 1);
});

test('التزامن: نفس requestId في طلبين متوازيين ⇒ زيادة واحدة', async () => {
  const { store } = await setup();
  const rid = 'concurrent-dup-1';
  const results = await Promise.all([bid(store, 'on1', 100, { rid }), bid(store, 'on1', 100, { rid })]);
  assert.deepEqual(results.map((r) => r.replayed).sort(), [false, true]);
  assert.equal((await store.getBid(AUCTION_ONLINE, 'on1')).increasesUsed, 0);
  assert.equal((await store.getAuction(AUCTION_ONLINE)).bidCount, 1);
});

test('التزامن: خمسة مدرسين يتنافسون ⇒ لا تُفقد أي مزايدة ولا يتكرر التخزين', async () => {
  const { store, onlineIds } = await setup({ online: 5 });
  await Promise.all(onlineIds.map((id, index) => bid(store, id, 100 + index * 10)));
  const auction = await store.getAuction(AUCTION_ONLINE);
  assert.equal(auction.biddersCount, 5);
  assert.equal(auction.bidCount, 5);
  assert.equal(auction.highestBid, 140);
});

test('فئات مستقلة: المزايدة عن بُعد لا تُغيّر عدّادات الفئة الحضورية', async () => {
  const { store } = await setup();
  await bid(store, 'on1', 500);
  const inPerson = await store.getAuction(AUCTION_IN_PERSON);
  assert.equal(inPerson.bidCount, 0);
  assert.equal(inPerson.highestBid, 0);
  assert.equal(await store.getBid(AUCTION_IN_PERSON, 'on1'), null);
});

test('مدرّس حضوري لا يزايد في فئة الأونلاين والعكس', async () => {
  const { store } = await setup();
  await assert.rejects(
    () => bid(store, 'in1', 100, { category: 'online' }),
    (error) => error.code === 'wrong-category',
  );
  await assert.rejects(
    () => bid(store, 'on1', 100, { category: 'inPerson' }),
    (error) => error.code === 'wrong-category',
  );
  assert.equal((await store.getAuction(AUCTION_ONLINE)).bidCount, 0);
});

test('غير موثّق/مخفي/غير موجود ⇒ مرفوض بلا كتابة', async () => {
  const { store } = await setup({ online: 1 });
  store.seedProfile('pending', teacher('pending', { status: 'pendingReview' }));
  store.seedProfile('hidden', teacher('hidden', { accountHidden: true }));

  await assert.rejects(() => bid(store, 'pending', 100), (e) => e.code === 'not-verified');
  await assert.rejects(() => bid(store, 'hidden', 100), (e) => e.code === 'account-hidden');
  await assert.rejects(() => bid(store, 'ghost', 100), (e) => e.code === 'not-verified');
  assert.equal((await store.getAuction(AUCTION_ONLINE)).bidCount, 0);
});

test('آخر 10 دقائق وبعد الإغلاق ⇒ مرفوض (ساعة الخادم هي الحكم)', async () => {
  const { store } = await setup();
  await assert.rejects(
    () => bid(store, 'on1', 100, { now: new Date(CYCLE.bidCutoffAt.getTime() + 1000) }),
    (e) => e.code === 'closed-last-minutes',
  );
  await assert.rejects(
    () => bid(store, 'on1', 100, { now: new Date(CYCLE.closesAt.getTime() + 60000) }),
    (e) => e.code === 'closed',
  );
  await assert.rejects(
    () => bid(store, 'on1', 100, { now: new Date(CYCLE.opensAt.getTime() - 60000) }),
    (e) => e.code === 'not-open',
  );
});

test('معرّف طلب غير صالح يُرفض قبل أي معاملة', async () => {
  const { store } = await setup();
  await assert.rejects(
    () => bid(store, 'on1', 100, { rid: 'bad id!' }),
    (e) => e.code === 'invalid-request-id',
  );
});

test('مزايدة على دورة غير موجودة', async () => {
  const { store } = await setup();
  await assert.rejects(
    () =>
      service.placeBid({
        store,
        now: NOW_MONDAY,
        uid: 'on1',
        category: 'online',
        cycleKey: '2020-W01',
        amount: 100,
        requestId: 'request-missing-1',
      }),
    (e) => e.code === 'no-auction',
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// 3) الإعلان والتعادل
// ─────────────────────────────────────────────────────────────────────────────

const THURSDAY = cairo(2026, 10, 15, 9, 10);
const FRIDAY = cairo(2026, 10, 16, 9, 10);
const SATURDAY = cairo(2026, 10, 17, 0, 10);

async function biddingDone() {
  const ctx = await setup({ online: 7, inPerson: 3 });
  // أعلى 5: on1..on5 بترتيب مبالغ متنازل عليه
  await bid(ctx.store, 'on1', 900);
  await bid(ctx.store, 'on2', 800);
  await bid(ctx.store, 'on3', 700);
  await bid(ctx.store, 'on4', 600);
  await bid(ctx.store, 'on5', 500);
  await bid(ctx.store, 'on6', 400);
  await bid(ctx.store, 'on7', 300);
  await bid(ctx.store, 'in1', 250, { category: 'inPerson' });
  await bid(ctx.store, 'in2', 150, { category: 'inPerson' });
  return ctx;
}

test('finalizeAuction يختار أعلى 5 ويُعيد المقعدين المتبقيين فارغين', async () => {
  const { store } = await biddingDone();
  const result = await service.finalizeAuction({
    store,
    now: THURSDAY,
    auctionId: AUCTION_ONLINE,
    actor: 'system',
  });
  assert.equal(result.winners.length, 5);
  assert.deepEqual(
    result.winners.map((w) => w.teacherId),
    ['on1', 'on2', 'on3', 'on4', 'on5'],
  );
  assert.deepEqual(result.winners.map((w) => w.rank), [1, 2, 3, 4, 5]);
  assert.equal(result.emptySeats, 0);

  const auction = await store.getAuction(AUCTION_ONLINE);
  assert.equal(auction.winnersCount, 5);
  assert.ok(auction.finalizedAt instanceof Date);
});

test('الإعلان قبل إغلاق المزايدة مرفوض، ومقبول بإذن تجاوز إداري صريح', async () => {
  const { store } = await biddingDone();
  await assert.rejects(
    () =>
      service.finalizeAuction({ store, now: NOW_MONDAY, auctionId: AUCTION_ONLINE, actor: 'admin-1' }),
    (e) => e.code === 'too-early',
  );
  const forced = await service.finalizeAuction({
    store,
    now: NOW_MONDAY,
    auctionId: AUCTION_ONLINE,
    actor: 'admin-override',
  });
  assert.equal(forced.winners.length, 5);
});

test('التعادل: الأسبق مزايدةً يتقدّم، والترتيب محفوظ في المستند', async () => {
  const store = createMemoryStore();
  await service.ensureWeeklyCycles({ store, now: NOW_MONDAY });
  for (const id of ['a', 'b', 'c']) store.seedProfile(id, teacher(id));
  // نفس المبلغ، أوقات مختلفة، والوصول بترتيب مقلوب.
  await bid(store, 'c', 500, { now: cairo(2026, 10, 13, 12) });
  await bid(store, 'b', 500, { now: cairo(2026, 10, 13, 11) });
  await bid(store, 'a', 500, { now: cairo(2026, 10, 13, 13) });

  const result = await service.finalizeAuction({
    store,
    now: THURSDAY,
    auctionId: AUCTION_ONLINE,
  });
  assert.deepEqual(result.winners.map((w) => w.teacherId), ['b', 'c', 'a']);
});

test('تعادل تام (نفس المبلغ والوقت) يُحسم بالمعرّف تصاعديًا', async () => {
  const store = createMemoryStore();
  await service.ensureWeeklyCycles({ store, now: NOW_MONDAY });
  const same = cairo(2026, 10, 13, 12);
  for (const id of ['z9', 'a1', 'm5']) {
    store.seedProfile(id, teacher(id));
    await bid(store, id, 500, { now: same });
  }
  const result = await service.finalizeAuction({
    store,
    now: THURSDAY,
    auctionId: AUCTION_ONLINE,
  });
  assert.deepEqual(result.winners.map((w) => w.teacherId), ['a1', 'm5', 'z9']);
});

test('إعادة تشغيل الإعلان لا تُغيّر الفائزين ولا تُكرّر الإشعارات', async () => {
  const { store } = await biddingDone();
  const first = await service.finalizeAuction({
    store,
    now: THURSDAY,
    auctionId: AUCTION_ONLINE,
  });
  const before = store.notificationsFor('on1').length;
  const second = await service.finalizeAuction({
    store,
    now: new Date(THURSDAY.getTime() + 600000),
    auctionId: AUCTION_ONLINE,
  });
  assert.equal(second.alreadyFinalized, true);
  assert.deepEqual(second.winners.sort(), first.winners.map((w) => w.teacherId).sort());
  assert.equal(store.notificationsFor('on1').length, before);
});

test('إشعار الفوز يذهب للفائزين فقط ويحمل مهلة الدفع وبلا مبالغ منافسين', async () => {
  const { store } = await biddingDone();
  await service.finalizeAuction({ store, now: THURSDAY, auctionId: AUCTION_ONLINE });

  for (const id of ['on1', 'on2', 'on3', 'on4', 'on5']) {
    const inbox = store.notificationsFor(id);
    assert.equal(inbox.length, 1);
    assert.equal(inbox[0].type, 'auctionWon');
    assert.equal(inbox[0].targetId, AUCTION_ONLINE);
    assert.ok(!/800|700|600/.test(inbox[0].body), 'لا مبالغ منافسين في نص الإشعار');
  }
  for (const id of ['on6', 'on7']) {
    assert.equal(store.notificationsFor(id).length, 0, 'الخاسر لا يُشعَر ولا يرى ترتيبه');
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// 4) الدفع والبديل
// ─────────────────────────────────────────────────────────────────────────────

test('تأكيد الدفع داخل المهلة يُثبِّت الحالة ويُسجِّل الفاعل', async () => {
  const { store } = await biddingDone();
  await service.finalizeAuction({ store, now: THURSDAY, auctionId: AUCTION_ONLINE });

  const result = await service.confirmWinnerPayment({
    store,
    now: cairo(2026, 10, 15, 12),
    auctionId: AUCTION_ONLINE,
    teacherId: 'on1',
    paid: true,
    actor: 'admin-1',
  });
  assert.equal(result.status, 'paid');
  assert.equal(store.auditEntries().some((e) => e.action === 'payment.confirm'), true);

  const replay = await service.confirmWinnerPayment({
    store,
    now: cairo(2026, 10, 15, 13),
    auctionId: AUCTION_ONLINE,
    teacherId: 'on1',
    paid: true,
    actor: 'admin-1',
  });
  assert.equal(replay.alreadyPaid, true);
});

test('الدفع بعد المهلة مرفوض، ورفض غير الفائز مرفوض', async () => {
  const { store } = await biddingDone();
  await service.finalizeAuction({ store, now: THURSDAY, auctionId: AUCTION_ONLINE });

  await assert.rejects(
    () =>
      service.confirmWinnerPayment({
        store,
        now: FRIDAY,
        auctionId: AUCTION_ONLINE,
        teacherId: 'on1',
        paid: true,
        actor: 'admin-1',
      }),
    (e) => e.code === 'payment-late',
  );
  await assert.rejects(
    () =>
      service.confirmWinnerPayment({
        store,
        now: THURSDAY,
        auctionId: AUCTION_ONLINE,
        teacherId: 'on7',
        paid: true,
        actor: 'admin-1',
      }),
    (e) => e.code === 'no-winner',
  );
  await assert.rejects(
    () =>
      service.confirmWinnerPayment({
        store,
        now: THURSDAY,
        auctionId: AUCTION_ONLINE,
        teacherId: 'on1',
        paid: true,
        actor: '',
      }),
    (e) => e.code === 'unauthorized',
  );
});

test('البديل: يملأ المقاعد غير المدفوعة بالترتيب التالي مرة واحدة فقط', async () => {
  const { store } = await biddingDone();
  await service.finalizeAuction({ store, now: THURSDAY, auctionId: AUCTION_ONLINE });

  for (const id of ['on1', 'on3', 'on4', 'on5']) {
    await service.confirmWinnerPayment({
      store,
      now: cairo(2026, 10, 15, 12),
      auctionId: AUCTION_ONLINE,
      teacherId: id,
      paid: true,
      actor: 'admin-1',
    });
  }
  // on2 استنفد الـ10 زيادات ولم يدفع ⇒ مقعده يُستبدل بـ on6.

  const first = await service.runReplacementRound({
    store,
    now: FRIDAY,
    auctionId: AUCTION_ONLINE,
    actor: 'system',
  });
  assert.equal(first.alreadyRan, false);
  assert.equal(first.seats, 1);
  assert.deepEqual(first.newWinners.map((w) => w.teacherId), ['on6']);
  assert.equal(first.newWinners[0].round, 2);
  assert.equal(store.notificationsFor('on6')[0].type, 'auctionReplacement');

  const second = await service.runReplacementRound({
    store,
    now: new Date(FRIDAY.getTime() + 600000),
    auctionId: AUCTION_ONLINE,
  });
  assert.equal(second.alreadyRan, true);
  assert.deepEqual(second.seats, []);

  const auction = await store.getAuction(AUCTION_ONLINE);
  assert.equal(auction.replacementRound, 1);
});

test('البديل قبل انتهاء مهلة الدفع مرفوض', async () => {
  const { store } = await biddingDone();
  await service.finalizeAuction({ store, now: THURSDAY, auctionId: AUCTION_ONLINE });
  await assert.rejects(
    () => service.runReplacementRound({ store, now: cairo(2026, 10, 15, 12), auctionId: AUCTION_ONLINE }),
    (e) => e.code === 'too-early',
  );
});

test('البديل: لا مرشحين ⇒ المقاعد تبقى فارغة، وغير المدفوع لا يُسنَد إليه شيء', async () => {
  const ctx = await setup({ online: 3 });
  await bid(ctx.store, 'on1', 300);
  await bid(ctx.store, 'on2', 200);
  await bid(ctx.store, 'on3', 100);
  await service.finalizeAuction({ store: ctx.store, now: THURSDAY, auctionId: AUCTION_ONLINE });

  const result = await service.runReplacementRound({
    store: ctx.store,
    now: FRIDAY,
    auctionId: AUCTION_ONLINE,
    actor: 'system',
  });
  assert.deepEqual(result.newWinners, []);
  // ثلاثة فائزين لم يدفعوا + مقعدان لم يُشغَلا أصلًا ⇒ 5 مقاعد بلا مرشح
  assert.equal(result.emptySeats, 5);

  const winners = ctx.store.listWinners(AUCTION_ONLINE);
  assert.ok(winners.every((w) => w.status !== 'pendingPayment'));
  assert.ok(winners.every((w) => w.teacherId !== undefined));
  assert.equal(ctx.store.listWinners(AUCTION_ONLINE).length, 3);
});

test('دفع فائز البديل يُقبل قبل مهلة البديل ويُرفض بعدها', async () => {
  const { store } = await biddingDone();
  await service.finalizeAuction({ store, now: THURSDAY, auctionId: AUCTION_ONLINE });
  await service.runReplacementRound({ store, now: FRIDAY, auctionId: AUCTION_ONLINE });

  const beforeWindowEnd = new Date(CYCLE.replacementDeadline.getTime() - 60000);
  const result = await service.confirmWinnerPayment({
    store,
    now: beforeWindowEnd,
    auctionId: AUCTION_ONLINE,
    teacherId: 'on6',
    paid: true,
    actor: 'admin-1',
  });
  assert.equal(result.status, 'paid');

  // on7 دخل دورة البديل أيضًا ⇒ متأخر، لا «غير فائز»
  await assert.rejects(
    () =>
      service.confirmWinnerPayment({
        store,
        now: new Date(CYCLE.replacementDeadline.getTime() + 60000),
        auctionId: AUCTION_ONLINE,
        teacherId: 'on7',
        paid: true,
        actor: 'admin-1',
      }),
    (e) => e.code === 'payment-late',
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// 5) النشر وانتهاء العرض
// ─────────────────────────────────────────────────────────────────────────────

async function paidAndPublished() {
  const ctx = await biddingDone();
  await service.finalizeAuction({ store: ctx.store, now: THURSDAY, auctionId: AUCTION_ONLINE });
  for (const id of ['on1', 'on2', 'on3', 'on4', 'on5']) {
    await service.confirmWinnerPayment({
      store: ctx.store,
      now: cairo(2026, 10, 15, 12),
      auctionId: AUCTION_ONLINE,
      teacherId: id,
      paid: true,
      actor: 'admin-1',
    });
  }
  return ctx;
}

test('النشر يضع العلم على المدفوعين فقط، والمستند العام بلا مبالغ', async () => {
  const { store } = await paidAndPublished();
  const result = await service.publishFeatured({
    store,
    now: SATURDAY,
    auctionId: AUCTION_ONLINE,
    actor: 'system',
  });
  assert.equal(result.published.length, 5);
  assert.equal(store.featuredOf('on1').isFeatured, true);
  assert.equal(store.featuredOf('on1').featuredOrder, 0);
  assert.equal(store.featuredOf('on5').featuredOrder, 4);
  assert.equal(store.featuredOf('on6'), null);

  const publicDoc = store.state.results.get(AUCTION_ONLINE);
  assert.equal(publicDoc.published, true);
  assert.deepEqual(publicDoc.winners.map((w) => w.teacherId), ['on1', 'on2', 'on3', 'on4', 'on5']);
  for (const winner of publicDoc.winners) {
    assert.equal('amount' in winner, false, 'المبلغ بيانات خاصة');
  }
  assert.ok(!JSON.stringify(publicDoc).includes('900'));
});

test('النشر قبل السبت مرفوض، وإعادة النشر لا تُكرَّر', async () => {
  const { store } = await paidAndPublished();
  await assert.rejects(
    () => service.publishFeatured({ store, now: FRIDAY, auctionId: AUCTION_ONLINE }),
    (e) => e.code === 'too-early',
  );
  await service.publishFeatured({ store, now: SATURDAY, auctionId: AUCTION_ONLINE });
  const again = await service.publishFeatured({
    store,
    now: new Date(SATURDAY.getTime() + 600000),
    auctionId: AUCTION_ONLINE,
  });
  assert.equal(again.alreadyPublished, true);
});

test('غير المدفوع لا يظهر تمييزًا ولا يُنشر', async () => {
  const { store } = await biddingDone();
  await service.finalizeAuction({ store, now: THURSDAY, auctionId: AUCTION_ONLINE });
  await service.confirmWinnerPayment({
    store,
    now: cairo(2026, 10, 15, 12),
    auctionId: AUCTION_ONLINE,
    teacherId: 'on1',
    paid: true,
    actor: 'admin-1',
  });
  await service.runReplacementRound({ store, now: FRIDAY, auctionId: AUCTION_ONLINE });
  const result = await service.publishFeatured({ store, now: SATURDAY, auctionId: AUCTION_ONLINE });

  assert.deepEqual(result.published.map((w) => w.teacherId), ['on1']);
  assert.equal(store.featuredOf('on1').isFeatured, true);
  for (const id of ['on2', 'on3', 'on4', 'on5']) {
    assert.equal(store.featuredOf(id), null, `${id} غير مدفوع ⇒ لا تمييز`);
  }
  assert.equal(store.state.results.get(AUCTION_ONLINE).emptySeats, 4);
});

test('expireFeatured يرفع العلم عن دورة المزاد فقط، ولا يُكرَّر', async () => {
  const { store } = await paidAndPublished();
  await service.publishFeatured({ store, now: SATURDAY, auctionId: AUCTION_ONLINE });

  // تمييز يدوي سابق لا علاقة له بالمزاد
  store.state.featured.set('manual', { isFeatured: true, featuredOrder: 7 });

  const endOfWeek = cairo(2026, 10, 23, 23, 59);
  const result = await service.expireFeatured({
    store,
    now: endOfWeek,
    auctionId: AUCTION_ONLINE,
    actor: 'system',
  });
  assert.equal(result.cleared.length, 5);
  assert.equal(store.featuredOf('on1').isFeatured, false);
  assert.equal(store.featuredOf('manual').isFeatured, true);

  const again = await service.expireFeatured({ store, now: endOfWeek, auctionId: AUCTION_ONLINE });
  assert.equal(again.alreadySettled, true);
});

test('الفئتان تنشران معًا بترتيب شريط غير متصادم (0..4 و5..9)', async () => {
  const { store } = await biddingDone();
  for (const auctionId of [AUCTION_ONLINE, AUCTION_IN_PERSON]) {
    await service.finalizeAuction({ store, now: THURSDAY, auctionId });
  }
  for (const id of ['on1', 'on2', 'on3', 'on4', 'on5']) {
    await service.confirmWinnerPayment({
      store,
      now: cairo(2026, 10, 15, 12),
      auctionId: AUCTION_ONLINE,
      teacherId: id,
      paid: true,
      actor: 'admin-1',
    });
  }
  for (const id of ['in1', 'in2']) {
    await service.confirmWinnerPayment({
      store,
      now: cairo(2026, 10, 15, 12),
      auctionId: AUCTION_IN_PERSON,
      teacherId: id,
      paid: true,
      actor: 'admin-1',
    });
  }
  await service.publishFeatured({ store, now: SATURDAY, auctionId: AUCTION_ONLINE });
  await service.publishFeatured({ store, now: SATURDAY, auctionId: AUCTION_IN_PERSON });

  assert.deepEqual(
    ['on1', 'on2', 'in1', 'in2'].map((id) => store.featuredOf(id).featuredOrder),
    [0, 1, 5, 6],
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// 6) الإعدادات
// ─────────────────────────────────────────────────────────────────────────────

test('updateConfig يرفض القيم خارج النطاق ويقبل الصحيحة', async () => {
  const { store } = await setup();
  await assert.rejects(
    () => service.updateConfig({ store, now: NOW_MONDAY, actor: 'admin-1', patch: { positionsPerCategory: 0 } }),
    (e) => e.code === 'invalid-config',
  );
  await assert.rejects(
    () => service.updateConfig({ store, now: NOW_MONDAY, actor: 'admin-1', patch: { bidStep: 0 } }),
    (e) => e.code === 'invalid-config',
  );
  await assert.rejects(
    () => service.updateConfig({ store, now: NOW_MONDAY, actor: '', patch: { minBid: 300 } }),
    (e) => e.code === 'unauthorized',
  );

  const next = await service.updateConfig({
    store,
    now: NOW_MONDAY,
    actor: 'admin-1',
    patch: { minBid: 300, bidStep: 50 },
  });
  assert.equal(next.minBid, 300);
  assert.equal(next.bidStep, 50);
  // الدورة القائمة تحتفظ بشروط إنشائها
  assert.equal((await store.getAuction(AUCTION_ONLINE)).minBid, 100);
});

// ─────────────────────────────────────────────────────────────────────────────
// 7) قراءات العرض: خصوصية المدرّس وشفافية الإدارة
// ─────────────────────────────────────────────────────────────────────────────

test('state: الفئة تُشتق من الملف على الخادم، ولا تُقبل من العميل', async () => {
  const { store } = await setup({ online: 3, inPerson: 2 });
  const online = await service.getTeacherAuctionState({ store, now: NOW_MONDAY, uid: 'on1' });
  const inPerson = await service.getTeacherAuctionState({ store, now: NOW_MONDAY, uid: 'in1' });
  assert.equal(online.category, 'online');
  assert.equal(inPerson.category, 'inPerson');
  assert.equal(online.auctionId, AUCTION_ONLINE);
  assert.equal(inPerson.auctionId, AUCTION_IN_PERSON);
});

test('state: لا تكشف أي بيانات منافس — لا مبالغ ولا عدّادات ولا هويات', async () => {
  const { store } = await setup({ online: 4 });
  await bid(store, 'on1', 100);
  await bid(store, 'on2', 400);
  await bid(store, 'on3', 900);

  const state = await service.getTeacherAuctionState({
    store,
    now: NOW_MONDAY,
    uid: 'on1',
  });
  const serialized = JSON.stringify(state);

  assert.equal(state.myBid.amount, 100);
  assert.equal(state.myBid.increasesUsed, 0);
  assert.equal(state.increasesRemaining, 10);
  assert.equal(state.nextMinimum, 125);

  // لا هوية منافس، ولا حقل من حقول الدورة الداخلية.
  for (const leaked of ['on2', 'on3', 'displayName', 'highestBid', 'biddersCount', 'bidCount']) {
    assert.equal(serialized.includes(leaked), false, `تسرّب: ${leaked}`);
  }
  // ولا مبلغ منافس: الحقول الرقمية كلها خاصة بي أو بحدود الأسبوع.
  assert.deepEqual(
    Object.keys(state).filter((key) => key.toLowerCase().includes('high')),
    [],
  );
});

test('state: تحمل المهلة والمعرّفات الزمنية بالأرقام (ms) لا كائنات', async () => {
  const { store } = await setup();
  const state = await service.getTeacherAuctionState({ store, now: NOW_MONDAY, uid: 'on1' });
  assert.equal(typeof state.serverNow, 'number');
  assert.equal(typeof state.closesAt, 'number');
  assert.equal(typeof state.paymentDeadline, 'number');
  assert.equal(state.timeZone, 'Africa/Cairo');
  assert.equal(state.phase, 'open');
  assert.equal(state.eligible, true);
  assert.equal(state.eligibility, null);
});

test('state: غير الموثّق/المخفي يرى السبب ولا يزايد', async () => {
  const { store } = await setup({ online: 1 });
  store.seedProfile('pending', teacher('pending', { status: 'pendingReview' }));
  store.seedProfile('hidden', teacher('hidden', { accountHidden: true }));

  const pending = await service.getTeacherAuctionState({ store, now: NOW_MONDAY, uid: 'pending' });
  assert.equal(pending.eligible, false);
  assert.equal(pending.eligibility, 'notVerified');

  const hidden = await service.getTeacherAuctionState({ store, now: NOW_MONDAY, uid: 'hidden' });
  assert.equal(hidden.eligible, false);
  assert.equal(hidden.eligibility, 'accountHidden');

  await assert.rejects(
    () => service.getTeacherAuctionState({ store, now: NOW_MONDAY, uid: 'ghost' }),
    (e) => e.code === 'not-verified',
  );
});

test('state: تنشئ الدورة تلقائيًا إن لم يُشغَّل المجدول (بلا دهس دورة قائمة)', async () => {
  const store = createMemoryStore();
  store.seedProfile('on1', teacher('on1'));
  const state = await service.getTeacherAuctionState({ store, now: NOW_MONDAY, uid: 'on1' });
  assert.ok(state.auctionId);
  assert.equal(await store.getAuction(state.auctionId) !== null, true);

  // وجود الدورة مسبقًا (بمزايدة) لا يُفقدها.
  await bid(store, 'on1', 100);
  await service.getTeacherAuctionState({ store, now: NOW_MONDAY, uid: 'on1' });
  assert.equal((await store.getBid(state.auctionId, 'on1')).amount, 100);
});

test('state: بعد الفوز تحمل مقعدي وماليته ومهلته فقط', async () => {
  const { store } = await biddingDone();
  await service.finalizeAuction({ store, now: THURSDAY, auctionId: AUCTION_ONLINE });

  const winner = await service.getTeacherAuctionState({
    store,
    now: cairo(2026, 10, 15, 12),
    uid: 'on1',
  });
  assert.equal(winner.myWinner.rank, 1);
  assert.equal(winner.myWinner.status, 'pendingPayment');
  assert.equal(winner.myWinner.paid, false);
  assert.equal(winner.myWinner.deadline, CYCLE.paymentDeadline.getTime());

  const loser = await service.getTeacherAuctionState({
    store,
    now: cairo(2026, 10, 15, 12),
    uid: 'on7',
  });
  assert.equal(loser.myWinner, null);
  assert.equal(JSON.stringify(loser).includes('on1'), false, 'لا هوية منافس');
});

test('state: النتائج العامة بلا مبالغ، وتظهر بعد النشر فقط', async () => {
  const { store } = await paidAndPublished();
  const before = await service.getTeacherAuctionState({
    store,
    now: FRIDAY,
    uid: 'on1',
  });
  assert.equal(before.results, null);

  await service.publishFeatured({ store, now: SATURDAY, auctionId: AUCTION_ONLINE });
  const after = await service.getTeacherAuctionState({
    store,
    now: SATURDAY,
    uid: 'on1',
  });
  assert.equal(after.results.winners.length, 5);
  assert.equal(after.results.winners[0].rank, 1);
  assert.equal(JSON.stringify(after.results).includes('900'), false);
});

test('admin overview: الفئتان والفائزون بمبالغهم وحالاتهم وسجل الأثر', async () => {
  const { store } = await biddingDone();
  await service.finalizeAuction({ store, now: THURSDAY, auctionId: AUCTION_ONLINE });
  await service.confirmWinnerPayment({
    store,
    now: cairo(2026, 10, 15, 12),
    auctionId: AUCTION_ONLINE,
    teacherId: 'on1',
    paid: true,
    actor: 'admin-1',
  });

  const overview = await service.getAdminOverview({ store, now: THURSDAY });
  assert.equal(overview.cycleKey, CYCLE.cycleKey);
  assert.equal(overview.categories.length, 2);

  const online = overview.categories.find((c) => c.category === 'online');
  // الخميس 09:10 ⇒ بعد الإعلان، وداخل مهلة الدفع (تنتهي الجمعة 09:00).
  assert.equal(online.phase, 'paymentWindow');
  assert.equal(online.winners.length, 5);
  assert.equal(online.winners[0].teacherId, 'on1');
  assert.equal(online.winners[0].amount, 900);
  assert.equal(online.winners[0].status, 'paid');
  assert.equal(online.winners[1].status, 'pendingPayment');
  assert.equal(online.highestBid, 900);
  assert.equal(online.biddersCount, 7);

  const inPerson = overview.categories.find((c) => c.category === 'inPerson');
  assert.equal(inPerson.biddersCount, 2);
  assert.equal(inPerson.winners.length, 0);

  assert.ok(overview.audit.length > 0);
  assert.ok(overview.audit.some((entry) => entry.action === 'payment.confirm'));
  // كل الطوابع الزمنية أرقام (JSON) لا كائنات Date.
  assert.equal(typeof online.paymentDeadline, 'number');
});

test('admin overview: أسبوع بلا دورات يُنشئها ثم يعرضها', async () => {
  const store = createMemoryStore();
  const overview = await service.getAdminOverview({ store, now: NOW_MONDAY });
  assert.equal(overview.categories.length, 2);
  assert.ok(overview.categories.every((c) => c.missing === false));
});

// ─────────────────────────────────────────────────────────────────────────────
// 8) النتائج المعروضة على شاشة «المميزون»
// ─────────────────────────────────────────────────────────────────────────────

test('featured results: بلا نشر ⇒ لا نتائج (لا أسماء مخمّنة)', async () => {
  const { store } = await biddingDone();
  const bundle = await service.getFeaturedResults({ store, now: THURSDAY });
  assert.equal(bundle.categories.online, null);
  assert.equal(bundle.categories.inPerson, null);
  assert.equal(bundle.displayCycleKey, null);
});

test('featured results: تعرض دورة العرض الحالية لكل فئة على حدة', async () => {
  const { store } = await paidAndPublished();
  await service.publishFeatured({ store, now: SATURDAY, auctionId: AUCTION_ONLINE });

  // أثناء أسبوع العرض (السبت): دورة هذا الأسبوع.
  const during = await service.getFeaturedResults({ store, now: SATURDAY });
  assert.equal(during.categories.online.cycleKey, CYCLE.cycleKey);
  assert.equal(during.categories.online.winners.length, 5);
  assert.equal(during.categories.inPerson, null, 'الفئة الحضورية لم تُنشر');

  // يوم الأربعاء من الأسبوع التالي: آخر دورة منشورة تبقى معروضة.
  const nextWeek = await service.getFeaturedResults({
    store,
    now: cairo(2026, 10, 21, 12),
  });
  assert.equal(nextWeek.categories.online.cycleKey, CYCLE.cycleKey);
});

test('featured results: بعد دورة جديدة تُقدَّم الأحدث', async () => {
  const { store } = await paidAndPublished();
  await service.publishFeatured({ store, now: SATURDAY, auctionId: AUCTION_ONLINE });

  // دورة الأسبوع التالي.
  const nextMonday = cairo(2026, 10, 19, 10);
  await service.ensureWeeklyCycles({ store, now: nextMonday });
  const nextCycle = core.weeklySchedule(nextMonday);
  const nextAuctionId = core.cycleId(nextCycle.cycleKey, 'online');
  await service.placeBid({
    store,
    now: nextMonday,
    uid: 'on1',
    category: 'online',
    cycleKey: nextCycle.cycleKey,
    amount: 700,
    requestId: 'next-week-bid-1',
  });
  await service.finalizeAuction({ store, now: cairo(2026, 10, 22, 10), auctionId: nextAuctionId });
  await service.confirmWinnerPayment({
    store,
    now: cairo(2026, 10, 22, 12),
    auctionId: nextAuctionId,
    teacherId: 'on1',
    paid: true,
    actor: 'admin-1',
  });
  await service.publishFeatured({
    store,
    now: cairo(2026, 10, 24, 0, 10),
    auctionId: nextAuctionId,
  });

  const bundle = await service.getFeaturedResults({
    store,
    now: cairo(2026, 10, 24, 0, 30),
  });
  assert.equal(bundle.categories.online.cycleKey, nextCycle.cycleKey);
  assert.equal(bundle.displayCycleKey, nextCycle.cycleKey);
});
