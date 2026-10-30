import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_select_field.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/data/constants/academic_options.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/teacher_profile_draft.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/profile/presentation/widgets/account_avatar_editor.dart';

/// نموذج ملف المدرس — إنشاء أو تعديل، **ويحفظ فعلًا** (P18، وسياسة P22).
///
/// ## سياسة التعديل (P22)
///
/// | الحالة | ما يستطيع المدرس فعله |
/// |---|---|
/// | لا ملف | إنشاء ملف + صورة، فيُرسل للمراجعة |
/// | `draft` / `rejected` | تعديل وإعادة إرسال للمراجعة |
/// | `pendingReview` | **لا شيء** — الحقول مقفلة بانتظار قرار الإدارة |
/// | `verified` | تعديل، لكن بعد تأكيد صريح: التعديل يعيد الملف للمراجعة |
///
/// القفل هنا **للوضوح** لا للأمان: القاعدة على الخادم ترفض أي تعديل على ملف
/// منتظر المراجعة (`ownerStatusTransitionAllowed`)، فحتى لو فُتح المسار
/// يدويًا لن تُقبل الكتابة.
class EditTeacherProfileScreen extends StatefulWidget {
  const EditTeacherProfileScreen({super.key});

  @override
  State<EditTeacherProfileScreen> createState() =>
      _EditTeacherProfileScreenState();
}

class _EditTeacherProfileScreenState extends State<EditTeacherProfileScreen> {
  /// معرّف المدرس يُقرأ مرة واحدة من الجلسة (uid الحقيقي، أو معرّف المعاينة).
  String? _teacherId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _teacherId ??= CurrentTeacher.idOf(SessionScope.read(context));
  }

  @override
  Widget build(BuildContext context) {
    final String? teacherId = _teacherId;

    return Scaffold(
      // شفاف لعرض تدرّج الخلفية العالمي.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('تعديل المعلومات')),
      body: SafeArea(
        child: teacherId == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  ResponsiveContent(
                    child: AsyncView<TeacherProfile?>(
                      // المفتاح يجعل إعادة الفتح تُعيد القراءة بعد أي حفظ.
                      key: ValueKey<String>(teacherId),
                      load: () =>
                          AppServicesScope.of(context).teachers.findMine(teacherId),
                      builder:
                          (BuildContext context, TeacherProfile? profile) {
                            // لا ملف ⇒ نموذج إنشاء بقيم مبدئية من الحساب.
                            return _ProfileForm(
                              teacherId: teacherId,
                              profile: profile,
                              initialName:
                                  SessionScope.read(
                                    context,
                                  ).user?.displayName ??
                                  '',
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

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({
    required this.teacherId,
    required this.profile,
    required this.initialName,
  });

  final String teacherId;

  /// `null` = إنشاء ملف جديد.
  final TeacherProfile? profile;

  final String initialName;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _area;
  late final TextEditingController _bio;
  late final TextEditingController _price;
  late final TextEditingController _district;

  /// (P19) المادة والمرحلة والمحافظة صارت **اختيارًا من قائمة معتمدة**؛
  /// و(P22) أُضيف خيار «أخرى» الذي يفتح حقل نص حرّ للقيم غير المدرجة
  /// (مثل «العلوم المتكاملة» أو «رياض الأطفال»).
  String? _subject;
  String? _stage;
  String? _governorate;

  /// (P22) هل المادة/المرحلة مكتوبة يدويًا الآن؟
  bool _subjectCustom = false;
  bool _stageCustom = false;

  late final TextEditingController _subjectText;
  late final TextEditingController _stageText;

  late bool _isOnline;
  bool _saving = false;

  /// (P22) هل توجد صورة شخصية للملف؟ يأتي من الصورة المرفوعة/المحمّلة.
  bool _hasPhoto = false;

  /// (P23) رسالة النقص المعروضة داخل النموذج (لا Toast عابر فقط): تسمّي
  /// الحقول الإلزامية الغائبة فعلًا — الصورة والمادة والمرحلة.
  String? _missingNotice;

  /// هل الملف مقفل بانتظار قرار الإدارة؟
  bool get _locked =>
      widget.profile?.status == TeacherProfileStatus.pendingReview;

  /// هل هذا تعديل على ملف **موثّق** (يحتاج تأكيدًا قبل الحفظ)؟
  bool get _isVerified =>
      widget.profile?.status == TeacherProfileStatus.verified;

  @override
  void initState() {
    super.initState();
    final TeacherProfileDraft? initial = widget.profile == null
        ? null
        : TeacherProfileDraft.fromProfile(widget.profile!);

    _name = TextEditingController(
      text: initial?.displayName ?? widget.initialName,
    );
    _area = TextEditingController(text: _meaningful(initial?.area) ?? '');
    _bio = TextEditingController(text: initial?.bio ?? '');
    _price = TextEditingController(text: initial?.priceHint ?? '');
    _district = TextEditingController(text: initial?.district ?? '');
    _isOnline = initial?.isOnline ?? false;
    _hasPhoto = widget.profile?.hasPhoto ?? false;

    // القيم المحفوظة تُحمَّل كما هي؛ غير المعروفة تفتح وضع الكتابة اليدوية
    // ومعها نصّها، فلا يرى المدرس قيمة لا يعرف مصدرها ولا يفقدها بالحفظ.
    final String? savedSubject = _meaningful(initial?.subject);
    final String? savedStage = _meaningful(initial?.stage);
    _governorate = _blankToNull(initial?.governorate);

    _subjectCustom = AcademicOptions.isCustomSubject(savedSubject);
    _stageCustom = AcademicOptions.isCustomStage(savedStage);

    _subject = _subjectCustom ? null : savedSubject;
    _stage = _stageCustom ? null : savedStage;

    _subjectText = TextEditingController(
      text: _subjectCustom ? savedSubject ?? '' : '',
    );
    _stageText = TextEditingController(
      text: _stageCustom ? savedStage ?? '' : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _bio.dispose();
    _price.dispose();
    _district.dispose();
    _subjectText.dispose();
    _stageText.dispose();
    super.dispose();
  }

  static String? _blankToNull(String? raw) {
    final String text = (raw ?? '').trim();
    return text.isEmpty ? null : text;
  }

  /// قيمة يحملها المُحوِّل (`firestore_mappers`) عند **غياب** الحقل — مثل
  /// مسودة أُنشئت تلقائيًا عند اختيار دور «مدرس» قبل تعبئة أي شيء.
  ///
  /// تُعامل كفراغ: كتابة «غير محدد» داخل حقل المادة كانت ستعني مادة اسمها
  /// «غير محدد» تُحفظ للمراجعة.
  static const String _unsetPlaceholder = 'غير محدد';

  static String? _meaningful(String? raw) {
    final String? value = _blankToNull(raw);
    return value == _unsetPlaceholder ? null : value;
  }

  /// القيمة التي ستُحفظ فعلًا (نص حرّ في وضع الكتابة اليدوية).
  String get _subjectValue =>
      (_subjectCustom ? _subjectText.text : _subject ?? '').trim();

  String get _stageValue =>
      (_stageCustom ? _stageText.text : _stage ?? '').trim();

  Future<void> _save() async {
    if (_saving || _locked) {
      return;
    }

    final bool valid = _formKey.currentState?.validate() ?? false;

    // (P23) الحقول الإلزامية الثلاثة تُفحص معًا وتُسمّى في رسالة واحدة.
    final String? missing = _missingMandatorySummary();
    if (!valid || missing != null) {
      final String message = missing ?? 'راجع الحقول المطلوبة قبل الحفظ.';
      setState(() => _missingNotice = missing);
      AppSnackBar.show(context, message, type: AppMessageType.warning);
      return;
    }

    setState(() => _missingNotice = null);

    // (P22) تعديل ملف موثّق = إعادة تحقق: تنبيه صريح **قبل** الحفظ.
    if (_isVerified) {
      final bool confirmed = await _confirmReverification();
      if (!confirmed || !mounted) {
        return;
      }
    }

    final TeacherProfileDraft draft = TeacherProfileDraft(
      displayName: _name.text,
      subject: _subjectValue,
      stage: _stageValue,
      area: _area.text,
      bio: _bio.text,
      isOnline: _isOnline,
      priceHint: _price.text,
      governorate: _isOnline ? null : _governorate,
      district: _isOnline ? null : _district.text,
      photoPath: TeacherProfile.photoPathFor(widget.teacherId),
    );

    setState(() => _saving = true);
    try {
      await AppServicesScope.of(
        context,
      ).teachers.saveMyProfile(uid: widget.teacherId, draft: draft);
      if (!mounted) {
        return;
      }

      final bool isDemo = SessionScope.read(context).isDemoSession;
      final bool isNew = widget.profile == null;
      AppSnackBar.show(
        context,
        isDemo
            ? 'حُفظ الملف لهذه الجولة فقط — أنشئ حسابًا ليظهر للطلاب.'
            : isNew
            ? 'أُنشئ ملفك وأُرسل للمراجعة. سيظهر للطلاب بعد التوثيق.'
            : _isVerified
            ? 'حُفظت التعديلات، وأُعيد ملفك إلى المراجعة للتحقق من التغييرات.'
            : 'حُفظت التعديلات وأُرسلت للمراجعة.',
        type: AppMessageType.success,
      );
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        error.overrideMessage ?? error.message,
        type: AppMessageType.error,
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
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// ملخّص الحقول الإلزامية الغائبة — `null` إن كان كل شيء مكتملًا.
  ///
  /// الحدود مطابقة للقواعد (`photoSatisfiedFor` و`academicFieldsSatisfiedFor`):
  /// صورة موجودة + مادة ومرحلة بطول 2..40. الرسالة تسمّي ما ينقص بالضبط.
  String? _missingMandatorySummary() {
    final List<String> missing = <String>[];
    if (!_hasPhoto) {
      missing.add('الصورة الشخصية');
    }
    final String subject = _subjectValue;
    if (subject.isEmpty) {
      missing.add('المادة');
    } else if (AcademicOptions.customTextProblem(subject, 'المادة') != null) {
      // نص حرّ قصير/طويل: التحقق الحقيقي في حقل النموذج، لكن نذكّره هنا أيضًا.
      missing.add('المادة (حرفان إلى 40)');
    }
    final String stage = _stageValue;
    if (stage.isEmpty) {
      missing.add('المرحلة الدراسية');
    } else if (AcademicOptions.customTextProblem(stage, 'المرحلة') != null) {
      missing.add('المرحلة الدراسية (حرفان إلى 40)');
    }

    if (missing.isEmpty) {
      return null;
    }
    return 'ملفك غير مكتمل — ينقصه: ${missing.join('، ')}. '
        'أكمل الحقول المطلوبة ليُرسل للمراجعة.';
  }

  /// تأكيد إعادة التحقق قبل تعديل ملف موثّق.
  ///
  /// الحوار يشرح **الأثر** لا مجرد السؤال: الملف يختفي من نتائج البحث حتى
  /// تُراجعه الإدارة، لأن الظهور مشروط بحالة `verified`.
  Future<bool> _confirmReverification() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          key: const Key('profile-reverify-dialog'),
          title: const Text('تعديل ملف موثّق'),
          content: const Text(
            'ملفك موثّق ويظهر للطلاب الآن. أي تعديل يعيده إلى قائمة المراجعة، '
            'ولن يظهر للطلاب حتى تعتمده الإدارة من جديد.\n\n'
            'هل تريد المتابعة؟',
          ),
          actions: <Widget>[
            TextButton(
              key: const Key('profile-reverify-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              key: const Key('profile-reverify-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('متابعة التعديل'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// حقل مكان اختياري: الفراغ مسموح، وأي نص يجب أن يقع بين حرفين والحدّ.
  ///
  /// الحدود مطابقة لـ`validOptionalText` في `firestore.rules` (المحافظة 40
  /// والحي 60) حتى لا يُقبل هنا ما ترفضه القواعد لاحقًا.
  String? _optionalPlace(String? value, String label, int maxLength) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.length < 2) {
      return '$label قصير جدًا (حرفان على الأقل)';
    }
    if (text.length > maxLength) {
      return '$label طويل جدًا ($maxLength حرفًا كحد أقصى)';
    }
    return null;
  }

  String? _required(String? value, String label) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return '$label مطلوب';
    }
    if (text.length > 40 && label != 'الاسم') {
      return '$label طويل جدًا';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isNew = widget.profile == null;
    final AppUser? user = SessionScope.of(context).user;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_locked) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            // (P22) إشعار صريح: لا «أزرار معطّلة بلا سبب».
            const InfoNote(
              key: Key('profile-locked-notice'),
              icon: Icons.lock_clock_outlined,
              text:
                  'ملفك قيد المراجعة من الإدارة، والتعديل مُعطَّل حتى يصل '
                  'القرار. لا تحتاج إلى أي خطوة الآن — سنُعلمك عند التوثيق. '
                  'إن كان لديك تصحيح عاجل، راسل الدعم.',
            ),
          ] else if (isNew) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const InfoNote(
              text:
                  'لا يوجد ملف تعريفي بعد. املأ الحقول التالية وأضف صورة '
                  'شخصية ليُنشأ ملفك ويُرسل للمراجعة، ويظهر للطلاب بعد '
                  'توثيق الإدارة.',
            ),
          ] else if (widget.profile?.status == TeacherProfileStatus.rejected) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            InfoNote(
              icon: Icons.report_outlined,
              text:
                  'ملفك يحتاج تعديلًا'
                  '${_reviewNoteSuffix()}. عدّل ما طُلب منك ثم احفظ ليُرسل '
                  'للمراجعة من جديد.',
            ),
          ] else if (_isVerified) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const InfoNote(
              key: Key('profile-reverify-notice'),
              icon: Icons.verified_outlined,
              text:
                  'ملفك موثّق ويظهر للطلاب. أي تعديل هنا يعيده إلى المراجعة، '
                  'ولن يظهر للطلاب حتى تعتمده الإدارة مرة أخرى.',
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // (P22) الصورة أولًا: أهم ما يبني الثقة، وشرط الإرسال.
          AccountAvatarEditor(
            key: const Key('profile-avatar'),
            userId: widget.teacherId,
            initialPreset: user?.resolvedAvatarPreset ?? 0,
            initials: user?.initials,
            enabled: !_locked,
            helperText: _locked
                ? 'مقفلة أثناء المراجعة'
                : 'صورة واضحة للوجه مطلوبة قبل حفظ الملف',
            onChanged: (AvatarSelection selection) {
              if (selection.hasCustomPhoto == _hasPhoto) {
                return;
              }
              setState(() => _hasPhoto = selection.hasCustomPhoto);
            },
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            key: const Key('profile-name'),
            controller: _name,
            enabled: !_locked,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'الاسم الظاهر',
              helperText: 'الاسم الذي يراه الطلاب',
            ),
            validator: (String? value) {
              final String? required = _required(value, 'الاسم');
              if (required != null) {
                return required;
              }
              final String text = (value ?? '').trim();
              if (text.length < 3) {
                return 'الاسم قصير جدًا (3 أحرف على الأقل)';
              }
              if (text.length > 80) {
                return 'الاسم طويل جدًا (80 حرفًا كحد أقصى)';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // (P19) قائمة منسدلة بدل نص حر + (P22) خيار «أخرى» للكتابة اليدوية.
          AppSelectField(
            key: const Key('profile-subject'),
            label: 'المادة',
            value: _subjectCustom
                ? AcademicOptions.customOption
                : _subject,
            enabled: !_locked,
            options: AcademicOptions.subjects,
            extraOptions: const <String>[AcademicOptions.customOption],
            optionLabel: _optionLabel,
            isRequired: true,
            helperText: 'اختر من القائمة، أو «أخرى» لكتابة مادتك بنفسك',
            onChanged: (String? next) {
              setState(() {
                if (next == AcademicOptions.customOption) {
                  _subjectCustom = true;
                  _subject = null;
                } else {
                  _subjectCustom = false;
                  _subject = next;
                }
              });
            },
            validator: (String? value) =>
                _subjectCustom ? null : _required(value, 'المادة'),
          ),
          if (_subjectCustom) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const Key('profile-subject-custom'),
              controller: _subjectText,
              enabled: !_locked,
              textInputAction: TextInputAction.next,
              maxLength: AcademicOptions.maxCustomLength,
              decoration: const InputDecoration(
                labelText: 'اسم المادة',
                helperText: 'مثال: العلوم المتكاملة',
                counterText: '',
              ),
              validator: (String? value) =>
                  AcademicOptions.customTextProblem(value, 'اسم المادة'),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),

          AppSelectField(
            key: const Key('profile-stage'),
            label: 'المرحلة الدراسية',
            value: _stageCustom
                ? AcademicOptions.customOption
                : _stage,
            enabled: !_locked,
            options: AcademicOptions.stages,
            extraOptions: const <String>[AcademicOptions.customOption],
            optionLabel: _optionLabel,
            isRequired: true,
            helperText: 'اختر من القائمة، أو «أخرى» لتكتب المرحلة بنفسك',
            onChanged: (String? next) {
              setState(() {
                if (next == AcademicOptions.customOption) {
                  _stageCustom = true;
                  _stage = null;
                } else {
                  _stageCustom = false;
                  _stage = next;
                }
              });
            },
            validator: (String? value) =>
                _stageCustom ? null : _required(value, 'المرحلة'),
          ),
          if (_stageCustom) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const Key('profile-stage-custom'),
              controller: _stageText,
              enabled: !_locked,
              textInputAction: TextInputAction.next,
              maxLength: AcademicOptions.maxCustomLength,
              decoration: const InputDecoration(
                labelText: 'اسم المرحلة',
                helperText: 'مثال: رياض الأطفال',
                counterText: '',
              ),
              validator: (String? value) =>
                  AcademicOptions.customTextProblem(value, 'اسم المرحلة'),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),

          TextFormField(
            key: const Key('profile-area'),
            controller: _area,
            enabled: !_locked,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'المنطقة',
              helperText: 'وصف حر يظهر في ملفك العام',
            ),
            validator: (String? value) => _required(value, 'المنطقة'),
          ),
          const SizedBox(height: AppSpacing.md),

          // (P15) طريقة التقديم: علم واحد مستقلّ عن المحافظة — من يعلّم «عن
          // بُعد» يظهر لكل المحافظات في فلتر «عن بُعد»، ويُستبعد من «حضوري».
          SwitchListTile(
            key: const Key('profile-online'),
            value: _isOnline,
            onChanged: _locked
                ? null
                : (bool value) => setState(() => _isOnline = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('أدرّس عن بُعد'),
            subtitle: Text(
              _isOnline
                  ? 'يظهر ملفك في «عن بُعد» لكل المحافظات، ويُستبعد من البحث '
                        'الحضوري.'
                  : 'حضوري فقط: يظهر ملفك حسب محافظتك، ويُستبعد من «عن بُعد».',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_isOnline)
            const InfoNote(
              text:
                  'المحافظة والحي يخصّان المحاضرات الحضورية، ولا يُطلبان في '
                  'التعليم عن بُعد. يمكنك تركهما فارغين.',
            )
          else ...<Widget>[
            // (P19) المحافظة من قائمة الـ27 محافظة، فتُطابق فلتر الطالب حرفيًا.
            AppSelectField(
              key: const Key('profile-governorate'),
              label: 'المحافظة (اختياري)',
              value: _governorate,
              enabled: !_locked,
              options: AcademicOptions.governorates,
              helperText: 'فلتر البحث الأساسي للطلاب',
              onChanged: (String? next) =>
                  setState(() => _governorate = next),
              validator: (String? value) =>
                  _optionalPlace(value, 'المحافظة', 40),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const Key('profile-district'),
              controller: _district,
              enabled: !_locked,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'الحي / المركز (اختياري)',
                helperText: 'أدقّ ما يراه الطالب قبل الحجز — مثل: المعادي',
              ),
              validator: (String? value) => _optionalPlace(value, 'الحي', 60),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),

          TextFormField(
            key: const Key('profile-bio'),
            controller: _bio,
            enabled: !_locked,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'نبذة',
              alignLabelWithHint: true,
              helperText: 'بين 20 و300 حرف',
            ),
            validator: (String? value) {
              final String text = (value ?? '').trim();
              if (text.length < 20) {
                return 'النبذة قصيرة جدًا (20 حرفًا على الأقل)';
              }
              if (text.length > 300) {
                return 'النبذة طويلة جدًا (300 حرف كحد أقصى)';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          TextFormField(
            key: const Key('profile-price'),
            controller: _price,
            enabled: !_locked,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'سعر استرشادي (اختياري)',
              helperText: 'نص حر — الدفع خارج التطبيق',
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (!_locked) ...<Widget>[
            if (_missingNotice != null) ...<Widget>[
              InfoNote(
                key: const Key('profile-missing-notice'),
                icon: Icons.error_outline,
                text: _missingNotice!,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            FilledButton(
              key: const Key('profile-save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isNew
                          ? 'إنشاء الملف وإرساله للمراجعة'
                          : _isVerified
                          ? 'حفظ (يعيد الملف للمراجعة)'
                          : 'حفظ وإرسال للمراجعة',
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const InfoNote(
              text:
                  'يُرسل ملفك للمراجعة بعد الحفظ، ويبقى غير ظاهر للطلاب حتى '
                  'توثّقه الإدارة. التمييز في الصفحة الرئيسية قرار إداري لا '
                  'يُضبط من هنا.',
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  /// « — ملاحظة المراجع: …» عند وجود سبب رفض، وإلا نصرة.
  String _reviewNoteSuffix() {
    final String? note = _blankToNull(widget.profile?.reviewNote);
    return note == null ? '' : ' — ملاحظة المراجع: $note';
  }

  static String _optionLabel(String value) =>
      value == AcademicOptions.customOption
      ? AcademicOptions.customOptionLabel
      : value;
}
