import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/data/validation/account_deletion_rules.dart';

/// مفاتيح ثابتة لعناصر حوار الحذف — تُستخدم في الاختبارات بدل الاعتماد على
/// وجود نص واحد فقط (العنوان والنص يظهران في الشاشة أيضًا).
abstract final class AccountDeletionKeys {
  static const Key dialog = Key('account-deletion-dialog');
  static const Key cancel = Key('account-deletion-cancel');
  static const Key confirm = Key('account-deletion-confirm');

  static const Key signOutDialog = Key('sign-out-dialog');
  static const Key signOutCancel = Key('sign-out-cancel');
  static const Key signOutConfirm = Key('sign-out-confirm');
}

/// يحوّل «تأكيد الحذف» إلى نتيجة منطقية.
///
/// الحوار يشرح مهلـة السماح قبل الكتابة: الطلب لا يحذف شيئًا الآن، بل يخفي
/// الحساب ويبدأ مهلة 7 أيام. نُعيد `false` بدل رمي استثناء عند الإلغاء حتى
/// تبقى الشاشة قادرة على تجاهل النتيجة بسهولة.
Future<bool> confirmAccountDeletion(
  BuildContext context, {
  DateTime? now,
}) async {
  final DateTime scheduledAt = AccountDeletionRules.scheduledAt(
    now ?? DateTime.now(),
  );

  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      key: AccountDeletionKeys.dialog,
      icon: Icon(
        Icons.delete_forever_outlined,
        color: Theme.of(dialogContext).colorScheme.error,
      ),
      title: const Text(AccountDeletionRules.deleteTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              AccountDeletionRules.deleteWarning(scheduledAt),
              style: Theme.of(
                dialogContext,
              ).textTheme.bodyMedium?.copyWith(height: 1.7),
            ),
            const SizedBox(height: AppSpacing.md),
            const InfoNote(
              text: AccountDeletionRules.deleteNotice,
              icon: Icons.hourglass_bottom,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: AccountDeletionKeys.cancel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(AccountDeletionRules.cancelAction),
        ),
        FilledButton(
          key: AccountDeletionKeys.confirm,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(AccountDeletionRules.deleteAction),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

/// تأكيد تسجيل الخروج (P17).
///
/// قرار واعٍ: الخروج ليس إجراءً مدمّرًا، لكنه على جهاز مشترك يقطع الوصول إلى
/// الحساب، ولذلك نطلب تأكيدًا واحدًا بلا تعقيد.
Future<bool> confirmSignOut(BuildContext context) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      key: AccountDeletionKeys.signOutDialog,
      icon: const Icon(Icons.logout),
      title: const Text(AccountDeletionRules.signOutAction),
      content: const Text(
        'ستحتاج إلى تسجيل الدخول مرة أخرى للوصول إلى حسابك. '
        'بياناتك تبقى كما هي.',
      ),
      actions: <Widget>[
        TextButton(
          key: AccountDeletionKeys.signOutCancel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(AccountDeletionRules.cancelAction),
        ),
        FilledButton(
          key: AccountDeletionKeys.signOutConfirm,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('نعم، خروج'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
