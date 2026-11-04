/// أسماء المسارات في التطبيق (مكان واحد).
///
/// التنقل الحالي بسيط (اسمي) مع تمرير المعرّف كـ`arguments`.
/// إذا احتجنا لاحقًا إلى روابط أعمق (`/teachers/:id`) يمكن الانتقال إلى
/// `go_router` دون تغيير أسماء المسارات هنا (انظر T-02 في
/// `docs/ARCHITECTURE_DECISIONS.md`).
abstract final class RoutePaths {
  static const String splash = '/';
  static const String login = '/login';

  /// الدخول/إنشاء حساب بالبريد وكلمة المرور (P4).
  static const String emailAuth = '/login/email';

  /// اختيار الدور عند أول دخول (P4) — يظهر مرة واحدة فقط.
  static const String roleSelection = '/onboarding/role';
  static const String shell = '/app';

  // ── شاشات التفاصيل (P3) ────────────────────────────────────────────────────
  // نمرّر الخريطة/المعرّف عبر `arguments`، والشاشة تقرأ الباقي من الجلسة
  // (الدور) ومن المستودعات (البيانات).

  /// ملف مدرس (واجهة الطالب). `arguments` = معرّف المدرس.
  static const String teacherProfile = '/teacher';

  /// «المدرسون المميزون» — صفحة كاملة (P25). بلا `arguments`: القائمة
  /// محسوبة أسبوعيًا من مصدرها، لا تُمرَّر من الشاشة السابقة.
  static const String featuredTeachers = '/teachers/featured';

  /// تفاصيل مجموعة. `arguments` = معرّف المجموعة.
  static const String groupDetails = '/group';

  /// إنشاء/تعديل مجموعة (واجهة المدرس — P7).
  /// `arguments` = معرّف المجموعة عند التعديل، أو `null` للإنشاء.
  static const String groupForm = '/group/form';

  /// أعضاء مجموعة (واجهة المدرس). `arguments` = معرّف المجموعة.
  static const String groupMembers = '/group/members';

  /// طلبات الانضمام (P8). `arguments` = معرّف المجموعة للمدرس، ويُتجاهل في
  /// واجهة الطالب (تعرض طلباته في كل المجموعات).
  static const String groupRequests = '/group/requests';

  /// جدول المجموعة الأسبوعي (P9). `arguments` = معرّف المجموعة.
  static const String groupTimetable = '/group/timetable';

  /// محادثة المجموعة (P9). `arguments` = معرّف المجموعة.
  static const String groupChat = '/group/chat';

  /// تفاصيل طلب حجز. `arguments` = معرّف الطلب.
  static const String bookingDetails = '/booking';

  /// صندوق المحادثات المباشرة (P11).
  static const String directChats = '/chats';

  /// محادثة مباشرة واحدة. `arguments` = معرّف المحادثة.
  static const String directChat = '/chat';

  /// المفضلة: مدرسون ومجموعات (P13).
  static const String favorites = '/favorites';

  /// الإشعارات داخل التطبيق (P12).
  static const String notifications = '/notifications';

  /// ملف المدرس الخاص (واجهة المدرس).
  static const String myTeacherProfile = '/me/teacher-profile';

  /// تعديل معلومات الملف (واجهة المدرس — نموذج عرض لا يحفظ).
  static const String editTeacherProfile = '/me/teacher-profile/edit';

  /// (P30) مزاد التمييز الأسبوعي — شاشة المدرّس (مزايدتي ومقعدي).
  ///
  /// بلا `arguments`: الشاشة تقرأ حالتها من الخادم (وفئتها من ملفها).
  static const String auction = '/me/auction';

  /// «بياناتي» (P18): تعديل الاسم والهاتف والمرحلة في `users/{uid}`.
  static const String myData = '/me/data';

  /// المساعدة والدعم (P18) — محتوى إرشادي وقناة تواصل.
  static const String support = '/support';

  /// الشروط وسياسة الخصوصية (P18).
  static const String legal = '/legal';

  /// لوحة الإدارة (P14) — محمية بـ[AdminGuard] وتُخفي عن غير المسؤول.
  static const String adminDashboard = '/admin';

  /// إدارة المدرسين المميزين (P15) — تمييز الملفات الموثّقة.
  static const String adminFeatured = '/admin/featured';

  /// طابور توثيق ملفات المدرسين (P14).
  static const String adminVerification = '/admin/teachers';

  /// مراجعة البلاغات والتقييمات (P14).
  static const String adminModeration = '/admin/moderation';

  /// (P30) إدارة مزاد التمييز: الدورتان، الفائزون، الدفع، النشر، والإعدادات.
  static const String adminAuction = '/admin/auction';

  /// استعادة حساب مجدول للحذف داخل مهلة السماح (P17).
  ///
  /// تُفتح بعد تسجيل الدخول مباشرةً لحساب حالته `pending_deletion`، ولا يمكن
  /// الوصول إليها من التنقل العادي: وجودها في المسارات لا يمنح دخولًا للتطبيق.
  static const String accountRestore = '/account/restore';

  /// معرض المكونات — شاشة تطوير للمراجعة البصرية فقط (P1).
  static const String designGallery = '/dev/design-gallery';
}
