# تشخيص عطل: «لا يوجد اتصال بالإنترنت» بعد اختيار حساب Google

**الحالة:** تشخيص فقط — لم يُعدَّل أي كود إنتاج في هذه الجولة.
**البناء المُختبَر:** `40844830356` (يشمل إصلاح إذن `INTERNET` في بيان release).
**التاريخ:** 2026-10-29.

---

## 0) ملخص تنفيذي — ثلاث نتائج مثبتة بالكود

| # | النتيجة | كيف أُثبتت |
|---|---|---|
| 1 | الرسالة الظاهرة تعني حرفيًا **رمز Firebase واحدًا من اثنين**: `network-request-failed` أو `unavailable`. لا شيء آخر في التطبيق ينتج هذا النص. | جرد كل منتجي `AppErrorKind.network` ومقارنة النصوص المعروضة (تفصيل في §2) |
| 2 | **نسخة التطبيق ليست تجريبية**، وFirebase مُهيَّأ فعليًا بقيم غير فارغة. | فتح نافذة اختيار الحساب مستحيل إن لم تكن الخدمات حقيقية (تفصيل في §3) |
| 3 | الرسالة **لا تأتي** من مسار `google_sign_in` ولا من مهلة الطلب ولا من الـcatch-all في مستودعات Firestore — نصوصها مختلفة. | مقارنة نصوص الـoverrides |

**ما لم يُثبت بعد:** هل الفشل في **مرحلة Firebase Auth** (`signInWithCredential`) أم في **مرحلة قراءة Firestore** (`users/{uid}`)؟ كلتاهما تنتج النص نفسه. هذا هو السؤال الوحيد المتبقي، وله تجربتان تحدّدانه **بلا أي كود** (§5).

---

## 1) المسار الكامل: من الضغط إلى الخطأ

| # | الخطوة | الموضع | ما يمكن أن يفشل هنا | الرمز المتوقع |
|---|---|---|---|---|
| 1 | ضغط الزر | `lib/features/auth/presentation/widgets/google_sign_in_button.dart:52` (`_handleTap`) | لا شيء شبكي | — |
| 2 | الشاشة تنفّذ الدخول | `lib/features/auth/presentation/login_screen.dart:34-57` | — | — |
| 3 | المتحكّم | `lib/app/session/session_controller.dart:93-96` → `_auth.signInWithGoogle()` | — | — |
| 4 | بوابة Google الأصلية | `lib/data/firebase/google_sign_in_gateway.dart:61-152` | إعداد ناقص / إلغاء / صيغة خاطئة | `unavailable` / `canceled` — **بنصوص مميّزة** |
| 5 | التحقق من `aud` | `google_sign_in_gateway.dart:118-136` | معرّف أندرويد بدل ويب | `unavailable` بنص «رمز Google صادر لعميل آخر» |
| 6 | **تبديل بيانات الاعتماد** | `lib/data/firebase/firebase_auth_service.dart:105-107` (`_auth.signInWithCredential`) | فشل النقل أو رفض الخادم للـapiKey/appId | `network-request-failed` ← **مرشح أول** |
| 7 | **قراءة مستند المستخدم** | `firebase_auth_service.dart` داخل `_resolve` → `_firestore.collection('users').doc(uid).get()` | قاعدة غير موجودة / صلاحيات / تعذّر الوصول | `unavailable` ← **مرشح ثانٍ** |
| 8 | قراءة الادعاء الإداري | `_readAdminClaim` → `getIdTokenResult()` | — | يُبتلع الخطأ ويعود `false` (لا يصل للمستخدم) |
| 9 | تحويل الخطأ | `firebase_auth_service.dart:452-460` (`_guard`) → `firebase_error_mapper.dart:104-109` | — | يحوّل إلى `AppErrorKind.network` |
| 10 | العرض | `login_screen.dart:46-57` (`AppSnackBar.show`) | — | «لا يوجد اتصال بالإنترنت — تحقّق من الاتصال ثم أعد المحاولة.» |

**ملاحظة مهمة:** الخطوة 8 **مُغطّاة** (`on Object → false`)، فلا يمكن أن تكون مصدر الرسالة.

---

## 2) جرد كل من ينتج رسالة «لا يوجد اتصال بالإنترنت»

| الموضع | الرمز/الحالة | النص المعروض | يطابق ما نراه؟ |
|---|---|---|---|
| `firebase_error_mapper.dart:104` | `network-request-failed` | «لا يوجد اتصال بالإنترنت — تحقّق من الاتصال ثم أعد المحاولة.» | ✅ **مطابق تمامًا** |
| `firebase_error_mapper.dart:105` | `unavailable` | نفس النص أعلاه | ✅ **مطابق تمامًا** |
| `google_sign_in_error_mapper.dart:56` | `interrupted` | «انقطعت عملية تسجيل الدخول — …» | ❌ نص مختلف |
| `request_timeout.dart:29` | مهلة 20 ثانية | «انتهت مهلة الاتصال — …» | ❌ نص مختلف |
| `firestore_repositories.dart:121` | catch-all لأي خطأ غير Firebase | «… — تعذّر إتمام الطلب. تحقّق من الاتصال…» | ❌ نص مختلف، **ولا يُستخدم في مسار الدخول أصلًا** |

**استنتاج قاطع (البند 6 من طلبك):** يوجد catch-all واحد ينتج رسالة شبكة، لكنه (أ) في مستودعات Firestore لا في مسار المصادقة، (ب) نصّه مختلف. إذن **لا يوجد تحويل عام يخفي نوع الخطأ في هذا المسار**؛ الرسالة صادقة بمعنى «فشل نقلي/خدمي»، لكنها **ليست دقيقة التشخيص** لأنها تغطي رمزين مختلفين تمامًا.

---

## 3) ما ثبت يقينًا — وما استُبعد

### مثبت
1. **Firebase مُهيَّأ بقيم حقيقية غير فارغة.**
   الدليل: `AppServices.bootstrap()` يعيد `AppServices.firebase()` فقط إذا كان
   `FirebaseBootstrap.status == ready` (`lib/data/services/app_services.dart`).
   وحالة `ready` لا تُضبط إلا بعد: `ENABLE_FIREBASE=true` **و** وجود القيم الخمس
   **و** نجاح `Firebase.initializeApp()`.
   ولو كانت الخدمات تجريبية لرمت `DemoAuthService` خطأ `unavailable` **فورًا بلا
   فتح أي نافذة**. وبما أن نافذة الحسابات فُتحت ⇒ الإعدادات سليمة ومُهيَّأة.
   ⇒ **البند 4 من طلبك مُجاب:** النسخة ليست تجريبية والقيم ليست فارغة.
2. **الكود لا يستخدم `signInWithProvider` بعد الآن.**
   `grep` يعطي مطابقتين فقط، وكلتاهما **تعليق** لا استدعاء
   (`firebase_auth_service.dart:99`، `google_sign_in_gateway.dart:29`).
   المسار الفعلي: `signInWithCredential(GoogleAuthProvider.credential(idToken: …))`.
3. **`serverClientId` = معرّف عميل الويب** (القيمة التي لصقتها)، ويُمرَّر في
   `initialize(serverClientId: …)` (`google_sign_in_gateway.dart:139`).
   ⇒ البند 5 من طلبك: الإعداد **مطابق للصيغة المطلوبة** نظريًا، لكن صحّة
   `client_type` لا تُثبت إلا بالتحقق من `google-services.json` أو من `aud` في
   الرمز (لدينا فحص `aud` صارم الآن، ورسالته مميّزة — ولم تظهر لك ⇒ إما أن
   `aud` مطابق، أو تعذّر فكّ الرمز فمررناه لـFirebase).
4. **إذن `INTERNET` موجود فعلًا في الـAPK** (CI: 2 من 2 بعد فكّ ضغط البيان).

### مستبعد (بدليل، لا برأي)
- الرسالة ليست من مهلة 20 ثانية (نصّها مختلف، ومسار الدخول لا يستخدم `withRequestTimeout` أصلًا).
- ليست من `google_sign_in` (نصّه مختلف).
- ليست من خطأ صلاحيات Firestore (`permission-denied` → «لا تملك صلاحية لهذا المحتوى»).
- ليست من قاعدة بيانات غير موجودة **إن** أعادت Firestore الرمز `not-found` (رسالته مختلفة) — لكن قد تعيد `unavailable` في بعض حالات عدم التهيئة، ولهذا تبقى فرضية مفتوحة.
- ليست خطأ بريد/كلمة مرور (نصوصها مختلفة).

### غير محسوم — ويحتاج الجهاز
التمييز بين المرحلتين 6 و7 في الجدول أعلاه. **لا أستطيع استخراجه من هنا**:
لا يمكنني تثبيت APK، ولا قراءة سجلات GitHub، ولا تحميل الـartifacts (النطاق
`productionresultssa5.blob.core.windows.net` محجوب في هذه البيئة).

---

## 4) الفرضيات المرتّبة + الدليل الذي يميّز كل واحدة

| # | الفرضية | المرحلة | الدليل المميّز (ما تراه) | أصغر إصلاح إن تأكدت |
|---|---|---|---|---|
| H1 | **Firestore**: قراءة `users/{uid}` فشلت بـ`unavailable` (قاعدة غير مُنشأة، أو Cloud Firestore API معطّل، أو حجب شبكي لمنفذ gRPC) | 7 | المستخدم **يظهر** في Authentication ← Users بعد المحاولة | إنشاء قاعدة Firestore (production mode) في المشروع نفسه، أو تفعيل الـAPI — **لا تغيير في الكود** |
| H2 | **Auth**: `signInWithCredential` فشل بـ`network-request-failed` لأسباب ليست الشبكة: `apiKey`/`appId` خاطئ أو من مشروع آخر (لم نتحقق من قيمة السرّين يومًا — تحققنا من **وجودهما** فقط) | 6 | المستخدم **لا يظهر** في Authentication ← Users | تصحيح `FIREBASE_API_KEY` / `FIREBASE_APP_ID` في الأسرار ثم إعادة بناء |
| H3 | تقييد مفتاح API على Android لا يطابق بصمة/حزمة | 6 | logcat يحوي `403` أو `Requests from this Android client application are blocked` | إصلاح التقييد **بإضافة** البصمة (`47:48:68:…:6F`) لا بإلغاء التقييد |
| H4 | حجب شبكي على مستوى التطبيق فقط (Data Saver / قيد بيانات لكل تطبيق على OriginOS-Vivo، VPN، Private DNS) — نافذة الحسابات تعمل لأنها من Play Services لا من مقابس تطبيقنا | 6 و7 | يفشل كل شيء شبكي في التطبيق، وينجح عبر شبكة أخرى (Wi-Fi بدل 4G أو العكس) | استثناء التطبيق من قيود البيانات — **لا تغيير في الكود** |
| H5 | مشروع Firebase نسخة أخرى/بيئة ثانية: المشروع `954683127001` موجود لكنه بلا Firestore أو بلا مزوّد Google مُفعّل | 6/7 | Authentication ← Sign-in method: Google = Enabled؟ وFirestore: قاعدة موجودة؟ | تفعيل المزوّد/إنشاء القاعدة في اللوحة |

**ملاحظة على H2:** الدليل الجزئي المؤيد لها أن `FIREBASE_MESSAGING_SENDER_ID`
يطابق رقم معرّف عميل الويب (`954683127001`) — أي أن **المرسل** من نفس المشروع.
لكن `FIREBASE_API_KEY` و`FIREBASE_APP_ID` لم يُتحقق من قيمتهما ولا من انتمائهما
للمشروع نفسه (السكربت يطبع «موجود» فقط). هذا ثقب حقيقي في تحققنا السابق.

---

## 5) تجربتان تحدّدان المرحلة — بلا كود ولا بناء جديد

### التجربة أ: قائمة المستخدمين في Firebase Console
1. افتح **Firebase Console ← Authentication ← Users** لِمشروع `954683127001`.
2. على الهاتف: أعد المحاولة (زر Google ← اختر الحساب ← ستظهر الرسالة).
3. حدّث قائمة Users:

| ما تراه | الاستنتاج |
|---|---|
| **حسابك ظهر** (بريدك + مزوّد Google) | Auth **نجح** ⇒ الفشل في **Firestore** ⇒ H1 |
| **لا يظهر شيء جديد** | الفشل في **`signInWithCredential`** ⇒ H2/H3/H4 |

> القيمة العلمية لهذه التجربة: تفصل بين مرحلتين تنتجان الرسالة نفسها، بلا أي تعديل.

### التجربة ب: سلوك إعادة التشغيل (تكشف عطلًا كامنًا أيضًا)
أغلق التطبيق تمامًا (من قائمة التطبيقات الحديثة) ثم افتحه:

| السلوك | الاستنتاج |
|---|---|
| تظهر شاشة الدخول عاديًا | لا جلسة محفوظة ⇒ Auth لم ينجح (H2/H3/H4) |
| **يدخل مباشرة إلى واجهة التطبيق** | Auth كان قد نجح وحُفظت الجلسة ⇒ H1، والفشل السابق كان مؤقتًا |
| **شاشة بيضاء / توقف عند الإقلاع** | H1 مؤكد + عيب كامن جديد (انظر §9) |

### التجربة ج (إن أمكن): `adb logcat`
```bash
# 1) امسح السجل ثم ابدأ التسجيل
adb logcat -c
adb logcat -v time > darsly-login.log      # اتركه يعمل

# 2) على الهاتف: اضغط زر Google ← اختر الحساب ← انتظر ظهور الرسالة

# 3) أوقف التسجيل (Ctrl+C) ثم ابحث:
```
```bash
grep -iE "firebase|firestore|grpc|auth|network|403|unavailable" darsly-login.log
```

**ما الذي يثبت أي فرضية (سطور فعلية من مكتبات Firebase الأصلية، لا من كودنا):**

| السطر المتوقع | الدلالة |
|---|---|
| `FirebaseAuth` + `ERROR_NETWORK_REQUEST_FAILED` أو `A network error …` | المرحلة 6 (Auth) |
| `Firestore` / `FirestoreGrpc` + `UNAVAILABLE` أو `io exception` | المرحلة 7 (Firestore) |
| `PERMISSION_DENIED` أو `API key not valid` أو `403` | H2/H3 (مفتاح/تقييد) |
| `NOT_FOUND` + `database … does not exist` | H1 (قاعدة غير مُنشأة) |
| لا شيء على الإطلاق من Firebase في السجل | H4 (لم تخرج أي حزمة من التطبيق) |

---

## 6) تسجيل تشخيصي آمن ومؤقت (جاهز — **لم يُطبَّق**)

الغرض: تحديد **اسم المرحلة** و**نوع الاستثناء** و**رمز Firebase** فقط. لا يسجّل
ID token ولا access token ولا كلمة مرور ولا بريدًا. يُطبع في السجل **ويظهر على
الشاشة** لتتمكن من تصويره بلا adb.

```dart
// firebase_auth_service.dart — تشخيص مؤقت، يُزال بعد تحديد السبب.

// 1) حقل يحمل اسم المرحلة الحالية
String _diagStage = 'لم تبدأ';

@override
Future<AuthResult> signInWithGoogle() {
  return _guard(() async {
    _diagStage = '1-obtainIdToken';
    final String idToken = await _googleSignIn.obtainIdToken();

    _diagStage = '2-signInWithCredential';
    final UserCredential result = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );

    _diagStage = '3-resolve/firestore';
    return _resolve(result.user!);
  });
}

// 2) في _guard: نُظهر المرحلة والرمز في الرسالة المعروضة
Future<AuthResult> _guard(Future<AuthResult> Function() action) async {
  try {
    return await action();
  } on FirebaseAuthException catch (error) {
    throw _diag(error.code, error.message);
  } on FirebaseException catch (error) {
    throw _diag(error.code, error.message);
  }
}

AppException _diag(String code, String? message) {
  // آمن: رمز الخطأ واسم المرحلة فقط.
  debugPrint('[DIAG-auth] stage=$_diagStage code=$code message=$message');
  final AppException mapped = firebaseCodeToException(code, debugMessage: message);
  return AppException(
    mapped.kind,
    debugMessage: mapped.debugMessage,
    overrideTitle: mapped.title,
    overrideMessage: '${mapped.message}\n[تشخيص: $code @ $_diagStage]',
  );
}
```

**ما ستحصل عليه بعد تصوير الشاشة:** سطر مثل
`[تشخيص: network-request-failed @ 2-signInWithCredential]`
أو `[تشخيص: unavailable @ 3-resolve/firestore]` — وهذا يحسم المسألة نهائيًا.

---

## 7) أصغر إصلاح مطلوب (لكل فرع)

| إن كانت النتيجة | أصغر إصلاح | ما لا يلزم |
|---|---|---|
| `2-signInWithCredential` | تصحيح قيمة `FIREBASE_API_KEY` و`FIREBASE_APP_ID` في الأسرار (تأكيد انتمائهما لمشروع `954683127001` وكون `appId` بصيغة `1:954683127001:android:…`) | لا تغيير في كود Dart |
| `2-…` + `403` في السجل | إضافة البصمة `47:48:68:E2:9D:D9:AD:49:B2:FC:08:4F:CA:10:D5:46:84:8B:E8:6F` إلى تقييد المفتاح | **لا** نضع التقييد على `None` (كما طلبت) |
| `3-resolve/firestore` | إنشاء قاعدة Firestore في المشروع نفسه، أو تفعيل Cloud Firestore API | لا تغيير في الكود |
| لا سطور Firebase في السجل | استثناء التطبيق من قيود البيانات/الـVPN | لا تغيير في الكود |

**وفي كل الحالات** (تحسين دقة الرسالة، لا إصلاح السبب): التفريق بين
`network-request-failed` و`unavailable` في `firebase_error_mapper.dart` برسالتين
مختلفتين، حتى لا يرى المستخدم «لا يوجد اتصال» عند خطأ إعداد. سأتركه لك كقرار
لأنه يغيّر نصًا يراه المستخدم.

---

## 8) عيب كامن مستقل اكتُشف أثناء التتبع

`lib/app/bootstrap.dart:49` → `await session.restore();` بلا `try/catch`،
و`SessionController.restore()` بلا حماية كذلك. وأي خطأ Firestore هنا يسقط
`bootstrap()` قبل `runApp` ⇒ **شاشة سوداء/بيضاء عند الإقلاع لمستخدم مسجّل**.
هذا لا يفسّر عطلنا الحالي (لأنك ترى شاشة الدخول)، لكنه سيصبح مرئيًا فور نجاح
الدخول مع أي تعطّل لاحق في Firestore. **لم أُصلحه** (تشخيص فقط).

---

## 9) ما لم أفعله عمدًا

- لم أُعدّل أي ملف إنتاج.
- لم أضع قيود API على `None`.
- لم أغيّر معرّفات التطبيق ولا إعدادات Firebase.
- لم أعتبر نجاح `analyze`/`test`/البناء دليلًا على حل المشكلة.
- لم أقدّم أي "إصلاح" جديد قبل تحديد المرحلة بدليل.
