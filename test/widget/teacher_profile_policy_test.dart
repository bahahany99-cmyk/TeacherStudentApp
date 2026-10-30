import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/constants/academic_options.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/image_picker_gateway.dart';
import 'package:teacher_student_app/features/teacher/presentation/edit_teacher_profile_screen.dart';

import '../helpers/avatar_helpers.dart';
import '../helpers/test_app.dart';

/// (P22) سياسة تعديل ملف المدرس **من الواجهة**:
/// 1. القفل الكامل أثناء المراجعة + إشعار صريح.
/// 2. تعديل ملف موثّق يمرّ بتأكيد، ثم يعيد الحالة إلى `pendingReview`.
/// 3. المادة/المرحلة المخصّصتان («أخرى») تُحفظان وتُعادان بلا أخطاء تحقق.
/// 4. لا حفظ بلا صورة.
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

/// يهيّئ مدرسًا بملف ذي حالة محددة، ويعيد الحزمة والجلسة.
///
/// نستخدم `DemoTeacherRepository` على قائمة **محلية**: الملف الذي نضبط حالته
/// هو نفسه الذي يقرأه النموذج، فلا نعتمد على حالة بيانات تجريبية قد تتغيّر.
({AppServices services, SessionController session, List<TeacherProfile> source})
_teacherWith(TeacherProfileStatus status, {bool withPhoto = true}) {
  final List<TeacherProfile> source = <TeacherProfile>[
    TeacherProfile(
      id: 'teacher-1',
      displayName: 'أ. سارة الخطيب',
      subject: 'الرياضيات',
      stage: 'الثانوية العامة',
      area: 'المعادي',
      bio: 'شرح مبسّط للجبر والتفاضل مع تدريبات محلولة بعد كل حصة.',
      status: status,
      governorate: 'القاهرة',
      photoPath: withPhoto ? TeacherProfile.photoPathFor('teacher-1') : null,
    ),
  ];

  final AppServices demo = AppServices.demo();
  final AppServices services = AppServices(
    auth: demo.auth,
    teachers: DemoTeacherRepository(source: source),
    groups: demo.groups,
    bookings: demo.bookings,
    schedules: demo.schedules,
    messages: demo.messages,
    chats: demo.chats,
    notifications: demo.notifications,
    reviews: demo.reviews,
    favorites: demo.favorites,
    admin: demo.admin,
    avatars: demo.avatars,
    imagePicker: FakeImagePickerGateway(
      result: PickedImage(
        bytes: tinyPngBytes(),
        mimeType: 'image/png',
      ),
    ),
  );

  return (
    services: services,
    session: SessionController(services.auth)..startDemoSession(UserRole.teacher),
    source: source,
  );
}

void main() {
  group('(P22) القفل أثناء المراجعة', () {
    testWidgets('كل الحقول معطّلة، ولا زر حفظ، مع إشعار واضح', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final ({AppServices services, SessionController session, List<TeacherProfile> source})
      bundle = _teacherWith(TeacherProfileStatus.pendingReview);

      await tester.pumpWidget(
        _host(const EditTeacherProfileScreen(), bundle.services, bundle.session),
      );
      await tester.pumpAndSettle();

      // إشعار القفل ظاهر.
      expect(find.byKey(const Key('profile-locked-notice')), findsOneWidget);
      expect(find.textContaining('قيد المراجعة'), findsWidgets);

      // لا زر حفظ إطلاقًا: لا «زر معطّل» يوحي بإمكانية التعديل.
      expect(find.byKey(const Key('profile-save')), findsNothing);

      // الحقول الأساسية معطّلة.
      for (final String key in <String>[
        'profile-name',
        'profile-area',
        'profile-bio',
        'profile-price',
      ]) {
        final TextFormField field = tester.widget<TextFormField>(
          find.byKey(Key(key)),
        );
        expect(field.enabled, isFalse, reason: 'الحقل $key يجب أن يكون معطّلًا');
      }

      // محرّر الصورة للعرض فقط (لا اختيار صورة أثناء المراجعة).
      expect(find.byKey(const Key('avatar-pick')), findsNothing);
      expect(find.byKey(const Key('avatar-preview')), findsOneWidget);
    });
  });

  group('(P22) إعادة التحقق عند تعديل ملف موثّق', () {
    testWidgets('إلغاء التأكيد لا يحفظ شيئًا', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final ({AppServices services, SessionController session, List<TeacherProfile> source})
      bundle = _teacherWith(TeacherProfileStatus.verified);
      await seedAvatar(bundle.services, 'teacher-1');

      await tester.pumpWidget(
        _host(const EditTeacherProfileScreen(), bundle.services, bundle.session),
      );
      await tester.pumpAndSettle();

      // إشعار سياسة إعادة التحقق قبل أي محاولة حفظ.
      expect(find.byKey(const Key('profile-reverify-notice')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('profile-name')),
        'أ. سارة — محاولة ملغاة',
      );

      final FilledButton save = tester.widget<FilledButton>(
        find.byKey(const Key('profile-save')),
      );
      save.onPressed!();
      await tester.pumpAndSettle();

      // الحوار ظاهر، ونلغي.
      expect(find.byKey(const Key('profile-reverify-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile-reverify-cancel')));
      await tester.pumpAndSettle();

      // لم تُكتب أي قيمة، والملف ما زال موثّقًا.
      expect(bundle.source.single.displayName, 'أ. سارة الخطيب');
      expect(bundle.source.single.status, TeacherProfileStatus.verified);
    });

    testWidgets('المتابعة تحفظ ويعود الملف إلى المراجعة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final ({AppServices services, SessionController session, List<TeacherProfile> source})
      bundle = _teacherWith(TeacherProfileStatus.verified);
      await seedAvatar(bundle.services, 'teacher-1');

      await tester.pumpWidget(
        _host(const EditTeacherProfileScreen(), bundle.services, bundle.session),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('profile-name')),
        'أ. سارة الخطيب — محدَّث',
      );
      await pressProfileSave(tester);

      expect(bundle.source.single.displayName, 'أ. سارة الخطيب — محدَّث');
      expect(bundle.source.single.status, TeacherProfileStatus.pendingReview);
      expect(bundle.source.single.isVisibleToStudents, isFalse);
      // الصورة باقية في الملف بعد التعديل.
      expect(bundle.source.single.hasPhoto, isTrue);
    });
  });

  group('(P22) المادة والمرحلة المخصّصتان', () {
    testWidgets('«أخرى» يفتح حقل نص، ويُحفظ النص لا القيمة الحارسة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final ({AppServices services, SessionController session, List<TeacherProfile> source})
      bundle = _teacherWith(TeacherProfileStatus.draft);
      await seedAvatar(bundle.services, 'teacher-1');

      await tester.pumpWidget(
        _host(const EditTeacherProfileScreen(), bundle.services, bundle.session),
      );
      await tester.pumpAndSettle();

      // الحقل النصي لا يظهر قبل اختيار «أخرى».
      expect(find.byKey(const Key('profile-subject-custom')), findsNothing);

      await _pick(
        tester,
        const Key('profile-subject'),
        AcademicOptions.customOption,
      );
      expect(find.byKey(const Key('profile-subject-custom')), findsOneWidget);

      await _pick(
        tester,
        const Key('profile-stage'),
        AcademicOptions.customOption,
      );
      expect(find.byKey(const Key('profile-stage-custom')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('profile-subject-custom')),
        'العلوم المتكاملة',
      );
      await tester.enterText(
        find.byKey(const Key('profile-stage-custom')),
        'رياض الأطفال',
      );
      await pressProfileSave(tester);

      final TeacherProfile saved = bundle.source.single;
      expect(saved.subject, 'العلوم المتكاملة');
      expect(saved.stage, 'رياض الأطفال');
      // لم تُحفظ القيمة الحارسة ولا رسالة تحقق.
      expect(saved.subject, isNot(AcademicOptions.customOption));
      expect(saved.status, TeacherProfileStatus.pendingReview);
    });

    testWidgets('نص مخصّص قصير يمنع الحفظ برسالة عربية', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final ({AppServices services, SessionController session, List<TeacherProfile> source})
      bundle = _teacherWith(TeacherProfileStatus.draft);
      await seedAvatar(bundle.services, 'teacher-1');

      await tester.pumpWidget(
        _host(const EditTeacherProfileScreen(), bundle.services, bundle.session),
      );
      await tester.pumpAndSettle();

      await _pick(
        tester,
        const Key('profile-subject'),
        AcademicOptions.customOption,
      );
      await tester.enterText(
        find.byKey(const Key('profile-subject-custom')),
        'ر',
      );
      await pressProfileSave(tester);

      expect(find.textContaining('قصير'), findsWidgets);
      // لم يُحفظ شيء: المادة الأصلية كما هي.
      expect(bundle.source.single.subject, 'الرياضيات');
    });

    testWidgets('قيمة مخصّصة محفوظة تُحمَّل في وضع الكتابة اليدوية', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final List<TeacherProfile> source = <TeacherProfile>[
        TeacherProfile(
          id: 'teacher-1',
          displayName: 'أ. سارة الخطيب',
          // قيمة قديمة غير معتمدة (نص حر قبل P19).
          subject: 'الرياضيات — التفاضل',
          stage: 'رياض الأطفال',
          area: 'المعادي',
          bio: 'شرح مبسّط للجبر والتفاضل مع تدريبات محلولة بعد كل حصة.',
          status: TeacherProfileStatus.draft,
          photoPath: TeacherProfile.photoPathFor('teacher-1'),
        ),
      ];
      final AppServices demo = AppServices.demo();
      final AppServices services = AppServices(
        auth: demo.auth,
        teachers: DemoTeacherRepository(source: source),
        groups: demo.groups,
        bookings: demo.bookings,
        schedules: demo.schedules,
        messages: demo.messages,
        chats: demo.chats,
        notifications: demo.notifications,
        reviews: demo.reviews,
        favorites: demo.favorites,
        admin: demo.admin,
        avatars: demo.avatars,
        imagePicker: demo.imagePicker,
      );
      await seedAvatar(services, 'teacher-1');
      final SessionController session = SessionController(services.auth)
        ..startDemoSession(UserRole.teacher);

      await tester.pumpWidget(_host(const EditTeacherProfileScreen(), services, session));
      await tester.pumpAndSettle();

      // النموذج يفتح على الكتابة اليدوية بالنص المحفوظ نفسه (لا فقدان بيانات).
      final TextFormField custom = tester.widget<TextFormField>(
        find.byKey(const Key('profile-subject-custom')),
      );
      expect(custom.controller?.text, 'الرياضيات — التفاضل');
      expect(find.byKey(const Key('profile-stage-custom')), findsOneWidget);

      // والحفظ بلا تغيير يُبقي القيمة كما هي.
      await pressProfileSave(tester);
      expect(source.single.subject, 'الرياضيات — التفاضل');
      expect(source.single.stage, 'رياض الأطفال');
    });
  });

  group('(P22) الصورة إلزامية', () {
    testWidgets('بلا صورة: لا يُرسل الملف ويظهر تنبيه', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final ({AppServices services, SessionController session, List<TeacherProfile> source})
      bundle = _teacherWith(
        TeacherProfileStatus.draft,
        withPhoto: false,
      );

      await tester.pumpWidget(
        _host(const EditTeacherProfileScreen(), bundle.services, bundle.session),
      );
      await tester.pumpAndSettle();

      // لا صورة مرفوعة ⇒ «صورتك الافتراضية» والإرشاد ظاهر.
      expect(find.textContaining('الصورة'), findsWidgets);

      await pressProfileSave(tester);

      expect(
        find.textContaining('أضف صورة شخصية واضحة'),
        findsWidgets,
        reason: 'التنبيه يجب أن يشرح سبب منع الحفظ',
      );
      // لم يُحفظ الملف ولم يتحول إلى «قيد المراجعة».
      expect(bundle.source.single.status, TeacherProfileStatus.draft);
    });

    testWidgets('اختيار صورة يفعّل الحفظ ويُثبّت مسار الصورة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final ({AppServices services, SessionController session, List<TeacherProfile> source})
      bundle = _teacherWith(
        TeacherProfileStatus.draft,
        withPhoto: false,
      );

      await tester.pumpWidget(
        _host(const EditTeacherProfileScreen(), bundle.services, bundle.session),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('avatar-pick')));
      await tester.pumpAndSettle();

      // الصورة المخصّصة أصبحت معروضة.
      expect(find.text('صورتك الشخصية'), findsOneWidget);

      await pressProfileSave(tester);

      final TeacherProfile saved = bundle.source.single;
      expect(saved.hasPhoto, isTrue);
      expect(saved.photoPath, TeacherProfile.photoPathFor('teacher-1'));
      expect(saved.status, TeacherProfileStatus.pendingReview);
    });

    testWidgets('إلغاء اختيار الصورة ليس خطأ ولا يغيّر شيئًا', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final List<TeacherProfile> source = <TeacherProfile>[
        TeacherProfile(
          id: 'teacher-1',
          displayName: 'أ. سارة الخطيب',
          subject: 'الرياضيات',
          stage: 'الثانوية العامة',
          area: 'المعادي',
          bio: 'شرح مبسّط للجبر والتفاضل مع تدريبات محلولة بعد كل حصة.',
          status: TeacherProfileStatus.draft,
        ),
      ];
      final AppServices demo = AppServices.demo();
      final FakeImagePickerGateway picker = FakeImagePickerGateway();
      final AppServices services = AppServices(
        auth: demo.auth,
        teachers: DemoTeacherRepository(source: source),
        groups: demo.groups,
        bookings: demo.bookings,
        schedules: demo.schedules,
        messages: demo.messages,
        chats: demo.chats,
        notifications: demo.notifications,
        reviews: demo.reviews,
        favorites: demo.favorites,
        admin: demo.admin,
        avatars: demo.avatars,
        imagePicker: picker,
      );
      final SessionController session = SessionController(services.auth)
        ..startDemoSession(UserRole.teacher);

      await tester.pumpWidget(
        _host(const EditTeacherProfileScreen(), services, session),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('avatar-pick')));
      await tester.pumpAndSettle();

      expect(picker.pickCalls, 1);
      expect(find.text('صورتك الافتراضية'), findsOneWidget);
      expect(source.single.hasPhoto, isFalse);
    });
  });
}

/// يختار قيمة من قائمة منسدلة عبر معالجها (النقر على العنصر غير موثوق).
Future<void> _pick(WidgetTester tester, Key field, String value) async {
  await tester.ensureVisible(find.byKey(field));
  await tester.pumpAndSettle();

  final DropdownButton<String> button = tester.widget<DropdownButton<String>>(
    find.descendant(
      of: find.byKey(field),
      matching: find.byType(DropdownButton<String>),
    ),
  );
  final bool offered = button.items!.any(
    (DropdownMenuItem<String> item) => item.value == value,
  );
  expect(offered, isTrue, reason: 'الخيار «$value» غير معروض في القائمة');

  button.onChanged!(value);
  await tester.pumpAndSettle();
}
