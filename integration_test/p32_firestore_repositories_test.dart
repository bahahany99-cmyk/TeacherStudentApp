/// **اختبار تكامل لتنفيذ Firestore الحقيقي** (P32 — محاولة أخيرة قبل الدمج).
///
/// **لماذا integration_test وليس `flutter test`؟**
/// * `cloud_firestore` يعتمد على قناة منصّة أصلية ⇒ لا يعمل في VM
///   (`flutter test` العادي).
/// * `flutter test --platform chrome` **لا يشغّل مُسجِّل إضافات الويب**، فتبقى
///   القناة بلا مستمع ويُعلَّق `Firebase.initializeApp` بلا خطأ (جُرّب فعلًا
///   وأُزيل: التشغيلات 41793072285 … 41800407384).
/// * `flutter test … -d chrome` يبني **تطبيق ويب حقيقيًا** يمرّ على
///   `web_plugin_registrant` المولَّد ⇒ تسجيل الإضافات يحدث تلقائيًا، فتعمل
///   Firebase كما في التطبيق الحقيقي. (جُرّب `flutter drive` بصيغتيه web-server
///   وchrome: الأولى أبلغت «نجاحًا» بلا اختبارات، والثانية عُلِّقت.)
///
/// **ما يُختبر:** `FirestoreNotificationRepository` و`FirestoreMessageRepository`
/// **نفسهما** — لا إعادة كتابة للاستعلامات — تحت قواعد المشروع (`firestore.rules`)
/// على محاكيي Firestore وAuth. البيانات تُهيَّأ قبل التشغيل بسكربت
/// `tool/rules_tests/seed_integration.mjs` (متجاوزًا القواعد للتهيئة فقط).
///
/// **التشغيل:** `tool/integration/run_web_integration.sh` داخل
/// `firebase emulators:exec` (يستدعي `flutter test … -d chrome`).
///
/// **كيف نعرف أن الاختبارات نُفِّذت فعلًا؟** لا بسطر «All tests passed» — فهو قد
/// يُطبع بعدد صفر. كل اختبار يُرسل نتيجته من داخل التطبيق إلى خادم محلي
/// (`tool/integration/results_server.mjs`، عبر `result_reporter_web.dart`)،
/// ويفشل التشغيل إن نقص تقرير واحد. الإشارتان `__main` و`__registered`
/// تفصلان: «التطبيق لم يبدأ» عن «بدأ ولم تُسجَّل الاختبارات» عن «سُجّلت ولم تُنفَّذ».
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

import 'result_reporter_stub.dart'
    if (dart.library.js_interop) 'result_reporter_web.dart';

const int _firestorePort = 8080;
const int _authPort = 9099;
const String _host = '127.0.0.1';
const String _password = 'Password1!';

const String _pagesEmail = 'pages@example.test';
const String _studentEmail = 'student@example.test';
const String _teacherEmail = 'teacher@example.test';

/// مهلة سخية: أول استدعاء على الويب يحمّل Firebase JS SDK من الشبكة.
const Timeout _slow = Timeout(Duration(minutes: 3));

/// عدد الاختبارات المتوقّع، يطابق `EXPECTED_TESTS` في سكربت التشغيل وسير العمل.
const int _expectedTests = 11;

/// **لماذا نُبلّغ من داخل التطبيق؟** لأن `flutter drive` على الويب قد يطبع
/// «All tests passed.» بعدد صفر اختبارات (flutter#94434، #150358، #151480)،
/// ولا يمكن قراءة سجلات Actions من بيئة التطوير. فكل اختبار يُرسل نتيجته إلى
/// `tool/integration/results_server.mjs` (انظر `result_reporter_web.dart`)،
/// ويفشل التشغيل إن لم تصل التقارير كلها.
void _report(String name, {required bool ok, String? error}) =>
    reportTestResult(name, ok: ok, error: error);

/// يغلّف اختبارًا: ينفّذه ثم يُبلّغ نتيجته إلى الخادم المحلي.
void reportedTest(String name, Future<void> Function() body) {
  test(name, () async {
    try {
      await body();
      _report(name, ok: true);
    } catch (error) {
      _report(name, ok: false, error: error.toString());
      rethrow;
    }
  }, timeout: _slow);
}

void _log(String message) => debugPrint('[تكامل] $message');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // إشارة بدء: أثرها الوحيد التمييز بين «التطبيق لم يبدأ إطلاقًا» و«بدأ
  // وسجّل الاختبارات» عند فحص النتائج — وهو الفرق الذي كان مجهولًا تمامًا.
  _report('__main', ok: true);

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
    reportedTest(
      'صفحات متعددة بلا فقد ولا تكرار، وترتيب حتمي عند تساوي createdAt',
      () async {
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
      },
    );

    reportedTest(
      'hasMore ونهاية النتائج',
      () async {
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
      },
    );

    reportedTest(
      'لا يقرأ إشعارات مستخدم آخر (القواعد هي الحارس)',
      () async {
        await signIn(_pagesEmail);
        await expectLater(
          notifications().listPage(recipientId: 'someone-else', limit: 5),
          throwsA(anything),
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('markChatMessagesRead — تعليم إشعارات محادثة واحدة', () {
    reportedTest(
      'يعلّم محادثة واحدة فقط ولا يمسّ غيرها',
      () async {
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
      },
    );

    reportedTest(
      'إشعار مستخدم آخر عن نفس المحادثة لا يُمسّ',
      () async {
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
      },
    );

    reportedTest(
      'لا يستطيع تعليم إشعارات مستخدم آخر (القواعد ترفض)',
      () async {
        await signIn(_studentEmail);
        await expectLater(
          notifications().markChatMessagesRead(
            recipientId: 'someone-else',
            chatId: 'chat-1',
          ),
          throwsA(anything),
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('unreadCount — عدّاد المجموعة على تنفيذ Firestore', () {
    reportedTest(
      '10 رسائل للعضو نفسه + واحدة من غيره ⇒ 1',
      () async {
        final String uid = await signIn(_studentEmail);
        final FirestoreMessageRepository repo = messages();

        expect(await repo.lastReadAt(groupId: 'g1', memberId: uid), isNotNull);
        expect(await repo.unreadCount(groupId: 'g1', memberId: uid), 1);
      },
    );

    reportedTest(
      'غياب lastReadAt ⇒ كل رسائل الآخرين غير مقروءة (ورسائلي لا تُحتسب)',
      () async {
        final String uid = await signIn(_studentEmail);
        final FirestoreMessageRepository repo = messages();

        expect(await repo.lastReadAt(groupId: 'g2', memberId: uid), isNull);
        expect(
          await repo.unreadCount(groupId: 'g2', memberId: uid),
          2,
          reason: 'رسالتا المدرس؛ رسالة العضو نفسه (mine-1) لا تُحتسب',
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('markRead — علامات القراءة', () {
    reportedTest(
      'علامة المجموعة تُحدَّث للعضو نفسه فيصفّر عدّاده',
      () async {
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
      },
    );

    reportedTest(
      'لا كتابة على علامة عضو آخر',
      () async {
        await signIn(_studentEmail);
        await expectLater(
          messages().markRead(groupId: 'g1', memberId: 'someone-else'),
          throwsA(anything),
        );
      },
    );

    reportedTest(
      'لا تعليم إشعار مستخدم آخر كمقروء',
      () async {
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
          mine
              .firstWhere((AppNotification item) => item.id == 'booking-same-target')
              .readAt,
          isNotNull,
        );
      },
    );
  });

  // إشارة اكتمال التسجيل: وصولها يعني أن الاختبارات كلها أُدرجت في المشغّل
  // ($_expectedTests اختبارًا) — ولو لم تُنفَّذ لاحقًا لكان الفرق ظاهرًا.
  _report('__registered', ok: true, error: '$_expectedTests');
}
