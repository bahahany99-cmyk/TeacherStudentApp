/// اختبار **تنفيذ Firestore الحقيقي** (`lib/data/firebase/firestore_repositories.dart`)
/// على Firestore Emulator من متصفح حقيقي (P32 — مراجعة نهائية).
///
/// **لماذا اسمه بلا لاحقة `_test`؟** لأن `cloud_firestore` يحتاج قناة منصّة
/// أصلية؛ فلا يعمل في `flutter test` العادي (VM). لذلك لا يجب أن يكتشفه
/// `flutter test` تلقائيًا (الاكتشاف يقتصر على `*_test.dart`)، ويُشغَّل بمساره
/// صريحًا في مهمة CI المخصّصة. هنا نُجمّع نفس الكود إلى JavaScript ونشغّله في
/// Chrome مقابل المحاكي، **بنفس القواعد**، وبعميل
/// `FirestoreNotificationRepository`/`FirestoreMessageRepository` نفسه — لا
/// إعادة كتابة للاستعلامات.
///
/// **التشغيل:** داخل `firebase emulators:exec` (انظر مهمة CI):
///   node tool/rules_tests/seed_web_emulator.mjs
///   flutter test --platform chrome test/web/firestore_repositories_emulator.dart
///
/// **حدود التغطية:** يعمل على المحاكي لا على مشروع Firebase حقيقي، والمحاكي
/// **لا يفرض الفهارس**؛ فمطابقة الفهرس المركّب تبقى فحصًا يدويًا عند النشر.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:cloud_firestore/cloud_firestore.dart';
// الإضافات الويب تُستورد مباشرةً لتسجيلها يدويًا: `flutter test --platform
// chrome` لا يشغّل مُسجِّل إضافات الويب تلقائيًا (خلافًا لبناء التطبيق).
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_web/cloud_firestore_web.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_web/firebase_auth_web.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/firebase/firestore_repositories.dart';
import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/notification_page.dart';

/// `eval` العام في المتصفح — نستخدمه لتحميل Firebase JS SDK الذي يعتمد عليه
/// `cloud_firestore_web` (هارنس `flutter test` لا يحمّله من تلقاء نفسه).
@JS('eval')
external JSAny? _evalJs(String source);

const int _firestorePort = 8080;
const int _authPort = 9099;
const String _host = '127.0.0.1';
const String _password = 'Password1!';

/// نسخة JS SDK متوافقة مع واجهة `firebase.*` التي يعتمدها FlutterFire الويب.
const List<String> _sdkScripts = <String>[
  'https://www.gstatic.com/firebasejs/10.12.5/firebase-app-compat.js',
  'https://www.gstatic.com/firebasejs/10.12.5/firebase-auth-compat.js',
  'https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore-compat.js',
];

bool _firebaseGlobalExists() =>
    (_evalJs('typeof firebase !== "undefined"') as JSBoolean).toDart;

Future<void> _loadScript(String url) async {
  final JSAny? promise = _evalJs('''
new Promise(function (resolve, reject) {
  var s = document.createElement('script');
  s.src = "$url";
  s.onload = function () { resolve(true); };
  s.onerror = function () { reject(new Error("تعذّر تحميل $url")); };
  document.head.appendChild(s);
})
''');
  await (promise as JSPromise<JSAny?>).toDart;
}

/// ينفّذ خطوة واحدة ويطبع بدايتها/نهايتها.
///
/// **لماذا؟** لأن سجل المتصفح هو الوسيلة الوحيدة لتشخيص فشل `setUpAll`
/// (سجلات Actions لا تُقرأ من بيئة التطوير)، وبلا هذه الخطوات يظهر الفشل
/// كـ«انتهت المهلة» بلا معرفة الخطوة المتوقفة.
Future<T> _step<T>(
  String label,
  Future<T> Function() action, {
  Duration limit = const Duration(seconds: 45),
}) async {
  debugPrint('→ $label');
  final T result = await action().timeout(
    limit,
    onTimeout: () => throw StateError('انتهت مهلة الخطوة: $label'),
  );
  debugPrint('✓ $label');
  return result;
}

/// يسجّل تنفيذات الويب للإضافات **يدويًا** — بنفس نمط
/// `web_plugin_registrant.dart` الذي يولّده Flutter لبناء التطبيق.
///
/// **لماذا؟** قنوات المنصّة (`firebase_core`, `cloud_firestore`, `firebase_auth`)
/// في الويب يخدمها مُسجِّل الإضافات. و`flutter test --platform chrome` **لا**
/// يشغّل ذلك المُسجِّل، فتُرسل الرسالة بلا مستمع: لا استثناء ولا نتيجة — تعليق
/// إلى ما لا نهاية (رأيناه فعلًا: توقّف `Firebase.initializeApp` بلا خطأ).
///
/// `ui_web.registerPlugin` هو الباب الرسمي الذي يستخدمه المُسجِّل المولَّد،
/// ويمرّر `Registrar` الذي تتوقعه الإضافات.
void _registerWebPlugins() {
  ui_web.registerPlugin(
    FirebaseCoreWeb.new,
    (dynamic registrar) => FirebaseCoreWeb.registerWith(registrar),
  );
  ui_web.registerPlugin(
    FirestoreWeb.new,
    (dynamic registrar) => FirestoreWeb.registerWith(registrar),
  );
  ui_web.registerPlugin(
    FirebaseAuthWeb.new,
    (dynamic registrar) => FirebaseAuthWeb.registerWith(registrar),
  );
}

Future<void> _bootstrap() async {
  await _step('فحص وجود firebase العالمي', () async {
    if (!_firebaseGlobalExists()) {
      for (final String url in _sdkScripts) {
        await _loadScript(url);
      }
    }
    return true;
  });

  await _step(
    'انتظار تحميل Firebase JS SDK',
    () async {
      for (int attempt = 0; attempt < 100 && !_firebaseGlobalExists(); attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!_firebaseGlobalExists()) {
        throw StateError('تعذّر تحميل Firebase JS SDK من gstatic (شبكة محجوبة؟)');
      }
      return true;
    },
  );

  await _step('تهيئة تطبيق Firebase', () async {
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
    return true;
  });

  await _step('توجيه Firestore إلى المحاكي', () async {
    FirebaseFirestore.instance.useFirestoreEmulator(_host, _firestorePort);
    return true;
  });

  await _step('توجيه Auth إلى المحاكي', () async {
    await FirebaseAuth.instance.useAuthEmulator(_host, _authPort);
    return true;
  });
}

/// يسجّل الدخول بحساب الاختبار ويعيد `uid` الفعلي — وهو نفسه `recipientId`
/// الذي كتبته بيانات التهيئة، لأنها أخذت uid من محاكي Auth.
Future<String> _signInAs(String email) async {
  final UserCredential credential = await FirebaseAuth.instance
      .signInWithEmailAndPassword(email: email, password: _password);
  final String? uid = credential.user?.uid;
  if (uid == null) {
    throw StateError('تسجيل الدخول لم يُرجع مستخدمًا: $email');
  }
  return uid;
}

FirestoreNotificationRepository _notifications() =>
    FirestoreNotificationRepository(
      firestore: FirebaseFirestore.instance,
    );

FirestoreMessageRepository _messages() =>
    FirestoreMessageRepository(firestore: FirebaseFirestore.instance);

List<String> _ids(List<AppNotification> items) =>
    items.map((AppNotification item) => item.id).toList(growable: false);

void main() {
  // إلزامي قبل أي استدعاء لـFirebase على الويب: `firebase_core` يمرّ على
  // `ServicesBinding` (PlatformChannel) حتى في التنفيذ الويب، وبدون التهيئة
  // يفشل setUpAll بـ«Binding has not yet been initialized».
  TestWidgetsFlutterBinding.ensureInitialized();
  // قبل أي تهيئة Firebase: بلا هذا التسجيل تبقى القناة بلا مستمع فتُعلَّق.
  _registerWebPlugins();
  setUpAll(_bootstrap);

  tearDown(() async {
    await FirebaseAuth.instance.signOut();
  });

  group('listPage — تنفيذ Firestore الحقيقي', () {
    test('كل الصفحات بلا فقد ولا تكرار وبالترتيب الصحيح', () async {
      final String uid = await _signInAs('pages@example.test');
      final FirestoreNotificationRepository repo = _notifications();

      final List<AppNotification> collected = <AppNotification>[];
      NotificationPage page = await repo.listPage(recipientId: uid, limit: 7);
      collected.addAll(page.items);

      int guard = 0;
      while (page.hasMore && guard < 20) {
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

      expect(guard, lessThan(20), reason: 'التصفّح يجب أن ينتهي');
      expect(collected.length, 48, reason: '45 إشعارًا متباعدًا + 3 متساوية الوقت');
      expect(
        collected.map((AppNotification item) => item.id).toSet().length,
        48,
        reason: 'لا تكرار بين الصفحات',
      );

      final List<String> ids = _ids(collected);
      expect(ids.sublist(0, 3), <String>['same-a', 'same-b', 'same-c']);
      expect(ids[3], 'p44', reason: 'بعده الأحدث من p ثم تنازليًا');
      expect(ids.last, 'p00', reason: 'الأقدم في النهاية');

      // ترتيب زمني تنازلي صارم في كل ما عدا الثلاثة المتساوية.
      for (int i = 4; i < collected.length; i++) {
        expect(
          collected[i - 1].createdAt.isAfter(collected[i].createdAt) ||
              collected[i - 1].createdAt.isAtSameMomentAs(
                collected[i].createdAt,
              ),
          isTrue,
          reason: 'ترتيب تنازلي عند الموضع $i',
        );
      }
    });

    test('hasMore ونهاية النتائج', () async {
      final String uid = await _signInAs('pages@example.test');
      final FirestoreNotificationRepository repo = _notifications();

      final NotificationPage all = await repo.listPage(
        recipientId: uid,
        limit: 50,
      );
      expect(all.items.length, 48);
      expect(all.hasMore, isFalse, reason: 'كل النتائج في صفحة واحدة');

      final AppNotification last = all.items.last;
      final NotificationPage afterEnd = await repo.listPage(
        recipientId: uid,
        limit: 50,
        before: last.createdAt,
        beforeId: last.id,
      );
      expect(afterEnd.items, isEmpty);
      expect(afterEnd.hasMore, isFalse);
    });

    test('لا يقرأ إشعارات مستخدم آخر (القواعد تمنع)', () async {
      await _signInAs('pages@example.test');
      // uid مختلف تمامًا عن صاحب البيانات ⇒ القواعد ترفض الاستعلام.
      await expectLater(
        _notifications().listPage(recipientId: 'someone-else', limit: 5),
        throwsA(isA<Object>()),
      );
    });
  });

  group('markChatMessagesRead — تنفيذ Firestore الحقيقي', () {
    test('يعلّم إشعارات المحادثة المحددة فقط', () async {
      final String uid = await _signInAs('student@example.test');
      final FirestoreNotificationRepository repo = _notifications();

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
      expect(byId('booking-same-target').readAt, isNull, reason: 'حجز بنفس الهدف');
      expect(byId('dm-other-chat').readAt, isNull, reason: 'محادثة أخرى');

      // تشغيل ثانٍ: لا شيء غير مقروء ⇒ صفر (ولا كتابة).
      expect(
        await repo.markChatMessagesRead(recipientId: uid, chatId: 'chat-1'),
        0,
      );

      // إشعار المستخدم الآخر عن نفس المحادثة لم يُمسّ.
      await FirebaseAuth.instance.signOut();
      final String teacherUid = await _signInAs('teacher@example.test');
      final List<AppNotification> teacherItems = await repo.listMine(teacherUid);
      expect(teacherItems.single.id, 'dm-teacher');
      expect(teacherItems.single.readAt, isNull);
    });
  });

  group('unreadCount و markRead — تنفيذ Firestore الحقيقي', () {
    test('10 رسائل لي بعد آخر قراءة + واحدة من غيري ⇒ 1', () async {
      final String uid = await _signInAs('student@example.test');
      final FirestoreMessageRepository repo = _messages();

      expect(await repo.lastReadAt(groupId: 'g1', memberId: uid), isNotNull);
      expect(await repo.unreadCount(groupId: 'g1', memberId: uid), 1);
    });

    test('غياب آخر قراءة يعني «كل رسائل الآخرين غير مقروءة»', () async {
      final String uid = await _signInAs('student@example.test');
      final FirestoreMessageRepository repo = _messages();

      expect(await repo.lastReadAt(groupId: 'g2', memberId: uid), isNull);
      expect(
        await repo.unreadCount(groupId: 'g2', memberId: uid),
        2,
        reason: 'رسالتا المدرس فقط؛ رسالة العضو نفسه لا تُحتسب',
      );
    });

    test('markRead يحدّث علامة العضو نفسه فيصفّر عدّاده', () async {
      final String uid = await _signInAs('student@example.test');
      final FirestoreMessageRepository repo = _messages();

      final DateTime before = DateTime.now().subtract(const Duration(minutes: 1));
      await repo.markRead(groupId: 'g1', memberId: uid);

      final DateTime? marker = await repo.lastReadAt(groupId: 'g1', memberId: uid);
      expect(marker, isNotNull);
      expect(marker!.isAfter(before), isTrue, reason: 'العلامة صارت الآن');
      expect(await repo.unreadCount(groupId: 'g1', memberId: uid), 0);

      // وعلامة مجموعة أخرى لم تُمسّ.
      expect(await repo.lastReadAt(groupId: 'g2', memberId: uid), isNull);
    });

    test('كتابة علامة عضو آخر مرفوضة (لا انتحال قراءة)', () async {
      await _signInAs('student@example.test');
      final FirestoreMessageRepository repo = _messages();

      await expectLater(
        repo.markRead(groupId: 'g1', memberId: 'someone-else'),
        throwsA(isA<Object>()),
      );
    });
  });
}
