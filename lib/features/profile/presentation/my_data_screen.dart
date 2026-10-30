import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/validation/profile_rules.dart';

/// «بياناتي» (P18): عرض وتعديل بيانات الحساب الأساسية.
///
/// **ماذا يكتب؟** `users/{uid}` فقط: الاسم الظاهر، الهاتف، المرحلة. لا يمسّ
/// الدور ولا حالة الحساب — والقواعد ترفض أي تغيير فيهما أصلًا.
///
/// **الترتيب الصادق:** الكتابة على الخادم أولًا ثم تحديث الجلسة
/// (`SessionController.updatePersonalInfo`)، فلا تُعرض قيمة لم تُحفظ.
class MyDataScreen extends StatefulWidget {
  const MyDataScreen({super.key});

  @override
  State<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends State<MyDataScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _stage;

  bool _saving = false;

  /// تُقرأ مرة واحدة في `didChangeDependencies` حتى لا يُعاد ضبط الحقول
  /// أثناء الكتابة عند أي إعادة بناء.
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) {
      return;
    }
    _initialised = true;
    final AppUser? user = SessionScope.read(context).user;
    _name = TextEditingController(text: user?.displayName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _stage = TextEditingController(text: user?.stage ?? '');
  }

  @override
  void dispose() {
    if (_initialised) {
      _name.dispose();
      _phone.dispose();
      _stage.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      AppSnackBar.show(
        context,
        'راجع الحقول قبل الحفظ.',
        type: AppMessageType.warning,
      );
      return;
    }

    final SessionController session = SessionScope.read(context);
    setState(() => _saving = true);
    try {
      await session.updatePersonalInfo(
        displayName: _name.text,
        phone: _phone.text,
        stage: _stage.text,
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        session.isDemoSession
            ? 'حُفظت البيانات لهذه الجولة فقط — أنشئ حسابًا لحفظها دائمًا.'
            : 'حُفظت بياناتك.',
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppUser? user = SessionScope.of(context).user;

    return Scaffold(
      // شفاف لعرض تدرّج الخلفية العالمي.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('بياناتي')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const Key('my-data-name'),
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الظاهر',
                        helperText: 'يظهر للمدرسين في الحجوزات والمحادثات',
                      ),
                      validator: ProfileRules.nameProblem,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      key: const Key('my-data-phone'),
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف (اختياري)',
                        helperText: 'للتواصل فقط — لا يُستخدم للدخول',
                      ),
                      validator: ProfileRules.phoneProblem,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      key: const Key('my-data-stage'),
                      controller: _stage,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'المرحلة الدراسية (اختياري)',
                        helperText: 'مثال: الثانوية العامة',
                      ),
                      validator: ProfileRules.stageProblem,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        for (final String suggestion
                            in ProfileRules.stageSuggestions)
                          ActionChip(
                            label: Text(suggestion),
                            onPressed: () =>
                                setState(() => _stage.text = suggestion),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      key: const Key('my-data-save'),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('حفظ التغييرات'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InfoNote(
                      text: user?.email == null
                          ? 'لا يوجد بريد مرتبط بالحساب.'
                          : 'البريد ${user!.email} لا يمكن تغييره من التطبيق؛ '
                                'هو هوية الدخول.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'لا يمكن تغيير نوع الحساب (طالب/مدرس) من هنا: يُحدَّد مرة '
                      'واحدة عند أول دخول، ويمكن تعديله عبر فريق الدعم.', 
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
