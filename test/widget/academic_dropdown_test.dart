import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/app_select_field.dart';
import 'package:teacher_student_app/data/constants/academic_options.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/teacher/presentation/edit_teacher_profile_screen.dart';

import '../helpers/avatar_helpers.dart';
import '../helpers/test_app.dart';

/// (P19) القوائم المنسدلة: المادة والمرحلة والمحافظة.
///
/// نختبر ثلاث دعاوى:
/// 1. الحقل نفسه لا ينكسر مع قيمة قديمة غير معتمدة (ولا يمحوها).
/// 2. النموذج الحقيقي يعرض القوائم الثلاث (لا حقول نص حر).
/// 3. الاختيار يُحفظ فعلًا في `teacherProfiles/{uid}` عبر نفس المستودع.
Widget _host(Widget child, AppServices services, SessionController session) {
  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(theme: AppTheme.light, home: child),
      ),
    ),
  );
}

/// يختار قيمة من قائمة منسدلة عبر **معالجها** لا عبر نقرة على عنصر القائمة.
///
/// سببان مقيسان على CI (لا نظريان):
/// 1. قائمة من 27 محافظة تُبنى عناصرها بتكاسل داخل قائمة قابلة للتمرير، فالعنصر
///    المطلوب قد لا يكون موجودًا في الشجرة أصلًا ⇒ `find.text(...)` يعيد صفرًا
///    و`tap` يرمي `Bad state: No element`.
/// 2. النقر على العنصر يعتمد على هندسة الموضع والتمرير، وقد يضيع بلا فشل صريح
///    (نفس درس أزرار الحفظ في P19).
/// استدعاء `onChanged` الذي يبنيه `DropdownButtonFormField` يُحدّث **حالة
/// النموذج** (`didChange`) وحالة الأب معًا، فيقيس السلوك الحقيقي: التحقق والحفظ.
Future<void> _pick(WidgetTester tester, Key field, String value) async {
  await tester.ensureVisible(find.byKey(field));
  await tester.pumpAndSettle();

  final DropdownButton<String> button = tester.widget<DropdownButton<String>>(
    find.descendant(
      of: find.byKey(field),
      matching: find.byType(DropdownButton<String>),
    ),
  );

  // كل قيمة نطلبها يجب أن تكون خيارًا معروضًا فعلًا (لا اختيار وهمي).
  final bool offered = button.items!.any(
    (DropdownMenuItem<String> item) => item.value == value,
  );
  expect(offered, isTrue, reason: 'الخيار «$value» غير معروض في القائمة');

  button.onChanged!(value);
  await tester.pumpAndSettle();
}

void main() {
  group('AppSelectField — الحقل نفسه', () {
    testWidgets('قيمة قديمة غير معتمدة تظهر كخيار إضافي لا كخطأ', (
      WidgetTester tester,
    ) async {
      String? value = 'الرياضيات — التفاضل';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return AppSelectField(
                    key: const Key('field'),
                    label: 'المادة',
                    value: value,
                    options: AcademicOptions.subjects,
                    isRequired: true,
                    onChanged: (String? next) => setState(() => value = next),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // لا استثناء: القيمة القديمة معروضة وموسومة.
      expect(
        find.text('الرياضيات — التفاضل (قيمة محفوظة سابقًا)'),
        findsOneWidget,
      );

      // ويستطيع صاحبها اختيار قيمة معتمدة بدلًا منها.
      await _pick(tester, const Key('field'), 'الفيزياء');
      expect(value, 'الفيزياء');
    });

    testWidgets('الحقل المطلوب الفارغ يفشل في التحقق برسالة عربية', (
      WidgetTester tester,
    ) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: Form(
                key: formKey,
                child: AppSelectField(
                  key: const Key('field'),
                  label: 'المرحلة الدراسية',
                  value: null,
                  options: AcademicOptions.stages,
                  isRequired: true,
                  onChanged: (String? _) {},
                  validator: (String? value) =>
                      (value ?? '').trim().isEmpty ? 'المرحلة مطلوبة' : null,
                ),
              ),
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('المرحلة مطلوبة'), findsOneWidget);
    });

    testWidgets('الحقل الاختياري يعرض «بدون تحديد» ويعيد null لا نصًا فارغًا', (
      WidgetTester tester,
    ) async {
      String? value = 'القاهرة';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return AppSelectField(
                    key: const Key('field'),
                    label: 'المحافظة',
                    value: value,
                    options: AcademicOptions.governorates,
                    onChanged: (String? next) => setState(() => value = next),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // «بدون تحديد» قيمتها `''` في عناصر القائمة (العناصر لا تقبل null).
      await _pick(tester, const Key('field'), '');

      // `null` هي «بلا اختيار»، فتكتب القواعد غياب الحقل لا سلسلة فارغة.
      expect(value, isNull);
    });
  });

  group('نموذج ملف المدرس — قوائم لا نص حر', () {
    testWidgets('يعرض القوائم الثلاث ويحفظ الاختيار في المستودع', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      // (P22) الملف التجريبي موثّق ويحتاج صورة قبل الحفظ.
      await seedAvatar(services, 'demo-teacher-1');
      final SessionController session = SessionController(services.auth)
        ..startDemoSession(UserRole.teacher);

      await tester.pumpWidget(
        _host(const EditTeacherProfileScreen(), services, session),
      );
      await tester.pumpAndSettle();

      // الحقول الثلاثة موجودة كقوائم منسدلة (لا `TextFormField`).
      expect(find.byKey(const Key('profile-subject')), findsOneWidget);
      expect(find.byKey(const Key('profile-stage')), findsOneWidget);
      expect(find.byKey(const Key('profile-governorate')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('profile-subject')),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
        findsOneWidget,
      );

      // القيمة الحالية للملف التجريبي معتمدة، فتظهر محدَّدة لا فارغة.
      expect(find.text('الرياضيات'), findsWidgets);
      expect(find.text('الثانوية العامة'), findsWidgets);

      await _pick(tester, const Key('profile-subject'), 'الفيزياء');
      await _pick(tester, const Key('profile-stage'), 'الجامعة');
      await _pick(tester, const Key('profile-governorate'), 'الفيوم');

      await pressProfileSave(tester);

      final TeacherProfile? saved = await services.teachers.findMine(
        'demo-teacher-1',
      );
      expect(saved, isNotNull);
      expect(saved!.subject, 'الفيزياء');
      expect(saved.stage, 'الجامعة');
      expect(saved.governorate, 'الفيوم');
    });

    testWidgets('القيم المعتمدة فقط تُكتب: لا نص حر يُدخل يدويًا', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      await seedAvatar(services, 'demo-teacher-1');
      final SessionController session = SessionController(services.auth)
        ..startDemoSession(UserRole.teacher);

      await tester.pumpWidget(
        _host(const EditTeacherProfileScreen(), services, session),
      );
      await tester.pumpAndSettle();

      await _pick(tester, const Key('profile-subject'), 'الكيمياء');
      await pressProfileSave(tester);

      final TeacherProfile? saved = await services.teachers.findMine(
        'demo-teacher-1',
      );
      expect(saved, isNotNull);
      expect(
        AcademicOptions.isKnownSubject(saved!.subject),
        isTrue,
        reason: 'ما يُحفظ يجب أن يكون من القائمة المعتمدة',
      );
    });
  });
}
