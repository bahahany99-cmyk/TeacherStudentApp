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

/// (P22 → P31) صورة الحساب: ليست فارغة أبدًا، وتُغيّر من بطاقة الملف نفسها.
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

/// محاكي شاشة القصّ: يمرّر الصورة كما هي (تأكيد) أو يعيد `null` (إلغاء).
///
/// **لماذا محاكاة؟** لأن شاشة القصّ الحقيقية تفكّ ترميز الصورة عبر `dart:ui`،
/// وهذا لا يكتمل داخل اختبار ويدجت إلا بـ`runAsync` (فخّ مقيس في هذا المشروع).
/// المحاكاة تُثبت **التدفّق** (اختيار ← قصّ ← رفع، أو إلغاء ⇒ لا تغيير) بدقة،
/// بينما يُغطّى حساب القصّ نفسه باختبارات مستقلة.
class _FakeCropper {
  _FakeCropper({this.cancel = false});

  final bool cancel;
  int calls = 0;

  Future<PickedImage?> present(BuildContext context, PickedImage source) async {
    calls++;
    return cancel ? null : source;
  }
}

void main() {
  group('(P31) UserAvatarView — أولوية العرض', () {
    testWidgets('بلا صورة: تُعرض الصورة الرمزية المضمَّنة الحتمية', (
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
      // صورة فعلية من الـAPK — لا دائرة حرف ولا شبكة.
      final Image image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect(
        (image.image as AssetImage).assetName,
        AvatarPresets.all[AvatarPresets.forId('uid-1')].asset,
      );
      expect(find.text('سا'), findsNothing);
    });

    testWidgets('مع صورة مرفوعة: تُعرض الصورة لا الرمزية', (
      WidgetTester tester,
    ) async {
      const UserAvatar avatar = UserAvatar(
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

      final Image image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
      expect(find.text('سا'), findsNothing);
    });

    testWidgets('بايتات تالفة: تعود إلى الصورة الرمزية (لا انهيار)', (
      WidgetTester tester,
    ) async {
      final UserAvatar broken = UserAvatar(
        ownerId: 'uid-1',
        imageBase64: base64Encode(Uint8List.fromList(<int>[9, 9, 9, 9])),
        mimeType: 'image/png',
        presetId: 6,
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

      expect(
        (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName,
        AvatarPresets.all[6].asset,
        reason: 'الرمزية المختارة هي البديل الصحيح عن بايتات تالفة',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('(P31) بطاقة الملف الشخصي', () {
    testWidgets('تحمل الصورة والاسم ونوع الحساب وزر إعدادات الصورة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = SessionController(
        services.auth,
        avatars: services.avatars,
      )..startDemoSession(UserRole.student);

      await tester.pumpWidget(_host(const ProfileScreen(), services, session));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile-card')), findsOneWidget);
      expect(find.byKey(const Key('profile-avatar-image')), findsOneWidget);
      expect(find.byKey(const Key('profile-avatar-settings')), findsOneWidget);
      expect(find.text(session.user!.displayName), findsWidgets);
      expect(find.text(UserRole.student.label), findsOneWidget);

      // (P31) لا يوجد قسم صورة منفصل مكرّر في الصفحة.
      expect(find.byKey(const Key('profile-avatar-editor')), findsNothing);
      expect(find.text('الصورة الشخصية'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('المدرس: زر معاينة الملف كما يراه الطلاب ظاهر في البطاقة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = SessionController(
        services.auth,
        avatars: services.avatars,
      )..startDemoSession(UserRole.teacher);

      await tester.pumpWidget(_host(const ProfileScreen(), services, session));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile-public-profile')), findsOneWidget);
      expect(find.text('معاينة ملفي كما يراه الطلاب'), findsOneWidget);
    });

    testWidgets('الطالب: لا زر معاينة ملف مدرس', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = SessionController(
        services.auth,
        avatars: services.avatars,
      )..startDemoSession(UserRole.student);

      await tester.pumpWidget(_host(const ProfileScreen(), services, session));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile-public-profile')), findsNothing);
    });
  });

  group('(P31) ورقة إعدادات الصورة', () {
    testWidgets('تُفتح من زر صغير وتعرض الخيارات الثلاثة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = SessionController(
        services.auth,
        avatars: services.avatars,
      )..startDemoSession(UserRole.student);

      await tester.pumpWidget(_host(const ProfileScreen(), services, session));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile-avatar-settings')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('avatar-settings-preview')), findsOneWidget);
      expect(find.byKey(const Key('avatar-pick')), findsOneWidget);
      expect(find.byKey(const Key('avatar-presets')), findsOneWidget);
      expect(find.byKey(const Key('avatar-remove')), findsOneWidget);
    });

    testWidgets('تغيير الصورة يمرّ بالقـصّ ويُحفظ بعد التأكيد', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeImagePickerGateway picker = FakeImagePickerGateway(
        result: PickedImage(bytes: tinyPngBytes(), mimeType: 'image/png'),
      );
      final _FakeCropper cropper = _FakeCropper();
      final AppServices services = AppServices.demo(
        imagePicker: picker,
        avatarCrop: cropper.present,
      );
      final SessionController session = SessionController(
        services.auth,
        avatars: services.avatars,
      )..startDemoSession(UserRole.student);
      final String uid = session.user!.id;

      await tester.pumpWidget(_host(const ProfileScreen(), services, session));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile-avatar-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avatar-pick')));
      await tester.pumpAndSettle();

      expect(picker.pickCalls, 1);
      expect(cropper.calls, 1, reason: 'القصّ يجب أن يحدث قبل الحفظ');
      final UserAvatar? stored = await services.avatars.getFor(uid);
      expect(stored, isNotNull);
      expect(stored!.hasCustomPhoto, isTrue);
    });

    testWidgets('إلغاء القصّ لا يترك أثرًا ولا رسالة خطأ', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeImagePickerGateway picker = FakeImagePickerGateway(
        result: PickedImage(bytes: tinyPngBytes(), mimeType: 'image/png'),
      );
      final _FakeCropper cropper = _FakeCropper(cancel: true);
      final AppServices services = AppServices.demo(
        imagePicker: picker,
        avatarCrop: cropper.present,
      );
      final SessionController session = SessionController(
        services.auth,
        avatars: services.avatars,
      )..startDemoSession(UserRole.student);
      final String uid = session.user!.id;

      await tester.pumpWidget(_host(const ProfileScreen(), services, session));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile-avatar-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avatar-pick')));
      await tester.pumpAndSettle();

      expect(picker.pickCalls, 1);
      expect(cropper.calls, 1);
      expect(
        await services.avatars.getFor(uid),
        isNull,
        reason: 'الإلغاء لا يكتب صورة',
      );
    });

    testWidgets('إلغاء المنتقي لا يفتح القصّ ولا يغيّر الصورة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeImagePickerGateway picker = FakeImagePickerGateway();
      final _FakeCropper cropper = _FakeCropper();
      final AppServices services = AppServices.demo(
        imagePicker: picker,
        avatarCrop: cropper.present,
      );
      final SessionController session = SessionController(
        services.auth,
        avatars: services.avatars,
      )..startDemoSession(UserRole.student);

      await tester.pumpWidget(_host(const ProfileScreen(), services, session));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile-avatar-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avatar-pick')));
      await tester.pumpAndSettle();

      expect(picker.pickCalls, 1);
      expect(cropper.calls, 0);
      expect(await services.avatars.getFor(session.user!.id), isNull);
    });

    testWidgets('اختيار صورة رمزية من المعرض يُحفظ ويُعتمد', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = SessionController(
        services.auth,
        avatars: services.avatars,
      )..startDemoSession(UserRole.student);
      final int before = session.user!.resolvedAvatarPreset;
      final int target = before == 7 ? 8 : 7;

      await tester.pumpWidget(_host(const ProfileScreen(), services, session));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile-avatar-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avatar-presets')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('avatar-gallery')), findsOneWidget);
      // 24 صورة موزّعة على ستة أقسام.
      for (final AvatarCategory category in AvatarCategory.values) {
        expect(find.text(category.label), findsOneWidget);
      }

      await tester.tap(find.byKey(Key('avatar-option-$target')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avatar-adopt')));
      await tester.pumpAndSettle();

      expect(session.user!.avatarPreset, target);
      expect((await services.avatars.getFor(session.user!.id))?.presetId, target);
    });

    testWidgets('إزالة الصورة تُبقي الاختيار الرمزي', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = SessionController(
        services.auth,
        avatars: services.avatars,
      )..startDemoSession(UserRole.student);
      final String uid = session.user!.id;

      await services.avatars.setPreset(uid: uid, preset: 13);
      await seedAvatar(services, uid);

      await tester.pumpWidget(_host(const ProfileScreen(), services, session));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile-avatar-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avatar-remove')));
      await tester.pumpAndSettle();

      final UserAvatar? after = await services.avatars.getFor(uid);
      expect(after?.hasCustomPhoto, isFalse, reason: 'الصورة أُزيلت');
      expect(after?.presetId, 13, reason: 'الاختيار الرمزي لا يُفقد بالإزالة');
    });
  });
}
