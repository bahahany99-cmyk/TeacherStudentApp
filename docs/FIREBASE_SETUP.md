# دليل ربط Firebase — خطوات خارجية مطلوبة

> **الحالة الآن:** المشروع مكتوب بالكامل للعمل مع Firebase، لكن **لا يوجد مشروع
> Firebase مُنشأ** ولا أي بيانات اعتماد في المستودع. التطبيق يبقى في الوضع
> التجريبي حتى تنفّذ الخطوات في §3. هذا الملف هو العقد بين ما ينفّذه الكود وما
> يجب أن تفعله أنت خارجيًا.

---

## 1. ما هو منفَّذ في الكود (P4)

| العنصر | الملف | الحالة |
|---|---|---|
| تهيئة Firebase معزولة عن الواجهات | `lib/core/config/firebase_bootstrap.dart` | ✅ منفَّذ — الفشل لا يعطّل التطبيق |
| إعدادات المشروع من `--dart-define` | `lib/core/config/firebase_config.dart` | ✅ منفَّذ — بلا ملفات أسرار في Git |
| مصادقة Google + بريد/كلمة مرور | `lib/data/firebase/firebase_auth_service.dart` | ✅ مكتوب مقابل `firebase_auth` |
| مستند المستخدم والدور (`users/{uid}`) | نفسه | ✅ قراءة عند كل دخول + كتابة مرة واحدة عند الاختيار |
| شاشة اختيار الدور (أول دخول فقط) | `lib/features/auth/presentation/role_selection_screen.dart` | ✅ منفَّذ |
| شاشة البريد/كلمة المرور | `lib/features/auth/presentation/email_auth_screen.dart` | ✅ منفَّذ |
| ترجمة أخطاء Firebase إلى عربية | `lib/core/errors/firebase_error_mapper.dart` | ✅ منفَّذ + مُختبَر |
| أدنى إصدار أندرويد | `tool/scaffold_android.sh` | ✅ `minSdk = 23` (متطلب Auth/Firestore) |
| قواعد أمان Firestore | — | ❌ **لم تُكتب ولم تُنشر** (تحتاج موافقتك — قاعدة A-09) |
| مستودعات Firestore (مدرسون/مجموعات/حجوزات) | — | ❌ **P5** — ما زالت تجريبية |

### ما يكتبه التطبيق في Firestore (فقط)

```jsonc
// users/{uid}
{
  "displayName": "…",
  "email": "…",            // أو null
  "role": "student",       // أو "teacher" — يُكتب مرة واحدة فقط
  "createdAt": <Timestamp>,
  "roleChosenAt": <Timestamp>
}
```

ويُكتب معه (P22) رقم الصورة الافتراضية **مرة واحدة عند الإنشاء فقط**
(`avatarPreset` من 0 إلى 5) — لا يُعاد ضبطه عند أي نداء تالٍ.

وعند اختيار الدور «مدرس» يُنشأ في نفس دفعة الكتابة `teacherProfiles/{uid}`:

```jsonc
{
  "ownerId": "<uid>",
  "displayName": "…",
  "status": "draft",        // P22: مسودة — لا تُرسل للمراجعة قبل الصورة
  "accountHidden": false,   // منذ الإنشاء: استعلامات الاكتشاف تفلتر عليه
  "createdAt": <Timestamp>
}
```

ثم عند أول حفظ للنموذج تُضاف الحقول الوصفية و`photoPath = "avatars/<uid>"`
وتصبح الحالة `pendingReview`. ولا تصبح `verified` إلا بقرار إداري.

لا يكتب التطبيق أي حقل إداري (`approved`, `isFeatured`, `isAdmin`…) ولا أي
قاعدة أمان. الدور يُقرأ من الخادم في كل دخول؛ وتغييره بعد الاختيار لا يحدث من
التطبيق. **ملف مدرس موجود لا يُعاد ضبطه أبدًا** (حالته قرار إداري).

### سياسة قواعد الأمان المعتمدة (2026-10-27) — تُكتب في P5

1. `users/{uid}`: قراءة وكتابة لصاحبه فقط؛ `role` لا يتغيّر بعد الكتابة الأولى،
   و`avatarPreset` (0..5) يكتبه صاحبه فقط.
2. `teacherProfiles/{uid}`: قراءة للطلاب على الملفات `verified` فقط؛ صاحبه يقرأ
   ملفه بكل حالاته ولا يغيّر `ownerId`. الحالة تنتقل عبر
   `ownerStatusTransitionAllowed` فقط: `pendingReview` **مقفل**، و`verified`
   يعود `pendingReview` عند أي تعديل (إعادة تحقق)، و`draft`/`rejected` تُعاد
   إرسالها.
3. `avatars/{uid}` (P22): يكتبها صاحبها فقط؛ النوع `image/jpeg` أو `image/png`
   وطول base64 بين 64 و200000 و`updatedAt` من نوع timestamp. القراءة لأي
   مستخدم مسجّل (صورة المدرس تظهر في ملفه).
4. لا وصول إداري من التطبيق: الاعتماد والتمييز بأدوات إدارية خارجية.

### وضع الزائر

قبل إنشاء المشروع يمكن تجربة التطبيق كاملًا: شاشة الدخول ← «وضع الزائر (بدون
حساب)». البيانات محلية، والشريط والوسم «زائر» يوضّحان ذلك، ولا يُلمس أي شيء من
Firebase في هذا المسار.

## 2. ما لا يمكن تنفيذه من داخل بيئة التطوير

1. **إنشاء مشروع Firebase** — يتطلب حسابك وملكيته (قاعدة A-08). **أنت** من ينشئه.
2. **بصمات SHA-1 / SHA-256** — تُستخرج من مفتاح التوقيع؛ بدونها لا يعمل Google.
3. **تفعيل المزوّدات** — يُفعَّل من Firebase Console، لا من الكود.
4. **اختبار الدخول فعليًا** — يحتاج جهازًا/محاكيًا ومشروعًا حقيقيًا؛ لا يمكن
   التحقق منه في CI.

## 3. الخطوات المطلوبة بالترتيب

### 3.1 إنشاء المشروع (مرة واحدة)

1. Firebase Console ← **Add project**. اختر اسمًا للمشروع.
2. بعد الإنشاء: **Firestore Database ← Create database**.
   - **المنطقة: `me-central1`** (قرار صاحب المشروع 2026-10-27، A-22).
   - ⚠️ **المنطقة لا تُغيَّر بعد الإنشاء** بلا ترحيل مكلف — تأكّد قبل الضغط.
   - ابدأ في وضع **Production mode** (لا قواعد مفتوحة)؛ القواعد تُكتب في مرحلة
     لاحقة بموافقتك.
3. **Authentication ← Get started**، ثم فعّل:
   - **Email/Password**
   - **Google** (يطلب بريد دعم للمشروع)
4. **Project settings ← Your apps ← Add app ← Android**:
   - Android package name: **`com.darsly.app`** (G1 المعتمد).
   - App nickname: `درسلي (dev)`.
   - **Add fingerprint**: SHA-1 لبناء التطوير، ثم SHA-256.
     استخرجه من جهازك:
     ```bash
     # مفتاح التصحيح الافتراضي
     keytool -list -v -keystore ~/.android/debug.keystore \
       -alias androiddebugkey -storepass android -keypass android
     ```
     (لمفتاح إصدار لاحقًا: `keytool -list -v -keystore <your>.jks`.)

### 3.2 الحصول على قيم الإعدادات

من **Project settings ← General ← Your apps ← SDK setup and configuration**،
انسخ:

| القيمة في Console | متغيّر `--dart-define` |
|---|---|
| `project_id` | `FIREBASE_PROJECT_ID` |
| `mobilesdk_app_id` | `FIREBASE_APP_ID` |
| `api_key.current_key` | `FIREBASE_API_KEY` |
| `project_number` | `FIREBASE_MESSAGING_SENDER_ID` |
| `storage_bucket` | `FIREBASE_STORAGE_BUCKET` |

> ملاحظة: يمكنك أيضًا تنزيل `google-services.json` واستخدامه محليًا (مستثنى
> من Git)، لكن الطريقة المعتمدة في هذا المستودع هي `--dart-define` لأنها
> تُبقي البناء والاختبار يعملان بلا أي ملف أسرار.

### 3.3 تشغيل النسخة المتصلة

```bash
flutter run \
  --dart-define=ENABLE_FIREBASE=true \
  --dart-define=FIREBASE_PROJECT_ID=<project_id> \
  --dart-define=FIREBASE_APP_ID=<mobilesdk_app_id> \
  --dart-define=FIREBASE_API_KEY=<api_key> \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<project_number> \
  --dart-define=FIREBASE_STORAGE_BUCKET=<storage_bucket>
```

لبناء APK متصل (يدويًا من Actions) أضف نفس القيم في خطوة البناء، أو شغّله
محليًا بالأمر أعلاه مع `build apk`.

### 3.4 نشر قواعد الأمان (إلزامي قبل أي تجربة حقيقية)

القواعد في `firestore.rules` مكتوبة ومُختبرة على المحاكي (234 حالة)، لكنها **لم
تُنشر**. بدون نشرها سيبقى الوصول إلى Firestore مفتوحًا أو مغلقًا حسب إعدادك
اليدوي، ولن يعمل حذف الحساب ولا الاكتشاف.

```bash
# مرة واحدة: ربط المشروع المحلي بمشروعك
firebase login
firebase use --add            # اختر مشروعك، والاسم المقترح: default

# نشر القواعد فقط (لا Functions ولا Storage في هذا الإصدار)
firebase deploy --only firestore:rules
```

بعد النشر، تحقق سريعًا من Console ← Firestore ← Rules (يظهر تاريخ النشر).

### 3.5 حقول جديدة يكتبها التطبيق (P17)

منذ P17 يكتب التطبيق — في **حزمة كتابة واحدة** — حالتين إضافيتين عند طلب حذف
الحساب، ويقرأهما عند الدخول ليعرض شاشة الاستعادة:

```jsonc
// users/{uid} — عند طلب الحذف فقط
{
  "status": "pending_deletion",              // أو "active" بعد الاستعادة
  "scheduledDeletionAt": <Timestamp>          // الآن + 7 أيام، يُحذف عند الاستعادة
}

// teacherProfiles/{uid} (للمدرس وحده) — في نفس الحزمة
{ "accountHidden": true }                     // false عند الاستعادة
```

`accountHidden` يخرج الملف من الاكتشاف فورًا، ويجب أن يوجد بـ`false` **منذ
الإنشاء** (يكتبه التطبيق)، لأن استعلامات البحث تفلتر عليه صراحةً. القواعد
تسمح بهذه الكتابة وحدها (`onlyHidingFlagChanged`) على ملف موثّق أو منتظر
مراجعة: لا محتوى ولا حالة يتغيّران معها.

### 3.5-ب صور الحساب (P22) — لماذا Firestore لا Storage

المشروع **لا يستخدم Firebase Storage**: لا حزمة في `pubspec.yaml`، ولا قسم
`storage` في `firebase.json`، ولا قواعد Storage، والمحاكي المستخدم في CI هو
Firestore فقط. إضافة مسار تخزين كامل غير قابل للاختبار كانت ستعني ميزة غير
مُختبرة، فالقرار المتعمّد:

- الصورة تُصغَّر وتُضغط على الجهاز (`image_picker` بـ`maxWidth: 512`،
  `imageQuality: 80`) قبل أي كتابة.
- تُحفظ base64 في مستند **مستقل** `avatars/{uid}` (وليس في `users/{uid}` ولا
  `teacherProfiles/{uid}`: هذان يُقرآن في كل دخول وكل نتيجة بحث).
- الصورة الافتراضية **مرسومة** بـFlutter من معرّف المستخدم، فلا شبكة ولا أصول.

**ما لا يقدّمه هذا المسار:** لا CDN ولا أحجام متعددة ولا ضغط على الخادم. عند
عشرات الآلاف من المستخدمين يصبح Storage هو الخيار الصحيح، والانتقال لا يغيّر
الواجهات: كلها تقرأ عبر `AvatarRepository`.

### 3.6 بصمة SHA لبناءات CI (مهم قبل Google Sign-In)

`flutter build apk` في Actions يُنتج APK موقّعًا بمفتاح **debug يُولَّد على كل
runner**، وقياسًا تبيّن أن بصمته تتغيّر بين بناءين متتاليين. لذلك:

- ✅ **البصمة الثابتة المعتمدة (مفتاح الإصدار الدائم، P17):**
  `47:48:68:E2:9D:D9:AD:49:B2:FC:08:4F:CA:10:D5:46:84:8B:E8:6F` (SHA-1) و
  `0B:5B:2E:67:1B:76:0D:5C:10:03:6B:79:EC:98:67:D4:67:26:B6:0C:9B:87:99:62:E8:54:1C:EC:C8:16:F5:7E`
  (SHA-256) — تُسجَّل مرة واحدة في Firebase Console ولا تتغيّر.
- ❌ **لا تُسجّل** بصمة APK مأخوذة من build في Actions **قبل** رفع أسرار
  keystore: حينها يُوقّع بمفتاح debug عابر تتغيّر بصمته في كل بناء.
- ✅ سجّل بصمة **مفتاحك الثابت**: مفتاح التصحيح على جهازك، ومفتاح الإصدار الذي
  تضعه في أسرار CI.

```bash
# مفتاح التصحيح على جهازك (يكفي لتجربة Google Sign-In محليًا)
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android

# مفتاح الإصدار (يُسجَّل للإطلاق)
keytool -list -v -keystore darsly-release.p12 -storetype PKCS12 -alias darsly
# أو من داخل android/:  ./gradlew signingReport
```

لجعل بناءات CI موقّعة بمفتاح ثابت، أضف الأسرار الأربعة (انظر `docs/SIGNING.md`):
`DARSLY_KEYSTORE_BASE64` · `DARSLY_STORE_PASSWORD` · `DARSLY_KEY_ALIAS` ·
`DARSLY_KEY_PASSWORD`. بعدها تصبح بصمة كل بناء ثابتة وقابلة للتسجيل مرة واحدة.
✅ (P17/P18) تم رفع الأسرار الأربعة، وبناء `40821394239` أثبت أن الـAPK
موقّع بـ`47:48:68:…:6F`، وهي البصمة المطلوبة في §3.8.

### 3.7 أول تشغيل: ما يجب أن يحدث

1. شاشة الدخول: زر Google وزر «الدخول بالبريد الإلكتروني» يعملان (لا رسالة
   «غير متاحة»).
2. بعد أول دخول تظهر **شاشة اختيار نوع الحساب** مرة واحدة.
3. بعد الاختيار: يُكتب `users/{uid}.role` وتُفتح الواجهة المناسبة.
4. في الدخول التالي **لا تظهر شاشة الاختيار** (الدور يُقرأ من الخادم).
5. بطاقة «معاينة الواجهات» تختفي تلقائيًا (لأنها تظهر فقط في
   `AppConfig.isDemoMode`).
6. «حسابي ← إعدادات الحساب ← تسجيل الخروج» يعمل، و«منطقة الخطر ← حذف الحساب»
   يسجّل الخروج فورًا، ثم تسجيل الدخول مرة أخرى يعرض **شاشة الاستعادة**.

### 3.8 تسجيل الدخول بـGoogle عبر الـSDK الأصلي (P18) — خطوة إعداد واحدة

**ماذا تغيّر؟** كان الدخول بـGoogle يمرّ عبر `signInWithProvider` في
`firebase_auth`، وهو يفتح **متصفحًا/صفحة ويب** ويعتمد على redirect. على أندرويد
ظهر الفشل كرسالة «لا يوجد اتصال بالإنترنت — تحقّق من الاتصال» رغم وجود شبكة،
لأن المشكلة في إعداد الـredirect لا في الشبكة.

الآن: حزمة `google_sign_in` (SDK أصلي، Credential Manager) تعرض **قائمة حسابات
Google المدمجة في النظام**، ثم نأخذ `idToken` ونمرّره إلى Firebase عبر
`GoogleAuthProvider.credential(idToken: …)` ثم `signInWithCredential`.
**لا متصفح، ولا redirect، ولا `google-services.json`.**

**ما يلزم منك (مرة واحدة):**

1. **بصمة SHA-1 مسجّلة** في Firebase ← Project settings ← Your apps ← تطبيق
   أندرويد (`com.darsly.app`) ← *Add fingerprint*. القيمة هي بصمة مفتاح
   الإصدار الدائم:
   `47:48:68:E2:9D:D9:AD:49:B2:FC:08:4F:CA:10:D5:46:84:8B:E8:6F`
   (وإن جرّبت بناء debug محليًا، أضف بصمة مفتاح debug أيضًا:
   `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`).
   ⚠️ بصمة واحدة مفقودة = الدخول يفشل، وكثيرًا ما يظهر ذلك كـ«إلغاء» لا كخطأ.

2. **معرّف عميل الويب (Web client ID)** — هذا هو *جمهور* الـ`idToken`:
   - Firebase Console ← Project settings ← General ← *Your apps* ← انزل إلى
     **Web apps**؛ إن لم يوجد تطبيق ويب فأضِفه (اسم أي شيء). أو:
   - Google Cloud Console ← APIs & Services ← Credentials ← انسخ
     `Client ID` الخاص بـ **Web client (auto created by Google Service)**.
   - الشكل: `123456789012-xxxxxxxxxxxxxxxx.apps.googleusercontent.com`.

3. **أضِفه سرًّا في GitHub** (اسم السر بالحرف). يقبل الـworkflow أربعة
   أماكن بديلة ويأخذ أول قيمة موجودة:
   `FIREBASE_GOOGLE_WEB_CLIENT_ID` أو `GOOGLE_WEB_CLIENT_ID` — في تبويب
   **Secrets** أو **Variables** (يُفضَّل Secrets). سبب هذا التسامح العملي:
   أظهر بناء فعلي `FIREBASE_GOOGLE_WEB_CLIENT_ID=غائب` رغم إضافة المستخدم له،
   والسببان الأشيع: اسم بلا بادئة `FIREBASE_`، أو إضافته في تبويب Variables.
   يُمرَّر إلى البناء باسم `--dart-define=FIREBASE_GOOGLE_WEB_CLIENT_ID` في كل
   الأحوال، ولا يُطبع في السجلات أبدًا.
   ```bash
   gh secret set FIREBASE_GOOGLE_WEB_CLIENT_ID --repo bahahany99-cmyk/TeacherStudentApp
   # الصق القيمة ثم Enter (لا تُمرّرها في سطر الأوامر حتى لا تُسجَّل في history)
   ```
   ثم أعد البناء (`[build-release]`). سيطبع تقرير CI
   `FIREBASE_GOOGLE_WEB_CLIENT_ID=موجود`.
   للتشغيل المحلي:
   ```bash
   flutter run --dart-define=ENABLE_FIREBASE=true \
     --dart-define=FIREBASE_PROJECT_ID=… --dart-define=FIREBASE_API_KEY=… \
     --dart-define=FIREBASE_APP_ID=… --dart-define=FIREBASE_MESSAGING_SENDER_ID=… \
     --dart-define=FIREBASE_GOOGLE_WEB_CLIENT_ID=…
   ```

**البديل الدائم (بلا أي سر) — المستخدم فعلًا:** القيمة موجودة الآن في
`lib/core/config/firebase_public_defaults.dart` → `googleWebClientId` =
`954683127001-v0sp63b397kru2066h81bta98un40v2d.apps.googleusercontent.com`
(رقم مشروع Firebase: `954683127001`). هي القيمة اللازمة، وتُحقِّق الشرط الذي
تفرضه الحزمة (جمهور `idToken` = عميل **ويب** من نفس مشروع Firebase).
هي معرّف عام يظهر داخل كل APK أصلًا، وإضافتها هناك تجعل الدخول يعمل في أي
بناء (CI أو محلي أو نسخة تُعطى لشخص آخر). الأولوية تبقى لقيمة
`--dart-define` إن وُجدت.

**إن نسيت الخطوة 3:** لن يفشل البناء؛ سيظهر زر Google ويعرض عند الضغط
«تسجيل الدخول بـGoogle غير مُهيّأ — معرّف عميل الويب غير موجود…». هذا سلوك
مقصود بدل فشل غامض (انظر `GoogleSignInGateway`).

**تشخيص سريع للأعراض:**

| ما تراه | المعنى | ما تفعله |
|---|---|---|
| «لا يوجد اتصال بالإنترنت» بعد اختيار الحساب | غالبًا **إذن INTERNET غائب من بيان release** | §3.9 — حدّث البناء |
| «رمز Google صادر لعميل آخر» | `serverClientId` ليس معرّف عميل الويب المتوقع | §3.8 الخطوة 2 |
| «تعذّر التحقق من حساب Google» (`invalid-idp-response`) | الرمز لم يُقبل: عميل أندرويد بدل ويب، أو بصمة مختلفة | §3.8 الخطوتان 1 و2 |

| ما تراه | المعنى | ما تفعله |
|---|---|---|
| «إعداد Google غير مكتمل» (`clientConfigurationError`) | بصمة SHA-1 أو اسم الحزمة غير مسجّل، أو معرّف عميل الويب خطأ | راجع 1 و2 أعلاه |
| «أُلغي تسجيل الدخول» مباشرة بعد اختيار الحساب | غالبًا **خطأ إعداد** لا إلغاء (توثيق الحزمة صريح في ذلك) | راجع 1 و2 أعلاه |
| «تعذّر إكمال الدخول بـGoogle» | عاد `idToken` فارغًا | معرّف عميل الويب ناقص أو ليس من نفس المشروع |
| يعمل على جهاز ولا يعمل على آخر | بصمة البناء مختلفة (debug/release) | أضف البصمة الناقصة |

### 3.9 `network-request-failed` في نسخة release: إذن الإنترنت (عطل حقيقي)

**العَرَض:** تُختار نافذة Google الأصلية ويعود الحساب بنجاح، ثم يفشل الطلب إلى
Firebase فورًا برسالة «لا يوجد اتصال بالإنترنت — تحقّق من الاتصال» مع أن
الشبكة تعمل (4G ظاهر، وتطبيقات أخرى تعمل).

**السبب:** قالب Flutter يضع
`<uses-permission android:name="android.permission.INTERNET"/>` في
`android/app/src/debug/AndroidManifest.xml` و
`src/profile/AndroidManifest.xml` **فقط**. نسخة **release** لا تحتوي إذنه إن لم
يُضَف إلى `src/main/AndroidManifest.xml`، فتفشل كل طلبات الشبكة أصلًا.

**الإصلاح:** `tool/scaffold_android.sh` يضيف الآن `INTERNET` و
`ACCESS_NETWORK_STATE` إلى البيان الرئيسي، ويتحقق من وجودهما (يفشل البناء إن
غابا). و`.github/workflows/build.yml` يطبع دليلًا من **البيان المدموج** ومن
داخل الـAPK.

**كيف تتأكد بنفسك على جهاز متصل:**
```bash
adb shell dumpsys package com.darsly.app | grep -i permission
# يجب أن يظهر android.permission.INTERNET
```

### 3.10 إن استمر `network-request-failed` بعد §3.9

الاحتمال التالي بالترتيب هو **تقييد مفتاح API** في Google Cloud Console
(APIs & Services ← Credentials ← عنصر `Android key (auto created by Firebase)`
← *Application restrictions*). إن كان مضبوطًا على Android مع اسم حزمة/بصمة
مختلفة عن بصمة توقيعنا، فسيرد Google على الطلبات بـ403، ويظهر ذلك في التطبيق
كرسالة شبكة لا كرسالة إعداد.

**الفحص:** اسم الحزمة يجب أن يكون `com.darsly.app`، والبصمة المسجّلة يجب أن
تكون إحدى هذه:

| مفتاح | SHA-1 |
|---|---|
| الإصدار الدائم (CI) | `47:48:68:E2:9D:D9:AD:49:B2:FC:08:4F:CA:10:D5:46:84:8B:E8:6F` |
| debug محلي (`~/.android/debug.keystore`) | يظهر من `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android` |

**حلّ سريع للتحقق (مؤقت):** ضع التقييد على *None* ثم أعد المحاولة؛ إن نجح
الدخول فالمشكلة في التقييد لا في الكود، ثم أعد التقييد بعد إضافة البصمة.

**تأكيد من الجهاز:** `adb logcat | grep -i "FirebaseAuth\|googleusercontent\|403"`
يعرض رمز HTTP الحقيقي.

### 3.11 منح صلاحية الإدارة (P19) — لا يمكن أن تُمنح من التطبيق

لوحة الإدارة وقرار التوثيق محميّان في `firestore.rules`، ولا يوجد أي مسار في
التطبيق يمنح الصلاحية. الطريقتان المعتمدتان (اختر واحدة، أو استخدم الاثنتين):

**الطريقة أ — Custom Claim (الأقوى، وتعمل للقراءة والكتابة):**

```bash
# مرة واحدة لكل مسؤول. تتطلب مفتاح خدمة (Service Account) خارج التطبيق.
# ملف المفتاح لا يُرفع إلى Git ولا يُضمَّن في التطبيق.
node -e "
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./service-account.json')) });
admin.auth().getUserByEmail('ADMIN_EMAIL').then(async (u) => {
  await admin.auth().setCustomUserClaims(u.uid, { admin: true });
  console.log('claim set for', u.uid);
});
"
```

بعدها يجب أن **يخرج المسؤول ويعيد الدخول** (أو يُحدَّث رمز الهوية)، لأن الادعاء
يُقرأ من الرمز الحالي.

**الطريقة ب — دور المستند (بلا مفتاح خدمة، من Firebase Console):**

افتح `Firestore → users → {uid المسؤول}` واجعل `role` = `"admin"`. هذا الحقل:

- لا يكتبه التطبيق: `allow create` يقبل `student`/`teacher` فقط، و`allow update`
  يشترط `role == resource.data.role` — فلا يمكن لأحد ترقية نفسه.
- تقرؤه القواعد بـ`get()` في `isAdminDoc()` و`isAdminWriter()`، فيكفي للكتابة
  الإدارية (توثيق/رفض/حسم بلاغ/حذف/تمييز) ولقراءة طابور التوثيق والبلاغات.

| القدرة | `isAdmin()` (Claim) | `isAdminDoc()` (دور المستند) |
|---|---|---|
| قراءة طابور التوثيق والبلاغات ومستندات المستخدمين | ✅ | ✅ |
| توثيق/رفض ملف، حسم بلاغ، حذف تقييم، تمييز | ✅ | ✅ |
| ظهورها في استعلام اكتشاف الطلاب | لا علاقة | لا علاقة (الاكتشاف للموثّق فقط) |

⚠️ **لماذا لا يعتمد الاكتشاف على دور المستند؟** لأن قواعد القراءة تُقيَّم لكل
مستند يعيده الاستعلام، و`get()` فيها محدود بعشرة نداءات لكل استعلام. وضع الفحص
في قاعدة الاكتشاف كان سيُسقط بحث الطلاب نفسه. التفصيل في `firestore.rules`
أعلى `isAdminDoc`، والاختبار العملي «طابور 15 ملفًا معلّقًا» في
`tool/rules_tests`.

**تحقق سريع بعد الضبط:** ادخل بحساب المسؤول ← «حسابي» ← «لوحة الإدارة» ←
«بانتظار التوثيق». يجب أن يظهر الملف المعلّق، وأن تكتب «توثيق» فيتحوّل الملف إلى
`verified` ويظهر فورًا في بحث الطالب. أي رفض من الخادم (`permission-denied`) يعني
أن الادعاء/الدور لم يُضبط كما في أ أو ب.

### 3.12 دوال المزاد الأسبوعي (P30) — نشر وسلوك متوقع

المزاد يحتاج **Cloud Functions**، وهذا يستلزم خطة **Blaze** (لا يعمل على Spark).
إن لم تُنشر الدوال، تظهر شاشة المزاد حالة صريحة ولا تُقبل أي مزايدة (لا يوجد
بديل محلي يزوّر النتيجة).

```bash
# 1) الدوال (nodejs20 · europe-west1 · جدول بتوقيت Africa/Cairo)
firebase deploy --only functions

# 2) القواعد (بنود §16 الخاصة بالمزاد)
firebase deploy --only firestore:rules

# 3) تحقق سريع (من حساب مدرّس): يجب أن يعيد cycleKey و phase
#    اسم الدالة: myAuctionState
```

- **المستندات:** `auctions/{cycleKey}-{online|inPerson}` + `bids/` + `winners/`،
  و`auctionResults`، و`auctionConfig/current`، و`auctionAudit`، و`auctionIdempotency`.
- **الفهارس:** لا فهرس مركّب جديد؛ القراءات بمعرّف مشتق.
- **الإعداد الافتراضي:** 5 مقاعد لكل فئة، أقل مزايدة 100، خطوة 25، 10 زيادات،
  سقف 50000، مهلة دفع 24 ساعة، مهلة بديل 12 ساعة. تُعدَّل من شاشة
  «الإدارة ← مزاد التمييز» (أو `auctionConfig/current`)، وتسري على الدورات
  القادمة فقط.
- **المجدولات:** `weeklyOpenAuctions` (اثنين 00:05) · `weeklyFinalizeAuctions`
  (خميس 09:05) · `weeklyReplacementRound` (جمعة 09:05) · `weeklyPublishFeatured`
  (سبت 00:05).
- **لا بوّابة دفع:** تأكيد الدفع يدوي من لوحة الإدارة بعد التحصيل، وكل تأكيد
  يُسجَّل باسم المنفّذ في `auctionAudit`.
- **التكلفة:** أربع مهام مجدولة أسبوعيًا + نداءات المزايدة. الاستدعاءات صغيرة؛
  راقب `Cloud Scheduler` و`Function invocations` في أول أسبوعين.

## 4. أسئلة مفتوحة (تحتاج قرارك قبل الإنتاج)

| السؤال | الأثر |
|---|---|
| هل يُسمح بتغيير الدور بعد الاختيار؟ وكيف (طلب للدعم/أداة إدارية)؟ | شاشة/مسار إداري + قاعدة أمان |
| هل يُمنع الحساب المدرسي الذي لم يُعتمد من استقبال الحجوزات في القواعد؟ | قواعد Firestore (P5/P8) |
| إعادة تعيين كلمة المرور: بريد Firebase الافتراضي أم قالب مخصص؟ | تجربة المستخدم + تكلفة |
| ماذا لو سجّل مستخدم بـGoogle ثم بالبريد بنفس العنوان؟ | ربط الحسابات (linking) |

## 5. ما لم يُتحقق منه بعد

- ❌ لم يُنشأ مشروع Firebase، ولم يُجرَّب تسجيل الدخول الحقيقي (لا جهاز ولا مفاتيح).
- ❌ لا قواعد أمان منشورة: **الوصول إلى Firestore مفتوح/مغلق حسب إعدادك اليدوي**،
  ولا تعتمد على التطبيق في الفرض — راجع §3.4.
- ✅ بناء APK في CI يعمل (20.1/17.8 MiB) وموقّع بمفتاح الإصدار الدائم.
- ❌ **تسجيل الدخول بـGoogle الأصلي لم يُجرَّب على جهاز بعد**: الكود والحزم
  وُضعا، لكن قائمة الحسابات تحتاج جهازًا حقيقيًا + بصمة مسجّلة + سر معرّف
  عميل الويب. هذه هي نقطة التحقق التالية الوحيدة.
