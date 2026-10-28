import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/detail_row.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/admin_rules.dart';

/// «طابور التوثيق» (P14): قرار المسؤول على كل ملف مدرس.
///
/// **التوثيق** يفتح الملف للطلاب فورًا (القواعد تقرأ الحالة لحظة كل قراءة).
/// **الرفض** لا يكفي وحده: يلزم سبب مكتوب يظهر للمدرس، ولهذا السبب لا يوجد
/// زر رفض «صامت».
class TeacherVerificationScreen extends StatefulWidget {
  const TeacherVerificationScreen({super.key});

  @override
  State<TeacherVerificationScreen> createState() =>
      _TeacherVerificationScreenState();
}

class _TeacherVerificationScreenState extends State<TeacherVerificationScreen> {
  /// يتغيّر بعد كل قرار لإجبار [AsyncView] على إعادة القراءة من المصدر.
  int _revision = 0;

  Future<void> _verify(TeacherProfile profile) async {
    try {
      await AppServicesScope.of(context).admin.verifyTeacher(profile.id);
      if (!mounted) {
        return;
      }
      setState(() => _revision++);
      AppSnackBar.show(
        context,
        'تم توثيق «${profile.displayName}» — الملف ظاهر الآن في البحث.',
        type: AppMessageType.success,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        toAppException(error).message,
        type: AppMessageType.error,
      );
    }
  }

  Future<void> _reject(TeacherProfile profile) async {
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => _RejectDialog(profile: profile),
    );
    if (reason == null || !mounted) {
      return;
    }
    try {
      await AppServicesScope.of(
        context,
      ).admin.rejectTeacher(teacherId: profile.id, reason: reason);
      if (!mounted) {
        return;
      }
      setState(() => _revision++);
      AppSnackBar.show(
        context,
        'تم رفض «${profile.displayName}» وإبلاغ السبب.',
        type: AppMessageType.warning,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        toAppException(error).message,
        type: AppMessageType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('طابور التوثيق')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: AsyncView<List<TeacherProfile>>(
                // مفتاح مختلف لكل مراجعة ⇒ قراءة جديدة لا نتيجة محفوظة.
                key: ValueKey<int>(_revision),
                load: () =>
                    AppServicesScope.of(context).admin.listVerificationQueue(),
                isEmpty: (List<TeacherProfile> queue) => queue.isEmpty,
                emptyBuilder: (BuildContext context) => const EmptyState(
                  icon: Icons.task_alt,
                  title: 'لا ملفات بانتظار قرار',
                  message: 'كل الملفات المُرسلة رُوجعت. عُد لاحقًا.',
                ),
                builder: (BuildContext context, List<TeacherProfile> queue) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      const InfoNote(
                        text:
                            'الملف الموثّق يظهر للطلاب في البحث ويستطيع قبول '
                            'الحجوزات وطلبات الانضمام. الرفض يحتاج سببًا مكتوبًا '
                            'يُراجع مع الملف.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final TeacherProfile profile in queue) ...<Widget>[
                        _QueueCard(
                          profile: profile,
                          onVerify: () => _verify(profile),
                          onReject: () => _reject(profile),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      const SizedBox(height: AppSpacing.md),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة ملف واحد في الطابور: بياناته + القرار.
class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.profile,
    required this.onVerify,
    required this.onReject,
  });

  final TeacherProfile profile;
  final VoidCallback onVerify;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool pending = profile.status == TeacherProfileStatus.pendingReview;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: AppSpacing.avatarMd / 2.6,
                child: Text(profile.initials),
              ),
              const SizedBox(width: AppSpacing.sm),
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
                      '${profile.subject} — ${profile.stage}',
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
              StatusChip(
                label: profile.status.label,
                color: pending
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (profile.bio.trim().isNotEmpty)
            Text(
              profile.bio,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
            ),
          const SizedBox(height: AppSpacing.xs),
          DetailRow(label: 'المنطقة', value: profile.area),
          if (profile.priceHint != null)
            DetailRow(label: 'السعر', value: profile.priceHint!),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: onVerify,
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('توثيق'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.block_outlined, size: 18),
                  label: const Text('رفض'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// نافذة سبب الرفض — لا تُغلق إلا بسبب صالح (نفس حدّ القواعد).
class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.profile});

  final TeacherProfile profile;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String reason = _controller.text;
    final String? problem = AdminRules.reasonProblem(reason);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(reason.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('رفض ملف ${widget.profile.displayName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'اكتب سببًا واضحًا يظهر للمدرس. الرفض بدون سبب لا يُرسل.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            maxLength: AdminRules.maxReasonLength,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'سبب الرفض',
              errorText: _error,
            ),
            onChanged: (String value) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('تأكيد الرفض')),
      ],
    );
  }
}
