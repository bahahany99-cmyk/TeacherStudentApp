import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/detail_row.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/core/widgets/user_avatar_view.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// «ملفي» — الملف التعريفي كما يراه المدرس صاحبه (P18: حقيقي لا تجريبي).
///
/// - يقرأ **ملف صاحب الجلسة** عبر `findMine(uid)`، لا ملفًا تجريبيًا ثابتًا.
///   و`findMine` يُعيد ملفه بأي حالة (مسودة/قيد المراجعة/مرفوض/موثّق)، لأن
///   القواعد تسمح لصاحبه بالقراءة دائمًا.
/// - **لا ملف بعد** ⇒ زر «إنشاء ملف تعريفي» يفتح النموذج مباشرة.
/// - بعد أي حفظ يعود النموذج بـ`true` فتُعاد القراءة من الخادم (لا نثق بقيمة
///   محلية قد تكون كُتبت ثم رُفضت).
///
/// حالة الملف تُعرض بوسم صريح مع سبب الرفض إن وُجد — وإلا لن يعرف المدرس
/// لماذا لا يظهر ملفه للطلاب.
class MyTeacherProfileScreen extends StatefulWidget {
  const MyTeacherProfileScreen({super.key});

  @override
  State<MyTeacherProfileScreen> createState() => _MyTeacherProfileScreenState();
}

class _MyTeacherProfileScreenState extends State<MyTeacherProfileScreen> {
  String? _teacherId;

  /// يُغيَّر بعد كل حفظ ناجح لإجبار `AsyncView` على القراءة من جديد.
  int _reloads = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _teacherId ??= CurrentTeacher.idOf(SessionScope.read(context));
  }

  Future<void> _openEditor() async {
    // بلا معامل نوع: الراوتر يعيد `Route<dynamic>`، وطلب `Route<bool?>`
    // يُفشل الإرسال (`is not a subtype of Route<bool?>`) في الاختبارات
    // وفي أي شاشة تعيد قيمة. نقارن الناتج بـ`true` بدل فرض النوع.
    final Object? saved = await Navigator.of(
      context,
    ).pushNamed(RoutePaths.editTeacherProfile);
    if (saved == true && mounted) {
      setState(() => _reloads++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? teacherId = _teacherId;

    return Scaffold(
      // شفاف لعرض تدرّج الخلفية العالمي (نسخة 3).
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('ملفي التعريفي'),
        actions: <Widget>[
          IconButton(
            key: const Key('my-profile-edit-action'),
            tooltip: 'تعديل',
            icon: const Icon(Icons.edit_outlined),
            onPressed: teacherId == null
                ? null
                : () async {
                    await _openEditor();
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: teacherId == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  ResponsiveContent(
                    child: AsyncView<TeacherProfile?>(
                      key: ValueKey<String>('$teacherId-$_reloads'),
                      load: () => AppServicesScope.of(
                        context,
                      ).teachers.findMine(teacherId),
                      builder:
                          (BuildContext context, TeacherProfile? profile) {
                            if (profile == null) {
                              return _NoProfileYet(onCreate: _openEditor);
                            }
                            return _MyProfileBody(
                              profile: profile,
                              onEdit: _openEditor,
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

/// لا ملف بعد: دعوة إنشاء واضحة (onboarding) لا رسالة صامتة ولا نص تقني.
///
/// (P21) بعد إزالة شريط التطوير، صار هذا **أول ما يراه المدرس الجديد**، فصيغته
/// صارت جملة فائدة + زر واحد بدل «لا يوجد ملف» المجرّدة.
class _NoProfileYet extends StatelessWidget {
  const _NoProfileYet({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      key: const Key('my-profile-empty-card'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary.withAlpha(24),
            child: Icon(
              Icons.badge_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'لم تنشئ ملفك التعريفي بعد',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'الملف هو ما يراه الطالب: مادتك ومرحلتك ومنطقتك ونبذة عن طريقة '
            'شرحك. أنشئه الآن ويظهر للطلاب بعد اعتماد الإدارة.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.75,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('my-profile-create'),
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            child: const Text('إنشاء ملف تعريفي'),
          ),
        ],
      ),
    );
  }
}

class _MyProfileBody extends StatelessWidget {
  const _MyProfileBody({required this.profile, required this.onEdit});

  final TeacherProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  // (P22) صورته التي رفعها — يرى نفس ما يراه الطالب.
                  UserAvatarLoader(
                    userId: profile.id,
                    initials: profile.initials,
                    size: AppSpacing.avatarMd,
                    semanticLabel: 'صورتك في الملف',
                  ),
                  const SizedBox(width: AppSpacing.sm),
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
              // (P15) المكان الدقيق وطريقة التقديم — يظهران للطالب قبل الحجز.
              DetailRow(
                icon: Icons.map_outlined,
                label: 'الموقع',
                value: profile.locationLabel,
              ),
              DetailRow(
                icon: Icons.laptop_mac_outlined,
                label: 'طريقة التقديم',
                value: profile.deliveryLabel,
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
        // سبب الرفض — يظهر لصاحبه فقط (هنا) لا للطلاب.
        if (profile.status == TeacherProfileStatus.rejected &&
            (profile.reviewNote ?? '').isNotEmpty) ...<Widget>[
          InfoNote(
            text:
                'سبب الرفض: ${profile.reviewNote} — صحّح ما يلزم ثم أعد '
                'الحفظ؛ يعود الملف للمراجعة.',
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (profile.status != TeacherProfileStatus.verified) ...<Widget>[
          InfoNote(
            text:
                'ملفك لا يظهر للطلاب بعد. حالته «${profile.status.label}» وستظهر '
                'في البحث بعد توثيق الإدارة.',
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('my-profile-edit'),
            onPressed: onEdit,
            child: const Text('تعديل المعلومات'),
          ),
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
