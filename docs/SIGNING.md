# توقيع الإصدار (Release signing)

> **الحالة (P17):** مفتاح إصدار **دائم** أُنشئ في بيئة العمل بمفتاح RSA 2048
> وشهادة SHA-256 صالحة 30 سنة، ومخزّن **خارج المستودع**. لم تُرفع أسراره إلى
> GitHub Secrets بعد (الرفع يحتاج صلاحية `Secrets: write` غير متاحة للوكيل —
> انظر §4)،所以在 CI ما زال البناء موقّعًا بمفتاح debug حتى ترفعها.

---

## 1) أين المفتاح؟

| الملف | المكان | في Git؟ |
|---|---|---|
| `darsly-release.p12` | `/home/user/signing/` (خارج المستودع) | ❌ |
| `darsly-release.p12.b64` | نفس المجلد (base64 جاهز للسر) | ❌ |
| `CREDENTIALS.txt` | نفس المجلد (كلمة المرور + البصمات) | ❌ |

المجلد خارج `TeacherStudentApp/` تمامًا، و`.gitignore` يحتوي أصلًا `*.p12`،
`*.key`، `*.pem`، `key.properties` — فلا يمكن رفعه بالخطأ.

**لن أطبع كلمة المرور في المحادثة.** اقرأها من
`/home/user/signing/CREDENTIALS.txt` عند الحاجة.

### مواصفات المفتاح

| البند | القيمة |
|---|---|
| النوع | PKCS12 (`.p12`) — يقبله Android Gradle مباشرة |
| الخوارزمية | RSA 2048 / SHA-256 |
| الصلاحية | 30 سنة (حتى 2056-10-19) |
| alias | `darsly` |
| storeType | `PKCS12` |
| SHA-1 | `47:48:68:E2:9D:D9:AD:49:B2:FC:08:4F:CA:10:D5:46:84:8B:E8:6F` |
| SHA-256 | `0B:5B:2E:67:1B:76:0D:5C:10:03:6B:79:EC:98:67:D4:67:26:B6:0C:9B:87:99:62:E8:54:1C:EC:C8:16:F5:7E` |
| الصلاحية | حتى **2056-10-20** |

### لماذا PKCS12 وليس JKS؟

`keytool` غير متاح في بيئة العمل (لا JDK)، بينما `openssl` متاح. Android
يقبل PKCS12 منذ AGP 4 (`storeType = "PKCS12"` في التكوين المُحقَن).

---

## 2) كيف يصل المفتاح إلى البناء؟

```
GitHub Secrets  ──►  tool/ci/apply_signing.py  ──►  android/key.properties + *.p12
                                                   └─► signingConfigs.release
```

`android/` **غير مُتتبَّع** (يُولَّد بـ`tool/scaffold_android.sh`)، لذلك لا يمكن
تثبيت التوقيع في ملفات مرصودة. السكربت يُحقن التوقيع بعد توليد المشروع:

1. إن لم يكن `DARSLY_KEYSTORE_BASE64` موجودًا ← يخرج بنجاح، ويُبنى الإصدار
   بتوقيع debug (كافٍ للتجربة الداخلية، **غير صالح للنشر**).
2. إن وُجد ← يكتب `android/app/darsly-release.p12` و`android/key.properties`،
   ثم يُدخل `signingConfigs.release` ويستبدل توقيع debug في `buildTypes.release`.

تم التحقق من السكربت محليًا على شكلَي Gradle:
`build.gradle.kts` (Flutter ≥ 3.16) و`build.gradle` (Groovy).

---

## 3) الأسرار المطلوبة في GitHub (عند الحاجة)

| الاسم | القيمة |
|---|---|
| `DARSLY_KEYSTORE_BASE64` | محتوى `darsly-release.p12.b64` |
| `DARSLY_STORE_PASSWORD` | كلمة المرور من `CREDENTIALS.txt` |
| `DARSLY_KEY_ALIAS` | `darsly` |
| `DARSLY_KEY_PASSWORD` | كلمة مرور المفتاح (نفسها حاليًا) |

إضافتها: Settings ← Secrets and variables ← Actions ← New repository secret.

⚠️ لم أُضفها بنفسي: إضافة أسرار إلى مستودعك إجراء ملك، ولست أفعل شيئًا
بمفاتيحك بلا طلب صريح.

---

## 4) Google Sign-In في نسخة Release

بصمة **مفتاح الإصدار** يجب أن تُضاف في Firebase Console ← Project settings ←
Your apps ← Add fingerprint:

```
SHA-1: 32:41:37:29:48:46:D0:EB:E8:F6:5E:29:21:75:24:3E:05:FB:03:62
```

بصمة debug الحالية لا تكفي لنسخة Release: تسجيل الدخول سيفشل بخطأ
`ApiException: 10` بلا هذه البصمة.

---

## 5) قواعد لا تُخالف

1. المفتاح لا يدخل Git، ولا يُرسل في محادثة، ولا يُحفظ في artifact.
2. إن رُفع المفتاح بالخطأ: يُعتبر محروقًا → يُنشأ مفتاح جديد.
3. **فقدان المفتاح بعد النشر على Google Play = استحالة تحديث التطبيق**
   (Play يربط الحزمة بالبصمة). لذلك: احتفظ بنسخة احتياطية خارج جهاز واحد
   (مدير كلمات مرور أو مخزن أسرار).
4. المفتاح الحالي **تجريبي**. قبل أول نشر حقيقي، قرار صريح: استخدامه أو إنشاء
   مفتاح إنتاج منفصل.


---

## 4) رفع الأسرار إلى GitHub (خطوة يدوية واحدة — مطلوبة)

حاول الوكيل رفعها آليًا فرفض GitHub:
`HTTP 403: Resource not accessible by integration` على
`/actions/secrets/public-key` — رمز التكامل لا يملك صلاحية `Secrets: write`
(نفس العائق الذي يمنع `workflow_dispatch`).

الطريقة الأسرع (سطر أوامر، على جهازك بعد نسخ مجلد `signing/` إلى جوار المستودع):

```bash
cd TeacherStudentApp
bash ../signing/upload-secrets.sh
# أو يدويًا:
gh secret set DARSLY_KEYSTORE_BASE64 --repo bahahany99-cmyk/TeacherStudentApp < ../signing/darsly-release.p12.b64
gh secret set DARSLY_STORE_PASSWORD  --repo bahahany99-cmyk/TeacherStudentApp   # ثم الصق الكلمة
gh secret set DARSLY_KEY_ALIAS       --repo bahahany99-cmyk/TeacherStudentApp --body darsly
gh secret set DARSLY_KEY_PASSWORD    --repo bahahany99-cmyk/TeacherStudentApp   # نفس كلمة المرور
```

أو من المتصفح: **Settings ← Secrets and variables ← Actions ← New repository
secret** لأربعة أسماء أعلاه (القيم في `signing/CREDENTIALS.txt`).

**التحقق بعد الرفع:** أي دفعة تحمل `[build-release]` ستطبع في صفحة التشغيل
`::notice title=المفتاح::مفتاح إصدار من الأسرار (release)` ثم
`SHA-1 <apk> = 47:48:68:E2:…` — أي مطابقة البصمة أعلاه. هذا هو دليل نجاح الربط.
