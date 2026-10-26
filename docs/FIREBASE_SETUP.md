# دليل ربط Firebase — خطوات خارجية مطلوبة

> **الحالة الآن:** Firebase **غير مربوط**. المشروع يهيّئ Firebase عند الإقلاع
> لكن التهيئة معطّلة افتراضيًا (`ENABLE_FIREBASE=false`)، ولم يُنشأ أي مشروع
> Firebase ولا أي حساب سحابي. هذا الملف يوضّح ما يلزم لإكمال الربط.

---

## 1. ما هو منفَّذ في الكود

| العنصر | الملف | الحالة |
|---|---|---|
| تهيئة Firebase معزولة عن الواجهات | `lib/core/config/firebase_bootstrap.dart` | منفَّذ (يتعامل مع الفشل بلا تعطيل التطبيق) |
| علم تفعيل التهيئة | `lib/core/config/app_config.dart` | منفَّذ (`--dart-define=ENABLE_FIREBASE=true`) |
| اعتمادية `firebase_core` | `pubspec.yaml` | مضافة (`^5.0.0`) |
| استثناء ملفات الإعداد من Git | `.gitignore` | منفَّذ |
| المصادقة / Firestore / Storage / FCM | — | **غير منفَّذ** (مراحل لاحقة) |

## 2. ما لا يمكن تنفيذه من داخل بيئة التطوير الحالية

1. **إنشاء مشروع Firebase** — يتطلب حساب Google وملكية المشروع، وقرارًا صريحًا
   من صاحب المشروع (قاعدة A-08). لا يُنشأ تلقائيًا.
2. **توليد `firebase_options.dart`** — يحتاج `flutterfire configure` + Flutter SDK
   (غير متاح في بيئة التنفيذ).
3. **تفعيل مزوّد Google** — يحتاج إعداد شاشة الموافقة (OAuth consent) في
   Google Cloud Console.
4. **بصمات SHA-1/SHA-256** — تُستخرج من جهاز البناء/التوقيع، ولا يمكن توليدها هنا.

## 3. الخطوات المطلوبة بالترتيب

### 3.1 إنشاء المشروع (مرة واحدة، بموافقة صاحب المشروع)

1. أنشئ مشروعًا في Firebase Console (مقترح: مشروعان `dev` و`prod` — انظر T-06، أو مشروع واحد مبدئيًا).
2. أضف تطبيق Android بالتطبيق `applicationId` المتفق عليه.
   - قيمة مقترحة: `com.example.teacher_student_app` — **يجب حسمها قبل أول إصدار**، وتُثبَّت في `android/app/build.gradle.kts`.
3. أضف بصمة SHA-1 (وبصمة SHA-256) لبناء التطوير، ثم لبصمة الإصدار لاحقًا.
   - بدون SHA-1 لن يعمل تسجيل Google على Android.
4. نزّل `google-services.json` وضعه في `android/app/` — **لا يُرفع إلى Git**.

### 3.2 توليد إعدادات Flutter

على جهاز فيه Flutter SDK و`flutterfire_cli`:

```
dart pub global activate flutterfire_cli
flutterfire configure --project=<PROJECT_ID> --platforms=android
```

يُنتج `lib/core/config/firebase_options.dart` — **مستثنى من Git**.
لذلك على أي جهاز جديد يجب إعادة توليده (وهذا مقصود: لا مفاتيح في المستودع).

### 3.3 تفعيل التهيئة في الكود

في `lib/core/config/firebase_bootstrap.dart` استبدل:

```dart
await Firebase.initializeApp();
```

بـ:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

مع إضافة الاستيراد المقابل، ثم شغّل:

```
flutter run --dart-define=ENABLE_FIREBASE=true
```

### 3.4 تفعيل تسجيل Google (المرحلة 4)

1. Firebase Console → Authentication → Sign-in method → **Google: تمكين**.
2. إضافة `google_sign_in` و`firebase_auth` إلى `pubspec.yaml` (حسب A-11 عند التنفيذ).
3. ضبط `Web client ID` (مطلوب لـ `idToken` على Android).
4. تنفيذ `AuthService` الحقيقي واستبدال `DemoAuthService` في `AppServices`.

### 3.5 Firestore

1. إنشاء قاعدة البيانات (اختيار المنطقة له أثر على التكلفة والزمن).
2. **كتابة قواعد الأمان أولًا** — لا تُفتح القواعد للجميع إطلاقًا.
3. إنشاء الفهارس المركبة المطلوبة للفلاتر (تُبنى حسب تصميم الاستعلامات في Phase 6).
4. مراجعة حدود الحصص (F-09): عدد القراءات/الكتابات يوميًا.

### 3.6 Storage و FCM

- **Storage:** تحديد المسارات `teachers/{teacherId}/…` وقيود الحجم والنوع، وقواعد تمنع الكتابة على مسار مدرس آخر.
- **FCM:** إضافة الحزمة، طلب إذن الإشعارات من المستخدم، حفظ الرموز (tokens) في Firestore، والإرسال من دالة خادمية.

## 4. ما يجب ألا يظهر في المستودع أبدًا

| الملف | السبب | الحالة |
|---|---|---|
| `google-services.json` | مفاتيح/إعدادات المشروع | مستثنى |
| `lib/core/config/firebase_options.dart` | مفاتيح API للمشروع | مستثنى |
| `*.jks` / `key.properties` | توقيع الإصدار | مستثنى |
| أي `service account` JSON | صلاحيات إدارية كاملة | ممنوع تمامًا داخل التطبيق |
| `.env` | أسرار محلية | مستثنى |

## 5. قبل أي إطلاق — قائمة تحقق

- [ ] قواعد Firestore مكتوبة ومختبرة (اختبارات قواعد، لا فقط تجربة يدوية).
- [ ] قواعد Storage مكتوبة ومختبرة.
- [ ] لا كتابة مباشرة من العميل على الحقول الحسّاسة (الحالة، السعة، الاعتماد).
- [ ] App Check مُقيَّم ومُفعَّل (T-05).
- [ ] تنبيهات ميزانية/حصة مضبوطة (T-11).
- [ ] `google-services.json` وبصمات التوقيع موجودة لبناء الإصدار.
- [ ] الوضع التجريبي (`startDemoSession` و`DemoBanner` و`AppServices.demo()`) معطّل أو محذوف.
