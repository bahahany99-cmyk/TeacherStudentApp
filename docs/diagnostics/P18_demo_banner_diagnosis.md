# تشخيص: ظهور «وضع الزائر · بيانات تجريبية» في الصفحة الرئيسية بعد الدخول بـGoogle

**النوع:** فحص كود فقط — لم يُعدَّل أي ملف، ولم تُنشأ أي بيانات، ولم تُمَس القواعد.
**التاريخ:** 2026-10-29.

---

## الخلاصة في سطرين

الشريحة التي تراها في الصفحة الرئيسية **ليست مؤشرًا على الجلسة**: هي ويدجت
`DemoBanner` مكتوبة في `student_home_screen.dart:40` **بلا أي شرط**، فتظهر لكل
حساب — حقيقي أو تجريبي. السبب إذن **عيب عرض (display bug) من مخلفات مرحلة
الواجهات**، وليس فشلًا في المصادقة ولا في Firestore.

المؤشر الحقيقي لحالة الجلسة موجود في موضع آخر: شريحة **«زائر»** في شريط
التطبيق (`app_shell.dart:152`) وهي مشروطة فعليًا بـ`session.isDemoSession`.

---

## 1) الملف والدالة المسؤولان عن تسجيل الدخول

| الطبقة | الملف | الدالة/السطر |
|---|---|---|
| الواجهة | `lib/features/auth/presentation/login_screen.dart` | `_signInWithGoogle()` — السطر 34 |
| المتحكّم | `lib/app/session/session_controller.dart` | `signInWithGoogle()` — السطر 93 |
| الخدمة (Firebase Auth) | `lib/data/firebase/firebase_auth_service.dart` | `signInWithGoogle()` — **السطر 102** |
| مزوّد Google الأصلي | `lib/data/firebase/google_sign_in_gateway.dart` | `obtainIdToken()` — السطر 61 |

المسار الفعلي داخل الخدمة (السطور 102-125):

```dart
final String idToken = await _googleSignIn.obtainIdToken();          // نافذة النظام
final OAuthCredential credential =
    GoogleAuthProvider.credential(idToken: idToken);
final UserCredential credentialResult =
    await _auth.signInWithCredential(credential);                     // Firebase Auth
final User? user = credentialResult.user;
return _resolve(user);                                                // قراءة Firestore
```

`signInWithProvider` لم يبقَ مستخدمًا (المطابقتان في المشروع تعليقان فقط).

---

## 2) ما يحدث مباشرة بعد نجاح تسجيل الدخول

```
signInWithCredential  ──نجاح──►  _resolve(user)                        [السطر 362]
                                       │
                                       ├─ Firestore: users/{uid}.get()   ← قراءة إلزامية
                                       ├─ role موجود؟  لا → AuthNeedsRole
                                       ├─ status == pending_deletion؟ → AuthPendingDeletion
                                       └─ غير ذلك → AuthSignedIn(AppUser)
                                       │
                              SessionController._apply()                [السطر 165]
                                       │  يضبط _user و _status ثم notifyListeners()
                                       ▼
                              continueAfterAuth()                      [auth_flow.dart]
                                       │
      needsRole → /auth/role-selection        signedIn → /app (الهيكل)        pendingDeletion → /account/restore
```

مهم: `AppUser` الذي يُبنى في `_resolve` **لا يمرّر** `isDemoAccount`، وقيمته
الافتراضية `false` (`app_user.dart:14`). أي أن أي حساب حقيقي يصل إلى الهيكل
بـ`isDemoSession == false` **بالضرورة**.

---

## 3) هل يُنشئ التطبيق مستند المستخدم تلقائيًا؟

**لا — ليس عند تسجيل الدخول.** لا يوجد أي `set()` على `users` داخل
`signInWithGoogle` ولا داخل `_resolve` ولا في `restoreSession`.

المستند يُنشأ في **خطوة لاحقة ومشروطة**: اختيار نوع الحساب.

| البند | القيمة المستخرجة من الكود |
|---|---|
| المجموعة | `users` — الثابت `usersCollection` في `firebase_auth_service.dart:58` |
| المستند | معرّف المستند = **`uid` الخاص بـFirebase Auth** (`users/{uid}`) |
| مكان الإنشاء | `assignRole()` — السطر **260**، عبر `batch.set(doc, {...}, SetOptions(merge: true))` |
| من يستدعيه | `role_selection_screen.dart:44` → `session.completeRoleSelection()` → `session_controller.dart:132` |
| الحقول المكتوبة | `displayName`, `email`, `role`, `createdAt`, `roleChosenAt` (خمسة فقط) |
| مجموعة إضافية | `teacherProfiles/{uid}` تُنشأ **في نفس الحزمة الذرّية** إن اختار الدور «مدرس» — الثابت في السطر 75 |

⇒ الحساب الذي يسجّل الدخول ثم يغلق التطبيق قبل اختيار الدور **يبقى بلا مستند**
في Firestore. هذا سلوك مصمَّم (`AuthNeedsRole`)، وليس خطأً.

---

## 4) هل تُقرأ بيانات المستخدم قبل عرض الصفحة الرئيسية؟ وكيف تُعالج الحالات؟

**نعم.** القراءة إلزامية في `_resolve()` (`firebase_auth_service.dart:362-378`):

```dart
final DocumentSnapshot<Map<String, dynamic>> doc =
    await _firestore.collection(usersCollection).doc(user.uid).get();
final Object? rawRole = doc.data()?['role'];
final UserRole? role = _roleFrom(rawRole);
if (role == null) return AuthNeedsRole(...);   // المستند غائب أو بلا دور
```

| الحالة | السلوك في الكود | ما يراه المستخدم |
|---|---|---|
| **المستند غير موجود** (أول دخول) | `doc.data()` = null ⇒ `role == null` ⇒ `AuthNeedsRole` | شاشة اختيار نوع الحساب — **ليس خطأً** |
| **المستند موجود بلا دور** | نفس المسار | شاشة اختيار الدور |
| **فشل قراءة Firestore** | `_guard` (السطر 452) يلتقط `FirebaseAuthException`/`FirebaseException` ويترجمه | حسب الرمز: `unavailable` ⇒ «لا يوجد اتصال بالإنترنت»؛ `permission-denied` ⇒ «لا تملك صلاحية» |
| **استثناء غير Firebase** أثناء القراءة | `_guard` **لا يلتقطه** (يلتقط نوعين فقط) ⇒ يصعد للشاشة | «حدث خطأ غير متوقع + أعد المحاولة» |
| **فشل كتابة الدور** | `assignRole` يلتقط `FirebaseException` ويترجمها؛ الشاشة تعرض `error.message` | رسالة الخطأ المترجمة داخل شاشة اختيار الدور |
| **فشل قراءة الادعاء الإداري** | `_readAdminClaim` يبتلع الخطأ ويعيد `false` | لا شيء (لا يؤثر) |
| **فشل استرجاع الجلسة عند الإقلاع** | `bootstrap.dart:49` بلا `try/catch` | شاشة بيضاء/توقف — عيب كامن مستقل |

---

## 5) السبب البرمجي الدقيق لعبارة «وضع الزائر» في الصفحة الرئيسية ⭐

| العنصر | القيمة |
|---|---|
| **الملف** | `lib/features/student/presentation/student_home_screen.dart` |
| **الدالة** | `StudentHomeScreen.build()` |
| **السطر** | **40** |
| **الكود** | `const DemoBanner(),` |
| **الشرط** | **لا يوجد شرط إطلاقًا** — ويدجت ثابتة في أول عناصر `Column` |
| **مصدر النص** | `AppStrings.demoBannerShort` — `app_strings.dart:18` = «وضع الزائر · بيانات تجريبية» |
| **الويدجت** | `lib/core/widgets/demo_banner.dart` — عرض بحت، **لا تقرأ الجلسة ولا `isDemoSession`** |

ونفس الشيء في `lib/features/teacher/presentation/teacher_home_screen.dart:39`.

### مدى الانتشار (من الكود، لا تخمينًا)

| النوع | العدد | المواضع |
|---|---|---|
| **غير مشروط** (`const DemoBanner()`) | **20 موضعًا** | student_home:40 · teacher_home:39 · direct_chats:66 · bookings:78 · booking_details:212 · favorites:124,148 · group_chat:162,208 · group_details:155 · group_members:362 · group_timetable:244,282 · groups:50 · join_requests:171 · notifications:137 · edit_teacher_profile:163 · my_teacher_profile:81 · teacher_profile:88 · teachers:81 |
| مشروط فعليًا | 3 مواضع فقط | profile_screen:159 (`session.isDemoSession`) · admin_dashboard:61 (`isDemo`) · account_restore:120 (`session.isDemoSession`) |

⇒ هذا أثر متبقٍ من مرحلة P2 حين كانت **كل** الشاشات تعرض بيانات تجريبية؛ رُبط
الشرط في ثلاث شاشات فقط، وبقيت العشرون الأخرى مطلقة.

### المؤشر الصحيح مقابل المؤشر الكاذب

| ما تراه | الشرط في الكود | الدلالة |
|---|---|---|
| شريحة «وضع الزائر · بيانات تجريبية» في أعلى **الصفحة الرئيسية** | **لا شرط** (`student_home_screen.dart:40`) | ❌ **لا تدل على شيء** عن الجلسة |
| شريحة **«زائر»** في شريط التطبيق العلوي | `if (session.isDemoSession)` — `app_shell.dart:152` | ✅ تدل على جلسة تجريبية فعلية |
| الشريحة داخل **«حسابي»** | `if (session.isDemoSession)` — `profile_screen.dart:159` | ✅ دقيقة |

### متى تصبح `isDemoSession` صحيحة؟ (سلسلة كاملة، بلا مسار آخر)

1. `session.isDemoSession` = `_user?.isDemoAccount ?? false` (`session_controller.dart:64`).
2. `isDemoAccount: true` يُكتب في **موضع واحد فقط** في كل المشروع:
   `session_controller.dart:162` داخل `startDemoSession()` (بحث `grep` يعطي مطابقة واحدة).
3. `startDemoSession` يُستدعى من: `login_screen.dart:60` (`_openDemoShell`) و
   `switchDemoRole` (الذي لا يعمل إلا في جلسة تجريبية أصلًا).
4. أزرار `_openDemoShell` لا تُرسم إلا داخل `if (AppConfig.isDemoMode)` —
   `login_screen.dart:164` — و`AppConfig.isDemoMode` = `!enableFirebase`
   (`app_config.dart:22`) وهو **ثابت وقت البناء**.

**نتيجة منطقية مهمة:** لا يمكن أن يجتمع «دخول Google ناجح» و«جلسة تجريبية» في
نفس العملية، لأن `_apply(AuthSignedIn)` يستبدل `_user` بحساب `isDemoAccount:
false`. وأي جلسة تجريبية تعني بالضرورة أن **بطاقة المعاينة** في شاشة الدخول
ظهرت وضُغط أحد أزرارها (طالب/مدرس/إدارة) — وتلك البطاقة لا تظهر إلا في بناء
بُني بـ`ENABLE_FIREBASE=false`.

---

## 6) تهيئة Firebase ومعرّف المشروع

| البند | القيمة |
|---|---|
| نقطة التهيئة | `lib/app/bootstrap.dart:45` → `FirebaseBootstrap.initialize()` |
| التنفيذ | `lib/core/config/firebase_bootstrap.dart` → `Firebase.initializeApp(options: FirebaseConfig.options)` |
| مصدر القيم | `--dart-define` وقت البناء (لا `google-services.json`، ولا `firebase_options.dart`) |
| الشرط الأدنى | `FirebaseConfig.hasOptions` = وجود `projectId` + `apiKey` + `appId` + `messagingSenderId` |
| **معرّف المشروع الفعلي** | `FirebaseConfig.projectId` = `String.fromEnvironment('FIREBASE_PROJECT_ID')` — **قيمته لا توجد في المستودع** (مصمَّم كذلك) |
| رقم المشروع | **`954683127001`** — مثبت من معرّف عميل الويب ومن `FIREBASE_MESSAGING_SENDER_ID` (تطابق تحقّق منه CI) |
| نسخة APK | ليست تجريبية: `AppServices.bootstrap()` لا يعيد الخدمات الحقيقية إلا إذا `FirebaseBootstrap.status == ready` |

**للحصول على النص الحرفي لمعرّف المشروع** (لأنه ليس في الكود): Firebase Console
← Project settings ← General ← *Project ID*، للمشروع الذي رقمه `954683127001`.
أو عند الإقلاع من السجل: `adb logcat | grep -i "FirebaseApp"`.

---

## 7) قواعد Firestore مقابل التصميم الحالي

`firestore.rules` — بلوك `match /users/{uid}` (السطر 110):

| العملية | القاعدة | متوافقة مع `assignRole`؟ |
|---|---|---|
| **read** | `isSelf(uid) || isAdmin()` | ✅ القراءة في `_resolve` بحساب صاحبه |
| **create** | `isSelf(uid)` + `role in ['student','teacher']` + `keys().hasOnly([displayName, email, role, createdAt, roleChosenAt])` + `displayName` نص غير فارغ ≤ 80 | ✅ `assignRole` يكتب **نفس الحقول الخمسة** حرفيًا، والدور من القيمتين المسموحتين فقط |
| **update** | `isSelf(uid)` + `role` **غير قابل للتغيير** + `hasOnly([…الخمسة, status, scheduledDeletionAt])` + `validAccountStateChange()` | ✅ تعديل الاسم/البريد مسموح، وتغيير الدور مرفوض (بالتصميم) |
| **delete** | `isAdmin()` فقط | ✅ الحذف من التطبيق حذف ناعم لا حذف مستند |

الخلاصة: **القواعد لا تمنع المستخدم المسجّل من إنشاء مستنده وقراءته وتحديث
بياناته**. لن يظهر `permission-denied` في المسار الطبيعي ما دام اسم المجموعة
`users` والحقول هي الخمسة المذكورة.

---

## 8) هل يحتاج التطبيق بيانات أولية تُضاف يدويًا؟

**لا، لتشغيل الحساب الأساسي:**

| البيانات | تُنشأ كيف؟ |
|---|---|
| `users/{uid}` | تلقائيًا عند اختيار نوع الحساب (`assignRole`) |
| `teacherProfiles/{uid}` | تلقائيًا في نفس الحزمة عند اختيار «مدرس» |
| بيانات المعاينة (الزائر) | ثوابت في `lib/data/demo/demo_data.dart` — في الذاكرة، لا تحتاج قاعدة بيانات |

**ما يحتاج تدخّلًا خارج التطبيق (لا شأن له بهذه المشكلة):**
1. **ادعاء `admin`** — يُمنح بمفتاح خدمة خارج التطبيق فقط (`isAdmin()` تقرأ `request.auth.token.admin`).
2. **إنشاء قاعدة Firestore نفسها** ونشر القواعد — إعداد بنية، لا بيانات.

---

## 9) السبب الأكثر ترجيحًا + ما يلزم إصلاحه

### السبب (مؤكد من الكود، ليس تخمينًا)
`student_home_screen.dart:40` يعرض `DemoBanner` بلا شرط ⇒ **كل** مستخدم حقيقي
يرى «وضع الزائر · بيانات تجريبية» في الرئيسية، بينما جلسة المصادقة سليمة.

### الدليل الذي يفصل بين «عيب عرض» و«جلسة تجريبية فعلية»
افحص **شريط التطبيق العلوي**:

| ما تراه | الاستنتاج |
|---|---|
| الشريحة في الرئيسية **فقط**، ولا شريحة «زائر» في الشريط، و«حسابي» بلا شريحة | ✅ **عيب عرض فقط** — الجلسة حقيقية، والمصادقة تعمل |
| شريحة **«زائر»** في الشريط العلوي أيضًا | جلسة تجريبية فعلية ⇒ دخلت من بطاقة المعاينة في شاشة الدخول (وبناء التطبيق `ENABLE_FIREBASE=false`) |

### أصغر إصلاح (لم يُطبَّق بعد)
1. **الأدق والأصغر لهذه الشكوى:** تغليف الشريحة بالشرط في الشاشتين الرئيسيتين:
   `if (SessionScope.of(context).isDemoSession) const DemoBanner(),`
   في `student_home_screen.dart:40` و`teacher_home_screen.dart:39`.
2. **الأشمل (يفسّر الشكوى في كل مكان):** نفس الشرط في المواضع الـ18 الباقية، أو —
   بجراحة واحدة — جعل `DemoBanner` نفسه متحققًا ذاتيًا من الجلسة وإلا أعاد
   `SizedBox.shrink()`. ⚠️ الخيار الثاني يتطلب قراءة آمنة للجلسة
   (`SessionScope.maybeOf`) لأن بعض الاختبارات تبني الويدجت بلا `SessionScope`،
   وإلا تسبب ذلك في انهيار اختبارات قائمة.

### كيف تتحقق أن الإصلاح نجح على هاتف حقيقي
1. بحساب Google حقيقي: الرئيسية **بلا شريحة**، والشريط العلوي **بلا «زائر»**، و«حسابي» يعرض بريدك الحقيقي.
2. بحساب جديد (بلا دور): تُعرض شاشة اختيار النوع ثم تدخل ⇒ نفس النتيجة أعلاه.
3. من بطاقة المعاينة في بناء تجريبي: الشريحة **تظهر** (يجب ألا تنكسر).
4. اختبار آلي مقترح بعد الإصلاح: بناء جلسة حقيقية → `expect(find.text('وضع الزائر · بيانات تجريبية'), findsNothing)`، وجلسة تجريبية → `findsOneWidget`.

---

## ما لم أفعله (التزامًا بالتعليمات)
- لم أُعدّل أي ملف إنتاج ولا أي قاعدة.
- لم أُنشئ بيانات.
- لم أفتح القواعد.
- لم أفترض أسماء المجموعات: `users` و`teacherProfiles` مأخوذة من الثوابت في الكود.
- لم أعتبر نجاح نافذة Google دليلًا على سلامة المسار؛ اعتمدت على قراءة الشيفرة.
