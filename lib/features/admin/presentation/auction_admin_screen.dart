import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
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
import 'package:teacher_student_app/features/auction/presentation/auction_text.dart';

/// «مزاد التمييز» — شاشة الإدارة (P30).
///
/// **ما تفعله:** تعرض الدورتين (أونلاين/حضوري) بمزايداتهما المجمّعة وفائزيهما
/// وحالة كل دفع، وتتيح: تعديل الإعدادات، حسم المزاد، تأكيد/رفض دفع، تشغيل
/// دورة البديل، نشر التمييز، وإنهاء تمييز دورة منتهية. وكل إجراء يُسجَّل في
/// سجل الأثر باسم المنفّذ.
///
/// **ما لا تفعله:** لا تحسب ترتيبًا ولا فائزًا ولا تتحقق من المهلة بنفسها.
/// الدوال في `functions/index.js` تتحقق من الادعاء الإداري ومن النافذة الزمنية
/// ومن التكرار، والقواعد تمنع أي كتابة مباشرة. فإن كان الزر معروضًا في وقت
/// غير صحيح رفض الخادم الطلب وظهر السبب بالعربية.
class AuctionAdminScreen extends StatefulWidget {
  const AuctionAdminScreen({super.key});

  @override
  State<AuctionAdminScreen> createState() => _AuctionAdminScreenState();
}

class _AuctionAdminScreenState extends State<AuctionAdminScreen> {
  int _reloads = 0;
  bool _busy = false;

  void _reload() {
    if (mounted) setState(() => _reloads++);
  }

  /// ينفّذ إجراءً إداريًا واحدًا مع تعطيل الأزرار وصياغة النتيجة.
  Future<void> _run(
    String confirmation,
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('تأكيد الإجراء'),
        content: Text(confirmation),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      AppSnackBar.show(context, successMessage, type: AppMessageType.success);
      _reload();
    } on AppException catch (error) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        error.overrideMessage ?? error.message,
        type: AppMessageType.error,
      );
    } on AuctionUnavailable {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        'هذه العملية تحتاج الاتصال بالخادم، ولا تعمل في النسخة بلا خادم.',
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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
            key: const Key('auction-admin-refresh'),
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _reload,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: AsyncView<AuctionAdminOverview>(
          reloadKey: _reloads,
          load: () => AppServicesScope.of(context).auctions.loadAdminOverview(),
          builder: (BuildContext context, AuctionAdminOverview overview) =>
              _body(context, overview),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AuctionAdminOverview overview) {
    final ThemeData theme = Theme.of(context);
    final AuctionRepository auctions = AppServicesScope.of(context).auctions;

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'دورة ${overview.cycleKey}',
                            key: const Key('auction-admin-cycle'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        StatusChip(
                          label: overview.timeZone,
                          color: AppColors.statusInfo,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'الجداول تُحتسب بتوقيت القاهرة. كل إجراء هنا يُسجَّل في '
                      'السجل باسمك، ولا يمكن التراجع عنه من التطبيق.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      key: const Key('auction-admin-ensure'),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              'إنشاء دورات الأسبوع الحالي والقادم إن لم تكن '
                              'موجودة. العملية آمنة ومتكررة.',
                              auctions.ensureCycles,
                              successMessage: 'تم التحقق من دورات الأسبوع.',
                            ),
                      icon: const Icon(Icons.event_available_outlined, size: 18),
                      label: const Text('تأكيد وجود دورات الأسبوع'),
                    ),
                  ],
                ),
              ),
              for (final AuctionAdminCategory category in overview.categories) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                _CategoryCard(
                  category: category,
                  busy: _busy,
                  onFinalize: () => _run(
                    'حسم مزاد ${category.category?.label ?? ''} الآن وتعيين '
                    'الفائزين؟ لا يمكن التراجع، والفائزون يبلغون فورًا.',
                    () => auctions.finalizeAuction(
                      cycleKey: overview.cycleKey,
                      category: category.category!,
                    ),
                    successMessage: 'تم حسم المزاد وإشعار الفائزين.',
                  ),
                  onPayment: (AuctionAdminWinner winner, bool paid) => _run(
                    paid
                        ? 'تأكيد استلام دفع «${winner.displayName}» '
                              '(${AuctionText.money(winner.amount ?? 0)})؟'
                        : 'تسجيل عدم دفع «${winner.displayName}»؟ سيُتاح مقعده '
                              'في دورة البديل.',
                    () => auctions.confirmWinnerPayment(
                      cycleKey: overview.cycleKey,
                      category: category.category!,
                      teacherId: winner.teacherId,
                      paid: paid,
                    ),
                    successMessage: paid ? 'تم تأكيد الدفع.' : 'تم تسجيل عدم الدفع.',
                  ),
                  onReplacement: () => _run(
                    'تشغيل دورة البديل مرة واحدة: تُعرض المقاعد غير المدفوعة '
                    'على التالي في الترتيب.',
                    () => auctions.runReplacement(
                      cycleKey: overview.cycleKey,
                      category: category.category!,
                    ),
                    successMessage: 'تم تشغيل دورة البديل.',
                  ),
                  onPublish: () => _run(
                    'نشر تمييز المدفوعين في شريط المميزين؟ يبدأ العرض السبت.',
                    () => auctions.publishFeatured(
                      cycleKey: overview.cycleKey,
                      category: category.category!,
                    ),
                    successMessage: 'تم نشر التمييز للمدفوعين.',
                  ),
                  onExpire: () => _run(
                    'إنهاء تمييز هذه الدورة (رفع العلم عن فائزيها المدفوعين)؟',
                    () => auctions.expireFeatured(
                      cycleKey: overview.cycleKey,
                      category: category.category!,
                    ),
                    successMessage: 'تم إنهاء تمييز الدورة.',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              const SectionHeader(title: 'إعدادات المزاد'),
              _ConfigCard(
                config: overview.config,
                busy: _busy,
                onSave: (AuctionConfig config) => _run(
                  'حفظ الإعدادات؟ تسري على الدورات القادمة فقط، ولا تغيّر '
                  'دورة جارية.',
                  () => auctions.updateConfig(config),
                  successMessage: 'تم حفظ إعدادات المزاد.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader(title: 'سجل النشاط'),
              AppCard(
                child: overview.audit.isEmpty
                    ? Text(
                        'لا نشاط مسجّل بعد.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (final AuctionAuditEntry entry in overview.audit)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  SizedBox(
                                    width: 78,
                                    child: Text(
                                      entry.at == null
                                          ? '—'
                                          : AuctionText.clock(entry.at!),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${entry.label} — ${entry.detail}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(height: 1.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              const AppCard(
                child: InfoNote(
                  text:
                      'لا توجد بوّابة دفع في التطبيق (قرار P30): الدفع يُحصَّل '
                      'بالوسيلة المعتمدة خارج التطبيق، ويُعتمد هنا يدويًا بعد '
                      'التحصيل. الفائز الذي لا يُدفع مقعده يذهب لدورة البديل '
                      'مرة واحدة، ثم يبقى المقعد فارغًا.',
                  icon: Icons.payments_outlined,
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

/// بطاقة فئة واحدة: الأرقام، الفائزون، وأزرار المرحلة.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.busy,
    required this.onFinalize,
    required this.onPayment,
    required this.onReplacement,
    required this.onPublish,
    required this.onExpire,
  });

  final AuctionAdminCategory category;
  final bool busy;
  final VoidCallback onFinalize;
  final void Function(AuctionAdminWinner, bool) onPayment;
  final VoidCallback onReplacement;
  final VoidCallback onPublish;
  final VoidCallback onExpire;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool finalized = category.finalizedAt != null;
    final bool published = category.publishedAt != null;
    final bool settled = category.settledAt != null;

    return AppCard(
      key: Key('auction-admin-${category.category?.wireName ?? 'unknown'}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'فئة ${category.category?.label ?? '—'}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusChip(
                label: category.phase.label,
                color: category.phase.canBid
                    ? AppColors.accent
                    : AppColors.statusNeutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (category.missing)
            Text(
              'الدورة غير موجودة بعد (لم يعمل المجدول). استخدم «تأكيد وجود '
              'دورات الأسبوع» أعلاه.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.attentionForeground,
                height: 1.7,
              ),
            )
          else ...<Widget>[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xxs,
              children: <Widget>[
                _metric(theme, 'مقاعد', '${category.positions}'),
                _metric(theme, 'مزايدون', '${category.biddersCount}'),
                _metric(theme, 'مزايدات', '${category.bidCount}'),
                _metric(theme, 'أعلى مزايدة', AuctionText.money(category.highestBid)),
                _metric(theme, 'مدفوع', '${category.paidCount}'),
                _metric(theme, 'بلا دفع', '${category.unpaidCount}'),
                _metric(theme, 'مقاعد فارغة', '${category.emptySeats}'),
              ],
            ),
            if (category.winners.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              for (final AuctionAdminWinner winner in category.winners)
                Container(
                  key: Key('auction-admin-winner-${winner.teacherId}'),
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${winner.rank == null ? 'بديل' : 'المركز ${winner.rank}'} · '
                              '${winner.displayName}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          StatusChip(
                            label: _paymentLabel(winner.status),
                            color: switch (winner.status) {
                              'paid' => AppColors.statusAccepted,
                              'unpaid' || 'unfilled' => AppColors.statusRejected,
                              _ => AppColors.statusPending,
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${AuctionText.money(winner.amount ?? 0)} · '
                        '${winner.round == 2 ? 'دورة البديل' : 'الدورة الأساسية'}'
                        '${winner.deadline == null ? '' : ' · المهلة ${AuctionText.dayTime(winner.deadline!)}'}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.6,
                        ),
                      ),
                      if (winner.status == 'pendingPayment') ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: FilledButton.tonal(
                                key: Key(
                                  'auction-admin-pay-${winner.teacherId}',
                                ),
                                onPressed: busy
                                    ? null
                                    : () => onPayment(winner, true),
                                child: const Text('تأكيد الدفع'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: OutlinedButton(
                                key: Key(
                                  'auction-admin-reject-${winner.teacherId}',
                                ),
                                onPressed: busy
                                    ? null
                                    : () => onPayment(winner, false),
                                child: const Text('لم يدفع'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const Key('auction-admin-finalize'),
                  onPressed: busy || finalized || category.category == null
                      ? null
                      : onFinalize,
                  icon: const Icon(Icons.gavel_outlined, size: 18),
                  label: Text(finalized ? 'تم الحسم' : 'حسم المزاد'),
                ),
                OutlinedButton.icon(
                  key: const Key('auction-admin-replacement'),
                  onPressed: busy ||
                          !finalized ||
                          category.replacementRound >= 1 ||
                          category.category == null
                      ? null
                      : onReplacement,
                  icon: const Icon(Icons.replay_outlined, size: 18),
                  label: Text(
                    category.replacementRound >= 1
                        ? 'تمت دورة البديل'
                        : 'دورة البديل',
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('auction-admin-publish'),
                  onPressed: busy || published || category.category == null
                      ? null
                      : onPublish,
                  icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                  label: Text(published ? 'تم النشر' : 'نشر التمييز'),
                ),
                OutlinedButton.icon(
                  key: const Key('auction-admin-expire'),
                  onPressed: busy ||
                          !published ||
                          settled ||
                          category.category == null
                      ? null
                      : onExpire,
                  icon: const Icon(Icons.event_busy_outlined, size: 18),
                  label: Text(settled ? 'انتهى التمييز' : 'إنهاء التمييز'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _paymentLabel(String status) => switch (status) {
    'paid' => 'مدفوع',
    'unpaid' => 'لم يدفع',
    'unfilled' => 'فارغ',
    _ => 'بانتظار الدفع',
  };

  Widget _metric(ThemeData theme, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// نموذج الإعدادات (مقاعد، أقل مزايدة، الخطوة، الزيادات، السقف، المهل).
class _ConfigCard extends StatefulWidget {
  const _ConfigCard({
    required this.config,
    required this.busy,
    required this.onSave,
  });

  final AuctionConfig config;
  final bool busy;
  final void Function(AuctionConfig) onSave;

  @override
  State<_ConfigCard> createState() => _ConfigCardState();
}

class _ConfigCardState extends State<_ConfigCard> {
  late final TextEditingController _positions;
  late final TextEditingController _minBid;
  late final TextEditingController _bidStep;
  late final TextEditingController _extraLimit;
  late final TextEditingController _maxBid;
  late final TextEditingController _announceHour;
  late final TextEditingController _cutoffMinutes;
  late final TextEditingController _paymentHours;
  late final TextEditingController _replacementHours;

  @override
  void initState() {
    super.initState();
    _positions = TextEditingController(
      text: '${widget.config.positionsPerCategory}',
    );
    _minBid = TextEditingController(text: '${widget.config.minBid}');
    _bidStep = TextEditingController(text: '${widget.config.bidStep}');
    _extraLimit = TextEditingController(text: '${widget.config.extraBidLimit}');
    _maxBid = TextEditingController(text: '${widget.config.maxBid}');
    _announceHour = TextEditingController(
      text: '${widget.config.announceHour}',
    );
    _cutoffMinutes = TextEditingController(
      text: '${widget.config.bidCutoffMinutes}',
    );
    _paymentHours = TextEditingController(
      text: '${widget.config.paymentWindowHours}',
    );
    _replacementHours = TextEditingController(
      text: '${widget.config.replacementWindowHours}',
    );
  }

  @override
  void dispose() {
    _positions.dispose();
    _minBid.dispose();
    _bidStep.dispose();
    _extraLimit.dispose();
    _maxBid.dispose();
    _announceHour.dispose();
    _cutoffMinutes.dispose();
    _paymentHours.dispose();
    _replacementHours.dispose();
    super.dispose();
  }

  int? _value(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  void _save() {
    final int? positions = _value(_positions);
    final int? minBid = _value(_minBid);
    final int? bidStep = _value(_bidStep);
    final int? extraLimit = _value(_extraLimit);
    final int? maxBid = _value(_maxBid);
    final int? announceHour = _value(_announceHour);
    final int? cutoffMinutes = _value(_cutoffMinutes);
    final int? paymentHours = _value(_paymentHours);
    final int? replacementHours = _value(_replacementHours);

    if (positions == null ||
        minBid == null ||
        bidStep == null ||
        extraLimit == null ||
        maxBid == null ||
        announceHour == null ||
        cutoffMinutes == null ||
        paymentHours == null ||
        replacementHours == null) {
      AppSnackBar.show(
        context,
        'كل الحقول أرقام صحيحة. راجع القيم قبل الحفظ.',
        type: AppMessageType.error,
      );
      return;
    }
    // تحقق محلي مبدئي فقط (الخادم يعيد التحقق ويرفض خارج النطاق).
    if (positions < 1 || positions > 10) {
      AppSnackBar.show(
        context,
        'عدد المقاعد لكل فئة يجب أن يكون بين 1 و10.',
        type: AppMessageType.error,
      );
      return;
    }
    if (minBid < 1 || bidStep < 1 || extraLimit < 0 || extraLimit > 50) {
      AppSnackBar.show(
        context,
        'القيم سالبة أو خارج النطاق المسموح.',
        type: AppMessageType.error,
      );
      return;
    }
    if (announceHour > 23) {
      AppSnackBar.show(
        context,
        'ساعة الإعلان بين 0 و23.',
        type: AppMessageType.error,
      );
      return;
    }
    if (cutoffMinutes < 1 || cutoffMinutes > 120) {
      AppSnackBar.show(
        context,
        'دقائق الحظر قبل الإغلاق بين 1 و120.',
        type: AppMessageType.error,
      );
      return;
    }
    if (maxBid < minBid) {
      AppSnackBar.show(
        context,
        'الحد الأقصى يجب أن يكون أكبر من أو يساوي أقل مزايدة.',
        type: AppMessageType.error,
      );
      return;
    }

    widget.onSave(
      AuctionConfig(
        positionsPerCategory: positions,
        minBid: minBid,
        bidStep: bidStep,
        extraBidLimit: extraLimit,
        maxBid: maxBid,
        announceHour: announceHour,
        bidCutoffMinutes: cutoffMinutes,
        paymentWindowHours: paymentHours,
        replacementWindowHours: replacementHours,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'تسري على الدورات القادمة فقط؛ الدورة الجارية تحتفظ بشروطها.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.7,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _numberField(_positions, 'عدد المقاعد لكل فئة', 'auction-config-positions'),
          _numberField(_minBid, 'أقل مزايدة (جنيه)', 'auction-config-min'),
          _numberField(_bidStep, 'خطوة الزيادة (جنيه)', 'auction-config-step'),
          _numberField(
            _extraLimit,
            'عدد الزيادات المجانية',
            'auction-config-extra',
          ),
          _numberField(_maxBid, 'الحد الأقصى للمزايدة', 'auction-config-max'),
          _numberField(
            _paymentHours,
            'مهلة الدفع (ساعات)',
            'auction-config-payment-hours',
          ),
          _numberField(
            _replacementHours,
            'مهلة دورة البديل (ساعات)',
            'auction-config-replacement-hours',
          ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton(
            key: const Key('auction-config-save'),
            onPressed: widget.busy ? null : _save,
            child: const Text('حفظ الإعدادات'),
          ),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: TextField(
        key: Key(key),
        controller: controller,
        enabled: !widget.busy,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(7),
        ],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
