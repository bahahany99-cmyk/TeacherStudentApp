import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/config/app_identity.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';

/// «المساعدة والدعم» (P18).
///
/// **لماذا محتوى ثابت لا نموذج إرسال؟** لأن إرسال تذكرة يحتاج خادمًا (دالة
/// سحابية أو صندوق بريد) غير موجود بعد. نعرض ما **يعمل فعلًا**: قنوات
/// التواصل، وأسئلة شائعة تجيب عن أكثر ما يسأل عنه المستخدم داخل التطبيق.
/// إظهار زر «أرسل» بلا خادم سيكون وعدًا كاذبًا — وهو بالضبط ما نُزيله.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  /// بريد الدعم — يُقرأ من هوية التطبيق حتى لا يتكرر في أكثر من مكان.
  static const String supportEmail = 'support@darsly.app';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('المساعدة والدعم')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SectionHeader(
                    title: 'كيف نساعدك؟',
                    subtitle: 'إجابات سريعة لأكثر ما يُسأل عنه',
                    icon: Icons.help_outline,
                  ),
                  // ثابت بالكامل: نصوص فقط، فلا يُعاد بناؤه مع كل إطار.
                  const AppCard(
                    child: Column(
                      children: <Widget>[
                        _FaqTile(
                          question: 'كيف أحجز حصة مع مدرس؟',
                          answer:
                              'من قسم «المدرسون» افتح ملف المدرس، ثم اضغط '
                              '«احجز حصة» واختر الوقت المناسب. يصل الطلب إلى '
                              'المدرس ويظهر في «الحجوزات» بحالته.',
                        ),
                        _FaqTile(
                          question: 'كيف أنشئ مجموعة دراسية؟',
                          answer:
                              'المدرس: من «مجموعاتي» اضغط «مجموعة جديدة» وحدّد '
                              'العنوان والمادة والمرحلة والسعة والموعد.',
                        ),
                        _FaqTile(
                          question: 'لماذا لا يظهر ملفي للطلاب؟',
                          answer:
                              'ملف المدرس يظهر بعد توثيق الإدارة. بعد الحفظ '
                              'تكون حالته «قيد المراجعة» حتى يُراجع.',
                        ),
                        _FaqTile(
                          question: 'كيف أحذف حسابي؟',
                          answer:
                              'من «حسابي» ← «حذف الحساب». يُجدول الحذف بعد '
                              '7 أيام ويمكنك التراجع خلالها من شاشة الاستعادة.',
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const SectionHeader(
                    title: 'تواصل معنا',
                    icon: Icons.mail_outline,
                  ),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SelectableText(
                          supportEmail,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'نرد خلال يوم عمل. اذكر بريد حسابك ونوع الحساب '
                          '(طالب/مدرس) لتسريع المتابعة.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${AppIdentity.displayName} · ${AppIdentity.tagline}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.question,
    required this.answer,
    this.isLast = false,
  });

  final String question;
  final String answer;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Theme(
          // إزالة خطوط التوسيع الافتراضية حتى لا يبدو القسم كجدول إعدادات.
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
            title: Text(
              question,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            children: <Widget>[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  answer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.7,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}

/// «الشروط وسياسة الخصوصية» (P18) — نص السياسة الفعلي، لا زر معطّل.
///
/// المحتوى يطابق ما يفعله التطبيق فعلًا (ما نجمعه، وأين يُخزَّن، ومن يراه).
/// أي بند لا يمكن الوفاء به يُحذف بدل أن يُكتب للشكل.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const List<(String, String)> _sections = <(String, String)>[
    (
      'ما نجمعه',
      'الاسم الظاهر والبريد من حساب Google أو من تسجيل البريد، ونوع الحساب '
          '(طالب/مدرس)، والهاتف والمرحلة إن أدخلتهما، وبيانات الاستخدام داخل '
          'التطبيق (حجوزات، مجموعات، رسائل، تقييمات).',
    ),
    (
      'لماذا نجمعه',
      'لتشغيل الخدمة: عرض المدرسين، وإتمام الحجز، وإدارة المجموعات، وتسليم '
          'الرسائل والإشعارات، وحماية الحساب من إساءة الاستخدام.',
    ),
    (
      'من يرى ماذا',
      'ملف المدرس الموثّق يراه كل المستخدمين. بيانات حسابك (البريد/الهاتف) '
          'يراها صاحب الحساب والإدارة فقط. رسائلك يراها طرف المحادثة فقط. '
          'أسماء أعضاء المجموعة يراها أعضاء المجموعة والمدرس.',
    ),
    (
      'أين تُخزَّن',
      'على Google Firebase (Firestore وAuthentication). الاتصال مشفّر، '
          'والوصول محكوم بقواعد أمان على الخادم لا يمكن تجاوزها من التطبيق.',
    ),
    (
      'حذف الحساب',
      'طلب الحذف من «حسابي» يخفي ملفك من البحث فورًا ويُجدول الحذف بعد 7 أيام، '
          'ويمكنك التراجع خلالها. بعد انتهاء المهلة يُحذف الحساب وبياناته '
          'المرتبطة به.',
    ),
    (
      'حقوقك',
      'يمكنك تعديل بياناتك أو حذف حسابك في أي وقت من داخل التطبيق، أو '
          'بمراسلة الدعم.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('الشروط وسياسة الخصوصية')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final (String title, String body) in _sections) ...<Widget>[
                    SectionHeader(title: title),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.8,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
