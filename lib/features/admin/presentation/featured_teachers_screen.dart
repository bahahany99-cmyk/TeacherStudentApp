import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// «المدرسون المميزون» (P15): تمييز الملفات الموثّقة التي تظهر في شريط
/// الرئيسية.
///
/// **لماذا شاشة مستقلة؟** لأن التمييز ليس قرار توثيق: الطابور يعالج ملفات
/// **غير** موثّقة، وهذا القسم يعالج ملفات موثّقة **منشورة**. خلطهما كان
/// سيضع سؤالين مختلفين في قائمة واحدة.
///
/// القرار نفسه يُفرض في القواعد: حقلان فقط، وملف موثّق، والمسؤول وحده.
class FeaturedTeachersScreen extends StatefulWidget {
  const FeaturedTeachersScreen({super.key});

  @override
  State<FeaturedTeachersScreen> createState() => _FeaturedTeachersScreenState();
}

class _FeaturedTeachersScreenState extends State<FeaturedTeachersScreen> {
  int _revision = 0;

  /// منع نقرتين على الملف نفسه أثناء الكتابة.
  final Set<String> _busy = <String>{};

  Future<void> _toggle(TeacherProfile profile, {required int nextOrder}) async {
    if (_busy.contains(profile.id)) {
      return;
    }
    setState(() => _busy.add(profile.id));
    final AppServices services = AppServicesScope.of(context);
    try {
      await services.admin.setFeatured(
        teacherId: profile.id,
        isFeatured: !profile.isFeatured,
        order: nextOrder,
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        profile.isFeatured
            ? 'أُزيل «${profile.displayName}» من شريط المميزين.'
            : 'أُضيف «${profile.displayName}» إلى شريط المميزين.',
        type: AppMessageType.success,
      );
      setState(() => _revision++);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        toAppException(error).message,
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busy.remove(profile.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('المدرسون المميزون')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SectionHeader(
                    title: 'شريط الرئيسية',
                    subtitle: 'الأصغر ترتيبًا يظهر أولًا',
                  ),
                  AsyncView<List<TeacherProfile>>(
                    key: ValueKey<int>(_revision),
                    load: () async {
                      final AppServices services = AppServicesScope.of(context);
                      final List<TeacherProfile> all =
                          await services.admin.listAllProfiles();
                      final List<TeacherProfile> verified = all
                          .where(
                            (TeacherProfile profile) =>
                                profile.status == TeacherProfileStatus.verified,
                          )
                          .toList(growable: false);
                      verified.sort((TeacherProfile a, TeacherProfile b) {
                        if (a.isFeatured != b.isFeatured) {
                          return a.isFeatured ? -1 : 1;
                        }
                        if (a.featuredOrder != b.featuredOrder) {
                          return a.featuredOrder.compareTo(b.featuredOrder);
                        }
                        return a.displayName.compareTo(b.displayName);
                      });
                      return verified;
                    },
                    isEmpty: (List<TeacherProfile> items) => items.isEmpty,
                    emptyBuilder: (BuildContext context) => const EmptyState(
                      icon: Icons.workspace_premium_outlined,
                      title: 'لا ملفات موثّقة بعد',
                      message: 'وثّق ملفًا من الطابور أولًا، ثم ميّزه هنا.',
                    ),
                    builder:
                        (BuildContext context, List<TeacherProfile> items) {
                          final int featuredCount = items
                              .where((TeacherProfile t) => t.isFeatured)
                              .length;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                '$featuredCount من ${items.length} في الشريط',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              for (final TeacherProfile profile in items)
                                Padding(
                                  padding: AppSpacing.listGap,
                                  child: _FeatureRow(
                                    profile: profile,
                                    busy: _busy.contains(profile.id),
                                    onToggle: () => _toggle(
                                      profile,
                                      nextOrder: featuredCount + 1,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  const InfoNote(
                    text: 'التمييز قرار إداري: صاحب الملف لا يكتبه، ولا يُقبل '
                        'مع أي تعديل آخر في الكتابة نفسها، ولا يُطبَّق على ملف '
                        'غير موثّق.',
                    icon: Icons.shield_outlined,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// صف ملف موثّق مع مفتاح التمييز.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.profile,
    required this.busy,
    required this.onToggle,
  });

  final TeacherProfile profile;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  profile.displayName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${profile.subject} • ${profile.locationLabel}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (profile.isFeatured) ...<Widget>[
            StatusChip(
              label: 'ترتيب ${profile.featuredOrder}',
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Switch(
            value: profile.isFeatured,
            onChanged: busy ? null : (bool _) => onToggle(),
          ),
        ],
      ),
    );
  }
}
