# TeacherStudentApp — منصة ربط المدرسين بالطلاب (مصر)

> **الحالة:** المرحلة 2 مكتملة — قرارات تقنية مثبتة + هيكل تطبيق Flutter أولي.
> **لا توجد ميزات حقيقية بعد:** لا تسجيل دخول فعلي، ولا Firestore، ولا بحث،
> ولا حجز. الواجهات تعمل ببيانات تجريبية محلية فقط.
> **لم يُبنَ التطبيق ولم يُشغَّل بعد:** بيئة التنفيذ لا تحتوي Flutter/Dart
> (انظر [التحقق المنفَّذ](#التحقق-المنفذ-وما-لم-يُنفَّذ)).

## الهوية والاسم المؤقت

كل ما يخص الاسم في هذه المرحلة **مؤقت**، ولا يوجد اسم تجاري معتمد ولا شعار ولا
هوية بصرية نهائية.

| العنصر | القيمة الحالية | مكان التعديل عند اعتماد الاسم |
|---|---|---|
| معرّف تقني (Dart package) | `teacher_student_app` | `pubspec.yaml` → `name` + استيرادات `package:teacher_student_app/…` |
| الاسم الظاهر للمستخدم | «مدرسون وطلاب» (مؤقت) | `lib/core/config/app_identity.dart` → `displayName` |
| الوصف المختصر | «منصة تجمع مدرسي مصر بطلابهم» | `lib/core/config/app_identity.dart` → `tagline` |
| عنوان النافذة/التطبيق في Flutter | من `AppIdentity.displayName` | — |
| اسم التطبيق على Android | **غير موجود بعد** (لا مجلد `android/`) | `android/app/src/main/AndroidManifest.xml` → `android:label` |
| `applicationId` على Google Play | **لم يُحسم** (Q-29) | `android/app/build.gradle.kts` |

قاعدة عمل: لا يُثبَّت أي اسم أو شعار أو لوحة ألوان نهائية قبل اعتماد صاحب المشروع.


## وصف مختصر

تطبيق Android باللغة العربية (RTL) يربط المدرسين بالطلاب في مصر:

- الطالب: يبحث عن مدرسين، يحجز دروسًا، يطلب الانضمام إلى مجموعات دراسية.
- المدرس: ينشئ ملفًا (يخضع لمراجعة إدارية)، يدير دروسه ومجموعاته، يوافق على الطلبات.
- الإدارة: تراجع ملفات المدرسين وتدير البلاغات (غير منفّذة بعد).

## الهدف

منصة موثوقة ومنخفضة التكلفة وسهلة الاستخدام بالعربية، تفصل بين ثلاثة أدوار،
وتعتمد على موافقة صريحة من المدرس قبل أي حجز أو انضمام — **مفروضة على الخادم**
لا في واجهة التطبيق.

## المنظومة التقنية (مثبتة)

| الطبقة | القرار |
|---|---|
| التطبيق | **Flutter + Dart** — Android فقط |
| الخلفية | **Firebase** (لا Supabase) |
| المصادقة | **Firebase Authentication** عبر **Google** فقط |
| قاعدة البيانات | **Cloud Firestore** لكل البيانات |
| الملفات والصور | **Firebase Storage** |
| الإشعارات | **Firebase Cloud Messaging** |
| منطق موثوق | **Cloud Functions** عند الحاجة وبعد تقدير التكلفة |
| البحث | **Firestore فقط** (فلاتر + فهارس مركبة + صفحات) — بلا محرك خارجي |
| المدفوعات | **لا شيء داخل التطبيق** في v1 (الاتفاق والدفع خارج التطبيق) |

التفاصيل والأسباب: [`docs/ARCHITECTURE_DECISIONS.md`](docs/ARCHITECTURE_DECISIONS.md)

## ما هو منفَّذ فعلًا الآن

| العنصر | الحالة |
|---|---|
| هيكل مشروع Flutter (`pubspec.yaml`, `analysis_options.yaml`, `lib/`, `test/`) | ✅ موجود |
| نظام تصميم مركزي (ألوان/مسافات/خطوط/ثيم) | ✅ |
| عربية + RTL + تعريب Material عبر `flutter_localizations` | ✅ في الكود |
| تنقّل مركزي + هيكل بأدوار (طالب/مدرس) | ✅ |
| شاشات: بداية، دخول، رئيسية طالب، رئيسية مدرس، مدرسون، مجموعات، حجوزات، حسابي | ✅ بنية عرض |
| عقود طبقة خدمات + تنفيذ تجريبي | ✅ |
| تهيئة Firebase معزولة (معطّلة افتراضيًا) | ✅ |
| Firebase Auth / Firestore / Storage / FCM / Functions | ❌ غير منفّذة |
| قواعد أمان Firestore/Storage | ❌ غير مكتوبة |
| مجلد `android/` (ملفات المنصة) | ❌ يجب توليده بأمر واحد (انظر أدناه) |
| اختبارات | ✅ مكتوبة — **لم تُشغَّل** (لا Flutter في بيئة التنفيذ) |

## التشغيل

### 1) توليد ملفات منصة Android (مرة واحدة، على جهاز فيه Flutter)

المشروع أُنشئ يديويًا في بيئة لا تحتوي Flutter، ولذلك لا يوجد مجلد `android/`.
على جهاز التطوير (Flutter stable):

```bash
# داخل المستودع، على نسخة احتياطية أو فرع منفصل:
flutter create --platforms=android \
  --org com.example --project-name teacher_student_app \
  .flutter_scaffold_tmp
# ثم انسخ مجلد المنصة فقط:
cp -r .flutter_scaffold_tmp/android ./android
rm -rf .flutter_scaffold_tmp
```

> السبب في استخدام مجلد مؤقت: `flutter create .` قد يعيد كتابة ملفات المشروع
> الموجودة، بينما نحتاج فقط مجلد `android/` المولَّد.

### 2) الحزم والتحقق

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # وضع تجريبي، بلا Firebase
```

إذا كانت نسخة Flutter أقدم من Dart 3.11، خفّض `flutter_lints` إلى `^5.0.0` في
`pubspec.yaml`.

### 3) ربط Firebase (لاحقًا)

انظر [`docs/FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md). الافتراضي
`ENABLE_FIREBASE=false`، والتطبيق يعمل ببيانات تجريبية محلية.

## التحقق المنفَّذ وما لم يُنفَّذ

بيئة التنفيذ الحالية (تم التحقق منها بالأوامر):

| الأداة | النتيجة |
|---|---|
| `git`, `gh` | متاحان |
| `flutter` | **غير موجود** (`command not found`) |
| `dart` | **غير موجود** |
| `java` / Android SDK | **غير موجودين** |
| `pub.dev` | **محجوب** (`curl` → `000`) — جلب الحزم سيفشل حتى لو وُجد SDK |

لذلك: `flutter pub get` و`flutter analyze` و`flutter test` و`flutter create`
**لم تُنفَّذ**. ما تم التحقق منه فعليًا محدود بـ: سلامة YAML، وتوازن الأقواس في
ملفات Dart، وصحة مسارات الاستيراد، وخلوّ المستودع من الأسرار، ومطابقة أسماء
واجهات Flutter المستخدمة مع المصدر الرسمي (تفاصيلها في `docs/WORK_LOG.md`).

الخطوة الأولى على جهاز فيه Flutter: `flutter pub get` ← `flutter analyze` ←
`flutter test` ← توليد `android/` ← `flutter build apk --debug`.

## بنية المشروع

```
lib/
  main.dart                  نقطة الدخول
  app/                       التطبيق: bootstrap, app, router, shell, session
  core/                      config, constants, theme, shared widgets
  data/                      models, services (عقود), demo (تنفيذ تجريبي)
  features/                  splash, auth, student, teacher, teachers,
                             groups, bookings, profile (presentation)
test/                        helpers, widget, unit
docs/                        خطة، متطلبات، قرارات بنية، إعداد Firebase، سجل عمل
```

قواعد الاتجاه العام:

- الشاشات لا تستورد `firebase_*` إطلاقًا؛ تتعامل مع عقود في `data/services/`.
- لا ألوان/مسافات مكتوبة داخل الشاشات؛ كلها في `core/theme/`.
- أي بيانات وهمية تظهر مع `DemoBanner`، وكلها معزولة في `data/demo/`.
- أي ميزة جديدة = مجلد داخل `features/` + عقد في `data/services/` + المرحلة المعنية.

## الوثائق

- [**خطة التنفيذ المرحلية (المراحل P0–P17)**](docs/ROADMAP.md) ← ابدأ من هنا
- [خطة المشروع](docs/PROJECT_PLAN.md)
- [متطلبات المنتج](docs/PRODUCT_REQUIREMENTS.md)
- [قرارات البنية](docs/ARCHITECTURE_DECISIONS.md)
- [إعداد Firebase](docs/FIREBASE_SETUP.md)
- [سجل العمل](docs/WORK_LOG.md)

## قواعد العمل

- كل مرحلة تُنفَّذ وتُراجَع منفصلة قبل التالية.
- لا تُضاف حزمة أو خدمة أو حساب خارجي بلا حاجة مبررة وموافقة.
- لا أسرار أو مفاتيح في المستودع (`.gitignore` يغطي: env، keystore،
  `google-services.json`، `firebase_options.dart`).
- لا يُدَّعى أن الأمان أو Firebase "يعمل" قبل كتابة القواعد واختبارها فعليًا.
