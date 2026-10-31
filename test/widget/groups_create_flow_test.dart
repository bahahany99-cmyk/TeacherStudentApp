import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/router/app_router.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/features/groups/presentation/group_form_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/groups_screen.dart';

import '../helpers/test_app.dart';

/// (P23) «مجموعاتي»: **زر واحد** للإنشاء، ويعمل فعلًا من أوله إلى آخره.
///
/// ما نثبته:
/// 1. زر «إنشاء مجموعة جديدة» يظهر **مرة واحدة** فقط (لا ثلاثة مداخل).
/// 2. لا يوجد زر/رابط إنشاء ثانٍ في العنوان ولا في حالة الفراغ ولا أسفلها.
/// 3. الضغط عليه يفتح النموذج الحقيقي، والحفظ يُضيف المجموعة للمستودع.
/// 4. القسم يعيد القراءة عند العودة من النموذج، فتظهر المجموعة فورًا.
///
/// المضيف يستخدم `AppRouter.onGenerateRoute` نفسه — لا نسخة مخففة — لأن
/// الانتقال إلى النموذج هو نصف الفعل المطلوب.
Widget _host(AppServices services, SessionController session) {
  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: MaterialApp(
        theme: AppTheme.light,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: const GroupsScreen.forTeacher()),
        ),
      ),
    ),
  );
}

/// حزمة بمجموعات محلية محدّدة (فارغة أو غير ذلك) — بلا مساس ببقية الخدمات.
///
/// `AppServices.demo()` يستخدم مجموعات `DemoData` الثابتة؛ نستبدل المستودع
/// وحده لنقيس حالة الفراغ ثم الإنشاء على **نفس** المستودع.
AppServices _servicesWithGroups(List<StudyGroup> source) {
  final AppServices demo = AppServices.demo();
  return AppServices(
    auth: demo.auth,
    teachers: demo.teachers,
    groups: DemoGroupRepository(source: source),
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
}

(AppServices, SessionController) _bundle() {
  final AppServices services = _servicesWithGroups(<StudyGroup>[]);
  final SessionController session = SessionController(services.auth)
    ..startDemoSession(UserRole.teacher);
  return (services, session);
}

/// صيغ النص التي كانت تمثّل مدخلًا ثانيًا للإنشاء قبل P23.
const List<String> _otherCreateLabels = <String>[
  'مجموعة جديدة',
  'إنشاء مجموعة',
  'إنشاء',
];

/// يثبت أن **الفعل له مدخل واحد**: الزر المعروف واحد، ونصّه مرة واحدة، ولا
/// يوجد أي زر آخر (بأي نوع) يحمل صيغة إنشاء.
///
/// `find.widgetWithText` يعيد **الزر** لا النص داخله، فلا تُحتسب التسمية نفسها
/// مدخلًا ثانيًا (وهو الخطأ الذي أسقط الفحص الأول).
void _expectSingleCreateEntryPoint() {
  expect(find.byKey(const Key('groups-create')), findsOneWidget);
  expect(
    find.widgetWithText(FilledButton, 'إنشاء مجموعة جديدة'),
    findsOneWidget,
  );
  expect(find.text('إنشاء مجموعة جديدة'), findsOneWidget);

  for (final String label in _otherCreateLabels) {
    for (final Finder button in <Finder>[
      find.widgetWithText(TextButton, label),
      find.widgetWithText(FilledButton, label),
      find.widgetWithText(OutlinedButton, label),
      find.widgetWithText(ElevatedButton, label),
      find.widgetWithText(FloatingActionButton, label),
      find.widgetWithText(IconButton, label),
    ]) {
      expect(button, findsNothing, reason: 'مدخل إنشاء ثانٍ بصيغة «$label»');
    }
  }
}

void main() {
  group('(P23) زر واحد لإنشاء المجموعة', () {
    testWidgets('يظهر زر أساسي واحد وليس ثلاثة', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final (AppServices services, SessionController session) = _bundle();

      await tester.pumpWidget(_host(services, session));
      await tester.pumpAndSettle();

      // الزر الأساسي موجود، ونصّه مرة واحدة، ولا مدخل ثانٍ بأي صيغة أو
      // نوع زر (لا في العنوان، ولا في حالة الفراغ، ولا أسفل القائمة).
      _expectSingleCreateEntryPoint();
    });

    testWidgets('حالة الفراغ تشرح ولا تُكرّر الزر', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final (AppServices services, SessionController session) = _bundle();

      await tester.pumpWidget(_host(services, session));
      await tester.pumpAndSettle();

      // حالة الفراغ ظاهرة…
      expect(find.text('لم تُنشئ مجموعات بعد'), findsOneWidget);
      // …وبلا رابط إنشاء ثانٍ داخلها، والزر الأساسي يبقى واحدًا.
      _expectSingleCreateEntryPoint();
    });

    testWidgets('الزر يفتح النموذج الحقيقي ويحفظ في المستودع ثم يُحدّث القائمة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final (AppServices services, SessionController session) = _bundle();

      // نبدأ بقائمة فارغة تمامًا: القسم يجب أن يعرض حالة الفراغ ثم المجموعة.
      await tester.pumpWidget(_host(services, session));
      await tester.pumpAndSettle();

      expect(find.text('لم تُنشئ مجموعات بعد'), findsOneWidget);

      // ① الزر الوحيد ⇒ النموذج الحقيقي.
      await tester.tap(find.byKey(const Key('groups-create')));
      await tester.pumpAndSettle();

      // النموذج الحقيقي مفتوح (نوعه لا نصّه: النص قد يتغيّر، والمسار لا).
      expect(
        find.byType(GroupFormScreen),
        findsOneWidget,
        reason: 'الزر لم يفتح نموذج الإنشاء',
      );
      expect(find.text('بيانات المجموعة'), findsOneWidget);

      // ② نملأ الحقول ونحفظ (نفس مسار المستخدم، بلا اختصارات).
      await tester.enterText(
        find.widgetWithText(TextFormField, 'عنوان المجموعة'),
        'مجموعة التفاضل — اختبار الزر الواحد',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'المادة'),
        'الرياضيات',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'المرحلة الدراسية'),
        'الثانوية العامة',
      );
      // الحفظ: نستدعي فعل الزر الأساسي نفسه (كما في `pressProfileSave`) بدل
      // الاعتماد على إصابة نقرة داخل قائمة قابلة للتمرير — النقر على عنصر
      // أسفل الشاشة قد «يُخطئ» بلا فشل، فيبدو الاختبار كأنه حفظ وهو لم يحفظ.
      final FilledButton save = tester.widget<FilledButton>(
        find.byKey(const Key('group-form-save')),
      );
      save.onPressed!();
      await tester.pumpAndSettle();

      final String onScreen = tester
          .widgetList<Text>(find.byType(Text))
          .map((Text text) => text.data ?? '')
          .where((String data) => data.isNotEmpty)
          .join(' | ');

      // ③ عاد إلى «مجموعاتي»: نموذج الإنشاء أُغلق فعلًا بالحفظ لا بالرجوع.
      expect(
        find.byType(GroupFormScreen),
        findsNothing,
        reason: 'النموذج ما زال مفتوحًا ⇒ الحفظ لم يحدث. المعروض: $onScreen',
      );
      expect(
        find.text('مجموعة التفاضل — اختبار الزر الواحد'),
        findsOneWidget,
      );
      final List<StudyGroup> after = await services.groups.listForTeacher(
        'demo-teacher-1',
      );
      expect(
        after.any((StudyGroup g) => g.title == 'مجموعة التفاضل — اختبار الزر الواحد'),
        isTrue,
        reason:
            'المجموعة يجب أن تُحفظ في المستودع لا أن تُعرض فقط. '
            'المخزّن الآن: ${after.map((StudyGroup g) => g.title).join(' | ')}',
      );
    });
  });

  group('(P23) تحديث حيّ عبر إشارة التغيير', () {
    testWidgets('تغيّر البيانات + الإشارة ⇒ القائمة تُقرأ من جديد', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final (AppServices services, SessionController session) = _bundle();

      await tester.pumpWidget(_host(services, session));
      await tester.pumpAndSettle();

      expect(find.text('لم تُنشئ مجموعات بعد'), findsOneWidget);

      // نكتب في المستودع خارج الواجهة (كما يفعل مسار آخر/تبويب آخر)، ثم
      // نُطلق الإشارة نفسها التي يُطلقها النموذج بعد الحفظ.
      await services.groups.createGroup(
        teacherId: 'demo-teacher-1',
        teacherName: 'أ. سارة الخطيب',
        draft: const GroupDraft(
          title: 'مجموعة أُضيفت من مسار آخر',
          subject: 'الرياضيات',
          stage: 'الثانوية العامة',
          meetingMode: GroupMeetingMode.online,
          seatsTotal: 8,
        ),
      );
      services.notifyGroupsChanged();
      await tester.pumpAndSettle();

      expect(find.text('مجموعة أُضيفت من مسار آخر'), findsOneWidget);
      expect(find.text('لم تُنشئ مجموعات بعد'), findsNothing);
    });
  });

  group('(P23) لا فعل مزدوج بعد الإنشاء', () {
    testWidgets('المفتاح نفسه لا يتكرّر عند وجود مجموعات', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      // مُهيّأة بمجموعة واحدة سلفًا.
      final AppServices services = _servicesWithGroups(<StudyGroup>[
        DemoData.groups.first,
      ]);
      final SessionController session = SessionController(services.auth)
        ..startDemoSession(UserRole.teacher);

      await tester.pumpWidget(_host(services, session));
      await tester.pumpAndSettle();

      // الزر يبقى واحدًا مهما كان عدد المجموعات، ويبقى ظاهرًا (لا يختفي
      // أسفل قائمة طويلة).
      _expectSingleCreateEntryPoint();
    });
  });
}
