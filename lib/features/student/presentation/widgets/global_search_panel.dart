import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/data/models/group_filter.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_filter.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_showcase_card.dart';

/// نتيجة بحث شامل واحدة: مدرسون + مجموعات في استعلام واحد منطقي (P25).
class GlobalSearchResults {
  const GlobalSearchResults({
    required this.query,
    required this.teachers,
    required this.groups,
  });

  final String query;
  final List<TeacherProfile> teachers;
  final List<StudyGroup> groups;

  bool get isEmpty => teachers.isEmpty && groups.isEmpty;

  int get total => teachers.length + groups.length;
}

/// البحث الشامل في الرئيسية (P25): مدرسون **ومجموعات** معًا (البند 2).
///
/// ## لماذا استعلامان لا واحد؟
/// المدرسون والمجموعات مجموعتان مختلفتان في Firestore بفلاتر مختلفة، ومحرّك
/// البحث الفعلي موجود أصلًا في `TeacherDiscoveryRules`/`GroupDiscoveryRules`
/// (نفس ما تستخدمه شاشتا المدرسين والمجموعات). فبدل كتابة مطابقة نصية ثانية
/// هنا — وهي التي تسبّب «البحث لا يجد شيئًا» — نستدعي **نفس** المستودعين
/// بالفلتر نفسه، ثم نعرض النتيجتين مدمجتين. أي تحسين مستقبلي في منطق البحث
/// يظهر هنا تلقائيًا بلا نسخة ثانية تنحرف عنه.
///
/// ## لماذا هنا لا في قسم المدرسين؟
/// كان الإرسال ينقل إلى قسم المدرسين ويُفرغ الحقل: يبحث الطالب عن «مجموعة
/// الرياضيات» فيرى مدرسين فقط. الآن النتيجة تظهر **تحت الحقل نفسه** فورًا،
/// والنقر على أي نتيجة يفتح صفحتها.
class GlobalSearchPanel extends StatefulWidget {
  const GlobalSearchPanel({
    super.key,
    required this.query,
    required this.onTeacherTap,
    required this.onGroupTap,
    required this.onSeeAllTeachers,
    required this.onSeeAllGroups,
  });

  /// النص المُدخل (بعد trim). فارغ = لا نتيجة ولا استعلام.
  final String query;

  final ValueChanged<TeacherProfile> onTeacherTap;
  final ValueChanged<StudyGroup> onGroupTap;
  final VoidCallback onSeeAllTeachers;
  final VoidCallback onSeeAllGroups;

  /// أقصى ما نعرضه لكل نوع داخل الرئيسية؛ الباقي عبر «عرض الكل».
  static const int previewLimit = 4;

  @override
  State<GlobalSearchPanel> createState() => _GlobalSearchPanelState();
}

class _GlobalSearchPanelState extends State<GlobalSearchPanel> {
  GlobalSearchResults _results = const GlobalSearchResults(
    query: '',
    teachers: <TeacherProfile>[],
    groups: <StudyGroup>[],
  );
  bool _loading = false;
  bool _failed = false;

  /// حماية من سباق الردود: نتيجة استعلام قديم تصل بعد نتيجة أحدث فتطمسها.
  int _sequence = 0;

  /// هل بدأنا الاستعلام الأول؟ (نبدأه مرة واحدة فقط.)
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // **لا `initState`:** `_run` يقرأ `AppServicesScope.of(context)`، وقراءة
    // وراثة أثناء `initState` غير مسموحة (`dependOnInheritedWidgetOfExactType`
    // قبل اكتمال `initState`) — وهي تُطلق استثناءً يُبقي مؤشّر التحميل يدور
    // بلا نهاية. `didChangeDependencies` أول موضع قانوني للقراءة.
    if (_started) {
      return;
    }
    _started = true;
    final String query = widget.query.trim();
    if (query.isNotEmpty) {
      _run(query);
    }
  }

  @override
  void didUpdateWidget(GlobalSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String query = widget.query.trim();
    if (query != oldWidget.query.trim()) {
      if (query.isEmpty) {
        _sequence++;
        setState(() {
          _loading = false;
          _failed = false;
          _results = const GlobalSearchResults(
            query: '',
            teachers: <TeacherProfile>[],
            groups: <StudyGroup>[],
          );
        });
      } else {
        _run(query);
      }
    }
  }

  Future<void> _run(String query) async {
    final int ticket = ++_sequence;
    setState(() {
      _loading = true;
      _failed = false;
    });

    final services = AppServicesScope.of(context);
    try {
      // الاستعلامان متوازيان: لا داعي أن ينتظر أحدهما الآخر.
      final (TeacherSearchResult teacherAnswer, GroupSearchResult groupAnswer) =
          await (
            services.teachers.search(TeacherFilter(query: query)),
            services.groups.searchDiscoverable(GroupFilter(query: query)),
          ).wait;

      if (!mounted || ticket != _sequence) {
        return;
      }
      setState(() {
        _loading = false;
        _results = GlobalSearchResults(
          query: query,
          teachers: teacherAnswer.teachers,
          groups: groupAnswer.groups,
        );
      });
    } on Object {
      if (!mounted || ticket != _sequence) {
        return;
      }
      // فشل البحث لا يُسقط الرئيسية: نُظهر رسالة هادئة مع إمكانية المحاولة.
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (widget.query.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    if (_loading && _results.query.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_failed) {
      return AppCard(
        child: Row(
          children: <Widget>[
            const Icon(Icons.wifi_off_rounded, color: AppColors.statusPending),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'تعذّر إكمال البحث الآن. تحقّق من الاتصال وحاول مرة أخرى.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () => _run(widget.query.trim()),
              child: const Text('إعادة'),
            ),
          ],
        ),
      );
    }

    final List<TeacherProfile> teachers = _results.teachers
        .take(GlobalSearchPanel.previewLimit)
        .toList(growable: false);
    final List<StudyGroup> groups = _results.groups
        .take(GlobalSearchPanel.previewLimit)
        .toList(growable: false);

    if (_results.isEmpty) {
      return AppCard(
        child: Row(
          children: <Widget>[
            const Icon(Icons.search_off_rounded, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'لا نتائج لـ«${_results.query}» بين المدرسين والمجموعات.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (teachers.isNotEmpty) ...<Widget>[
          _ResultHeader(
            icon: Icons.person_search_outlined,
            title: 'مدرسون',
            count: _results.teachers.length,
            actionLabel: _results.teachers.length > teachers.length
                ? 'عرض الكل'
                : null,
            onActionTap: widget.onSeeAllTeachers,
          ),
          for (final TeacherProfile teacher in teachers)
            Padding(
              padding: AppSpacing.listGap,
              child: TeacherShowcaseCard(
                teacher: teacher,
                compact: false,
                onTap: () => widget.onTeacherTap(teacher),
              ),
            ),
        ],
        if (groups.isNotEmpty) ...<Widget>[
          _ResultHeader(
            icon: Icons.groups_outlined,
            title: 'مجموعات',
            count: _results.groups.length,
            actionLabel: _results.groups.length > groups.length
                ? 'عرض الكل'
                : null,
            onActionTap: widget.onSeeAllGroups,
          ),
          for (final StudyGroup group in groups)
            Padding(
              padding: AppSpacing.listGap,
              child: AppCard(
                onTap: () => widget.onGroupTap(group),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(24),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(
                        Icons.groups_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            group.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${group.subject} • ${group.teacherName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    PillChip(
                      dense: true,
                      icon: Icons.event_seat_outlined,
                      label: '${group.seatsTaken}/${group.seatsTotal}',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.actionLabel,
    required this.onActionTap,
  });

  final IconData icon;
  final String title;
  final int count;
  final String? actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.xxs,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          if (actionLabel != null)
            TextButton(
              onPressed: onActionTap,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
