import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// نموذج تعديل معلومات الملف — **عرض فقط، لا يحفظ**.
///
/// الغرض في هذه المرحلة: تثبيت شكل النموذج وقواعد التحقق (طول الاسم، النبذة،
/// السعر) قبل بناء الحفظ الفعلي. بعد الضغط على «حفظ» نتحقق ثم نقول الحقيقة:
/// لم يُرسل شيء إلى أي خادم.
///
/// سبب مهم: لا نكتب قيمة محلية ونعرضها لاحقًا كأنها محفوظة، لأن ذلك يعطي
/// انطباعًا خاطئًا بأن التعديل نُفِّذ.
class EditTeacherProfileScreen extends StatelessWidget {
  const EditTeacherProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل المعلومات')),
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
                  message: 'لا يمكن تعديل ملف غير موجود.',
                ),
                builder: (BuildContext context, TeacherProfile? profile) {
                  if (profile == null) {
                    return const EmptyState(
                      icon: Icons.person_off_outlined,
                      title: 'لا يوجد ملف تعريفي',
                    );
                  }
                  return _EditProfileForm(profile: profile);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileForm extends StatefulWidget {
  const _EditProfileForm({required this.profile});

  final TeacherProfile profile;

  @override
  State<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<_EditProfileForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _subject;
  late final TextEditingController _stage;
  late final TextEditingController _area;
  late final TextEditingController _bio;
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    final TeacherProfile profile = widget.profile;
    _name = TextEditingController(text: profile.displayName);
    _subject = TextEditingController(text: profile.subject);
    _stage = TextEditingController(text: profile.stage);
    _area = TextEditingController(text: profile.area);
    _bio = TextEditingController(text: profile.bio);
    _price = TextEditingController(text: profile.priceHint ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _subject.dispose();
    _stage.dispose();
    _area.dispose();
    _bio.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      AppSnackBar.show(
        context,
        'راجع الحقول المطلوبة قبل الحفظ.',
        type: AppMessageType.warning,
      );
      return;
    }

    AppSnackBar.show(
      context,
      'لم يُحفظ شيء: النموذج للعرض فقط في هذه المرحلة، والحفظ على الخادم '
      'سيُضاف لاحقًا.',
      type: AppMessageType.info,
    );
  }

  String? _required(String? value, String label) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return '$label مطلوب';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const DemoBanner(),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
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
              if ((value ?? '').trim().length < 3) {
                return 'الاسم قصير جدًا (3 أحرف على الأقل)';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _subject,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'المادة'),
            validator: (String? value) => _required(value, 'المادة'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _stage,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'المرحلة الدراسية'),
            validator: (String? value) => _required(value, 'المرحلة'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _area,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'المنطقة'),
            validator: (String? value) => _required(value, 'المنطقة'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
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
            controller: _price,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'سعر استرشادي (اختياري)',
              helperText: 'نص حر — الدفع خارج التطبيق',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: _save, child: const Text('حفظ')),
          const SizedBox(height: AppSpacing.sm),
          const InfoNote(
            text:
                'لا يُرسل هذا النموذج أي بيانات، ولا يُحدَّث الملف بعد الحفظ. '
                'وجوده الآن لتثبيت الحقول وقواعد التحقق قبل ربط Firestore.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
