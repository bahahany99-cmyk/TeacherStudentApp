import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_effects.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/weekly_auction.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/auction_repository.dart';
import 'package:teacher_student_app/data/validation/auction_rules.dart';
import 'package:teacher_student_app/features/auction/presentation/auction_text.dart';

/// شاشة المدرّس في مزاد التمييز الأسبوعي (P30).
///
/// **ما تفعله:** تعرض حالة الأسبوع (فئتي، المرحلة، العدّاد، شروطي)، ومزايدتي
/// أنا، ومقعدي إن فزت، والنتائج المنشورة. وترسل مزايدة واحدة عبر الخادم.
///
/// **ما لا تفعله — بقصد:**
///   - لا تحسب الأهلية ولا الفائز ولا الترتيب: كلها من الخادم.
///   - لا تُظهر أي مبلغ أو اسم لمنافس: لا يوجد في الاستجابة ما يُظهره.
///   - لا تعتمد على ساعة الجهاز في القرار: العدّاد للعرض، والقبول للخادم.
///   - لا تعرض «ادفع الآن» كبوّابة دفع: لا توجد بوّابة في هذا المشروع (قرار
///     P30). تُعرض تعليمات سداد عبر الدعم، ويُعتمد الدفع إداريًا بعد التحصيل.
class AuctionScreen extends StatefulWidget {
  const AuctionScreen({super.key});

  @override
  State<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends State<AuctionScreen> {
  final TextEditingController _amountController = TextEditingController();

  /// ساعة عرض مربوطة بساعة الخادم (تتحدّث كل ثانية للعدّاد).
  Timer? _ticker;
  int _reloads = 0;
  bool _submitting = false;

  /// مفتاح منع الازدواج للطلب الجاري: يُولَّد عند الضغط ويُعاد إرساله في كل
  /// محاولة حتى تنجح، فلا تُحتسب زيادة مرتين لو ضعف الاتصال وأُعيد الإرسال.
  String? _requestId;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  /// معرّف طلب عشوائي (32 حرفًا) — الخادم يقبل `[A-Za-z0-9_-]{8,128}`.
  String _newRequestId() {
    final DateTime now = DateTime.now();
    final int salt = now.microsecondsSinceEpoch;
    return 'bid-${now.millisecondsSinceEpoch}-$salt'
        .replaceAll(RegExp('[^A-Za-z0-9_-]'), '-');
  }

  Future<void> _submit(AuctionState state) async {
    final int? amount = int.tryParse(_amountController.text.trim());
    final String? problem = amount == null
        ? 'أدخل المبلغ بالأرقام.'
        : AuctionRules.validateAmount(
            amount: amount,
            minBid: state.minBid,
            bidStep: state.bidStep,
            maxBid: state.maxBid,
            isFirst: state.myBid == null,
            currentAmount: state.myBid?.amount,
          );
    if (problem != null) {
      AppSnackBar.show(context, problem, type: AppMessageType.error);
      return;
    }

    final AuctionCategory? category = state.category;
    if (category == null) return;

    setState(() => _submitting = true);
    _requestId ??= _newRequestId();
    try {
      final AuctionBidOutcome outcome = await AppServicesScope.of(
        context,
      ).auctions.placeBid(
        category: category,
        amount: amount!,
        requestId: _requestId!,
      );
      if (!mounted) return;
      // بعد النجاح نبدأ مفتاحًا جديدًا: الزيادة القادمة طلب مستقل.
      _requestId = null;
      _amountController.clear();
      setState(() => _reloads++);
      AppSnackBar.show(
        context,
        outcome.replayed
            ? 'تم تأكيد مزايدتك السابقة (${AuctionText.money(outcome.amount)}).'
            : outcome.isFirst
            ? 'سُجّلت مزايدتك: ${AuctionText.money(outcome.amount)}. '
                  'تبقّى ${outcome.increasesRemaining} زيادة.'
            : 'زيادة مقبولة: ${AuctionText.money(outcome.amount)}. '
                  'تبقّى ${outcome.increasesRemaining} زيادة.',
        type: AppMessageType.success,
      );
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackBar.show(
        context,
        error.overrideMessage ?? error.message,
        type: AppMessageType.error,
      );
    } on AuctionUnavailable {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackBar.show(
        context,
        'المزاد يحتاج الاتصال بخادم درسلي. هذه النسخة تعمل بلا خادم.',
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('مزاد التمييز'),
        actions: <Widget>[
          IconButton(
            key: const Key('auction-refresh'),
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _reloads++),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: AsyncView<AuctionState>(
          reloadKey: _reloads,
          keepPreviousData: true,
          load: () => AppServicesScope.of(context).auctions.loadMyState(),
          builder: (BuildContext context, AuctionState state) =>
              _body(context, state),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AuctionState state) {
    final ThemeData theme = Theme.of(context);
    final ServerClockView clock = ServerClockView(state: state);

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: AppSpacing.sm),
              _PhaseCard(state: state, clock: clock),
              const SizedBox(height: AppSpacing.sm),
              if (!state.eligible)
                _IneligibleCard(state: state)
              else if (state.myWinner != null)
                _SeatCard(seat: state.myWinner!, state: state)
              else
                _BidCard(
                  state: state,
                  controller: _amountController,
                  submitting: _submitting,
                  onSubmit: () => _submit(state),
                ),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader(title: 'شروط هذا الأسبوع'),
              _RulesCard(state: state),
              if (state.results != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const SectionHeader(title: 'فائزون تميّزوا هذا الأسبوع'),
                _ResultsCard(results: state.results!),
              ],
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    InfoNote(
                      text:
                          'كل شيء يُحسم على الخادم: الأهلية، والوقت، وعدد '
                          'الزيادات، والترتيب، والفائز. التطبيق يعرض ويُرسل '
                          'طلبك فقط، ولا يمكنه تعديل مزاد أو ترتيب.',
                      icon: Icons.shield_outlined,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    InfoNote(
                      text:
                          'لا يظهر لك أي مبلغ أو اسم لمنافسيك، ولا يظهر لهم '
                          'اسمك أو مبلغك. تُعلن الأسماء فقط بعد انتهاء العرض.',
                      icon: Icons.visibility_outlined,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'الفئة: ${state.category?.label ?? '—'} · '
                      'الجدول بتوقيت القاهرة (${state.timeZone}).',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// بطاقات الشاشة
// ─────────────────────────────────────────────────────────────────────────────

/// المرحلة + العدّاد التنازلي.
class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.state, required this.clock});

  final AuctionState state;
  final ServerClockView clock;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool open = state.phase.canBid;
    final DateTime target = switch (state.phase) {
      AuctionPhase.scheduled => state.opensAt,
      AuctionPhase.open => state.bidCutoffAt,
      AuctionPhase.paymentWindow => state.myWinner?.deadline ?? state.paymentDeadline,
      AuctionPhase.replacement =>
        state.myWinner?.deadline ?? state.replacementDeadline ?? state.paymentDeadline,
      AuctionPhase.awaitingPublish => state.displayStartsAt,
      _ => state.closesAt,
    };
    final Duration remaining = clock.remainingUntil(target);

    return AppCard(
      gradient: open ? AppGradients.glow : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  state.phase.label,
                  key: const Key('auction-phase'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusChip(
                label: state.phase.canBid ? 'مفتوح' : 'مغلق',
                color: state.phase.canBid ? AppColors.accent : AppColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            AuctionText.phaseCaption(state),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.7,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            key: const Key('auction-countdown'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.timer_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    remaining.isNegative
                        ? 'انتهى الموعد'
                        : 'المتبقي ${AuctionText.duration(remaining)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// المزايدة: الحالة الحالية + صندوق الزيادة.
class _BidCard extends StatelessWidget {
  const _BidCard({
    required this.state,
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  final AuctionState state;
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuctionBidSummary? myBid = state.myBid;
    final bool canBid = state.phase.canBid;
    final bool noIncreasesLeft = myBid != null && state.increasesRemaining <= 0;
    final int suggested = AuctionRules.nextMinimum(
      minBid: state.minBid,
      bidStep: state.bidStep,
      currentAmount: myBid?.amount,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            myBid == null ? 'مزايدتي' : 'مزايدتي الحالية',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (myBid == null)
            Text(
              'لم تزايد بعد. أول مزايدة تبدأ من ${AuctionText.money(state.minBid)}.',
              key: const Key('auction-no-bid'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.7,
              ),
            )
          else ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    AuctionText.money(myBid.amount),
                    key: const Key('auction-my-bid'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                StatusChip(
                  label: '${state.increasesRemaining} زيادة متاحة',
                  color: noIncreasesLeft
                      ? AppColors.attentionForeground
                      : AppColors.accent,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'استخدمت ${myBid.increasesUsed} من ${state.extraBidLimit} زيادة. '
              'أقل زيادة مقبولة الآن: ${AuctionText.money(suggested)}.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('auction-amount-field'),
            controller: controller,
            enabled: canBid && !noIncreasesLeft && !submitting,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: InputDecoration(
              labelText: myBid == null ? 'مبلغ المزايدة' : 'مبلغ الزيادة',
              helperText: 'المقترح: ${AuctionText.thousands(suggested)} جنيه',
              suffixText: 'جنيه',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('auction-use-suggested'),
                  onPressed: canBid && !noIncreasesLeft
                      ? () => controller.text = '$suggested'
                      : null,
                  icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                  label: const Text('استخدم المقترح'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('auction-submit'),
                  onPressed: canBid && !noIncreasesLeft && !submitting
                      ? onSubmit
                      : null,
                  icon: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.gavel_outlined, size: 18),
                  label: Text(myBid == null ? 'زايد' : 'زد'),
                ),
              ),
            ],
          ),
          if (!canBid) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              state.phase == AuctionPhase.gracePeriod
                  ? 'لا تُقبل مزايدات في آخر 10 دقائق قبل الإغلاق.'
                  : 'المزايدة متاحة بين فتح الأسبوع وإغلاقه فقط.',
              key: const Key('auction-closed-note'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.attentionForeground,
                height: 1.6,
              ),
            ),
          ],
          if (noIncreasesLeft) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'استنفدت زياداتك المجانية (${state.extraBidLimit}). '
              'مزايدتك الأخيرة قائمة حتى إعلان النتائج.',
              key: const Key('auction-no-increases'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.attentionForeground,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// مقعد الفائز: المركز/الترتيب، المهلة، وحالة الدفع.
class _SeatCard extends StatelessWidget {
  const _SeatCard({required this.seat, required this.state});

  final AuctionSeat seat;
  final AuctionState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool paid = seat.paid;
    final DateTime? deadline = seat.deadline;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                paid ? Icons.verified_outlined : Icons.emoji_events_outlined,
                color: paid ? AppColors.accent : theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  paid ? 'مقعدك مؤكَّد' : 'فزت بمقعد',
                  key: const Key('auction-seat-title'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusChip(
                label: AuctionText.seatStatus(seat),
                color: paid
                    ? AppColors.accent
                    : seat.status == 'unpaid'
                    ? AppColors.statusRejected
                    : AppColors.attentionForeground,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            seat.round == 2
                ? 'مقعد من دورة البديل.'
                : 'المركز ${seat.rank ?? '—'} في فئة ${state.category?.label ?? '—'}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.7,
            ),
          ),
          if (!paid && seat.status == 'pendingPayment') ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.attentionForeground.withAlpha(18),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    deadline == null
                        ? 'بانتظار تأكيد الدفع من الإدارة.'
                        : 'مهلة الدفع حتى ${AuctionText.dayTime(deadline)}.',
                    key: const Key('auction-payment-deadline'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.attentionForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'للدفع: تواصل مع الدعم (support@darsly.app) وسيُسجَّل الدفع '
                    'بعد التحصيل. لا توجد بوّابة دفع داخل التطبيق.',
                    style: theme.textTheme.labelSmall?.copyWith(height: 1.7),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// غير مؤهل: السبب + ما يفعله.
class _IneligibleCard extends StatelessWidget {
  const _IneligibleCard({required this.state});

  final AuctionState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'لا يمكنك المزايدة الآن',
            key: const Key('auction-ineligible'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            state.ineligibilityMessage ?? 'حسابك غير مؤهل للمشاركة في المزاد.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

/// شروط الأسبوع (تُقرأ من الدورة نفسها — لا أرقام مكتوبة في الواجهة).
class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.state});

  final AuctionState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<(String, String)> rows = <(String, String)>[
      ('مقاعد الفئة', '${state.positions}'),
      ('أقل مزايدة', AuctionText.money(state.minBid)),
      ('خطوة الزيادة', AuctionText.money(state.bidStep)),
      ('زيادات مجانية', '${state.extraBidLimit}'),
      ('الحد الأقصى', AuctionText.money(state.maxBid)),
      ('يُغلق باب المزايدة', AuctionText.dayTime(state.bidCutoffAt)),
      ('إعلان الفائزين', AuctionText.dayTime(state.announcesAt)),
      ('مهلة الدفع', AuctionText.dayTime(state.paymentDeadline)),
      ('بدء العرض', AuctionText.dayDate(state.displayStartsAt)),
      ('نهاية العرض', AuctionText.dayDate(state.displayEndsAt)),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (String label, String value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// الفائزون المنشورون (أسماء ومراكز فقط).
class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.results});

  final AuctionResultsView results;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      key: const Key('auction-results'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final AuctionResultEntry winner in results.winners)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primary.withAlpha(24),
                    child: Text(
                      '${winner.rank ?? '•'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      winner.displayName.isEmpty ? 'مدرّس' : winner.displayName,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  if (winner.round == 2)
                    StatusChip(
                      label: 'بديل',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          if (results.emptySeats > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${results.emptySeats} مقعد بقي فارغًا هذا الأسبوع.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
