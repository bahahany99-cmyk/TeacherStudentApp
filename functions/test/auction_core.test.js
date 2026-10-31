/**
 * اختبارات نواة المزاد — بلا Firebase ولا محاكي.
 *
 * تغطي: الجدول الأسبوعي (بتوقيت القاهرة، بما فيه تغيير التوقيت الصيفي)، آلة
 * الحالات، تحقق المزايدات، الترتيب والتعادل، اختيار الفائزين، دورة البديل.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const core = require('../lib/auction_core');

/** تاريخ محلي في القاهرة ⇒ Date (لمقروئية الاختبارات). */
const cairo = (year, month, day, hour = 0, minute = 0) =>
  core.cairoTimeToUtc({ year, month, day, hour, minute });

const auctionFromSchedule = (schedule, overrides = {}) => ({
  id: `${schedule.cycleKey}-online`,
  cycleKey: schedule.cycleKey,
  category: 'online',
  ...schedule,
  minBid: 100,
  bidStep: 25,
  extraBidLimit: 10,
  maxBid: 50000,
  positions: 5,
  ...overrides,
});

const verifiedTeacher = (id, overrides = {}) => ({
  id,
  status: 'verified',
  isOnline: true,
  accountHidden: false,
  displayName: id,
  ...overrides,
});

// ─────────────────────────────────────────────────────────────────────────────
// 1) التوقيت والجدول
// ─────────────────────────────────────────────────────────────────────────────

test('Cairo offset: +02:00 شتاءً و+03:00 صيفًا', () => {
  assert.equal(core.cairoOffsetMinutes(new Date('2026-01-15T12:00:00Z')), 120);
  assert.equal(core.cairoOffsetMinutes(new Date('2026-07-15T12:00:00Z')), 180);
});

test('تحويل وقت محلي إلى UTC صحيح في الشتاء والصيف', () => {
  assert.equal(
    cairo(2026, 1, 12, 9, 0).toISOString(),
    '2026-01-12T07:00:00.000Z',
  );
  assert.equal(
    cairo(2026, 7, 16, 9, 0).toISOString(),
    '2026-07-16T06:00:00.000Z',
  );
});

test('الجدول: مزايدة الاثنين 00:00 → الأربعاء 23:59، والإعلان الخميس 09:00', () => {
  const schedule = core.weeklySchedule(new Date('2026-10-12T10:00:00Z')); // اثنين
  assert.equal(schedule.cycleKey, '2026-W42');
  assert.equal(schedule.opensAt.toISOString(), cairo(2026, 10, 12, 0, 0).toISOString());
  assert.equal(
    schedule.closesAt.toISOString(),
    new Date(cairo(2026, 10, 14, 23, 59).getTime() + 59000).toISOString(),
  );
  // آخر مزايدة مقبولة = الإغلاق − 10 دقائق
  assert.equal(
    schedule.closesAt.getTime() - schedule.bidCutoffAt.getTime(),
    10 * 60 * 1000,
  );
  assert.equal(schedule.announcesAt.toISOString(), cairo(2026, 10, 15, 9, 0).toISOString());
  assert.equal(
    schedule.paymentDeadline.getTime() - schedule.announcesAt.getTime(),
    24 * 3600 * 1000,
  );
  assert.equal(schedule.displayStartsAt.toISOString(), cairo(2026, 10, 17, 0, 0).toISOString());
  assert.equal(
    schedule.displayEndsAt.toISOString(),
    new Date(cairo(2026, 10, 23, 23, 59).getTime() + 59000).toISOString(),
  );
});

test('مفتاح الأسبوع ثابت داخل الأسبوع ومختلف بين أسبوعين', () => {
  const monday = core.weeklySchedule(new Date('2026-10-12T09:00:00Z')).cycleKey;
  const wednesday = core.weeklySchedule(new Date('2026-10-14T20:00:00Z')).cycleKey;
  const nextMonday = core.weeklySchedule(new Date('2026-10-19T09:00:00Z')).cycleKey;
  assert.equal(monday, wednesday);
  assert.notEqual(monday, nextMonday);
});

test('الجدول يبقى صحيحًا في الأسبوع الذي يسبق تغيير التوقيت الصيفي', () => {
  // مصر تعود للتوقيت الصيفي (+3) الجمعة الأخيرة من أبريل. أسبوع 20–26 أبريل
  // يقع بكامله في التوقيت الشتوي (+2)، فيجب أن تبقى كل حدوده متسقة.
  const schedule = core.weeklySchedule(new Date('2026-04-21T12:00:00Z'));
  assert.equal(schedule.cycleKey, '2026-W17');
  assert.equal(schedule.opensAt.toISOString(), '2026-04-19T22:00:00.000Z'); // +2
  assert.equal(schedule.announcesAt.toISOString(), '2026-04-23T07:00:00.000Z'); // +2
  // والأسبوع التالي يقع بكامله في التوقيت الصيفي (+3).
  const next = core.weeklySchedule(new Date('2026-04-27T12:00:00Z'));
  assert.equal(next.opensAt.toISOString(), '2026-04-26T21:00:00.000Z'); // +3
  assert.equal(next.announcesAt.toISOString(), '2026-04-30T06:00:00.000Z'); // +3
});

test('تحويل الأوقات غير الموجودة/المكرّرة عند تغيير التوقيت لا ينهار', () => {
  // 24 أبريل 2026 الساعة 00:00 غير موجودة محليًا (القفز إلى 01:00).
  const springForward = cairo(2026, 4, 24, 0, 0);
  assert.ok(Number.isFinite(springForward.getTime()));
  // ومع ذلك يبقى الرجوع لوقت لاحق صحيحًا.
  assert.ok(cairo(2026, 4, 24, 9, 0).getTime() > springForward.getTime());
});

// ─────────────────────────────────────────────────────────────────────────────
// 2) آلة الحالات
// ─────────────────────────────────────────────────────────────────────────────

test('deriveStatus يمر بكل المراحل بترتيب صحيح', () => {
  const schedule = core.weeklySchedule(new Date('2026-10-12T10:00:00Z'));
  const auction = auctionFromSchedule(schedule);
  const at = (localDate) => core.deriveStatus(auction, localDate);

  assert.equal(at(cairo(2026, 10, 11, 12)), 'scheduled');
  assert.equal(at(cairo(2026, 10, 12, 0, 1)), 'open');
  // نافذة الحظر = آخر 10 دقائق قبل الإغلاق (23:49:00 → 23:59:59 محليًا).
  assert.equal(at(cairo(2026, 10, 14, 23, 48)), 'open');
  assert.equal(at(cairo(2026, 10, 14, 23, 52)), 'gracePeriod');
  assert.equal(at(cairo(2026, 10, 15, 0, 30)), 'awaitingFinalize');
  assert.equal(at(cairo(2026, 10, 15, 10)), 'paymentWindow');
  assert.equal(at(cairo(2026, 10, 16, 10)), 'replacement');
  assert.equal(at(cairo(2026, 10, 17, 1)), 'awaitingPublish');
  assert.equal(
    at(cairo(2026, 10, 17, 1)) === 'awaitingPublish' &&
      core.deriveStatus({ ...auction, settledAt: cairo(2026, 10, 17, 1) }, cairo(2026, 10, 17, 2)),
    'ended',
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// 3) تحقق المزايدة
// ─────────────────────────────────────────────────────────────────────────────

const bidSetup = () => {
  const schedule = core.weeklySchedule(new Date('2026-10-12T10:00:00Z'));
  return {
    auction: auctionFromSchedule(schedule),
    now: cairo(2026, 10, 13, 12), // الثلاثاء
    profile: verifiedTeacher('teacher-1'),
  };
};

test('المزايدة الأولى: أقل مبلغ = minBid، والزيادات = 0', () => {
  const { auction, now, profile } = bidSetup();
  const result = core.validateBid({ auction, profile, currentBid: null, amount: 100, now });
  assert.deepEqual(result, { amount: 100, increasesUsed: 0, isFirst: true });
});

test('المزايدة الأولى تحت الحد الأدنى مرفوضة', () => {
  const { auction, now, profile } = bidSetup();
  assert.throws(
    () => core.validateBid({ auction, profile, currentBid: null, amount: 99, now }),
    (error) => error.code === 'below-min',
  );
});

test('الزيادة أقل من الخطوة مرفوضة، والمساوية مقبولة', () => {
  const { auction, now, profile } = bidSetup();
  const currentBid = { amount: 100, increasesUsed: 0, placedAt: now };
  assert.throws(
    () => core.validateBid({ auction, profile, currentBid, amount: 124, now }),
    (error) => error.code === 'below-step',
  );
  assert.equal(
    core.validateBid({ auction, profile, currentBid, amount: 125, now }).increasesUsed,
    1,
  );
});

test('الزيادات المجانية محدودة بعشر، والحادية عشرة مرفوضة', () => {
  const { auction, now, profile } = bidSetup();
  const currentBid = { amount: 500, increasesUsed: 10, placedAt: now };
  assert.throws(
    () => core.validateBid({ auction, profile, currentBid, amount: 600, now }),
    (error) => error.code === 'no-increases-left',
  );
  assert.equal(core.increasesRemaining(auction, currentBid), 0);
  assert.equal(
    core.increasesRemaining(auction, { amount: 500, increasesUsed: 7 }),
    3,
  );
});

test('آخر 10 دقائق: المزايدة مرفوضة قبل الإغلاق بعشر دقائق', () => {
  const { auction, profile } = bidSetup();
  const exactCutoff = new Date(auction.bidCutoffAt);
  assert.throws(
    () => core.validateBid({ auction, profile, currentBid: null, amount: 200, now: exactCutoff }),
    (error) => error.code === 'closed-last-minutes',
  );
  const oneMinuteBeforeCutoff = new Date(auction.bidCutoffAt.getTime() - 60000);
  assert.equal(
    core.validateBid({ auction, profile, currentBid: null, amount: 200, now: oneMinuteBeforeCutoff })
      .amount,
    200,
  );
});

test('بعد الإغلاق وبعد الإعلان: المزايدة مرفوضة دائمًا', () => {
  const { auction, profile } = bidSetup();
  for (const now of [cairo(2026, 10, 15, 10), cairo(2026, 10, 16, 10)]) {
    assert.throws(
      () => core.validateBid({ auction, profile, currentBid: null, amount: 500, now }),
      (error) => error.code === 'closed',
    );
  }
});

test('قبل الفتح: المزايدة مرفوضة', () => {
  const { auction, profile } = bidSetup();
  assert.throws(
    () =>
      core.validateBid({
        auction,
        profile,
        currentBid: null,
        amount: 500,
        now: cairo(2026, 10, 11, 12),
      }),
    (error) => error.code === 'not-open',
  );
});

test('الأهلية: غير موثّق، أو مخفي، أو فئة مختلفة ⇒ مرفوضون', () => {
  const { auction, now } = bidSetup();
  const attempt = (profile) =>
    core.validateBid({ auction, profile, currentBid: null, amount: 500, now });

  assert.throws(() => attempt(verifiedTeacher('t', { status: 'pendingReview' })), (e) => e.code === 'not-verified');
  assert.throws(() => attempt(verifiedTeacher('t', { accountHidden: true })), (e) => e.code === 'account-hidden');
  assert.throws(() => attempt(verifiedTeacher('t', { isOnline: false })), (e) => e.code === 'wrong-category');
});

test('المبالغ غير الصحيحة والحد الأقصى', () => {
  const { auction, now, profile } = bidSetup();
  const attempt = (amount) =>
    core.validateBid({ auction, profile, currentBid: null, amount, now });
  for (const amount of [0, -5, 1.5, NaN]) {
    assert.throws(() => attempt(amount), (error) => error.code === 'invalid-amount');
  }
  assert.throws(() => attempt(50001), (error) => error.code === 'amount-too-high');
});

test('nextMinimumBid يطابق قاعدة الخادم', () => {
  const { auction } = bidSetup();
  assert.equal(core.nextMinimumBid(auction, null), 100);
  assert.equal(core.nextMinimumBid(auction, { amount: 250 }), 275);
});

// ─────────────────────────────────────────────────────────────────────────────
// 4) الترتيب والتعادل
// ─────────────────────────────────────────────────────────────────────────────

const bid = (teacherId, amount, seconds) => ({
  teacherId,
  amount,
  placedAt: new Date(Date.UTC(2026, 9, 13, 10, 0, seconds)),
});

test('الترتيب: المبلغ الأعلى أولًا', () => {
  const ranked = core.rankBids([bid('a', 100, 1), bid('b', 300, 2), bid('c', 200, 3)]);
  assert.deepEqual(ranked.map((x) => x.teacherId), ['b', 'c', 'a']);
});

test('التعادل: الأسبق مزايدةً يفوز، ثم المعرّف تصاعديًا (حتمي)', () => {
  const ranked = core.rankBids([bid('c', 500, 9), bid('a', 500, 3), bid('b', 500, 9)]);
  assert.deepEqual(ranked.map((x) => x.teacherId), ['a', 'b', 'c']);
});

test('الترتيب لا يعتمد على ترتيب الإدخال (ثبات)', () => {
  const input = [bid('x', 400, 5), bid('y', 400, 5), bid('z', 700, 1)];
  const first = core.rankBids(input).map((b) => b.teacherId);
  const shuffled = [input[2], input[0], input[1]];
  assert.deepEqual(core.rankBids(shuffled).map((b) => b.teacherId), first);
});

test('اختيار الفائزين: أعلى 5 فقط، والمقاعد الناقصة تبقى فارغة', () => {
  const bids = ['a', 'b', 'c', 'd', 'e', 'f'].map((id, index) =>
    bid(id, 1000 - index * 10, index),
  );
  const winners = core.selectWinners(bids, 5);
  assert.equal(winners.length, 5);
  assert.equal(winners[0].teacherId, 'a');
  assert.ok(!winners.some((w) => w.teacherId === 'f'));

  assert.equal(core.selectWinners(bids.slice(0, 2), 5).length, 2);
  assert.equal(core.selectWinners([], 5).length, 0);
});

test('selectWinners يحترم قائمة المستبعدين', () => {
  const bids = ['a', 'b', 'c'].map((id, index) => bid(id, 900 - index, index));
  const winners = core.selectWinners(bids, 1, { exclude: new Set(['a']) });
  assert.deepEqual(winners.map((w) => w.teacherId), ['b']);
});

// ─────────────────────────────────────────────────────────────────────────────
// 5) دورة البديل
// ─────────────────────────────────────────────────────────────────────────────

test('دورة البديل تملأ المقاعد غير المدفوعة بالترتيب التالي', () => {
  const bids = ['a', 'b', 'c', 'd', 'e', 'f', 'g'].map((id, index) =>
    bid(id, 900 - index * 10, index),
  );
  const winners = [
    { teacherId: 'a', paid: true },
    { teacherId: 'b', paid: false },
    { teacherId: 'c', paid: true },
    { teacherId: 'd', paid: false },
    { teacherId: 'e', paid: true },
  ];
  const plan = core.buildReplacement({ bids, winners, positions: 5 });
  assert.equal(plan.seats, 2);
  assert.deepEqual(plan.filled.map((w) => w.teacherId), ['f', 'g']);
  assert.equal(plan.emptySeats, 0);
});

test('دورة البديل: لا مرشحين ⇒ المقاعد تبقى فارغة', () => {
  const bids = ['a', 'b'].map((id, index) => bid(id, 500 - index, index));
  const winnerRows = [
    { teacherId: 'a', paid: false },
    { teacherId: 'b', paid: true },
  ];
  const plan = core.buildReplacement({ bids, winners: winnerRows, positions: 5 });
  // مقعد واحد غير مدفوع + 3 مقاعد لم تُملأ أصلًا
  assert.equal(plan.seats, 4);
  assert.equal(plan.filled.length, 0);
  assert.equal(plan.emptySeats, 4);
});

test('دورة البديل: كل الفائزين دفعوا ⇒ لا شيء يُستبدل', () => {
  const bids = ['a', 'b'].map((id, index) => bid(id, 500 - index, index));
  const winners = bids.map((b) => ({ teacherId: b.teacherId, paid: true }));
  const plan = core.buildReplacement({ bids, winners, positions: 2 });
  assert.deepEqual(plan, { seats: 0, filled: [], emptySeats: 0 });
});

// ─────────────────────────────────────────────────────────────────────────────
// 6) التكرار والتمييز
// ─────────────────────────────────────────────────────────────────────────────

test('معرّف الطلب: يرفض الفارغ والقصير والحروف غير المسموحة', () => {
  for (const bad of ['', 'short', 'has space 123', 'x'.repeat(129), null, 42]) {
    assert.throws(() => core.assertRequestId(bad), (error) => error.code === 'invalid-request-id');
  }
  assert.equal(core.assertRequestId('abc12345'), 'abc12345');
});

test('معرّف التكرار يجمع المستخدم والطلب', () => {
  assert.equal(core.idempotencyDocId('u1', 'req12345'), 'u1_req12345');
});

test('assignments: أونلاين 0..4 وحضوري 5..9 (بلا تصادم)', () => {
  const assignments = core.featuredAssignments({
    online: [{ teacherId: 'a' }, { teacherId: 'b' }],
    inPerson: [{ teacherId: 'c' }],
  });
  assert.deepEqual(
    assignments.map((a) => [a.teacherId, a.featuredOrder]),
    [
      ['a', 0],
      ['b', 1],
      ['c', 5],
    ],
  );
});

test('cycleId يرفض فئة غير معروفة', () => {
  assert.equal(core.cycleId('2026-W42', 'online'), '2026-W42-online');
  assert.throws(() => core.cycleId('2026-W42', 'hybrid'), (e) => e.code === 'invalid-category');
});
