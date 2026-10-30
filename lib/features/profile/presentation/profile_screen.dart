import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/settings_group.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/core/widgets/user_avatar_view.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/account_deletion_rules.dart';
import 'package:teacher_student_app/features/account/presentation/account_deletion_dialog.dart';
import 'package:teacher_student_app/features/profile/presentation/widgets/account_avatar_editor.dart';

/// صفحة الحساب والملف الشخصي — **مشتركة** بين الطالب والمدرس (تبويب «حسابي»).
///
/// ## بنية الصفحة (نسخة 5 — 2026-10-30)
///
/// كانت الصفحة قائمة واحدة طويلة من تسعة صفوف متساوية (بياناتي، المحادثات،
/// الإشعارات، المساعدة، الشروط، الخروج…) ثم فقرة شرح ثم محرّر صورة ثم
/// «منطقة خطر». الأثر: المستخدم يرى «قائمة إعدادات» مسطّحة بلا تسلسل،
/// والبيانات الشخصية (أهم ما في الصفحة) مدفونة في المنتصف.
///
/// الترتيب الجديد يتبع ما يفعله المستخدم فعلًا:
/// 1. **بطاقة الهوية** — الصورة والاسم ونوع الحساب والبريد، والضغط عليها يفتح
///    «بياناتي». لا شرح نظري تحتها (الشرح داخل الحقول نفسها).
/// 2. **الصورة الشخصية** — محرّر واحد واضح، لا صفوف متعددة لنفس الفعل.
/// 3. **الحساب / التواصل / الدعم / الجلسة / منطقة الخطر** — مجموعات مفصولة
///    بعنوان، وخطوط بادئة بعد الأيقونة، وأيقونة في مربع ملوّن هادئ.
///
/// **لا تكرار:** كل وجهة تظهر مرة واحدة. «المساعدة والدعم» و«الشروط وسياسة
/// الخصوصية» في مجموعة واحدة تحت عنوان «الدعم والمعلومات»، و«تسجيل الخروج»
/// منفصل عن «حذف الحساب» لأن أولهما عادي والثاني لا رجعة فيه.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.now});

  /// ساعة الاختبار: تُمرَّر إلى حوار الحذف ليثبت الموعد المعروض.
  final DateTime? now;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// عملية حسابية جارية (خروج/حذف). نُقفل الأزرار أثناءها حتى لا يُرسل
  /// المستخدم الطلب مرتين، وحتى لا يُغادر الشاشة قبل اكتمال الكتابة.
  bool _busy = false;

  void _switchRole(UserRole role) {
    SessionScope.read(context).switchDemoRole(role);
  }

  void _open(String route) => Navigator.of(context).pushNamed(route);

  /// تسجيل الخروج: تأكيد ← إنهاء الجلسة ← شاشة الدخول.
  ///
  /// ننتظر `signOut()` قبل التنقل: لو تنقّلنا أولًا لبقي رمز الهوية صالحًا
  /// لحظات، وظهرت شاشة الدخول بينما الجلسة ما زالت قائمة.
  Future<void> _signOut() async {
    if (_busy) {
      return;
    }
    final bool confirmed = await confirmSignOut(context);
    if (!confirmed || !mounted) {
      return;
    }

    final NavigatorState navigator = Navigator.of(context);
    final SessionController session = SessionScope.read(context);
    setState(() => _busy = true);

    try {
      await session.signOut();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      AppSnackBar.show(
        context,
        toAppException(error).message,
        type: AppMessageType.error,
      );
      return;
    }

    if (!mounted) {
      return;
    }
    await navigator.pushNamedAndRemoveUntil(
      RoutePaths.login,
      (Route<dynamic> route) => false,
    );
  }

  /// طلب حذف الحساب (حذف ناعم، مهلة 7 أيام) ← خروج ← شاشة الدخول.
  Future<void> _deleteAccount() async {
    if (_busy) {
      return;
    }
    final bool confirmed = await confirmAccountDeletion(
      context,
      now: widget.now,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final NavigatorState navigator = Navigator.of(context);
    final SessionController session = SessionScope.read(context);
    final bool demo = session.isDemoSession;
    setState(() => _busy = true);

    try {
      final DateTime? scheduledAt = await session.requestAccountDeletion();
      if (!mounted) {
        return;
      }
      if (scheduledAt == null) {
        setState(() => _busy = false);
        return;
      }
      // التنبيه قبل التنقل: الـ`ScaffoldMessenger` أعلى الموجّه، فيبقى ظاهرًا
      // على شاشة الدخول بعد إزالة الشاشة الحالية.
      AppSnackBar.show(
        context,
        demo
            ? 'طلبك مسجّل في هذه الجولة فقط. أنشئ حسابًا لحذفه فعليًا، وتبدأ '
                  'حينها مهلة ${AccountDeletionRules.gracePeriod.inDays} أيام.'
            : 'سُجّل طلب الحذف وسُجّل خروجك. لديك '
                  '${AccountDeletionRules.gracePeriod.inDays} أيام لاستعادة '
                  'الحساب بتسجيل الدخول من جديد.',
        type: AppMessageType.warning,
        duration: const Duration(seconds: 7),
      );
      await navigator.pushNamedAndRemoveUntil(
        RoutePaths.login,
        (Route<dynamic> route) => false,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      AppSnackBar.show(
        context,
        toAppException(error).message,
        type: AppMessageType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = SessionScope.of(context);
    final AppUser? user = session.user;

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 1) الهوية: صورة + اسم + نوع الحساب + البريد، والضغط يفتح
              //    «بياناتي» — أقصر طريق إلى أهم فعل في الصفحة.
              _IdentityCard(
                user: user,
                onTap: () => _open(RoutePaths.myData),
                onOpenPublicProfile: user?.role == UserRole.teacher
                    ? () => _open(RoutePaths.myTeacherProfile)
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // 2) الصورة الشخصية: محرّر واحد، متاح للطالب والمدرس معًا —
              //    الحساب ليس بلا صورة أبدًا (P22).
              if (user != null)
                SettingsGroup(
                  title: 'الصورة الشخصية',
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: AccountAvatarEditor(
                        key: const Key('profile-avatar-editor'),
                        userId: user.id,
                        initialPreset: user.resolvedAvatarPreset,
                        initials: user.initials,
                        helperText: 'تظهر بجانب اسمك في المحادثات وملفك.',
                      ),
                    ),
                  ],
                ),

              // 3) الحساب: بياناتي + (المدرس) ملفه التعريفي + (الطالب) مفضلته.
              SettingsGroup(
                title: 'الحساب',
                children: <Widget>[
                  // (P14) الإدارة فقط: مدخل اللوحة. القرار الحقيقي في القواعد،
                  // و`AdminGuard` يمنع الوصول لو فُتح المسار من حساب آخر.
                  if (session.isAdmin)
                    SettingsTile(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'لوحة الإدارة',
                      onTap: () => _open(RoutePaths.adminDashboard),
                    ),
                  SettingsTile(
                    key: const Key('profile-my-data'),
                    icon: Icons.person_outline,
                    label: 'بياناتي',
                    subtitle: 'الاسم والصورة والبيانات الأكاديمية',
                    onTap: () => _open(RoutePaths.myData),
                  ),
                  if (user?.role == UserRole.teacher)
                    SettingsTile(
                      icon: Icons.badge_outlined,
                      label: 'ملفي التعريفي',
                      subtitle: 'ما يراه الطلاب في صفحتك',
                      onTap: () => _open(RoutePaths.myTeacherProfile),
                    ),
                  // المفضلة للطالب (P13): المدرس لا يحفظ مدرسين ولا مجموعات.
                  if (user?.role == UserRole.student)
                    SettingsTile(
                      icon: Icons.favorite_border,
                      label: 'المفضلة',
                      subtitle: 'المدرسون والمجموعات المحفوظة',
                      onTap: () => _open(RoutePaths.favorites),
                    ),
                ],
              ),

              // 4) التواصل: المحادثات والإشعارات — لا تظهر أي منهما في مكان آخر.
              SettingsGroup(
                title: 'التواصل',
                children: <Widget>[
                  SettingsTile(
                    icon: Icons.forum_outlined,
                    label: 'المحادثات',
                    subtitle: 'حواراتك المباشرة مع المدرسين',
                    onTap: () => _open(RoutePaths.directChats),
                  ),
                  SettingsTile(
                    icon: Icons.notifications_none,
                    label: 'الإشعارات',
                    subtitle: 'طلبات الحجز والانضمام وقراراتها',
                    onTap: () => _open(RoutePaths.notifications),
                  ),
                ],
              ),

              SettingsGroup(
                title: 'الدعم والمعلومات',
                children: <Widget>[
                  SettingsTile(
                    icon: Icons.help_outline,
                    label: 'المساعدة والدعم',
                    subtitle: 'أسئلة شائعة وقناة تواصل',
                    onTap: () => _open(RoutePaths.support),
                  ),
                  SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'الشروط وسياسة الخصوصية',
                    onTap: () => _open(RoutePaths.legal),
                  ),
                ],
              ),

              // 5) الجلسة: الخروج فعل عادي، وفي مجموعة مستقلة.
              SettingsGroup(
                title: 'الجلسة',
                children: <Widget>[
                  SettingsTile(
                    key: const Key('profile-sign-out'),
                    icon: Icons.logout,
                    label: AccountDeletionRules.signOutAction,
                    danger: true,
                    busy: _busy,
                    onTap: _busy ? null : _signOut,
                  ),
                ],
              ),

              // 6) منطقة الخطر: فعل لا رجعة فيه، منفصل بصريًا ونصيًا.
              SettingsGroup(
                title: 'منطقة الخطر',
                children: <Widget>[
                  SettingsTile(
                    key: const Key('profile-delete-account'),
                    icon: Icons.delete_forever_outlined,
                    label: AccountDeletionRules.deleteTitle,
                    subtitle:
                        'مهلة ${AccountDeletionRules.gracePeriod.inDays} '
                        'أيام للتراجع قبل الحذف النهائي',
                    danger: true,
                    busy: _busy,
                    onTap: _busy ? null : _deleteAccount,
                  ),
                ],
              ),
              const InfoNote(
                text:
                    'حذف الحساب في هذه النسخة حذف ناعم: يخفي حسابك من البحث '
                    'ويوقف استخدامه، ويبدأ مهلة استعادة. الحذف النهائي '
                    'للبيانات إجراء إداري.',
                icon: Icons.shield_outlined,
              ),
              if (session.isDemoSession) ...<Widget>[
                // (P21) أدوات تطوير: لا تُبنى في نسخة الإصدار أصلًا.
                //
                // آخر ما يجب أن يراه مستخدم على جهاز حقيقي: أزرار تبديل
                // «واجهة الطالب/المدرس/الإدارة» ومعرض مكوّنات. `kDebugMode` ثابت
                // وقت الترجمة، فالفرع كله يُحذف من APK الإصدار ولا يبقى مجرد
                // مخفي.
                if (kDebugMode) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  SettingsGroup(
                    title: 'معاينة الواجهات (تطوير)',
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.school_outlined,
                        label: 'واجهة الطالب',
                        onTap: () => _switchRole(UserRole.student),
                      ),
                      SettingsTile(
                        icon: Icons.co_present_outlined,
                        label: 'واجهة المدرس',
                        onTap: () => _switchRole(UserRole.teacher),
                      ),
                      SettingsTile(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'واجهة الإدارة (تجريبي)',
                        onTap: () => _switchRole(UserRole.admin),
                      ),
                      SettingsTile(
                        icon: Icons.widgets_outlined,
                        label: 'معرض المكونات',
                        onTap: () => _open(RoutePaths.designGallery),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }
}

/// بطاقة الهوية أعلى «حسابي»: صورة + اسم + نوع الحساب + البريد.
///
/// **لماذا بطاقة لا مجرد صف؟** لأن هذه هي المعلومات التي يحتاج المستخدم
/// التأكد منها فورًا (بأي حساب أنا داخل؟ وما بريدي؟)، ثم ضغطة واحدة تنقله إلى
/// تعديلها. الاسم والبريد هنا للقراءة فقط، والقرار في «بياناتي».
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.user,
    required this.onTap,
    this.onOpenPublicProfile,
  });

  final AppUser? user;
  final VoidCallback onTap;

  /// فتح الملف العام كما يراه الطلاب (للمدرس فقط).
  final VoidCallback? onOpenPublicProfile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = user?.displayName ?? 'مستخدم غير معروف';

    return AppCard(
      padding: AppSpacing.cardPaddingRoomy,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          // (P22) الصورة الفعلية للحساب: صورة مخصّصة إن وُجدت، وإلا التصميم
          // الافتراضي — لا دائرة بحرف فقط.
          UserAvatarLoader(
            key: const Key('profile-avatar-image'),
            userId: user?.id ?? '',
            presetId: user?.resolvedAvatarPreset,
            initials: user?.initials,
            size: AppSpacing.avatarMd,
            semanticLabel: 'صورة الحساب',
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: <Widget>[
                    StatusChip(
                      label: user?.role.label ?? '—',
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        user?.email ?? 'لا يوجد بريد مرتبط بعد',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                // (P28) حالة الملف العام كما يراها الطالب — داخل الهوية لا في
                // صفحة منفصلة، لأنها جزء من «من أنا في هذا التطبيق».
                if (user?.role == UserRole.teacher && user != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs + 2),
                    child: _TeacherProfileState(
                      teacherId: user!.id,
                      onTap: onOpenPublicProfile,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Icon(
            Icons.chevron_left,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
          ),
        ],
      ),
    );
  }
}


/// حالة الملف التعريفي للمدرس: مكتمل/ناقص + حالة التوثيق + مدخل للملف العام.
///
/// **لماذا هنا؟** لأن المدرس يحتاج أن يعرف بلحظة واحدة: هل ملفي جاهز ومقبول،
/// وما الذي يراه الطالب الآن؟ وضعها في بطاقة الهوية يمنع تكرارها في مكانين.
class _TeacherProfileState extends StatelessWidget {
  const _TeacherProfileState({required this.teacherId, this.onTap});

  final String teacherId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AsyncView<TeacherProfile?>(
      load: () => AppServicesScope.of(context).teachers.findMine(teacherId),
      builder: (BuildContext context, TeacherProfile? profile) {
        final (String, Color) state = switch (profile?.status) {
          TeacherProfileStatus.verified => ('موثّق ويظهر للطلاب', AppColors.statusAccepted),
          TeacherProfileStatus.pendingReview => ('قيد المراجعة', AppColors.statusPending),
          TeacherProfileStatus.rejected => ('يحتاج تعديلًا', AppColors.statusRejected),
          TeacherProfileStatus.draft => ('مسودة غير مكتملة', AppColors.statusPending),
          null => ('لا يوجد ملف تعريفي بعد', AppColors.statusNeutral),
        };

        return Row(
          children: <Widget>[
            StatusChip(label: state.$1, color: state.$2),
            const SizedBox(width: AppSpacing.xs),
            if (onTap != null)
              Flexible(
                child: TextButton(
                  key: const Key('profile-public-profile'),
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: theme.textTheme.labelSmall,
                  ),
                  child: const Text('ما يراه الطلاب'),
                ),
              ),
          ],
        );
      },
    );
  }
}
