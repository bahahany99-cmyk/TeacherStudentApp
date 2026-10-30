import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/user_avatar_view.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/image_picker_gateway.dart';
import 'package:teacher_student_app/features/profile/presentation/profile_screen.dart';

import '../helpers/avatar_helpers.dart';
import '../helpers/test_app.dart';

/// (P22) صورة الحساب: ليست فارغة أبدًا، والطالب يغيّرها من الإعدادات.
Widget _host(Widget child, AppServices services, SessionController session) {
  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
      ),
    ),
  );
}

void main() {
  group('(P22) UserAvatarView — عرض فقط', () {
    testWidgets('بلا صورة: تصميم افتراضي مع الحرف الأول (لا دائرة فارغة)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: UserAvatarView(userId: 'uid-1', initials: 'سارة', size: 72),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(UserAvatarView), findsOneWidget);
      expect(find.text('سا'), findsOneWidget);
      // لا صورة شبكة/ذاكرة: لا شيء يُفكّ ترميزه.
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('مع صورة مخصّصة: تُعرض الصورة لا الحرف', (
      WidgetTester tester,
    ) async {
      final UserAvatar avatar = UserAvatar(
        ownerId: 'uid-1',
        imageBase64: kTinyPngBase64,
        mimeType: 'image/png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: UserAvatarView(
                  userId: 'uid-1',
                  image: avatar,
                  initials: 'سارة',
                  size: 72,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('سا'), findsNothing);
    });

    testWidgets('بايتات تالفة: يعود للافتراضية بلا انهيار', (
      WidgetTester tester,
    ) async {
      final UserAvatar broken = UserAvatar(
        ownerId: 'uid-1',
        imageBase64: base64Encode(Uint8List.fromList(<int>[9, 9, 9, 9])),
        mimeType: 'image/png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: UserAvatarView(
                  userId: 'uid-1',
                  image: broken,
                  initials: 'س',
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // الصورة مبنية، لكن فك الترميز يفشل ⇒ الحرف الافتراضي بديلًا.
      expect(find.text('س'), findsOneWidget);
    });
  });

  group('(P22) صورة الحساب في الإعدادات', () {
    testWidgets('الطالب يرى صورته ويغيّرها بصورة من الجهاز', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeImagePickerGateway picker = FakeImagePickerGateway(
        result: PickedImage(bytes: tinyPngBytes(), mimeType: 'image/png'),
      );
      final AppServices services = AppServices.demo(imagePicker: picker);
      final SessionController session = SessionController(
        services.auth,
        avatars: services.avatars,
      )..startDemoSession(UserRole.student);

      final String uid = session.user!.id;

      await tester.pumpWidget(
        _host(const ProfileScreen(), services, session),
      );
      await tester.pumpAndSettle();

      // (1) الحساب ليس بلا صورة: الصورة معروضة في ترويسة الحساب.
      expect(find.byKey(const Key('profile-avatar-image')), findsOneWidget);
      expect(find.byKey(const Key('profile-avatar-editor')), findsOneWidget);
      expect(find.text('صورتك الافتراضية'), findsOneWidget);

      // (2) اختيار صورة من الجهاز.
      await tester.ensureVisible(find.byKey(const Key('avatar-pick')));
      await tester.tap(find.byKey(const Key('avatar-pick')));
      await tester.pumpAndSettle();

      expect(picker.pickCalls, 1);
      expect(find.text('صورتك الشخصية'), findsOneWidget);
      final UserAvatar? stored = await services.avatars.getFor(uid);
      expect(stored, isNotNull);
      expect(stored!.hasCustomPhoto, isTrue);
    });

    testWidgets('اختيار تصميم افتراضي يُحفظ في الجلسة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = SessionController(
        services.auth,
        avatars: services.avatars,
      )..startDemoSession(UserRole.student);

      final int before = session.user!.resolvedAvatarPreset;
      final int target = before == 2 ? 3 : 2;

      await tester.pumpWidget(
        _host(const ProfileScreen(), services, session),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('avatar-presets')));
      await tester.tap(find.byKey(const Key('avatar-presets')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('avatar-preset-$target')));
      await tester.pumpAndSettle();

      expect(session.user!.avatarPreset, target);
      expect(
        find.byKey(const Key('avatar-presets')),
        findsOneWidget,
        reason: 'الشاشة تعمل بعد الاختيار',
      );
    });

    testWidgets('إلغاء اختيار الصورة لا يترك أثرًا ولا رسالة خطأ', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeImagePickerGateway picker = FakeImagePickerGateway();
      final AppServices services = AppServices.demo(imagePicker: picker);
      final SessionController session = SessionController(
        services.auth,
        avatars: services.avatars,
      )..startDemoSession(UserRole.student);

      await tester.pumpWidget(
        _host(const ProfileScreen(), services, session),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('avatar-pick')));
      await tester.tap(find.byKey(const Key('avatar-pick')));
      await tester.pumpAndSettle();

      expect(picker.pickCalls, 1);
      expect(find.text('صورتك الافتراضية'), findsOneWidget);
      expect(await services.avatars.getFor(session.user!.id), isNull);
    });
  });
}
