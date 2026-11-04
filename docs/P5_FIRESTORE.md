# P5 — Firestore: مستودعات القراءة وقواعد الأمان

> **ما هو منفَّذ:** قراءة المدرسين/المجموعات/الأعضاء/الحجوزات من Firestore،
> وتحويل مستنداتها إلى نماذج التطبيق، وملف قواعد أمان كامل بالسياسة المعتمدة
> (A-42).
>
> **ما لم يُنفَّذ:** لا يوجد مشروع Firebase مُنشأ، فلم تُنشر القواعد ولم تُقرأ
> مستندات حقيقية. كل الاختبارات أدناه على التحويل في الذاكرة، لا على خادم.

---

## 1) هيكل البيانات (المجموعات والحقول)

### `users/{uid}` — يُكتب من التطبيق (P4)

| الحقل | النوع | يكتبه |
|---|---|---|
| `displayName` | string | التطبيق |
| `email` | string? | التطبيق |
| `role` | `'student'` \| `'teacher'` | التطبيق **مرة واحدة** |
| `createdAt`, `roleChosenAt` | timestamp | التطبيق |

### `teacherProfiles/{uid}` — يُنشأ تلقائيًا عند اختيار دور المدرس

| الحقل | النوع | يكتبه |
|---|---|---|
| `ownerId` | string (uid) | التطبيق |
| `displayName` | string | التطبيق |
| `status` | `pendingReview` \| `approved` \| `rejected` \| `draft` | التطبيق يكتب `pendingReview` فقط |
| `subject`, `stage`, `area`, `bio`, `priceHint` | string | التطبيق (المدرس) |
| `createdAt` | timestamp | التطبيق |
| `isFeatured`, `rating`, `reviewsCount` | bool / number / number | **الإدارة فقط** (ليست في القواعد ⇒ مرفوضة من التطبيق) |

### `studyGroups/{groupId}` — للقراءة فقط في هذه المرحلة

| الحقل | النوع |
|---|---|
| `teacherId`, `teacherName` | string |
| `title`, `subject`, `stage` | string |
| `seatsTotal`, `seatsTaken` | int |
| `meetingMode` | `online` \| `home` \| `center` |
| `scheduleNote` | string? |
| `isActive` | bool (الافتراضي `true`) |

### `studyGroups/{groupId}/members/{memberUid}`

`name` (string) · `joinedAt` (timestamp) · `status`: `active` \| `waitlist`

### `bookingRequests/{bookingId}`

`teacherId`, `teacherName`, `studentId`, `studentName` · `subject` · `requestedAt` ·
`status`: `pending` \| `accepted` \| `rejected` \| `cancelled` \| `completed` · `note`

---

## 2) الاستعلامات المستخدمة (وفهارسها)

| الاستعلام | الفهرس |
|---|---|
| `teacherProfiles where status == 'approved'` | مفرد (تلقائي) |
| `teacherProfiles where status == 'approved' and isFeatured == true` | **مركّب** (في `firestore.indexes.json`) |
| `studyGroups where isActive == true` | مفرد |
| `studyGroups where teacherId == teacherId` | مفرد |
| `studyGroups/{id}/members` | مجموعة فرعية |
| `bookingRequests where studentId == uid` + `where teacherId == uid` | مفردان ثم دمج في التطبيق |

**لماذا ندمج الطلبات في التطبيق؟** لأن استعلامًا واحدًا بـ`OR` على حقلين يحتاج
`array-contains` على حقل مصفوفة (تغيير في هيكل البيانات) أو استعلامين. اخترنا
استعلامين صغيرين ودمجًا في الذاكرة، فلم نُغيّر هيكل البيانات لأجل الأداء.

---

## 3) قاعدة القرار: كيف تُقرأ البيانات في التطبيق

```
AppServices.bootstrap()
├── Firebase جاهز  →  FirestoreTeacherRepository / Group / Booking  + FirebaseAuthService
└── غير جاهز      →  الحزمة التجريبية (وضع الزائر) كما هي
```

الشاشات لا تعرف أي تنفيذ وراءها: كلها تتعامل مع العقود (`TeacherRepository`…).
هذا ما يجعل «وضع الزائر» و«الوضع المتصل» يعملان بنفس الواجهات.

**تسامح التحويل** (`lib/data/firebase/mappers/firestore_mappers.dart`):
- مستند بلا حقل أساسي (اسم/عنوان/مالك) ⇒ **يُتجاهل** ولا يُسقط القائمة.
- حقل ناقص غير أساسي ⇒ قيمة آمنة («غير محدد»، 0، `false`).
- حالة ملف غير معروفة ⇒ `pendingReview`، فلا يظهر ملف مجهول للطلاب.
- أرقام مقاعد سالبة ⇒ صفر.

---

## 4) قواعد الأمان (`firestore.rules`)

| المسار | القراءة | الكتابة |
|---|---|---|
| `users/{uid}` | صاحبه أو إدارة | صاحبه فقط؛ `role` ثابت بعد الإنشاء؛ الحقول محدّدة بقائمة |
| `teacherProfiles/{uid}` | الجميع إن `status == 'approved'`؛ صاحبه دائمًا؛ الإدارة | صاحبه للحقول الوصفية فقط؛ `status` و`ownerId` ثابتان؛ حقول الإدارة ممنوعة |
| `studyGroups/{id}` | النشِطة للمسجّلين؛ صاحبها يرى الموقوفة | ممنوعة الآن (تُفتح في P7) |
| `studyGroups/{id}/members/{m}` | الإدارة والمدرس صاحب المجموعة فقط | ممنوعة الآن |
| `bookingRequests/{id}` | الطرفان فقط | ممنوعة الآن (تُفتح في P8) |
| كل ما عدا ذلك | **مرفوض** | **مرفوض** |

الدور الإداري يُمنح فقط عبر Custom Claim (`request.auth.token.admin`)، ويُضبط
بمفتاح خدمة خارج التطبيق — لا يمكن للتطبيق منح نفسه صلاحية.

### النشر (من صاحب المشروع)

```bash
# بعد إنشاء المشروع (me-central1) وتثبيت Firebase CLI
firebase login
firebase use <PROJECT_ID>
firebase deploy --only firestore:rules,firestore:indexes
```

⚠️ **لا تنشر القواعد قبل أن يعمل تسجيل الدخول**، لأن القواعد تمنع أي قراءة
بلا مستخدم مصادق. ترتيب آمن: Auth → القواعد → التطبيق.

### ما لا تفحصه أدواتنا

`tool/ci/check_rules.py` يفحص أشياء بنيوية فقط (توازن الأقواس، وجود الرفض
الافتراضي، منع `allow ... if true`، ثبات الدور والحالة، عدم ذكر حقول الإدارة).
**الفحص المنطقي الحقيقي** يحتاج محاكي Firestore:
`firebase emulators:exec --only firestore 'npm test'` مع `@firebase/rules-unit-testing`
(البند T-09)، وهو غير منفَّذ بعد.

---

## 5) ما لم يُنفَّذ في هذه المرحلة (بصراحة)

- ❌ **لا نشر للقواعد ولا لقراءة حقيقية**: لا مشروع، ولا مفاتيح، ولا جهاز.
- ❌ **لا كتابة** من التطبيق إلى `studyGroups` أو `bookingRequests` — مؤجّلة
  إلى P7/P8 بحسب الروادماب، والقواعد ترفضها الآن صراحةً.
- ❌ `limit`/pagination: الاستعلامات تقرأ كل النتائج المطابقة. مقبول الآن
  (بيانات صفرية/قليلة)، ومطلوب قبل الإطلاق (T-04).
- ❌ لا `Stream` لحظي: الشاشات تقرأ عند البناء، وإعادة القراءة عند «إعادة
  المحاولة» فقط.
- ❌ لا مراقبة اتصال (`OfflineBanner` جاهز وغير مستخدم).
