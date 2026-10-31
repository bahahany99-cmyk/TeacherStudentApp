import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/demo/demo_auction_repository.dart';
import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/weekly_auction.dart';
import 'package:teacher_student_app/data/services/auction_repository.dart';
import 'package:teacher_student_app/data/validation/auction_rules.dart';
import 'package:teacher_student_app/features/auction/presentation/auction_text.dart';

/// اختبارات نواة الواجهة لمزاد التمييز (P30).
///
/// **ما تُثبته:** أن التطبيق يقرأ ما يُرسله الخادم كما هو، ولا يحسب قرارًا
/// بنفسه؛ وأن الخصوصية في النموذج بنيوية (لا حقول منافسين أصلًا)؛ وأن قواعد
/// العرض في `AuctionRules` تطابق قواعد الخادم المعلنة.
void main() {
  group('AuctionState.fromMap', () {
    Map<Object?, Object?> payload({Object? myBid, Object? myWinner}) =>
        <Object?, Object?>{
          'serverNow': 1791000000000,
          'timeZone': 'Africa/Cairo',
          'cycleKey': '2026-W45',
          'auctionId': '2026-W45-online',
          'category': 'online',
          'phase': 'open',
          'opensAt': 1790800000000,
          'closesAt': 1791000000000,
          'bidCutoffAt': 1790999400000,
          'announcesAt': 1791100000000,
          'paymentDeadline': 1791186400000,
          'displayStartsAt': 1791300000000,
          'displayEndsAt': 1791900000000,
          'minBid': 100,
          'bidStep': 25,
          'maxBid': 50000,
          'extraBidLimit': 10,
          'positions': 5,
          'eligible': true,
          'increasesRemaining': 8,
          'nextMinimum': 350,
          'myBid': myBid,
          'myWinner': myWinner,
          'results': null,
        };

    test('تقرأ الحقول الأساسية وتفهم الفئة والمرحلة', () {
      final AuctionState state = AuctionState.fromMap(payload());
      expect(state.cycleKey, '2026-W45');
      expect(state.auctionId, '2026-W45-online');
      expect(state.category, AuctionCategory.online);
      expect(state.phase, AuctionPhase.open);
      expect(state.phase.canBid, isTrue);
      expect(state.timeZone, 'Africa/Cairo');
      expect(state.positions, 5);
      expect(state.minBid, 100);
      expect(state.bidStep, 25);
      expect(state.extraBidLimit, 10);
      expect(state.eligible, isTrue);
      expect(state.ineligibilityMessage, isNull);
      // الطوابع الزمنية أرقام ميلي ثانية، لا كائنات جهاز.
      expect(state.closesAt.millisecondsSinceEpoch, isNot(0));
      expect(state.myBid, isNull);
      expect(state.myWinner, isNull);
      expect(state.results, isNull);
    });

    test('فئة غير معروفة تُقرأ null، ومرحلة غير معروفة تُقرأ scheduled', () {
      final AuctionState state = AuctionState.fromMap(<Object?, Object?>{
        ...payload(),
        'category': 'hybrid',
        'phase': 'teleported',
      });
      expect(state.category, isNull);
      expect(state.phase, AuctionPhase.scheduled);
      expect(state.phase.canBid, isFalse);
    });

    test('مزايدتي أنا فقط — لا حقول لمنافس في النموذج', () {
      final AuctionState state = AuctionState.fromMap(
        payload(
          myBid: <Object?, Object?>{
            'amount': 325,
            'increasesUsed': 2,
            'placedAt': 1790900000000,
          },
          myWinner: <Object?, Object?>{
            'rank': 2,
            'status': 'pendingPayment',
            'round': 1,
            'paid': false,
            'amount': 325,
            'deadline': 1791186400000,
          },
        ),
      );
      expect(state.myBid?.amount, 325);
      expect(state.myBid?.increasesUsed, 2);
      expect(state.myWinner?.rank, 2);
      expect(state.myWinner?.isPendingPayment, isTrue);
      expect(state.myWinner?.paid, isFalse);
      // لا يوجد في النموذج ما يُقرأ منه مبلغ منافس أو هويته.
      expect(state.toString(), isNot(contains('highestBid')));
    });

    test('سبب عدم الأهلية يُترجم إلى نص عربي', () {
      final AuctionState hidden = AuctionState.fromMap(<Object?, Object?>{
        ...payload(),
        'eligible': false,
        'eligibility': 'accountHidden',
      });
      expect(hidden.eligible, isFalse);
      expect(hidden.ineligibilityMessage, contains('ملفك مخفي'));

      final AuctionState pending = AuctionState.fromMap(<Object?, Object?>{
        ...payload(),
        'eligible': false,
        'eligibility': 'notVerified',
      });
      expect(pending.ineligibilityMessage, contains('الموثّقين'));
    });

    test('النتائج العامة: أسماء ومراكز فقط', () {
      final AuctionResultsView? results = AuctionResultsView.fromMap(
        <Object?, Object?>{
          'cycleKey': '2026-W45',
          'category': 'inPerson',
          'published': true,
          'emptySeats': 1,
          'winners': <Object?>[
            <Object?, Object?>{
              'teacherId': 't1',
              'displayName': 'أ. سارة',
              'rank': 1,
              'round': 1,
            },
            <Object?, Object?>{
              'teacherId': 't2',
              'displayName': 'أ. منى',
              'rank': 2,
              'round': 2,
            },
          ],
        },
      );
      expect(results, isNotNull);
      expect(results!.category, AuctionCategory.inPerson);
      expect(results.winners.length, 2);
      expect(results.winners.first.displayName, 'أ. سارة');
      expect(results.winners.last.round, 2);
      expect(results.emptySeats, 1);
    });

    test('مستند غير منشور يُقرأ null (لا نتائج تقديرية)', () {
      expect(
        AuctionResultsView.fromMap(<Object?, Object?>{
          'published': false,
          'winners': <Object?>[],
        }),
        isNull,
      );
    });

    test('نظرة الإدارة تقرأ الفائزين والمبالغ والأثر', () {
      final AuctionAdminOverview overview = AuctionAdminOverview.fromMap(
        <Object?, Object?>{
          'cycleKey': '2026-W45',
          'serverNow': 1791000000000,
          'config': <Object?, Object?>{'minBid': 150, 'positionsPerCategory': 5},
          'categories': <Object?>[
            <Object?, Object?>{
              'auctionId': '2026-W45-online',
              'category': 'online',
              'missing': false,
              'phase': 'paymentWindow',
              'positions': 5,
              'bidCount': 12,
              'biddersCount': 4,
              'highestBid': 900,
              'emptySeats': 0,
              'replacementRound': 0,
              'winners': <Object?>[
                <Object?, Object?>{
                  'teacherId': 't1',
                  'displayName': 'أ. سارة',
                  'rank': 1,
                  'amount': 900,
                  'round': 1,
                  'status': 'paid',
                },
                <Object?, Object?>{
                  'teacherId': 't2',
                  'displayName': 'أ. منى',
                  'rank': 2,
                  'amount': 800,
                  'round': 1,
                  'status': 'pendingPayment',
                },
              ],
            },
          ],
          'audit': <Object?>[
            <Object?, Object?>{
              'at': 1791000000000,
              'actor': 'admin-1',
              'action': 'payment.confirm',
              'detail': '2026-W45-online/t1',
            },
          ],
        },
      );

      expect(overview.config.minBid, 150);
      expect(overview.categories.single.highestBid, 900);
      expect(overview.categories.single.paidCount, 1);
      expect(overview.categories.single.unpaidCount, 0);
      expect(overview.audit.single.label, 'تأكيد دفع');
    });
  });

  group('AuctionRules — مطابقة قواعد الخادم المعروضة', () {
    test('أقل مزايدة تالية: الحد الأدنى أولًا ثم الحالي + الخطوة', () {
      expect(AuctionRules.nextMinimum(minBid: 100, bidStep: 25), 100);
      expect(
        AuctionRules.nextMinimum(minBid: 100, bidStep: 25, currentAmount: 300),
        325,
      );
    });

    test('التحقق يرفض ما دون الحد ويرفض الزيادة الأقل من الخطوة', () {
      expect(
        AuctionRules.validateAmount(
          amount: 99,
          minBid: 100,
          bidStep: 25,
          maxBid: 50000,
          isFirst: true,
        ),
        contains('100'),
      );
      expect(
        AuctionRules.validateAmount(
          amount: 124,
          minBid: 100,
          bidStep: 25,
          maxBid: 50000,
          isFirst: false,
          currentAmount: 100,
        ),
        contains('125'),
      );
      expect(
        AuctionRules.validateAmount(
          amount: 125,
          minBid: 100,
          bidStep: 25,
          maxBid: 50000,
          isFirst: false,
          currentAmount: 100,
        ),
        isNull,
      );
    });

    test('الحد الأقصى والأرقام غير الصحيحة', () {
      expect(
        AuctionRules.validateAmount(
          amount: 50001,
          minBid: 100,
          bidStep: 25,
          maxBid: 50000,
          isFirst: true,
        ),
        contains('50000'),
      );
      for (final int bad in <int>[0, -25]) {
        expect(
          AuctionRules.validateAmount(
            amount: bad,
            minBid: 100,
            bidStep: 25,
            maxBid: 50000,
            isFirst: true,
          ),
          isNotNull,
        );
      }
      expect(AuctionRules.clampAmount(amount: 999999, maxBid: 50000), 50000);
      expect(AuctionRules.clampAmount(amount: -5, maxBid: 50000), 0);
    });

    test('canSubmit يحترم المرحلة والأهلية ورصيد الزيادات', () {
      AuctionState state({String phase = 'open', bool eligible = true, int remaining = 10}) =>
          AuctionState.fromMap(<Object?, Object?>{
            'serverNow': 1791000000000,
            'cycleKey': '2026-W45',
            'auctionId': '2026-W45-online',
            'category': 'online',
            'phase': phase,
            'opensAt': 1790800000000,
            'closesAt': 1791000000000,
            'bidCutoffAt': 1790999400000,
            'announcesAt': 1791100000000,
            'paymentDeadline': 1791186400000,
            'displayStartsAt': 1791300000000,
            'displayEndsAt': 1791900000000,
            'minBid': 100,
            'bidStep': 25,
            'maxBid': 50000,
            'extraBidLimit': 10,
            'positions': 5,
            'eligible': eligible,
            'increasesRemaining': remaining,
            'nextMinimum': 100,
            'myBid': remaining == 10
                ? null
                : <Object?, Object?>{
                    'amount': 500,
                    'increasesUsed': 10 - remaining,
                  },
          });

      expect(
        AuctionRules.canSubmit(state: state(), amount: 100, submitting: false),
        isTrue,
      );
      expect(
        AuctionRules.canSubmit(state: state(), amount: 99, submitting: false),
        isFalse,
      );
      expect(
        AuctionRules.canSubmit(
          state: state(phase: 'gracePeriod'),
          amount: 100,
          submitting: false,
        ),
        isFalse,
      );
      expect(
        AuctionRules.canSubmit(
          state: state(eligible: false),
          amount: 100,
          submitting: false,
        ),
        isFalse,
      );
      expect(
        AuctionRules.canSubmit(
          state: state(remaining: 0),
          amount: 525,
          submitting: false,
        ),
        isFalse,
        reason: 'استنفد الزيادات المجانية',
      );
      expect(
        AuctionRules.canSubmit(state: state(), amount: 100, submitting: true),
        isFalse,
      );
    });
  });

  group('AuctionText — صياغة عربية موحّدة', () {
    test('المبالغ بفواصل الآلاف', () {
      expect(AuctionText.thousands(500), '500');
      expect(AuctionText.thousands(1500), '1,500');
      expect(AuctionText.thousands(1234567), '1,234,567');
      expect(AuctionText.money(2500), '2,500 جنيه');
    });

    test('الساعة بنظام 12 ساعة مع ص/م', () {
      expect(AuctionText.clock(DateTime(2026, 10, 14, 23, 59)), '11:59 م');
      expect(AuctionText.clock(DateTime(2026, 10, 14, 9, 5)), '9:05 ص');
      expect(AuctionText.clock(DateTime(2026, 10, 14, 12, 0)), '12:00 م');
      expect(AuctionText.clock(DateTime(2026, 10, 14, 0, 30)), '12:30 ص');
    });

    test('اليوم والتاريخ بالعربية', () {
      expect(
        AuctionText.dayTime(DateTime(2026, 10, 14, 23, 59)),
        'الأربعاء 11:59 م',
      );
      expect(
        AuctionText.dayDate(DateTime(2026, 10, 17)),
        'السبت 17 أكتوبر',
      );
    });

    test('المدد بأقرب وحدة مفهومة', () {
      expect(AuctionText.duration(const Duration(days: 2, hours: 5)), '2 يوم و5 ساعة');
      expect(AuctionText.duration(const Duration(hours: 3, minutes: 20)), '3 ساعة و20 دقيقة');
      expect(AuctionText.duration(const Duration(minutes: 14)), '14 دقيقة');
      expect(AuctionText.duration(const Duration(seconds: 30)), '30 ثانية');
      expect(AuctionText.duration(const Duration(seconds: -5)), 'انتهى');
      expect(AuctionText.duration(Duration.zero), 'انتهى');
    });
  });

  group('ServerClockView — العدّاد لا يُخدع بساعة الجهاز', () {
    test('يعرض وقت الخادم لا وقت الجهاز', () {
      final DateTime device = DateTime(2026, 10, 14, 12);
      final AuctionState state = AuctionState.fromMap(<Object?, Object?>{
        'serverNow': device
            .add(const Duration(hours: 3))
            .millisecondsSinceEpoch,
        'cycleKey': '2026-W45',
        'auctionId': '2026-W45-online',
        'phase': 'open',
        'closesAt': device
            .add(const Duration(hours: 5))
            .millisecondsSinceEpoch,
        'bidCutoffAt': device
            .add(const Duration(hours: 5))
            .millisecondsSinceEpoch,
        'announcesAt': 0,
        'paymentDeadline': 0,
        'displayStartsAt': 0,
        'displayEndsAt': 0,
      });

      final ServerClockView clock = ServerClockView(
        state: state,
        deviceNow: () => device,
      );
      // ساعة الخادم تسبق الجهاز 3 ساعات ⇒ المتبقي ساعتان فقط.
      expect(clock.remainingUntil(state.bidCutoffAt).inHours, 2);
      expect(clock.now, device.add(const Duration(hours: 3)));
    });
  });

  group('DemoAuctionRepository — محاكاة محلية صريحة', () {
    // الثلاثاء 13 أكتوبر 2026 (داخل نافذة المزايدة).
    final DateTime tuesday = DateTime(2026, 10, 13, 12);

    test('المزايدة تُقبل، والزيادة تحسب من رصيد الزيادات', () async {
      final DemoAuctionRepository repo = DemoAuctionRepository(
        clock: () => tuesday,
      );
      final AuctionState before = await repo.loadMyState();
      expect(before.phase, AuctionPhase.open);
      expect(before.myBid, isNull);
      expect(before.nextMinimum, 100);

      final AuctionBidOutcome first = await repo.placeBid(
        category: AuctionCategory.online,
        amount: 100,
        requestId: 'req-1-abcdefgh',
      );
      expect(first.isFirst, isTrue);
      expect(first.increasesRemaining, 10);

      final AuctionBidOutcome increase = await repo.placeBid(
        category: AuctionCategory.online,
        amount: 125,
        requestId: 'req-2-abcdefgh',
      );
      expect(increase.increasesUsed, 1);
      expect(increase.nextMinimum, 150);

      final AuctionState after = await repo.loadMyState();
      expect(after.myBid?.amount, 125);
      expect(after.increasesRemaining, 9);
    });

    test('زيادة أقل من الخطوة أو مبلغ أكبر من السقف تُرفض', () async {
      final DemoAuctionRepository repo = DemoAuctionRepository(
        clock: () => tuesday,
      );
      await repo.placeBid(
        category: AuctionCategory.online,
        amount: 100,
        requestId: 'req-1-abcdefgh',
      );
      await expectLater(
        repo.placeBid(
          category: AuctionCategory.online,
          amount: 110,
          requestId: 'req-2-abcdefgh',
        ),
        throwsA(isA<AuctionUnavailable>()),
      );
      await expectLater(
        repo.placeBid(
          category: AuctionCategory.online,
          amount: 500000,
          requestId: 'req-3-abcdefgh',
        ),
        throwsA(isA<AuctionUnavailable>()),
      );
    });

    test('خارج النافذة (بعد آخر 10 دقائق) تُرفض المزايدة', () async {
      // الأربعاء 23:55 تقريبًا — داخل آخر 10 دقائق.
      final DateTime late = DateTime(2026, 10, 14, 23, 52);
      final DemoAuctionRepository repo = DemoAuctionRepository(clock: () => late);
      final AuctionState state = await repo.loadMyState();
      expect(state.phase, AuctionPhase.gracePeriod);
      expect(state.phase.canBid, isFalse);
      await expectLater(
        repo.placeBid(
          category: AuctionCategory.online,
          amount: 100,
          requestId: 'req-late-abcdefgh',
        ),
        throwsA(isA<AuctionUnavailable>()),
      );
    });

    test('استنفاد الزيادات يمنع المزيد', () async {
      final DemoAuctionRepository repo = DemoAuctionRepository(
        clock: () => tuesday,
        extraBidLimit: 2,
      );
      await repo.placeBid(
        category: AuctionCategory.online,
        amount: 100,
        requestId: 'req-0-abcdefgh',
      );
      for (int i = 1; i <= 2; i += 1) {
        await repo.placeBid(
          category: AuctionCategory.online,
          amount: 100 + i * 25,
          requestId: 'req-$i-abcdefgh',
        );
      }
      await expectLater(
        repo.placeBid(
          category: AuctionCategory.online,
          amount: 175,
          requestId: 'req-3-abcdefgh',
        ),
        throwsA(isA<AuctionUnavailable>()),
      );
    });

    test('عمليات الإدارة غير متاحة في المحاكاة (لا تزييف)', () async {
      final DemoAuctionRepository repo = DemoAuctionRepository(
        clock: () => tuesday,
      );
      await expectLater(
        repo.loadAdminOverview(),
        throwsA(isA<AuctionUnavailable>()),
      );
      expect(await repo.loadPublishedResults(), isEmpty);
    });

    test('فئة المدرّس الحضوري لا تزايد في فئة الأونلاين', () async {
      final DemoAuctionRepository repo = DemoAuctionRepository(
        clock: () => tuesday,
        isOnline: false,
      );
      final AuctionState state = await repo.loadMyState();
      expect(state.category, AuctionCategory.inPerson);
      await expectLater(
        repo.placeBid(
          category: AuctionCategory.online,
          amount: 100,
          requestId: 'req-wrong-abcdefgh',
        ),
        throwsA(isA<AuctionUnavailable>()),
      );
    });
  });

  group('إشعارات المزاد', () {
    test('الأنواع الثلاثة تُقرأ من الخادم وتفتح شاشة المزاد', () {
      for (final NotificationType type in <NotificationType>[
        NotificationType.auctionWon,
        NotificationType.auctionReplacement,
        NotificationType.auctionPaymentExpired,
      ]) {
        expect(NotificationType.parse(type.wireName), type);
        expect(type.target, NotificationTarget.auction);
      }
      expect(NotificationTarget.parse('auction'), NotificationTarget.auction);
      expect(NotificationType.auctionWon.wireName, 'auctionWon');
    });
  });

  group('AuctionConfig', () {
    test('تُرسل كاملة إلى الخادم وتُقرأ ناقصة بأمان', () {
      const AuctionConfig config = AuctionConfig(
        positionsPerCategory: 5,
        minBid: 150,
        bidStep: 50,
        extraBidLimit: 8,
        maxBid: 20000,
        paymentWindowHours: 24,
        replacementWindowHours: 12,
      );
      final Map<String, Object?> map = config.toMap();
      expect(map['minBid'], 150);
      expect(map['extraBidLimit'], 8);
      // الحقول السبعة القديمة + ساعة الإعلان + دقائق الحظر.
      expect(map['announceHour'], 9);
      expect(map['bidCutoffMinutes'], 10);
      expect(map.keys.length, 9);

      expect(AuctionConfig.fromMap(<Object?, Object?>{}).minBid, 100);
      expect(
        AuctionConfig.fromMap(<Object?, Object?>{'bidStep': 40}).bidStep,
        40,
      );
      expect(
        AuctionConfig.fromMap(null).positionsPerCategory,
        5,
      );
    });
  });
}
