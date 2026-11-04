import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// زر «المتابعة باستخدام Google» بالشكل المعتمد من Google (P18).
///
/// لماذا زر مخصّص بدل `FilledButton.icon`؟
/// - العلامة التجارية لـGoogle تفرض شكلًا محددًا: **خلفية بيضاء**، شعار
///   «G» رباعي الألوان الرسمي، حدّ رمادي فاتح، ونص داكن محايد. الزر الوردي
///   السابق كان مخالفًا (استخدام شعار Google على خلفية بلون الهوية).
/// - المواصفات المطبّقة هنا (Branding Guidelines — «Sign in with Google»):
///   * الخلفية `#FFFFFF` والحدّ `#DADCE0`.
///   * الشعار 20×20 (المدى المسموح 18–20 لارتفاع 52) في الطرف الأمامي.
///   * النص `#1F1F1F` بوزن متوسط، بحجم 15، دون كتابة أي شيء غير نص الموافقة.
///   * ارتفاع 52 (الحد الأدنى 40) وحواف دائرية كاملة (أحد الأشكال المسموحة).
/// - لا يُعاد رسم الشعار بـ`Icon` أو حرف «G»: الشعار ملف رسمي (انظر
///   `assets/images/NOTICE.md`).
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'المتابعة باستخدام Google',
  });

  /// العملية نفسها؛ الزر يتولّى منع النقر المزدوج وإظهار مؤشر تقدّم.
  final Future<void> Function() onPressed;

  /// نص الموافقة. الافتراضي «المتابعة باستخدام Google» (Continue with Google).
  final String label;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _handleTap() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      // الشاشة قد تكون أُغلقت بعد نجاح الدخول؛ الفحص قبل setState.
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      button: true,
      label: widget.label,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: InkWell(
          onTap: _busy ? null : _handleTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: Container(
            height: AppSpacing.buttonHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(color: const Color(0xFFDADCE0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (_busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else
                  Image.asset(
                    'assets/images/google_g.png',
                    width: 20,
                    height: 20,
                    filterQuality: FilterQuality.high,
                    // الأصل زخرفي: النص المجاور يحمل المعنى لقارئ الشاشة.
                    excludeFromSemantics: true,
                    // لو تعذّر تحميل الأصل (بناء بلا assets) لا نُسقط الشاشة:
                    // يظهر الزر بنصه فقط، ويُكتشف النقص من الاختبارات.
                    errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                        const SizedBox.shrink(),
                  ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF1F1F1F),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
