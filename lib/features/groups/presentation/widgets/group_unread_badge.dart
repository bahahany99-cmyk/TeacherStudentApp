import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/group_unread_rules.dart';

/// شارة «رسائل مجموعة غير مقروءة» لعضو واحد (P32).
///
/// **لماذا مكوّن مستقل؟** لأن العدد يُقرأ لعضو **واحد** في مجموعة **واحدة**،
/// ويُعاد حسابه عند العودة من المحادثة. وضعه داخل البطاقة مباشرة كان يعني
/// `FutureBuilder` يُنشئ `Future` جديدة في كل بناء — أي قراءة لكل إعادة رسم.
///
/// **السلوك:** لا شيء إن كان العدد صفرًا أو فشلت القراءة (شارة خاطئة أسوأ من لا
/// شارة)، ورقم حتى 9 ثم «9+».
///
/// **العزل:** القراءة مقيدة بمستند عضوية [viewerId]، والقواعد ترفض قراءة عضوية
/// عضو آخر، فلا يمكن لطالب أن يرى عدّاد زميله.
class GroupUnreadBadge extends StatefulWidget {
  const GroupUnreadBadge({
    super.key,
    required this.groupId,
    required this.viewerId,
    this.reloadKey = 0,
  });

  final String groupId;
  final String viewerId;

  /// تغييره يعيد الحساب (تعليم القراءة يحتاج إعادة قراءة الأرقام).
  final int reloadKey;

  /// مفتاح يثبته الاختبار بلا الاعتماد على النص.
  static const Key badgeKey = Key('group-unread-badge');

  @override
  State<GroupUnreadBadge> createState() => _GroupUnreadBadgeState();
}

class _GroupUnreadBadgeState extends State<GroupUnreadBadge> {
  Future<int>? _count;
  bool _resolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_resolved) {
      _resolved = true;
      _count = _load();
    }
  }

  @override
  void didUpdateWidget(GroupUnreadBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reloadKey != oldWidget.reloadKey ||
        widget.groupId != oldWidget.groupId ||
        widget.viewerId != oldWidget.viewerId) {
      _count = _load();
    }
  }

  Future<int> _load() async {
    try {
      return await AppServicesScope.of(context).messages.unreadCount(
        groupId: widget.groupId,
        memberId: widget.viewerId,
      );
    } on Object {
      // أفضل جهد: شارة غير مؤكدة لا تُعرض.
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Future<int>? future = _count;
    if (future == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<int>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        final String? label = GroupUnreadRules.badgeLabel(snapshot.data ?? 0);
        if (label == null) {
          return const SizedBox.shrink();
        }
        final ThemeData theme = Theme.of(context);
        return Semantics(
          label: 'رسائل غير مقروءة: $label',
          child: Container(
            key: GroupUnreadBadge.badgeKey,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.chat_bubble_rounded,
                  size: 14,
                  color: theme.colorScheme.onPrimary,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
