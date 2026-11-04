/// **اختبار تكامل لتنفيذ Firestore الحقيقي** (P32 — محاولة أخيرة قبل الدمج).
///
/// **لماذا integration_test وليس `flutter test`؟**
/// * `cloud_firestore` يعتمد على قناة منصّة أصلية ⇒ لا يعمل في VM
///   (`flutter test` العادي).
/// * `flutter test --platform chrome` **لا يشغّل مُسجِّل إضافات الويب**، فتبقى
///   القناة بلا مستمع ويُعلَّق `Firebase.initializeApp` بلا خطأ (جُرّب فعلًا
///   وأُزيل: التشغيلات 41793072285 … 41800407384).
/// * `integration_test` + `flutter drive` يبنيان **تطبيق ويب حقيقيًا** يمرّ على
///   `web_plugin_registrant` المولَّد ⇒ تسجيل الإضافات يحدث تلقائيًا، فتعمل
///   Firebase كما في التطبيق الحقيقي.
///
/// **ما يُختبر:** `FirestoreNotificationRepository` و`FirestoreMessageRepository`
/// **نفسهما** — لا إعادة كتابة للاستعلامات — تحت قواعد المشروع (`firestore.rules`)
/// على محاكيي Firestore وAuth. البيانات تُهيَّأ قبل التشغيل بسكربت
/// `tool/rules_tests/seed_integration.mjs` (متجاوزًا القواعد للتهيئة فقط).
///
/// **التشغيل:** `tool/integration/run_web_drive.sh` داخل `firebase emulators:exec`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:teacher_student_app/data/firebase/firestore_repositories.dart';
import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/notification_page.dart';

const int _firestorePort = 8080;
const int _authPort = 9099;
const String _host = '127.0.0.1';
const String _password = 'Password1!';

const String _pagesEmail = 'pages@example.test';
const String _studentEmail = 'student@example.test';
const String _teacherEmail = 'teacher@example.test';

/// مهلة سخية: أول استدعاء على الويب يحمّل Firebase JS SDK من الشبكة.
const Timeout _slow = Timeout(Duration(minutes: 3));

void _log(String message) => debugPrint('[تكامل] $message');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _log('تهيئة تطبيق Firebase (مشروع المحاكي demo-darsly)');
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: '1:1:web:1',
        messagingSenderId: '1',
        projectId: 'demo-darsly',
        authDomain: 'demo-darsly.firebaseapp.com',
        storageBucket: 'demo-darsly.appspot.com',
      ),
    );
    FirebaseFirestore.instance.useFirestoreEmulator(_host, _firestorePort);
    FirebaseAuth.instance.useAuthEmulator(_host, _authPort);
    _log('المحاكيان: firestore=$_firestorePort auth=$_authPort');
  });

  tearDown(() async {
    await FirebaseAuth.instance.signOut();
  });

  /// يسجّل الدخول بحساب المحاكي ويعيد `uid` الفعلي (وهو `recipientId` في
  /// البيانات المهيّأة، لأنها أخذت uid من محاكي Auth نفسه).
  Future<String> signIn(String email) async {
    final UserCredential credential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: _password);
    final String? uid = credential.user?.uid;
    expect(uid, isNotNull, reason: 'تسجيل الدخول يجب أن يُرجع مستخدمًا');
    _log('دخول $email ⇒ $uid');
    return uid!;
  }

  FirestoreNotificationRepository notifications() =>
      FirestoreNotificationRepository(firestore: FirebaseFirestore.instance);

  FirestoreMessageRepository messages() =>
      FirestoreMessageRepository(firestore: FirebaseFirestore.instance);

  // ══════════════════════════════════════════════════════════════════════════
  group('listPage — تصفّح الإشعارات على تنفيذ Firestore', () {
    test('صفحات متعددة بلا فقد ولا تكرار، وترتيب حتمي عند تساوي createdAt', () async {
      final String uid = await signIn(_pagesEmail);
      final FirestoreNotificationRepository repo = notifications();

      final List<AppNotification> collected = <AppNotification>[];
      NotificationPage page = await repo.listPage(recipientId: uid, limit: 7);
      collected.addAll(page.items);

      int guard = 0;
      while (page.hasMore && guard < 30) {
        guard++;
        final AppNotification last = page.items.last;
        page = await repo.listPage(
          recipientId: uid,
          limit: 7,
          before: last.createdAt,
          beforeId: last.id,
        );
        collected.addAll(page.items);
      }

      expect(guard, lessThan(30), reason: 'التصفّح يجب أن ينتهي');
      expect(collected.length, 48, reason: '45 متباعدًا + 3 متساوية الوقت');

      final Set<String> unique = collected
          .map((AppNotification item) => item.id)
          .toSet();
      expect(unique.length, 48, reason: 'لا تكرار بين الصفحات');

      final List<String> ids = collected
          .map((AppNotification item) => item.id)
          .toList(growable: false);
      // الثلاثة المتساوية الوقت أولًا، وترتيبها بالمعرّف تصاعديًا.
      expect(ids.sublist(0, 3), <String>['same-a', 'same-b', 'same-c']);
      expect(ids[3], 'p44', reason: 'بعده الأحدث من p');
      expect(ids.last, 'p00', reason: 'الأقدم في النهاية');

      // الباقي تنازلي زمنيًا بصرامة.
      for (int i = 4; i < collected.length; i++) {
        expect(
          collected[i - 1].createdAt.isAfter(collected[i].createdAt),
          isTrue,
          reason: 'ترتيب تنازلي عند الموضع $i',
        );
      }
    }, timeout: _slow);

    test('hasMore ونهاية النتائج', () async {
      final String uid = await signIn(_pagesEmail);
      final FirestoreNotificationRepository repo = notifications();

      final NotificationPage all = await repo.listPage(
        recipientId: uid,
        limit: 50,
      );
      expect(all.items.length, 48);
      expect(all.hasMore, isFalse);

      final AppNotification last = all.items.last;
      final NotificationPage afterEnd = await repo.listPage(
        recipientId: uid,
        limit: 50,
        before: last.createdAt,
        beforeId: last.id,
      );
      expect(afterEnd.items, isEmpty);
      expect(afterEnd.hasMore, isFalse);
    }, timeout: _slow);

    test('لا يقرأ إشعارات مستخدم آخر (القواعد هي الحارس)', () async {
      await signIn(_pagesEmail);
      await expectLater(
        notifications().listPage(recipientId: 'someone-else', limit: 5),
        throwsA(anything),
      );
    }, timeout: _slow);
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('markChatMessagesRead — تعليم إشعارات محادثة واحدة', () {
    test('يعلّم محادثة واحدة فقط ولا يمسّ غيرها', () async {
      final String uid = await signIn(_studentEmail);
      final FirestoreNotificationRepository repo = notifications();

      final int changed = await repo.markChatMessagesRead(
        recipientId: uid,
        chatId: 'chat-1',
      );
      expect(changed, 2, reason: 'dm-1 وdm-2 فقط');

      final List<AppNotification> mine = await repo.listMine(uid);
      AppNotification byId(String id) =>
          mine.firstWhere((AppNotification item) => item.id == id);

      expect(byId('dm-1').readAt, isNotNull);
      expect(byId('dm-2').readAt, isNotNull);
      expect(byId('booking-same-target').readAt, isNull,
          reason: 'إشعار حجز بنفس targetId لم يُمسّ');
      expect(byId('dm-other-chat').readAt, isNull, reason: 'محادثة أخرى لم تُمسّ');
      expect(byId('dm-read').readAt, isNotNull,
          reason: 'ما كان مقروءًا يبقى مقروءًا');

      // تشغيل ثانٍ: لا شيء غير مقروء ⇒ صفر، ولا كتابة.
      expect(
        await repo.markChatMessagesRead(recipientId: uid, chatId: 'chat-1'),
        0,
      );
    }, timeout: _slow);

    test('إشعار مستخدم آخر عن نفس المحادثة لا يُمسّ', () async {
      // الطالب يعلّم محادثته…
      final String studentUid = await signIn(_studentEmail);
      await notifications().markChatMessagesRead(
        recipientId: studentUid,
        chatId: 'chat-1',
      );
      await FirebaseAuth.instance.signOut();

      // … ثم نتحقّق بحساب المدرس أن إشعاره ما زال غير مقروء.
      final String teacherUid = await signIn(_teacherEmail);
      final List<AppNotification> teacherItems =
          await notifications().listMine(teacherUid);
      expect(teacherItems.length, 1);
      expect(teacherItems.single.id, 'dm-teacher');
      expect(teacherItems.single.readAt, isNull);
    }, timeout: _slow);

    test('لا يستطيع تعليم إشعارات مستخدم آخر (القواعد ترفض)', () async {
      await signIn(_studentEmail);
      await expectLater(
        notifications().markChatMessagesRead(
          recipientId: 'someone-else',
          chatId: 'chat-1',
        ),
        throwsA(anything),
      );
    }, timeout: _slow);
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('unreadCount — عدّاد المجموعة على تنفيذ Firestore', () {
    test('10 رسائل للعضو نفسه + واحدة من غيره ⇒ 1', () async {
      final String uid = await signIn(_studentEmail);
      final FirestoreMessageRepository repo = messages();

      expect(await repo.lastReadAt(groupId: 'g1', memberId: uid), isNotNull);
      expect(await repo.unreadCount(groupId: 'g1', memberId: uid), 1);
    }, timeout: _slow);

    test('غياب lastReadAt ⇒ كل رسائل الآخرين غير مقروءة (ورسائلي لا تُحتسب)', () async {
      final String uid = await signIn(_studentEmail);
      final FirestoreMessageRepository repo = messages();

      expect(await repo.lastReadAt(groupId: 'g2', memberId: uid), isNull);
      expect(
        await repo.unreadCount(groupId: 'g2', memberId: uid),
        2,
        reason: 'رسالتا المدرس؛ رسالة العضو نفسه (mine-1) لا تُحتسب',
      );
    }, timeout: _slow);
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('markRead — علامات القراءة', () {
    test('علامة المجموعة تُحدَّث للعضو نفسه فيصفّر عدّاده', () async {
      final String uid = await signIn(_studentEmail);
      final FirestoreMessageRepository repo = messages();

      final DateTime before =
          DateTime.now().subtract(const Duration(minutes: 1));
      await repo.markRead(groupId: 'g1', memberId: uid);

      final DateTime? marker = await repo.lastReadAt(groupId: 'g1', memberId: uid);
      expect(marker, isNotNull);
      expect(marker!.isAfter(before), isTrue);
      expect(await repo.unreadCount(groupId: 'g1', memberId: uid), 0);

      // علامة مجموعة أخرى لم تُمسّ.
      expect(await repo.lastReadAt(groupId: 'g2', memberId: uid), isNull);
    }, timeout: _slow);

    test('لا كتابة على علامة عضو آخر', () async {
      await signIn(_studentEmail);
      await expectLater(
        messages().markRead(groupId: 'g1', memberId: 'someone-else'),
        throwsA(anything),
      );
    }, timeout: _slow);

    test('لا تعليم إشعار مستخدم آخر كمقروء', () async {
      await signIn(_studentEmail);
      await expectLater(
        notifications().markRead(
          notificationId: 'dm-teacher',
          recipientId: 'someone-else',
        ),
        throwsA(anything),
      );
      // وإشعاره هو يُعلَّم بنجاح.
      final String uid = FirebaseAuth.instance.currentUser!.uid;
      await notifications().markRead(
        notificationId: 'booking-same-target',
        recipientId: uid,
      );
      final List<AppNotification> mine = await notifications().listMine(uid);
      expect(
        mine.firstWhere((AppNotification item) => item.id == 'booking-same-target').readAt,
        isNotNull,
      );
    }, timeout: _slow);
  });
}
