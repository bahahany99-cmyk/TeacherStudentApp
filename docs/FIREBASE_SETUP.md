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

وعند اختيار الدور «مدرس» يُنشأ في نفس دفعة الكتابة `teacherProfiles/{uid}`:

```jsonc
{
  "ownerId": "<uid>",
  "displayName": "…",
  "status": "pendingReview",   // لا يصبح approved إلا من الإدارة
  "createdAt": <Timestamp>
}
```

لا يكتب التطبيق أي حقل إداري (`approved`, `isFeatured`, `isAdmin`…) ولا أي
قاعدة أمان. الدور يُقرأ من الخادم في كل دخول؛ وتغييره بعد الاختيار لا يحدث من
التطبيق. **ملف مدرس موجود لا يُعاد ضبطه أبدًا** (حالته قرار إداري).

### سياسة قواعد الأمان المعتمدة (2026-10-27) — تُكتب في P5

1. `users/{uid}`: قراءة وكتابة لصاحبه فقط؛ `role` لا يتغيّر بعد الكتابة الأولى.
2. `teacherProfiles/{uid}`: قراءة عامة للملفات `approved` فقط؛ صاحبه يقرأ ملفه
   بكل حالاته، ولا يستطيع تغيير `status`.
3. لا وصول إداري من التطبيق: الاعتماد والتمييز بأدوات إدارية خارجية.

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

القواعد في `firestore.rules` مكتوبة ومُختبرة على المحاكي (209 حالة)، لكنها **لم
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
الإنشاء** (يكتبه التطبيق)، لأن استعلامات البحث تفلتر عليه صراحةً.

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
- ❌ بناء APK بعد إضافة `firebase_auth`/`cloud_firestore` لم يُجرَّب في CI بعد
  (البناء اليدوي غير متاح لبيئة التطوير). أول بناء يدوي منك هو نقطة التحقق.
