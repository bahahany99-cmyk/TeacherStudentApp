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
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/teacher_profile_draft.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// نموذج ملف المدرس — **إنشاء أو تعديل، ويحفظ فعلًا** (P18).
///
/// ## ما تغيّر
///
/// كان النموذج عرضًا فقط: يتحقق من المدخلات ثم يقول «لم يُحفظ شيء». الآن:
/// - يقرأ **ملف صاحب الجلسة** (`findMine(uid)`)، لا ملفًا تجريبيًا ثابتًا.
/// - إن لم يوجد ملف ⇒ يُنشئه بحالة `pendingReview` (نفس ما تفرضه القاعدة).
/// - إن وُجد ⇒ يُحدّث الحقول الوصفية فقط (merge)، والحالة والحقول الإدارية
///   تبقى كما هي.
/// - يعيد `true` عند النجاح حتى تُعيد الشاشة السابقة القراءة.
///
/// الحدود مطابقة لـ`firestore.rules`: الطول الأقصى للاسم 80، والنبذة 300،
/// والمحافظة 40، والحي 60 — فالرفض يحدث هنا أولًا برسالة عربية مفهومة.
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
                      load: () => AppServicesScope.of(
                        context,
                      ).teachers.findMine(teacherId),
                      builder:
                          (BuildContext context, TeacherProfile? profile) {
                            // لا ملف ⇒ نموذج إنشاء بقيم مبدئية من الحساب.
                            return _ProfileForm(
                              teacherId: teacherId,
                              initial: profile == null
                                  ? null
                                  : TeacherProfileDraft.fromProfile(profile),
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
    required this.initial,
    required this.initialName,
  });

  final String teacherId;

  /// `null` = إنشاء ملف جديد.
  final TeacherProfileDraft? initial;

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

  /// (P19) المادة والمرحلة والمحافظة صارت **اختيارًا من قائمة معتمدة** لا
  /// نصًا حرًا: قيمة واحدة لكل مفهوم، فلا تتفرّق نتائج البحث بين «رياضيات»
  /// و«الرياضيات». تُحفظ كما تُختار، والقيمة القديمة غير المعتمدة تبقى
  /// معروضةً وقابلةً للحفظ حتى يعيد المدرس اختيارها بنفسه.
  String? _subject;
  String? _stage;
  String? _governorate;
  late bool _isOnline;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final TeacherProfileDraft? initial = widget.initial;
    _name = TextEditingController(
      text: initial?.displayName ?? widget.initialName,
    );
    _area = TextEditingController(text: initial?.area ?? '');
    _bio = TextEditingController(text: initial?.bio ?? '');
    _price = TextEditingController(text: initial?.priceHint ?? '');
    _district = TextEditingController(text: initial?.district ?? '');
    _isOnline = initial?.isOnline ?? false;

    // القيم المحفوظة تُحمَّل كما هي حتى لو لم تعد في القائمة المعتمدة.
    _subject = _blankToNull(initial?.subject);
    _stage = _blankToNull(initial?.stage);
    _governorate = _blankToNull(initial?.governorate);
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _bio.dispose();
    _price.dispose();
    _district.dispose();
    super.dispose();
  }

  static String? _blankToNull(String? raw) {
    final String text = (raw ?? '').trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      AppSnackBar.show(
        context,
        'راجع الحقول المطلوبة قبل الحفظ.',
        type: AppMessageType.warning,
      );
      return;
    }

    final TeacherProfileDraft draft = TeacherProfileDraft(
      displayName: _name.text,
      subject: _subject ?? '',
      stage: _stage ?? '',
      area: _area.text,
      bio: _bio.text,
      isOnline: _isOnline,
      priceHint: _price.text,
      governorate: _isOnline ? null : _governorate,
      district: _isOnline ? null : _district.text,
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
      AppSnackBar.show(
        context,
        isDemo
            ? 'حُفظ الملف لهذه الجولة فقط — أنشئ حسابًا ليظهر للطلاب.'
            : widget.initial == null
            ? 'أُنشئ ملفك وأُرسل للمراجعة. سيظهر للطلاب بعد التوثيق.'
            : 'حُفظت التعديلات. تبقى حالة التوثيق كما هي.',
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
    final bool isNew = widget.initial == null;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (isNew) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const InfoNote(
              text:
                  'لا يوجد ملف تعريفي بعد. املأ الحقول التالية ليُنشأ ملفك '
                  'بحالة «قيد المراجعة»، ويظهر للطلاب بعد توثيق الإدارة.',
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const Key('profile-name'),
            controller: _name,
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
          // (P19) قائمة منسدلة بدل نص حر: قيمة واحدة لكل مادة.
          AppSelectField(
            key: const Key('profile-subject'),
            label: 'المادة',
            value: _subject,
            options: AcademicOptions.subjects,
            isRequired: true,
            helperText: 'من قائمة معتمدة حتى تتوافق نتائج البحث',
            onChanged: (String? next) => setState(() => _subject = next),
            validator: (String? value) => _required(value, 'المادة'),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSelectField(
            key: const Key('profile-stage'),
            label: 'المرحلة الدراسية',
            value: _stage,
            options: AcademicOptions.stages,
            isRequired: true,
            onChanged: (String? next) => setState(() => _stage = next),
            validator: (String? value) => _required(value, 'المرحلة'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            key: const Key('profile-area'),
            controller: _area,
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
            value: _isOnline,
            onChanged: (bool value) => setState(() => _isOnline = value),
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
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'سعر استرشادي (اختياري)',
              helperText: 'نص حر — الدفع خارج التطبيق',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('profile-save'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isNew ? 'إنشاء الملف' : 'حفظ'),
          ),
          const SizedBox(height: AppSpacing.sm),
          const InfoNote(
            text:
                'يُحفظ الملف في `teacherProfiles` ويبقى «قيد المراجعة» حتى '
                'توثّقه الإدارة. التمييز في الصفحة الرئيسية قرار إداري لا '
                'يُضبط من هنا.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
