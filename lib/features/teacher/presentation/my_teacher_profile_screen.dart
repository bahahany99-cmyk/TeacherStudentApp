import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/detail_row.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// «ملفي» — الملف التعريفي كما يراه المدرس صاحبه.
///
/// نقرأ الملف التجريبي المرتبط بحساب المعاينة ([DemoData.demoTeacherId])، ونعرض
/// حالته الحقيقية من البيانات بدل وسم ثابت. التعديل يفتح نموذجًا لا يحفظ على
/// أي خادم (انظر [RoutePaths.editTeacherProfile]).
class MyTeacherProfileScreen extends StatelessWidget {
  const MyTeacherProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // شفاف لعرض تدرّج الخلفية العالمي (نسخة 3).
        backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('ملفي التعريفي')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: AsyncView<TeacherProfile?>(
                load: () => AppServicesScope.of(
                  context,
                ).teachers.findById(DemoData.demoTeacherId),
                emptyBuilder: (BuildContext context) => const EmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'لا يوجد ملف تعريفي',
                  message: 'لم يُنشأ ملف المدرس بعد.',
                ),
                builder: (BuildContext context, TeacherProfile? profile) {
                  if (profile == null) {
                    return const EmptyState(
                      icon: Icons.person_off_outlined,
                      title: 'لا يوجد ملف تعريفي',
                    );
                  }
                  return _MyProfileBody(profile: profile);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyProfileBody extends StatelessWidget {
  const _MyProfileBody({required this.profile});

  final TeacherProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const DemoBanner(),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      profile.displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  StatusChip(
                    label: profile.status.label,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${profile.subject} • ${profile.stage}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        const SectionHeader(
          title: 'المعلومات الظاهرة للطلاب',
          subtitle: 'هذه هي الحقول التي تُعرض في ملفك العام',
          icon: Icons.visibility_outlined,
        ),
        AppCard(
          child: Column(
            children: <Widget>[
              DetailRow(
                icon: Icons.menu_book_outlined,
                label: 'المادة',
                value: profile.subject,
              ),
              DetailRow(
                icon: Icons.school_outlined,
                label: 'المرحلة',
                value: profile.stage,
              ),
              DetailRow(
                icon: Icons.place_outlined,
                label: 'المنطقة',
                value: profile.area,
              ),
              DetailRow(
                icon: Icons.payments_outlined,
                label: 'السعر',
                value: profile.priceHint ?? 'غير محدد',
              ),
              DetailRow(
                icon: Icons.notes_outlined,
                label: 'النبذة',
                value: profile.bio,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pushNamed(
              RoutePaths.editTeacherProfile,
            ),
            child: const Text('تعديل المعلومات'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const InfoNote(
          text:
              'الحفظ على الخادم غير منفّذ: النموذج يتحقق من المدخلات فقط ولا '
              'يرسل أي شيء. ربط الحفظ بـFirestore يتم في مرحلة لاحقة.',
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        const SectionHeader(
          title: 'الخصوصية والرسائل',
          subtitle: 'من يستطيع مراسلتك قبل أن يحجز؟',
          icon: Icons.lock_outline,
        ),
        _DirectMessageSetting(),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(RoutePaths.directChats),
            icon: const Icon(Icons.forum_outlined, size: 18),
            label: const Text('محادثات الطلاب'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// مفتاح «استقبال رسائل الطلاب قبل الحجز» (A-78).
///
/// القيمة تُقرأ من المستودع (ومصدرها `teacherSettings/{uid}`)، وتُكتب فور
/// التبديل. **الإيقاف لا يقطع** محادثة قائمة مرتبطة بحجز أو بعضوية مجموعة —
/// يمنع الجديد فقط.
class _DirectMessageSetting extends StatefulWidget {
  const _DirectMessageSetting();

  @override
  State<_DirectMessageSetting> createState() => _DirectMessageSettingState();
}

class _DirectMessageSettingState extends State<_DirectMessageSetting> {
  bool? _allow;
  bool _saving = false;

  String get _teacherId =>
      CurrentTeacher.idOf(SessionScope.read(context));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_allow == null) {
      _load();
    }
  }

  Future<void> _load() async {
    final bool value = await AppServicesScope.of(
      context,
    ).chats.allowDirectMessages(_teacherId);
    if (mounted) {
      setState(() => _allow = value);
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _allow = value;
      _saving = true;
    });
    try {
      await AppServicesScope.of(context).chats.setAllowDirectMessages(
        teacherId: _teacherId,
        allow: value,
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        value ? 'يمكن للطلاب الآن مراسلتك قبل الحجز.' : 'أُوقف استقبال رسائل الطلاب قبل الحجز.',
        type: AppMessageType.success,
      );
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _allow = !value);
      AppSnackBar.show(
        context,
        error.overrideMessage ?? error.message,
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool? value = _allow;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: value ?? false,
            onChanged: value == null || _saving ? null : _toggle,
            title: const Text('استقبال رسائل قبل الحجز'),
            subtitle: Text(
              value == null
                  ? 'جارٍ قراءة الإعداد…'
                  : value
                  ? 'يستطيع أي طالب مسجّل بدء استفسار. البقية بحاجة إلى حجز أو '
                        'عضوية مجموعة.'
                  : 'مغلق: لا يراسلك إلا من له حجز قائم أو عضوية في إحدى '
                        'مجموعاتك.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const InfoNote(
            text:
                'القيمة الافتراضية مغلقة، والإغلاق يمنع المحادثات الجديدة فقط '
                'ولا يحذف محادثة قائمة.',
          ),
        ],
      ),
    );
  }
}
