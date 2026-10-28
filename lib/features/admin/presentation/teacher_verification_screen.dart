import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/admin_rules.dart';

/// «طابور التوثيق» (P14): قرار «توثيق» أو «رفض بسبب».
///
/// القاعدة الحاكمة: الرفض بلا سبب لا يُرسل، ولا يُغلق الحوار. السبب يُحفظ في
/// `reviewNote` ويقرأه المدرس — فهو تفسير القرار لا عقوبة خفية.
class TeacherVerificationScreen extends StatefulWidget {
  const TeacherVerificationScreen({super.key});

  @override
  State<TeacherVerificationScreen> createState() =>
      _TeacherVerificationScreenState();
}

class _TeacherVerificationScreenState extends State<TeacherVerificationScreen> {
  /// يُزاد بعد كل قرار لتُقرأ القائمة من جديد من المستودع.
  int _revision = 0;

  /// منع نقرتين متتاليتين على القرار نفسه أثناء الكتابة.
  final Set<String> _busy = <String>{};

  Future<void> _verify(TeacherProfile profile) async {
    if (_busy.contains(profile.id)) {
      return;
    }
    setState(() => _busy.add(profile.id));
    final AppServices services = AppServicesScope.of(context);
    try {
      await services.admin.verifyTeacher(profile.id);
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        'تم توثيق ${profile.displayName} — ظهر الآن في نتائج البحث.',
        type: AppMessageType.success,
      );
      setState(() => _revision++);
    } catch (error) {
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

  Future<void> _reject(TeacherProfile profile) async {
    if (_busy.contains(profile.id)) {
      return;
    }
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) =>
          _RejectReasonDialog(teacherName: profile.displayName),
    );
    if (reason == null || !mounted) {
      return;
    }

    setState(() => _busy.add(profile.id));
    final AppServices services = AppServicesScope.of(context);
    try {
      await services.admin.rejectTeacher(teacherId: profile.id, reason: reason);
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        'تم رفض الملف وإبلاغ المدرس بالسبب.',
        type: AppMessageType.warning,
      );
      setState(() => _revision++);
    } catch (error) {
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

  /// تمييز/إزالة تمييز ملف موثّق. الترتيب الجديد يُلحق بالشريط.
  Future<void> _toggleFeatured(
    TeacherProfile profile, {
    required int nextOrder,
  }) async {
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
            ? 'أُزيل ${profile.displayName} من المميزين.'
            : 'أُضيف ${profile.displayName} إلى شريط المميزين.',
        type: AppMessageType.success,
      );
      setState(() => _revision++);
    } catch (error) {
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
      appBar: AppBar(title: const Text('طابور التوثيق')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const DemoBanner(),
                  const SectionHeader(
                    title: 'ملفات بانتظار قرار',
                    subtitle: 'قيد المراجعة أولًا ثم المسودات',
                  ),
                  AsyncView<List<TeacherProfile>>(
                    key: ValueKey<int>(_revision),
                    load: () =>
                        AppServicesScope.of(context).admin.listVerificationQueue(),
                    builder:
                        (
                          BuildContext context,
                          List<TeacherProfile> queue,
                        ) {
                          if (queue.isEmpty) {
                            return const EmptyState(
                              icon: Icons.task_alt_rounded,
                              title: 'لا ملفات بانتظار قرار',
                              message: 'كل الملفات المرسلة حُسمت.',
                            );
                          }
                          return Column(
                            children: <Widget>[
                              for (final TeacherProfile profile in queue)
                                _QueueCard(
                                  profile: profile,
                                  busy: _busy.contains(profile.id),
                                  onVerify: () => _verify(profile),
                                  onReject: () => _reject(profile),
                                ),
                            ],
                          );
                        },
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  // (P15) التمييز قرار إداري: شريط «مدرسون مميزون» في الرئيسية
                  // يقرأ `isFeatured`/`featuredOrder`، وهما لا يُكتبان من حساب
                  // المدرس في القواعد.
                  const SectionHeader(
                    title: 'المدرسون الموثّقون',
                    subtitle: 'تمييز الملف يضعه في شريط الرئيسية',
                  ),
                  AsyncView<List<TeacherProfile>>(
                    key: ValueKey<String>('verified-$_revision'),
                    load: () async {
                      final List<TeacherProfile> all = await AppServicesScope.of(
                        context,
                      ).admin.listAllProfiles();
                      final List<TeacherProfile> verified = all
                          .where(
                            (TeacherProfile profile) =>
                                profile.status ==
                                TeacherProfileStatus.verified,
                          )
                          .toList(growable: false);
                      verified.sort((TeacherProfile a, TeacherProfile b) {
                        if (a.isFeatured != b.isFeatured) {
                          return a.isFeatured ? -1 : 1;
                        }
                        return a.displayName.compareTo(b.displayName);
                      });
                      return verified;
                    },
                    builder:
                        (BuildContext context, List<TeacherProfile> verified) {
                          if (verified.isEmpty) {
                            return const EmptyState(
                              icon: Icons.verified_outlined,
                              title: 'المدرسون الموثّقون',
                              message: 'لا ملف موثّق بعد — وثّق ملفًا من الأعلى.',
                            );
                          }
                          final int featuredCount = verified
                              .where((TeacherProfile t) => t.isFeatured)
                              .length;
                          return Column(
                            children: <Widget>[
                              for (final TeacherProfile profile in verified)
                                _VerifiedCard(
                                  profile: profile,
                                  busy: _busy.contains(profile.id),
                                  onToggleFeatured: () => _toggleFeatured(
                                    profile,
                                    nextOrder: featuredCount + 1,
                                  ),
                                ),
                            ],
                          );
                        },
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  const InfoNote(
                    text: 'التوثيق يفتح الملف للطلاب ويسمح بقبول الحجوزات؛ '
                        'الرفض يُبقيه مخفيًا ويحفظ السبب للمدرس.',
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

/// بطاقة ملف في الطابور: وصف مختصر + قرارا التوثيق والرفض.
class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.profile,
    required this.busy,
    required this.onVerify,
    required this.onReject,
  });

  final TeacherProfile profile;
  final bool busy;
  final VoidCallback onVerify;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color statusColor =
        profile.status == TeacherProfileStatus.pendingReview
        ? AppColors.statusPending
        : AppColors.statusNeutral;

    return Padding(
      padding: AppSpacing.listGap,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: AppSpacing.avatarSm / 2,
                  backgroundColor: theme.colorScheme.primary.withAlpha(26),
                  child: Text(
                    profile.initials,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        profile.displayName,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${profile.subject} • ${profile.stage} • '
                        '${profile.locationLabel}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                StatusChip(label: profile.status.label, color: statusColor),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              profile.bio,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onVerify,
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: const Text('توثيق'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.block_outlined, size: 18),
                    label: const Text('رفض'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// حوار سبب الرفض: لا يُغلق بزر التأكيد ما دام السبب غير صالح.
class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog({required this.teacherName});

  final String teacherName;

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final TextEditingController _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final String? problem = AdminRules.reasonProblem(_reason.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(_reason.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      title: const Text('سبب الرفض'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'سيقرأ ${widget.teacherName} هذا السبب، فلابد أن يشرح ما ينقص '
            'أو ما يجب تعديله.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _reason,
            autofocus: true,
            maxLength: AdminRules.maxReasonLength,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'سبب الرفض',
              hintText: 'اكتب سببًا واضحًا يظهر للمدرس. الرفض بدون سبب لا '
                  'يُرسل.',
            ),
            onChanged: (String value) {
              if (_error != null && AdminRules.reasonProblem(value) == null) {
                setState(() => _error = null);
              }
            },
          ),
          if (_error != null)
            Text(
              _error!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('تأكيد الرفض'),
        ),
      ],
    );
  }
}

/// صف ملف موثّق مع مفتاح التمييز.
class _VerifiedCard extends StatelessWidget {
  const _VerifiedCard({
    required this.profile,
    required this.busy,
    required this.onToggleFeatured,
  });

  final TeacherProfile profile;
  final bool busy;
  final VoidCallback onToggleFeatured;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: AppSpacing.listGap,
      child: AppCard(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    profile.displayName,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    profile.isFeatured
                        ? 'مميز · ترتيب ${profile.featuredOrder}'
                        : '${profile.subject} • ${profile.locationLabel}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Switch(
              value: profile.isFeatured,
              onChanged: busy ? null : (bool _) => onToggleFeatured(),
            ),
          ],
        ),
      ),
    );
  }
}
