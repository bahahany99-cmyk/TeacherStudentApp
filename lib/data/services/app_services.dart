import 'package:flutter/foundation.dart';

import 'package:teacher_student_app/core/config/firebase_bootstrap.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/firebase/firebase_auth_service.dart';
import 'package:teacher_student_app/data/firebase/firestore_repositories.dart';
import 'package:teacher_student_app/data/services/admin_repository.dart';
import 'package:teacher_student_app/data/services/avatar_repository.dart';
import 'package:teacher_student_app/data/services/chat_image_repository.dart';
import 'package:teacher_student_app/data/services/chat_image_saver.dart';
import 'package:teacher_student_app/data/services/image_picker_gateway.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/teacher_review.dart';
import 'package:teacher_student_app/data/services/booking_repository.dart';
import 'package:teacher_student_app/data/services/direct_chat_repository.dart';
import 'package:teacher_student_app/data/services/favorite_repository.dart';
import 'package:teacher_student_app/data/services/notification_repository.dart';
import 'package:teacher_student_app/data/services/review_repository.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';
import 'package:teacher_student_app/data/services/message_repository.dart';
import 'package:teacher_student_app/data/services/schedule_repository.dart';
import 'package:teacher_student_app/data/services/teacher_repository.dart';

/// حاوية واحدة تعرّف "حدود" طبقة البيانات أمام الواجهات.
///
/// الشاشات لا تستورد Firebase ولا أي حزمة شبكة؛ تطلب هذه العقود فقط.
/// استبدال التنفيذ التجريبي بتنفيذ Firestore يتم في مكان واحد (هذه الحاوية).
class AppServices {
  AppServices({
    required this.auth,
    required this.teachers,
    required this.groups,
    required this.bookings,
    required this.schedules,
    required this.messages,
    required this.chats,
    required this.notifications,
    required this.reviews,
    required this.favorites,
    required this.admin,
    AvatarRepository? avatars,
    ImagePickerGateway? imagePicker,
    ChatImageRepository? chatImages,
    ChatImageSaver? imageSaver,
    ValueNotifier<int>? groupsRevision,
  }) : avatars = avatars ?? const EmptyAvatarRepository(),
       imagePicker = imagePicker ?? const UnavailableImagePickerGateway(),
       chatImages = chatImages ?? const EmptyChatImageRepository(),
       imageSaver = imageSaver ?? const UnavailableChatImageSaver(),
       groupsRevision = groupsRevision ?? ValueNotifier<int>(0);

  final AuthService auth;
  final TeacherRepository teachers;
  final GroupRepository groups;
  final BookingRepository bookings;

  /// الجدول الأسبوعي للمجموعات (P9).
  final ScheduleRepository schedules;

  /// محادثة المجموعة (P9).
  final MessageRepository messages;

  /// المحادثات المباشرة بين الطالب والمدرس (P11).
  final DirectChatRepository chats;

  /// الإشعارات داخل التطبيق (P12).
  final NotificationRepository notifications;

  /// تقييمات المدرسين ومتوسطاتها (P13).
  final ReviewRepository reviews;

  /// مفضلة الطالب: مدرسون ومجموعات (P13).
  final FavoriteRepository favorites;

  /// لوحة الإدارة: طابور التوثيق والمراجعة (P14).
  ///
  /// وجوده في الحاوية لا يمنح صلاحية: كل دالة فيه مشروطة في القواعد بـ
  /// `request.auth.token.admin == true`، والواجهة تُخفي الشاشات عن غير المسؤول.
  final AdminRepository admin;

  /// صور الحساب (P22): الافتراضية والمخصّصة.
  ///
  /// الافتراضي [EmptyAvatarRepository] ليس تنفيذًا حقيقيًا: الحزمتان في
  /// `firebase()`/`demo()` تحقنان التنفيذ الفعلي. الفارغ يخدم الحاويات
  /// المصغّرة في الاختبارات، فلا شاشة تنهار على «لا صورة».
  final AvatarRepository avatars;

  /// (P23) إشارة تغيير قائمة المجموعات.
  ///
  /// **لماذا؟** تبويب «مجموعاتي» موجود في مكانين (الرئيسية + تبويب المجموعات)
  /// وكلاهما يبقى حيًّا داخل `IndexedStack`. إنشاء مجموعة من الرئيسية كان
  /// يترك قائمة التبويب قديمة حتى إعادة تشغيل الشاشة. هنا يُبلّغ النموذج عن
  /// كل حفظ ناجح، فتقرأ **كل** الأقسام من المصدر من جديد فورًا.
  ///
  /// إشارة لا دفق بيانات: المستودعات تبقى `Future`، والإشارة تطلب قراءة
  /// جديدة فقط (لا تُخزّن نسخة ثانية من البيانات قد تتقادم).
  final ValueNotifier<int> groupsRevision;

  /// يُستدعى بعد كل حفظ ناجح للمجموعة (إنشاء أو تعديل).
  void notifyGroupsChanged() => groupsRevision.value++;

  /// اختيار صورة من جهاز المستخدم (P22).
  ///
  /// عقد لا حزمة: الشاشات لا تستورد `image_picker`، والاختبارات تحقن منتقيًا
  /// وهميًا يعيد بايتات جاهزة.
  final ImagePickerGateway imagePicker;

  /// (P24) صور المحادثة المؤقتة: رفع وقراءة وحذف بعد انتهاء صلاحيتها.
  ///
  /// الافتراضي [EmptyChatImageRepository] يخدم الاختبارات القديمة؛ الحزمتان
  /// الحقيقيتان تحقنان التنفيذ الفعلي.
  final ChatImageRepository chatImages;

  /// (P24) حفظ صورة المحادثة في معرض الجهاز — زر «تنزيل» في العارض.
  final ChatImageSaver imageSaver;

  /// الحزمة المناسبة للبيئة الحالية.
  ///
  /// - Firebase جاهز ← مصادقة وقراءة حقيقية من Firestore (P4 + P5).
  /// - غير جاهز ← حزمة تجريبية كاملة (وضع الزائر)، والتطبيق يعمل بلا خادم.
  ///
  /// التبديل يحدث **هنا فقط**: الشاشات لا تعرف أي تنفيذ وراء العقد، ولا تستورد
  /// Firebase.
  factory AppServices.bootstrap() {
    if (FirebaseBootstrap.status == FirebaseStatus.ready) {
      return AppServices.firebase();
    }
    return AppServices.demo();
  }

  /// حزمة متصلة بـFirestore (تُستخدم فقط بعد نجاح التهيئة).
  factory AppServices.firebase() {
    // كاتب إشعارات واحد يخدم المستودعات الثلاثة التي تُنتج إشعارات (P12)،
    // فتبقى سياسة الإشعارات في مكان واحد.
    final FirestoreNotificationRepository notifications =
        FirestoreNotificationRepository();
    return AppServices(
      auth: FirebaseAuthService(),
      teachers: FirestoreTeacherRepository(),
      groups: FirestoreGroupRepository(notifications: notifications),
      bookings: FirestoreBookingRepository(notifications: notifications),
      schedules: FirestoreScheduleRepository(),
      messages: FirestoreMessageRepository(),
      chats: FirestoreDirectChatRepository(notifications: notifications),
      notifications: notifications,
      reviews: FirestoreReviewRepository(),
      favorites: FirestoreFavoriteRepository(),
      admin: FirestoreAdminRepository(),
      avatars: FirestoreAvatarRepository(),
      imagePicker: PlatformImagePickerGateway(),
      chatImages: FirestoreChatImageRepository(),
      imageSaver: const PlatformChatImageSaver(),
    );
  }

  /// حزمة تجريبية كاملة للعمل بلا خادم (الوضع الافتراضي في المرحلة 2).
  /// (P22) يُمرَّر المنتقي والصور في الاختبارات؛ الافتراضي هو التنفيذ
  /// التجريبي الحقيقي (ذاكرة) ومنتقي المنصّة.
  factory AppServices.demo({
    AvatarRepository? avatars,
    ImagePickerGateway? imagePicker,
    ChatImageRepository? chatImages,
    ChatImageSaver? imageSaver,
  }) {
    // المستودعات مترابطة عمدًا: المحادثة تتحقق من «الأصل الموثّق» (حجز قائم أو
    // عضوية مجموعة) من نفس مصادر البيانات، فلا يمرّ خيط بلا علاقة حقيقية.
    final DemoNotificationRepository notifications =
        DemoNotificationRepository();
    final DemoBookingRepository bookings = DemoBookingRepository(
      notifications: notifications,
    );
    final DemoGroupRepository groups = DemoGroupRepository(
      notifications: notifications,
    );
    // (P14) الإدارة والتقييمات والبحث تتقاسم **نفس القوائم**: قرار التوثيق
    // يظهر في البحث فورًا، وحذف تقييم يغيّر المتوسط المعروض.
    final List<TeacherProfile> profiles = <TeacherProfile>[...DemoData.teachers];
    final List<TeacherReview> reviews = <TeacherReview>[...DemoData.reviews];
    return AppServices(
      auth: const DemoAuthService(),
      teachers: DemoTeacherRepository(source: profiles),
      groups: groups,
      bookings: bookings,
      schedules: DemoScheduleRepository(),
      messages: DemoMessageRepository(),
      chats: DemoDirectChatRepository(
        findBooking: bookings.findById,
        isMember: groups.isMember,
        // (P24) خيط «طلب انضمام» يُنشأ فقط بعد وجود طلب فعلي — كما تفرضه
        // القواعد على الخادم.
        hasJoinRequest: ({required String groupId, required String studentId}) =>
            groups
                .findMyRequest(groupId: groupId, studentId: studentId)
                .then(
                  (GroupJoinRequest? request) =>
                      request != null &&
                      (request.isPending || request.status.isAccepted),
                ),
        notifications: notifications,
      ),
      notifications: notifications,
      // التقييم يقرأ الحجز طازجًا من نفس المستودع، فلا يُقيَّم حجز لم يُنفَّذ.
      reviews: DemoReviewRepository(
        findBooking: bookings.findById,
        source: reviews,
      ),
      favorites: DemoFavoriteRepository(),
      admin: DemoAdminRepository(profiles: profiles, reviews: reviews),
      // نفس مسار الصور في الجولة: اختيار ومعاينة، لكن في الذاكرة فقط.
      avatars: avatars ?? DemoAvatarRepository(),
      imagePicker: imagePicker ?? PlatformImagePickerGateway(),
      chatImages: chatImages ?? DemoChatImageRepository(),
      imageSaver: imageSaver ?? const PlatformChatImageSaver(),
    );
  }
}
