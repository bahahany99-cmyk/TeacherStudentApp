import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/weekly_auction.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// شريط «فائزو المزاد» أعلى قائمة المميزين (P30).
///
/// **المصدر:** نتائج المزاد المنشورة (`auctionResults` عبر دالة تُنقّيها)، لا
/// قائمة الملفات المميّزة. الفرق مهم: التمييز قد يُرفع في نهاية الأسبوع، أما
/// النتيجة فتبقى سجلًّا لما حدث.
///
/// **الخصوصية:** ما يظهر هو الأسماء والمراكز فقط. المبالغ لا تُرسلها الدالة
/// أصلًا، فلا يمكن أن تظهر هنا ولو أرادت الواجهة.
///
/// **الفشل الهادئ:** إن تعذّر النداء (بلا شبكة، أو دوال غير منشورة) يختفي
/// الشريط كاملًا — لا رسالة خطأ تعطّل تصفّح المميزين.
class AuctionWinnersStrip extends StatefulWidget {
  const AuctionWinnersStrip({super.key, required this.category});

  final AuctionCategory category;

  @override
  State<AuctionWinnersStrip> createState() => _AuctionWinnersStripState();
}

class _AuctionWinnersStripState extends State<AuctionWinnersStrip> {
  late Future<Map<AuctionCategory, AuctionResultsView?>> _load;

  @override
  void initState() {
    super.initState();
    _load = const Future<Map<AuctionCategory, AuctionResultsView?>>.value(
      <AuctionCategory, AuctionResultsView?>{},
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // القراءة هنا لا في `initState`: تحتاج `AppServicesScope`.
    _load = AppServicesScope.of(context).auctions.loadPublishedResults();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<AuctionCategory, AuctionResultsView?>>(
      future: _load,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<AuctionCategory, AuctionResultsView?>> snapshot,
          ) {
            final AuctionResultsView? results =
                snapshot.data?[widget.category];
            if (results == null || results.winners.isEmpty) {
              return const SizedBox.shrink();
            }
            return _content(context, results);
          },
    );
  }

  Widget _content(BuildContext context, AuctionResultsView results) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: AppCard(
        key: Key('auction-winners-${widget.category.wireName}'),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.emoji_events_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'فائزو مزاد هذا الأسبوع',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusChip(
                  label: '${results.winners.length} مقعد',
                  color: AppColors.accent,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              results.winners
                  .map(
                    (AuctionResultEntry winner) =>
                        winner.displayName.isEmpty
                        ? 'مدرّس'
                        : winner.displayName,
                  )
                  .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
