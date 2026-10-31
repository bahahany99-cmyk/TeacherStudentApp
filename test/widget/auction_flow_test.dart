import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/models/weekly_auction.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/auction_repository.dart';
import 'package:teacher_student_app/features/auction/presentation/auction_screen.dart';

import '../helpers/test_app.dart';

/// اختبارات شاشة المزاد (P30) على مستودع مزيّف.
///
/// **ما تُثبته:**
///   1. الشاشة تعرض ما يُرسله الخادم فقط (المرحلة، الشروط، مزايدتي).
///   2. الإرسال يمرّ بمعرّف طلب (منع الازدواج) وبالمبلغ المكتوب.
///   3. الحالات الأربع تظهر صريحة: مفتوح، مغلق، فائز، غير مؤهل.
///   4. **لا تُعرض أرقام منافسين** — وهي غير موجودة في النموذج أصلًا.

/// مستودع مزيّف: يعيد حالة جاهزة ويسجّل النداءات.
class _FakeAuctionRepository implements AuctionRepository {
  _FakeAuctionRepository(this.state);

  AuctionState state;
  final List<({int amount, String requestId, AuctionCategory category})> bids =
      <({int amount, String requestId, AuctionCategory category})>[];

  @override
  Future<AuctionState> loadMyState() async => state;

  @override
  Future<AuctionBidOutcome> placeBid({
    required AuctionCategory category,
    required int amount,
    required String requestId,
  }) async {
    bids.add((amount: amount, requestId: requestId, category: category));
    return AuctionBidOutcome(
      amount: amount,
      increasesUsed: 0,
      increasesRemaining: 10,
      nextMinimum: amount + 25,
      isFirst: true,
      replayed: false,
    );
  }

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

/// الأربعاء 14 أكتوبر 2026، 12:00 — منتصف نافذة المزايدة.
final DateTime _now = DateTime(2026, 10, 14, 12);

AuctionState _state({
  String phase = 'open',
  bool eligible = true,
  AuctionBidSummary? myBid,
  AuctionSeat? myWinner,
  AuctionResultsView? results,
  int increasesRemaining = 10,
}) {
  return AuctionState(
    serverNow: _now,
    timeZone: 'Africa/Cairo',
    cycleKey: '2026-W42',
    auctionId: '2026-W42-online',
    category: AuctionCategory.online,
    phase: AuctionPhase.parse(phase),
    opensAt: _now.subtract(const Duration(days: 2)),
    closesAt: _now.add(const Duration(hours: 12)),
    bidCutoffAt: _now.add(const Duration(hours: 11, minutes: 50)),
    announcesAt: _now.add(const Duration(hours: 21)),
    paymentDeadline: _now.add(const Duration(days: 2)),
    replacementDeadline: _now.add(const Duration(days: 3)),
    displayStartsAt: _now.add(const Duration(days: 3, hours: 12)),
    displayEndsAt: _now.add(const Duration(days: 10, hours: 12)),
    minBid: 100,
    bidStep: 25,
    maxBid: 50000,
    extraBidLimit: 10,
    positions: 5,
    eligible: eligible,
    eligibility: eligible ? null : 'notVerified',
    myBid: myBid,
    increasesRemaining: increasesRemaining,
    nextMinimum: myBid == null ? 100 : myBid.amount + 25,
    myWinner: myWinner,
    results: results,
  );
}

AppServices _services(AuctionRepository auctions) {
  final AppServices base = AppServices.demo();
  return AppServices(
    auth: base.auth,
    teachers: base.teachers,
    groups: base.groups,
    bookings: base.bookings,
    schedules: base.schedules,
    messages: base.messages,
    chats: base.chats,
    notifications: base.notifications,
    reviews: base.reviews,
    favorites: base.favorites,
    admin: base.admin,
    avatars: base.avatars,
    auctions: auctions,
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  AuctionRepository auctions,
) async {
  usePhoneSurface(tester);
  await tester.pumpWidget(
    AppServicesScope(
      services: _services(auctions),
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: AuctionScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('تعرض المرحلة والشروط والعدّاد من حالة الخادم', (
    WidgetTester tester,
  ) async {
    final _FakeAuctionRepository repo = _FakeAuctionRepository(_state());
    await _pumpScreen(tester, repo);

    expect(find.byKey(const Key('auction-phase')), findsOneWidget);
    expect(find.text('المزايدة مفتوحة'), findsOneWidget);
    expect(find.byKey(const Key('auction-countdown')), findsOneWidget);
    expect(find.byKey(const Key('auction-no-bid')), findsOneWidget);
    // الشروط من الدورة نفسها لا من ثوابت في الواجهة.
    expect(find.text('5'), findsWidgets);
    expect(find.text('100 جنيه'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('إرسال مزايدة: يمتد بمعرّف طلب ويُرسل المبلغ المكتوب', (
    WidgetTester tester,
  ) async {
    final _FakeAuctionRepository repo = _FakeAuctionRepository(_state());
    await _pumpScreen(tester, repo);

    await tester.tap(find.byKey(const Key('auction-use-suggested')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('auction-submit')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.bids.length, 1);
    expect(repo.bids.single.amount, 100);
    expect(repo.bids.single.category, AuctionCategory.online);
    expect(repo.bids.single.requestId.length >= 8, isTrue);
    expect(repo.bids.single.requestId, matches(RegExp(r'^[A-Za-z0-9_-]+$')));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('مبلغ أقل من الحد الأدنى لا يُرسل', (WidgetTester tester) async {
    final _FakeAuctionRepository repo = _FakeAuctionRepository(_state());
    await _pumpScreen(tester, repo);

    await tester.enterText(find.byKey(const Key('auction-amount-field')), '50');
    await tester.pump();
    await tester.tap(find.byKey(const Key('auction-submit')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.bids, isEmpty);
    expect(find.textContaining('أقل مزايدة مقبولة'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('آخر 10 دقائق: الحقل والزر معطّلان مع سبب صريح', (
    WidgetTester tester,
  ) async {
    final _FakeAuctionRepository repo = _FakeAuctionRepository(
      _state(phase: 'gracePeriod'),
    );
    await _pumpScreen(tester, repo);

    expect(find.byKey(const Key('auction-closed-note')), findsOneWidget);
    expect(find.textContaining('آخر 10 دقائق'), findsOneWidget);

    final Finder submit = find.byKey(const Key('auction-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('غير المؤهل: يرى السبب ولا يزايد', (WidgetTester tester) async {
    final _FakeAuctionRepository repo = _FakeAuctionRepository(
      _state(eligible: false),
    );
    await _pumpScreen(tester, repo);

    expect(find.byKey(const Key('auction-ineligible')), findsOneWidget);
    expect(find.textContaining('الموثّقين'), findsOneWidget);
    expect(find.byKey(const Key('auction-amount-field')), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('الفائز يرى مقعده ومهلته وتعليمات السداد', (
    WidgetTester tester,
  ) async {
    final _FakeAuctionRepository repo = _FakeAuctionRepository(
      _state(
        phase: 'paymentWindow',
        myBid: AuctionBidSummary(amount: 500, increasesUsed: 3, placedAt: _now),
        myWinner: AuctionSeat(
          status: 'pendingPayment',
          round: 1,
          paid: false,
          deadline: _now.add(const Duration(days: 2)),
          rank: 1,
          amount: 500,
        ),
      ),
    );
    await _pumpScreen(tester, repo);

    expect(find.byKey(const Key('auction-seat-title')), findsOneWidget);
    expect(find.text('فزت بمقعد'), findsOneWidget);
    expect(find.byKey(const Key('auction-payment-deadline')), findsOneWidget);
    expect(find.textContaining('support@darsly.app'), findsOneWidget);
    // لا يوجد حقل مزايدة لفائز انتهى مزاده.
    expect(find.byKey(const Key('auction-amount-field')), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('مزايدتي الحالية تظهر مع رصيد الزيادات', (
    WidgetTester tester,
  ) async {
    final _FakeAuctionRepository repo = _FakeAuctionRepository(
      _state(
        myBid: AuctionBidSummary(amount: 325, increasesUsed: 2, placedAt: _now),
        increasesRemaining: 8,
      ),
    );
    await _pumpScreen(tester, repo);

    expect(find.byKey(const Key('auction-my-bid')), findsOneWidget);
    expect(find.text('325 جنيه'), findsOneWidget);
    expect(find.text('8 زيادة متاحة'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('النتائج المنشورة تُعرض بالأسماء والمراكز فقط', (
    WidgetTester tester,
  ) async {
    final _FakeAuctionRepository repo = _FakeAuctionRepository(
      _state(
        phase: 'awaitingPublish',
        results: const AuctionResultsView(
          cycleKey: '2026-W42',
          category: AuctionCategory.online,
          emptySeats: 1,
          winners: <AuctionResultEntry>[
            AuctionResultEntry(
              teacherId: 't1',
              displayName: 'أ. سارة',
              round: 1,
              rank: 1,
            ),
          ],
        ),
      ),
    );
    await _pumpScreen(tester, repo);

    expect(find.byKey(const Key('auction-results')), findsOneWidget);
    expect(find.text('أ. سارة'), findsOneWidget);
    expect(find.textContaining('مقعد بقي فارغًا'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
