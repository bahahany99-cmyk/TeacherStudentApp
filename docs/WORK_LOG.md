# سجل العمل — TeacherStudentApp

> يُحدَّث هذا الملف في نهاية كل مرحلة: ما نُفِّذ، ما تم التحقق منه فعليًا، المشكلات المتبقية، والخطوة التالية.

---

## المرحلة 1 — فحص البيئة والتأسيس التنظيمي

**التاريخ:** 2026-10-26
**الفرع:** `arena/3fbab133-teacherstudentapp` (من `main` عند `2e09398`)
**الحالة:** منجزة بانتظار مراجعة صاحب المشروع

### ما نُفِّذ

1. فحص المستودع والبيئة (Git، الفروع، الأدوات المتاحة، الشبكة، الموارد).
2. إنشاء/تحديث وثائق المشروع:
   - `README.md` (أُعيدت كتابته — كان سطرًا واحدًا فقط).
   - `docs/PROJECT_PLAN.md`
   - `docs/PRODUCT_REQUIREMENTS.md`
   - `docs/ARCHITECTURE_DECISIONS.md`
   - `docs/WORK_LOG.md` (هذا الملف)
3. إضافة `.gitignore` احترازي يمنع حفظ الأسرار والمفاتيح لاحقًا.
4. مراجعة الجاهزية (فحص الأسرار، فحص النطاق، فحص حالة المستودع).

### ما تم التحقق منه فعليًا (بالأوامر)

| الفحص | الأمر | النتيجة الفعلية |
|---|---|---|
| إصدار Git | `git --version` | `2.39.5` |
| الوجود داخل مستودع | `git rev-parse --is-inside-work-tree` | نعم (جذر `/home/user/TeacherStudentApp`) |
| اسم المستودع البعيد | `git remote -v` | `github.com/bahahany99-cmyk/TeacherStudentApp.git` |
| الفروع | `git branch -a` | `arena/3fbab133-teacherstudentapp` (حالي)، `main`، `origin/main` |
| التاريخ | `git log --oneline` | commit واحد: `2e09398 Initial commit` |
| محتوى المستودع قبل العمل | `git ls-files` | ملف واحد: `README.md` (20 بايت) |
| حالة العمل | `git status` | نظيف قبل البدء |
| `gh` | `gh auth status` | مصادَق عليه كـ `bahahany99-cmyk` |
| Flutter | `which flutter` / `flutter --version` | **غير موجود** |
| Dart | `which dart` | **غير موجود** |
| Java | `which java` | **غير موجود** |
| Android SDK | `echo $ANDROID_HOME` / `ls ~/Android` | غير موجود |
| pub.dev | `curl --max-time 8 https://pub.dev` | **فشل (`000`)** |
| storage.googleapis.com | `curl` | فشل (`000`) |
| github.com | `curl` | `200` |
| الموارد | `free -h` / `df -h` | 3.8 GB RAM، ~20 GB حرة |
| أسرار في المستودع | `env` + فحص الملفات | لا أسرار داخل الملفات؛ متغيرا `GH_TOKEN`/`GITHUB_TOKEN` من البيئة فقط، غير محفوظين في المستودع |

### ما لم يُنفَّذ (بقصد)

- لم يُنشأ مشروع Flutter (`flutter create`) — الأدوات غير متاحة والمرحلة لا تسمح ببناء واجهات.
- لم تُنشأ أي خدمة Firebase/Supabase أو حساب سحابي.
- لم تُضف أي حزمة أو مكتبة.
- لم يُبنَ أي APK (غير مطلوب في هذه المرحلة).
- لم تُنفَّذ عمليات `push` أو `pull request` أو نشر.

### المشكلات والقيود

1. **لا يمكن تطوير أو بناء Flutter في هذه البيئة** لسببين مستقلين: غياب SDK، وحجب `pub.dev` (وبالتالي تعذّر جلب الحزم حتى مع وجود SDK).
2. بيئة موارد محدودة (3.8 GB RAM) — يجب تجنّب عمليات البناء الثقيلة والاختبارات البصرية المعتمدة على محاكيات.
3. لا يوجد خط عربي أو أدوات تصميم جاهزة — ستُحدد في مرحلة الهيكل الأساسي.
4. قرار الخادم لم يُحسم، ومعه تكلفة التشغيل غير معروفة.

### الملفات المعدّلة/المُنشأة

| الملف | النوع |
|---|---|
| `README.md` | معدّل (استُبدل محتواه من سطر واحد إلى وصف كامل) |
| `.gitignore` | جديد |
| `docs/PROJECT_PLAN.md` | جديد |
| `docs/PRODUCT_REQUIREMENTS.md` | جديد |
| `docs/ARCHITECTURE_DECISIONS.md` | جديد |
| `docs/WORK_LOG.md` | جديد |


### الخطوة التالية المقترحة آنذاك (اعتُمدت في المرحلة 2)

مراجعة تقرير المرحلة 1 والموافقة على خطة المراحل، وحسم قيد البيئة (أين يُبنى
تطبيق Flutter؟)، والإجابة على الحد الأدنى من الأسئلة الحرجة (الخادم، المميزون،
الفلاتر، دورة حياة الحجز، السعة).

> **تمّ في المرحلة 2:** قرار الخادم (Firebase) والمميزون/الفلاتر كأسئلة مفتوحة
> موثّقة. أما قيد البيئة فما زال قائمًا (لا Flutter في بيئة التنفيذ).

---

## المرحلة 2 — تثبيت القرارات التقنية وإنشاء هيكل التطبيق

**التاريخ:** 2026-10-26
**الفرع:** `arena/3fbab133-teacherstudentapp`
**الحالة:** منجزة بانتظار مراجعة صاحب المشروع — **الكود لم يُصرَّف ولم يُختبر آليًا**

### ما نُفِّذ

1. **تثبيت القرارات:** Firebase (Auth / Firestore / Storage / FCM / Cloud Functions)
   منظومة أساسية، لا Supabase، البحث بـ Firestore فقط. موثّقة كـ F-01..F-10
   في `ARCHITECTURE_DECISIONS.md`، وبعضها كمتطلبات منتج C-20..C-26.
2. **هيكل مشروع Flutter:**
   - `pubspec.yaml` (اعتمادية واحدة إضافية فقط: `firebase_core`).
   - `analysis_options.yaml` مع `flutter_lints`.
   - `.gitignore` موسّع (أسرار + مخرجات Flutter + ملفات Firebase المحلية).
3. **نظام تصميم مركزي:** `core/theme/` (ألوان، مسافات، خطوط، ثيم فاتح/داكن).
4. **العربية وRTL:** `locale: ar_EG`، `flutter_localizations`، وفرض
   `Directionality(rtl)` في `MaterialApp.builder`.
5. **التنقل:** `AppRouter` مركزي + `RoutePaths` + `AppShell` بقائمة تنقّل
   مختلفة للطالب (5 تبويبات) والمدرس (4 تبويبات).
6. **الجلسة:** `SessionController` + `SessionScope`، مع جلسة معاينة معلَّمة
   (`isDemoAccount`) و`DemoBanner` على كل شاشة تعرض بيانات وهمية.
7. **طبقة البيانات:** عقود (`AuthService`, `TeacherRepository`, `GroupRepository`,
   `BookingRepository`) + نماذج + تنفيذ تجريبي معزول في `data/demo/`.
   الشاشات **لا تستورد** أي حزمة Firebase.
8. **Firebase:** نقطة تهيئة واحدة `FirebaseBootstrap` معطّلة افتراضيًا عبر
   `--dart-define=ENABLE_FIREBASE` (الافتراضي `false`)، وتفشل بأمان.
9. **الشاشات (بنية عرض):** البداية، الدخول، رئيسية الطالب، رئيسية المدرس،
   المدرسون، المجموعات (صفحة مستقلة)، الحجوزات، الحساب.
10. **الاختبارات:** 3 ملفات (2 widget + 1 unit) + helper مشترك.
11. **وثيقة جديدة:** `docs/FIREBASE_SETUP.md` بخطوات الربط الخارجية.
12. **تحديث الوثائق:** `README`, `PROJECT_PLAN`, `PRODUCT_REQUIREMENTS`,
    `ARCHITECTURE_DECISIONS`, `WORK_LOG`.

### ما تم التحقق منه فعليًا

| الفحص | الأداة | النتيجة |
|---|---|---|
| وجود الأدوات | `which flutter dart java` | **لا شيء** — غير متاحة |
| الشبكة | `curl` لـ `pub.dev`, `storage.googleapis.com`, `api.github.com` | pub.dev **محجوب** (000)، googleapis **محجوب**، api.github.com **200** |
| إصدارات الحزم | `api.github.com` → `firebase/flutterfire` و`flutter/packages` | firebase_core 5.1.0، firebase_auth 7.0.1، cloud_firestore 7.1.0، firebase_storage 14.0.1، firebase_messaging 17.0.1، google_sign_in 7.2.0، flutter_lints 6.0.0 |
| سلامة الأقواس في كل ملفات Dart | سكربت Python (توازن `{}` `()` `[]` بعد إزالة التعليقات والنصوص) | 49 ملفًا — لا اختلال |
| صحة مسارات الاستيراد | نفس السكربت (تحقق من وجود كل ملفات `package:teacher_student_app/…` والمسارات النسبية) | لا مسار مفقود |
| أسرار في المستودع | `grep` لأنماط (api key / secret / AIza / ghp_ / private key / client_secret) | لا نتائج (بند واحد هو نمط في `.gitignore`) |
| صحة YAML | PyYAML في بيئة معزولة | `pubspec.yaml` و`analysis_options.yaml` يُحلَّلان بنجاح؛ الاعتماديات: flutter, flutter_localizations, firebase_core |
| استيرادات غير مستخدمة | سكربت Python يقارن الرموز المعلنة مع كل ملف | لا استيراد غير مستخدم |
| تطابق واجهات Flutter المستخدمة | مقارنة مع `theme_data.dart`, `app_bar_theme.dart`, `navigation_bar_theme.dart`, `input_decorator.dart`, `divider_theme.dart`, `text_theme.dart`, `material_localizations.dart` من فرع `stable` | الأنواع والمعاملات موجودة (`inputDecorationTheme`/`appBarTheme` من نوع `Object?` في `copyWith`، `TextTheme.apply(fontFamilyFallback:)`، `GlobalMaterialLocalizations.delegates`) |
| ارتفاعات/نطاق | مراجعة يدوية للملفات | لا منطق حجز/محادثة/بحث حقيقي |

### ما لم يُنفَّذ ولم يُختبر (بصراحة)

- **`flutter pub get` لم يُنفَّذ** (لا Flutter، وpub.dev محجوب) → إصدارات
  الاعتماديات لم تُحلَّ فعليًا.
- **`flutter analyze` لم يُنفَّذ** → يمكن أن توجد أخطاء أنواع/واجهات برمجية لم
  يكتشفها فحص الأقواس والاستيراد.
- **`flutter test` لم يُنفَّذ** → الاختبارات الثلاثة مكتوبة وغير مُشغَّلة.
- **`flutter build apk` لم يُنفَّذ** ولا يوجد مجلد `android/` (يُولَّد بأمر
  موثّق في README لأن `flutter create` يحتاج SDK).
- **لا مشروع Firebase** ولا `google-services.json` ولا `firebase_options.dart`.
- **لا قواعد Firestore/Storage** — مكتوبة كالتزامات في ARCHITECTURE فقط.
- **لا تحقق بصري** من الواجهات (لا محاكي/جهاز).

### المشكلات والقيود

1. غياب Flutter/Dart/Java/Android SDK + حجب `pub.dev` → استحالة أي تحقق آلي.
2. إصدارات الحزم مأخوذة من ملفات المستودعات الرسمية لأن pub.dev غير متاح؛
   قد يختلف الحل الفعلي عند أول `pub get`.
3. `google_sign_in` 7.2.0 يتطلب Dart ^3.11: من يستخدم Flutter أقدم يحتاج
   تخفيض الاعتماديات (موثّق في README).
4. `applicationId` نهائي غير محدد (Q-29) — يلزم قبل إنشاء تطبيق Firebase.

### الملفات

| النوع | الملفات |
|---|---|
| جديدة (إعداد) | `pubspec.yaml`, `analysis_options.yaml`, `docs/FIREBASE_SETUP.md` |
| معدّلة | `.gitignore`, `README.md`, `docs/PROJECT_PLAN.md`, `docs/PRODUCT_REQUIREMENTS.md`, `docs/ARCHITECTURE_DECISIONS.md`, `docs/WORK_LOG.md` |
| جديدة (كود) | 49 ملف Dart في `lib/` و`test/` (تفصيلها في `ARCHITECTURE_DECISIONS.md` → البنية المنفذة) |

### الخطوة التالية المقترحة (لا تبدأ دون موافقة)

**المرحلة 3:** تنفيذ المشروع على جهاز فيه Flutter — توليد `android/`، ثم
`pub get` + `analyze` + `test` + بناء APK، وإصلاح أي أخطاء تظهر، وتوثيق
النتائج الفعلية. بعدها تُعتمد المرحلة 4 (المصادقة + قواعد Firestore الأولى).


---

## جلسة 2026-10-26 (بعد المرحلة 2) — طلب "المرحلة الأولى من المواصفات" والتحقق الفعلي

**السياق:** وصل طلب يفترض أن المستودع **فارغ** وأن Flutter/Dart متاحان. تحققت من
الوضع قبل أي تنفيذ، ولم تكن المقدمتان صحيحتين.

### نتائج التحقق من الحالة الفعلية

| الفحص | النتيجة الفعلية |
|---|---|
| حالة المستودع | **ليس فارغًا**: 58 ملفًا في شجرة العمل (وثائق المرحلة 1، هيكل المرحلة 2، 48 ملف Dart) |
| تاريخ Git | **أُعيد استنساخ المستودع** فصار `git log` = commit واحد `2e09398 Initial commit`، وملفات المرحلتين 1 و2 **غير مُودَعة** (untracked/modified). لا commits مفقودة يمكن استرجاعها (`git fsck` نظيف، `git reflog` يبدأ من الاستنساخ) |
| مجلد `android/` | **غير موجود** (المشروع لم يُولَّد بأمر `flutter create`) |
| `flutter` / `dart` | **غير موجودين** (`command not found`) |
| `java` / Android SDK | **غير موجودين** |
| `pub.dev` | **محجوب** (`curl` → `000`) |

**النتيجة:** لا يمكن تنفيذ `flutter pub get` ولا `flutter analyze` ولا
`flutter test` ولا `flutter create`، وبالتالي لا يمكن إنشاء ملفات منصة Android
قياسية قابلة للبناء ولا الجزم بأن التطبيق يعمل.

### قرار صاحب المشروع (استُؤذن صريحًا)

1. **إبقاء العمل الحالي كما هو** والمتابعة عليه (لا حذف ولا استبدال).
2. **عدم كتابة ملفات `android/` يدويًا** في هذه البيئة؛ تُولَّد على جهاز فيه
   Flutter SDL في المرحلة 3.

**أثر القرار الأول:** بقيت اعتمادية `firebase_core` وكود تهيئة Firebase كما
اعتُمد في المرحلة 2، رغم أن الطلب الجديد ذكر «لا تربط Firebase». أُبقي الوضع
الحالي بناءً على قرارك، وتهيئة Firebase معطّلة افتراضيًا
(`ENABLE_FIREBASE=false`) فلا يوجد أي اتصال فعلي بأي خدمة.

### ما نفّذته في هذه الجلسة (فعليًا)

1. **تثبيت الهوية المؤقتة في مكان واحد:** `lib/core/config/app_identity.dart`
   (`technicalId = teacher_student_app`, `displayName`, `tagline`,
   `isProvisional = true`)، وربط `AppStrings` و`AppConfig` و`MaterialApp.title`
   به، وحذف الاسم المكرر من `AppConfig`.
2. **تعليق توضيحي في `pubspec.yaml`** يوضّح أن `name` معرّف تقني مؤقت لا اسم تجاري.
3. **README:** قسم «الهوية والاسم المؤقت» بجدول يحدد مكان تعديل كل عنصر عند
   اعتماد الاسم، وقسم «التحقق المنفَّذ وما لم يُنفَّذ».
4. **PROJECT_PLAN:** توضيح أن المرحلة 3 متوقفة بانتظار بيئة فيها Flutter.
5. هذا السجل.

### ما لم يُنفَّذ (وسببه)

| المطلوب في الطلب | الحالة | السبب |
|---|---|---|
| التحقق من أن المستودع فارغ | ❌ غير صحيح | المستودع يحتوي عمل المرحلتين 1 و2 |
| التحقق من توفّر Flutter/Dart | ✅ تحقّق — غير متاحين | — |
| `flutter create` لمشروع قياسي | ❌ | لا SDK |
| ملفات Android قابلة للتشغيل | ❌ | لا SDK؛ وكتابتها يدويًا مرفوضة بقرارك (كما أنها ستكون ناقصة: `gradle-wrapper.jar` ملف ثنائي لا يمكن توليده هنا) |
| `flutter pub get` | ❌ | لا SDK + `pub.dev` محجوب |
| `flutter analyze` | ❌ | لا SDK |
| تشغيل الاختبارات | ❌ | لا SDK |
| تشغيل التطبيق على جهاز/محاكي | ❌ **لم يحدث إطلاقًا** | لا محاكي ولا جهاز |

### الخطوة التالية

تنفيذ المرحلة 3 على جهاز فيه Flutter stable + Android SDK:
`flutter create` لتوليد `android/` ثم `pub get` → `analyze` → `test` →
`build apk --debug`، مع إصلاح أي أخطاء تظهر وتسجيل مخرجاتها الفعلية.
