import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/admin_rules.dart';

/// قرار التوثيق في مكان واحد (P19).
///
/// **لماذا ملف مشترك؟** نفس القرار يظهر في «طابور التوثيق» وفي «لوحة الإدارة»
/// (قائمة سريعة). نسخ المنطق في مكانين يعني أن يتباعدا: رسالة مختلفة، أو
/// معالجة خطأ مختلفة، أو — الأسوأ — رفض بلا سبب في أحد المكانين فقط.
///
/// كل دالة تعيد `true` عند نجاح الكتابة، فيقرر المنادي إعادة القراءة.
/// الأخطاء تُعرض هنا برسالة عربية وتُعاد `false`، فلا يحتاج المنادي إلى
/// `try/catch` مكرر.
///
/// ⚠️ **الصلاحية ليست هنا**: هذه الدوال تطلب من المستودع، و`firestore.rules`
/// هي التي تفحص الادعاء الإداري. لو نُودِيت من حساب عادي لرفض الخادم وظهرت
/// رسالة صلاحيات عربية.

/// يوافق على ملف: `pendingReview`/`draft` ← `verified`.
Future<bool> approveTeacherProfile(
  BuildContext context,
  TeacherProfile profile,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    await AppServicesScope.of(context).admin.verifyTeacher(profile.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('تم توثيق «${profile.displayName}» — ظاهر الآن في البحث.'),
      ),
    );
    return true;
  } on Object catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(toAppException(error).message)),
    );
    return false;
  }
}

/// يرفض ملفًا بسبب مكتوب (يلزم سبب: يظهر للمدرس).
///
/// يعيد `true` فقط إذا كتب المستخدم سببًا صالحًا ونجحت الكتابة. إلغاء الحوار
/// يعيد `false` بلا أي رسالة — الإلغاء ليس خطأً.
Future<bool> rejectTeacherProfile(
  BuildContext context,
  TeacherProfile profile,
) async {
  final String? reason = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => _RejectDialog(profile: profile),
  );
  if (reason == null || !context.mounted) {
    return false;
  }

  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    await AppServicesScope.of(
      context,
    ).admin.rejectTeacher(teacherId: profile.id, reason: reason);
    messenger.showSnackBar(
      SnackBar(
        content: Text('تم رفض «${profile.displayName}» وإبلاغ السبب.'),
      ),
    );
    return true;
  } on Object catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(toAppException(error).message)),
    );
    return false;
  }
}

/// حوار سبب الرفض — يمنع الإرسال قبل كتابة سبب صالح الطول.
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
    final String reason = _controller.text.trim();
    final String? problem = AdminRules.reasonProblem(reason);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(reason);
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
            key: const Key('verification-reject-reason'),
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
