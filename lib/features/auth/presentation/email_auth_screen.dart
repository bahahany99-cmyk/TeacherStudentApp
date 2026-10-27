import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/features/auth/presentation/auth_flow.dart';

/// الدخول وإنشاء حساب بالبريد الإلكتروني وكلمة المرور.
///
/// - الوضعان في شاشة واحدة (تبويب) لتقليل التنقل.
/// - التحقق المحلي يحدث قبل النداء حتى لا نُرسل طلبات مضمونة الرفض.
/// - أخطاء Firebase تُعرض عربية عبر `AppException` (لا رموز إنجليزية).
/// - كلمة المرور لا تُسجَّل ولا تُحفظ في أي مكان.
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key, this.startInRegisterMode = false});

  final bool startInRegisterMode;

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  late bool _registerMode = widget.startInRegisterMode;
  bool _busy = false;
  bool _obscure = true;

  /// آخر خطأ من الخادم — يُعرض داخل الصفحة لا في تنبيه عابر.
  ///
  /// السبب: فشل تسجيل الدخول يحتاج أن يبقى أمام المستخدم أثناء تصحيح البيانات،
  /// ولأن التنبيه العابر قد يختفي قبل أن يقرأه.
  AppException? _failure;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final SessionController session = SessionScope.read(context);
    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      if (_registerMode) {
        await session.registerWithEmail(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
      } else {
        await session.signInWithEmail(
          email: _email.text,
          password: _password.text,
        );
      }

      if (!mounted) {
        return;
      }
      await continueAfterAuth(context, session);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _failure = toAppException(error);
      });
    }
  }

  String? _validateEmail(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'البريد الإلكتروني مطلوب';
    }
    if (!text.contains('@') || text.endsWith('@') || text.length < 6) {
      return 'صيغة البريد غير صحيحة';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final String text = value ?? '';
    if (text.isEmpty) {
      return 'كلمة المرور مطلوبة';
    }
    if (text.length < 6) {
      return 'كلمة المرور 6 أحرف على الأقل';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (!_registerMode) {
      return null;
    }
    final String text = (value ?? '').trim();
    if (text.length < 3) {
      return 'الاسم 3 أحرف على الأقل';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (!_registerMode) {
      return null;
    }
    if ((value ?? '') != _password.text) {
      return 'كلمتا المرور غير متطابقتين';
    }
    return null;
  }

  void _switchMode(bool register) {
    if (_busy || register == _registerMode) {
      return;
    }
    setState(() {
      _registerMode = register;
      _failure = null;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
        // شفاف لعرض تدرّج الخلفية العالمي (نسخة 3).
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_registerMode ? 'إنشاء حساب' : 'تسجيل الدخول'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              ResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<bool>(
                      segments: const <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('لدي حساب'),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('حساب جديد'),
                        ),
                      ],
                      selected: <bool>{_registerMode},
                      onSelectionChanged: (Set<bool> selection) =>
                          _switchMode(selection.first),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_registerMode) ...<Widget>[
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل',
                          helperText: 'يظهر للمدرسين أو الطلاب لاحقًا',
                        ),
                        validator: _validateName,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                          tooltip: _obscure ? 'إظهار' : 'إخفاء',
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    if (_registerMode) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _confirm,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'تأكيد كلمة المرور',
                        ),
                        validator: _validateConfirm,
                      ),
                    ],
                    if (_failure != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      _FailureCard(failure: _failure!),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            )
                          : Text(
                              _registerMode ? 'إنشاء الحساب' : 'دخول',
                            ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _registerMode
                          ? 'ستختار بعد إنشاء الحساب إن كنت طالبًا أم مدرسًا.'
                          : 'بعد الدخول، يُقرأ نوع حسابك من الخادم.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const InfoNote(
                      text:
                          'لا نحفظ كلمة المرور في التطبيق، ولا نطلب أي بيانات '
                          'إضافية. إعادة تعيين كلمة المرور عبر البريد ستُضاف '
                          'لاحقًا (تحتاج قوالب بريد المشروع).',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صندوق خطأ ثابت داخل النموذج (لا يختفي تلقائيًا).
class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.failure});

  final AppException failure;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            size: 20,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  failure.title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  failure.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
