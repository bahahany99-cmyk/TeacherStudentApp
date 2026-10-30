import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/errors/request_timeout.dart';
import 'package:teacher_student_app/core/errors/firebase_error_mapper.dart';
import 'package:teacher_student_app/data/firebase/mappers/firestore_mappers.dart';
import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/data/services/avatar_repository.dart';
import 'package:teacher_student_app/data/models/group_filter.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/favorite.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/content_report.dart';
import 'package:teacher_student_app/data/models/chat_image.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/group_message.dart';
import 'package:teacher_student_app/data/models/group_session.dart';
import 'package:teacher_student_app/data/models/group_waitlist_entry.dart';
import 'package:teacher_student_app/data/models/member_move.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_filter.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/teacher_profile_draft.dart';
import 'package:teacher_student_app/data/models/teacher_rating.dart';
import 'package:teacher_student_app/data/models/teacher_review.dart';
import 'package:teacher_student_app/data/services/admin_repository.dart';
import 'package:teacher_student_app/data/services/booking_repository.dart';
import 'package:teacher_student_app/data/services/favorite_repository.dart';
import 'package:teacher_student_app/data/services/notification_repository.dart';
import 'package:teacher_student_app/data/services/review_repository.dart';
import 'package:teacher_student_app/data/services/chat_image_repository.dart';
import 'package:teacher_student_app/data/services/direct_chat_repository.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';
import 'package:teacher_student_app/data/services/message_repository.dart';
import 'package:teacher_student_app/data/services/schedule_repository.dart';
import 'package:teacher_student_app/data/services/teacher_repository.dart';
import 'package:teacher_student_app/data/validation/admin_rules.dart';
import 'package:teacher_student_app/data/validation/booking_rules.dart';
import 'package:teacher_student_app/data/validation/review_rules.dart';
import 'package:teacher_student_app/data/validation/notification_rules.dart';
import 'package:teacher_student_app/data/validation/direct_chat_rules.dart';
import 'package:teacher_student_app/data/validation/discovery_rules.dart';
import 'package:teacher_student_app/data/validation/teacher_discovery_rules.dart';
import 'package:teacher_student_app/data/validation/group_rules.dart';
import 'package:teacher_student_app/data/validation/join_rules.dart';
import 'package:teacher_student_app/data/validation/message_rules.dart';
import 'package:teacher_student_app/data/validation/move_rules.dart';
import 'package:teacher_student_app/data/validation/session_rules.dart';
import 'package:teacher_student_app/data/validation/waitlist_rules.dart';
import 'package:teacher_student_app/data/validation/model_validators.dart';

/// أسماء المجموعات في Firestore — مكان واحد، مطابقة لـ`firestore.rules`.
abstract final class FirestoreCollections {
  static const String users = 'users';
  static const String teacherProfiles = 'teacherProfiles';
  static const String studyGroups = 'studyGroups';
  static const String groupMembers = 'members';
  static const String groupJoinRequests = 'groupJoinRequests';
  static const String groupSessions = 'sessions';
  static const String groupMessages = 'messages';
  static const String groupWaitlist = 'groupWaitlist';
  static const String bookingRequests = 'bookingRequests';

  /// تقويم يومي لكل مدرس (P10): مستند واحد لكل `teacherId + تاريخ` يحمل فترات
  /// محجوزة، فتصبح المعاملات المتزامنة مسلسلة بلا حاجة إلى استعلام (A-76).
  static const String teacherCalendar = 'teacherCalendar';

  /// إعدادات خصوصية المدرس (P11): مستند لكل مدرس، وأهم حقل فيه
  /// `allowDirectMessages`. منفصل عن `teacherProfiles` عمدًا: الملف التعريفي
  /// بيانات عامة يحرّرها صاحبها بقائمة حقول محكمة، والخصوصية قرار مستقل.
  static const String teacherSettings = 'teacherSettings';

  /// المحادثات المباشرة (P11) — خيط واحد لكل زوج (مدرس، طالب).
  static const String directChats = 'directChats';
  static const String directChatMessages = 'messages';

  /// صور المحادثة المؤقتة (P24) — مجموعة فرعية تحت كل محادثة.
  static const String directChatImages = 'images';

  /// إشعارات داخل التطبيق (P12) — مستند لكل إشعار لمستلم واحد.
  static const String notifications = 'notifications';

  /// تقييمات المدرسين (P13) — معرّف المستند = معرّف الحجز (A-84).
  static const String reviews = 'reviews';

  /// المتوسط التراكمي لكل مدرس (P13) — مجموع + عدد، لا متوسط عشري (A-85).
  static const String teacherRatings = 'teacherRatings';

  /// مفضلة الطلاب (P13) — معرّف مشتق: `{studentId}_{kind}_{targetId}`.
  static const String favorites = 'favorites';

  /// بلاغات المحتوى (P14) — ينشئها المستخدم بحالة `open`، وتحسمها الإدارة.
  static const String contentReports = 'contentReports';
}

/// زوج (معرّف، بيانات) لخرائط التحويل في `firestore_mappers`.
(String, Map<String, Object?>) _entry(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) => (doc.id, doc.data());

/// يدمج تدفّقَي قوائم في تدفّق واحد: يُعاد الدمج عند وصول أي طرف.
///
/// **لماذا؟** الحجوزات والمحادثات تُقرأ باستعلامين متساويين (كطالب وكمعلم)
/// لأن Firestore لا يدعم `OR` على حقلين بلا فهرس مركّب. الطلب الواحد
/// (`listMine`) يجمعهما مرة واحدة، أما المراقبة الحيّة فتحتاج الاستماع
/// للاثنين معًا. الاعتماد على `await` داخل `StreamBuilder` كان يعني إعادة
/// الاشتراك عند كل بناء — وهو أصل عطل «الرسائل تختفي».
///
/// [combine] يستقبل أحدث قائمة من كل تدفّق ويعيد النتيجة النهائية؛ تُستدعى مرة
/// عند وصول أول قيمة من أحدهما (والأخرى فارغة) ثم عند كل تحديث.
Stream<List<T>> mergeListStreams<T>({
  required Stream<List<T>> first,
  required Stream<List<T>> second,
  required List<T> Function(List<T> left, List<T> right) combine,
}) {
  late StreamController<List<T>> controller;
  StreamSubscription<List<T>>? leftSub;
  StreamSubscription<List<T>>? rightSub;
  List<T> leftItems = <T>[];
  List<T> rightItems = <T>[];

  void emit() {
    if (!controller.isClosed) {
      controller.add(combine(leftItems, rightItems));
    }
  }

  void onError(Object error, StackTrace stack) {
    if (!controller.isClosed) {
      controller.addError(error, stack);
    }
  }

  controller = StreamController<List<T>>(
    onListen: () {
      leftSub = first.listen(
        (List<T> items) {
          leftItems = items;
          emit();
        },
        onError: onError,
      );
      rightSub = second.listen(
        (List<T> items) {
          rightItems = items;
          emit();
        },
        onError: onError,
      );
    },
    onCancel: () async {
      await leftSub?.cancel();
      await rightSub?.cancel();
    },
  );
  return controller.stream;
}

/// أخطاء Firestore → [AppException] عربية.
///
/// نلتقط `FirebaseException` فقط؛ أي خطأ آخر يبقى كما هو ليُصنَّف «غير متوقع»
/// في `toAppException` بدل أن نُخفيه كخطأ شبكة.
/// ينفّذ طلب Firestore ويترجم أخطاءه إلى [AppException] عربية.
///
/// (P16) كل طلب محكوم بمهلة ([withRequestTimeout]): انقطاع الشبكة عند Firestore
/// لا يعني فشلًا سريعًا بل إعادة محاولة صامتة، فتظل الشاشة «تحميل» بلا نهاية.
/// بعد المهلة يصل للمستخدم خطأ شبكي مفهوم مع «إعادة المحاولة».
///
/// الأخطاء غير المتوقعة تُغلَّف أيضًا: الواجهة تعرض [AppException] فقط، فلا
/// يصل نصّ استثناء إنجليزي إلى المستخدم ولا ينهار التطبيق.
Future<T> _guard<T>(Future<T> Function() action) async {
  try {
    return await withRequestTimeout(action);
  } on FirebaseException catch (error) {
    throw firebaseCodeToException(error.code, debugMessage: error.message);
  } on AppException {
    rethrow;
  } catch (error) {
    throw AppException(
      AppErrorKind.network,
      debugMessage: error.toString(),
      overrideMessage:
          'تعذّر إتمام الطلب. تحقّق من الاتصال ثم أعد المحاولة.',
    );
  }
}

/// قراءة ملفات المدرسين من `teacherProfiles`.
///
/// ⚠️ الفلترة على `status == 'verified'` مكرّرة هنا **وعلى الخادم** (قواعد
/// Firestore + فهارس). تكرارها في التطبيق ليس إجراءً أمنيًا؛ هو فقط يمنع إرسال
/// بيانات غير لازمة إلى الواجهة، ويجعل الاستعلام قابلاً للفهرسة.
class FirestoreTeacherRepository implements TeacherRepository {
  FirestoreTeacherRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection(FirestoreCollections.teacherProfiles);

  @override
  Future<List<TeacherProfile>> listVerified() {
    return _guard(() async {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _profiles
          .where('status', isEqualTo: 'verified')
          // (P17) القواعد **ليست فلترًا**: الاستعلام نفسه هو ما يستبعد الملفات
          // المخفية بحذف الحساب، فلا تعتمد على رفض القاعدة للملف.
          .where('accountHidden', isEqualTo: false)
          .get();
      return mapDocuments(snapshot.docs.map(_entry), teacherProfileFromMap);
    });
  }

  @override
  Future<List<TeacherProfile>> listFeatured() {
    return _guard(() async {
      // شرطان بالمساواة فقط (بلا `orderBy`) ⇒ لا فهرس مركّب (A-91). الترتيب
      // (`featuredOrder` ثم التقييم ثم الاسم) يُطبَّق في العميل بنفس دالة
      // الوضع التجريبي، فلا يختلف الشريط بين البيئتين (P15).
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _profiles
          .where('status', isEqualTo: 'verified')
          .where('accountHidden', isEqualTo: false)
          .where('isFeatured', isEqualTo: true)
          .get();
      return TeacherDiscoveryRules.featured(
        mapDocuments(snapshot.docs.map(_entry), teacherProfileFromMap),
      );
    });
  }

  @override
  Future<TeacherSearchResult> search(TeacherFilter filter) {
    return _guard(() async {
      // شروط الخادم وحدها هنا؛ النص/المادة/المرحلة في العميل. كل شرط مساواة
      // على حقل واحد، فتكفي الفهارس الأحادية المرتّبة تلقائيًا.
      Query<Map<String, dynamic>> query = _profiles
          .where('status', isEqualTo: 'verified')
          .where('accountHidden', isEqualTo: false);
      switch (filter.delivery) {
        case TeacherDeliveryFilter.any:
          break;
        case TeacherDeliveryFilter.online:
          query = query.where('isOnline', isEqualTo: true);
        case TeacherDeliveryFilter.inPerson:
          query = query.where('isOnline', isEqualTo: false);
      }
      if (filter.governorate != null) {
        query = query.where('governorate', isEqualTo: filter.governorate);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      return TeacherDiscoveryRules.search(
        mapDocuments(snapshot.docs.map(_entry), teacherProfileFromMap),
        filter,
      );
    });
  }

  @override
  Future<TeacherProfile?> findMine(String uid) {
    return _guard(() async {
      // قراءة مباشرة للمستند: القاعدة تسمح لصاحبه بأي حالة (`isSelf`)، فلا
      // نحتاج استعلامًا ولا شرط `status` — وإلا لما رأى المدرس مسودته.
      final DocumentSnapshot<Map<String, dynamic>> doc = await _profiles
          .doc(uid)
          .get();
      final Map<String, Object?>? data = doc.data();
      if (!doc.exists || data == null) {
        return null;
      }
      return teacherProfileFromMap(doc.id, data);
    });
  }

  @override
  Future<TeacherProfile> saveMyProfile({
    required String uid,
    required TeacherProfileDraft draft,
  }) {
    return _guard(() async {
      // (P22) الصورة إلزامية: نموذج بلا صورة لا يُرسل أصلًا، ولو وصل هنا
      // (شاشة أخرى، استدعاء مباشر) نرفضه محليًا قبل الكتابة. القواعد ترفضه
      // أيضًا (`photoSatisfiedFor`)، فالطريقان مغلقان.
      if (!draft.hasPhoto) {
        throw const AppException(
          AppErrorKind.invalidInput,
          debugMessage: 'teacher profile saved without a photo',
          overrideTitle: 'الصورة مطلوبة',
          overrideMessage:
              'أضف صورة شخصية واضحة قبل حفظ ملفك — بدونها لا يُرسل الملف '
              'للمراجعة.',
        );
      }

      // (P23) المادة والمرحلة إلزاميتان مثل الصورة: ملف بلا مادة أو مرحلة لا
      // يُرسل للمراجعة. نفس الحدود في `academicFieldsSatisfiedFor` بالقواعد.
      final String? academicProblem = draft.academicProblem;
      if (academicProblem != null) {
        throw AppException(
          AppErrorKind.invalidInput,
          debugMessage: 'teacher profile saved without academic fields',
          overrideTitle: 'بيانات ناقصة',
          overrideMessage: '$academicProblem — لا يُرسل ملفك للمراجعة بدونها.',
        );
      }

      final DocumentReference<Map<String, dynamic>> ref = _profiles.doc(uid);
      final DocumentSnapshot<Map<String, dynamic>> existing = await ref.get();

      if (existing.exists) {
        // تعديل: الحقول الوصفية فقط. `update` ترفض المستند الغائب — وهذا
        // مطلوب: لو حُذف الملف بين القراءة والكتابة لا نُنشئه بلا فحص.
        final Map<String, Object?> changes = draft.toWriteMap();
        // تفريغ حقل اختياري = **حذفه**، لا تركه بقيمته القديمة. `merge`
        // وحدها لا تحذف مفاتيح، فالحذف يحتاج `FieldValue.delete()` صريحًا.
        for (final String field in <String>[
          'priceHint',
          'governorate',
          'district',
        ]) {
          if (!changes.containsKey(field)) {
            changes[field] = FieldValue.delete();
          }
        }

        // (P22) سياسة إعادة التحقق: أي تعديل يعيد الملف إلى قائمة المراجعة.
        // - الموثّق: تعديل بياناته يُلغي أثر التوثيق القديم، فيعود
        //   `pendingReview` حتى يراجعته الإدارة على القيم الجديدة.
        // - المسودة/المرفوض: أول حفظ كامل = طلب مراجعة فعلي.
        // - المنتظر مراجعةً: مقفل تمامًا (القاعدة ترفض، والنموذج لا يُفتح).
        final TeacherProfileStatus current =
            teacherProfileFromMap(uid, existing.data() ?? <String, Object?>{})
                ?.status ??
            TeacherProfileStatus.draft;
        if (current != TeacherProfileStatus.pendingReview) {
          changes['status'] = TeacherProfileStatus.pendingReview.wireValue;
        }
        await ref.update(changes);
      } else {
        // إنشاء: الحقول التي تفرضها القاعدة `allow create` حرفيًا.
        await ref.set(<String, Object?>{
          ...draft.toWriteMap(),
          'ownerId': uid,
          'status': TeacherProfileStatus.pendingReview.wireValue,
          // (P17) الحقل موجود منذ الإنشاء: استعلامات الاكتشاف تفلتر عليه،
          // ومستند بلا الحقل لا يظهر في `where(accountHidden == false)`.
          'accountHidden': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // نقرأ بعد الكتابة بدل تركيب النموذج محليًا: `createdAt` وقت الخادم
      // والحقول الإدارية لا نعرفها، فالعرض من المصدر أصدق.
      final DocumentSnapshot<Map<String, dynamic>> saved = await ref.get();
      final Map<String, Object?> data = saved.data() ?? <String, Object?>{};
      final TeacherProfile? profile = teacherProfileFromMap(uid, data);
      if (profile == null) {
        throw const AppException(
          AppErrorKind.unavailable,
          debugMessage: 'teacher profile saved but unreadable',
        );
      }
      return profile;
    });
  }

  @override
  Future<TeacherProfile?> findById(String id) {
    return _guard(() async {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _profiles
          .doc(id)
          .get();
      final Map<String, Object?>? data = doc.data();
      if (!doc.exists || data == null) {
        return null;
      }

      final TeacherProfile? profile = teacherProfileFromMap(doc.id, data);
      // نفس قاعدة الظهور: الملف غير المعتمد لا يُكشف للطلاب (C-06).
      if (profile == null || !profile.isVisibleToStudents) {
        return null;
      }
      return profile;
    });
  }

  /// إزالة عضو (P9): حذف العضوية وإنقاص المقعد **في معاملة واحدة**.
  ///
  /// لو نقص المقعد وحده لبقيت عضوية بلا مقعد، ولو حُذفت العضوية وحدها لبقي
  /// مقعد محسوبًا لغير أحد — وكلاهما يفسد فحص السعة في القبول التالي.

  (String, Map<String, Object?>) _entry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => (doc.id, doc.data());
}

/// قراءة المجموعات وأعضائها.
class FirestoreGroupRepository implements GroupRepository {
  FirestoreGroupRepository({
    FirebaseFirestore? firestore,
    NotificationRepository? notifications,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _notifications = notifications;

  final FirebaseFirestore _firestore;

  /// اختياري: REPOSITORY الإشعارات (P12). غيابه يعني «بلا إشعارات»، وهو وضع
  /// الاختبارات التي تختبر عملية واحدة بمعزل.
  final NotificationRepository? _notifications;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection(FirestoreCollections.studyGroups);

  @override
  Future<List<StudyGroup>> listDiscoverable() {
    return _guard(() async {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _groups
          .where('isActive', isEqualTo: true)
          .get();
      return mapDocuments(snapshot.docs.map(_entry), studyGroupFromMap);
    });
  }

  /// استكشاف مفلتر (P9).
  ///
  /// **ما يُدفع للخادم:** `isActive == true` (تشترطه القواعد للقراءة) ومساواة
  /// المادة/المرحلة/طريقة الحضور — مساواة على حقل واحد، فلا فهرس مركّب.
  /// **ما يُطبَّق في العميل:** البحث النصي وشرط «بها مقعد» والترتيب، لأن أياها
  /// لا يُعبَّر عنه في استعلام Firestore بلا حقل منسوخ (A-66). النتيجة تحمل
  /// إجمالي ما ورد من الخادم حتى تعرض الشاشة «3 من 12» بصدق.
  @override
  Future<GroupSearchResult> searchDiscoverable(GroupFilter filter) {
    return _guard(() async {
      Query<Map<String, dynamic>> query = _groups.where(
        'isActive',
        isEqualTo: true,
      );
      if (filter.subject != null) {
        query = query.where('subject', isEqualTo: filter.subject);
      }
      if (filter.stage != null) {
        query = query.where('stage', isEqualTo: filter.stage);
      }
      if (filter.meetingMode != null) {
        query = query.where(
          'meetingMode',
          isEqualTo: filter.meetingMode!.name,
        );
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      return DiscoveryRules.search(
        mapDocuments(snapshot.docs.map(_entry), studyGroupFromMap),
        filter,
      );
    });
  }

  @override
  Future<List<StudyGroup>> listForTeacher(String teacherId) {
    return _guard(() async {
      // لا شرط على isActive هنا: المدرس يرى مجموعاته حتى الموقوفة.
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _groups
          .where('teacherId', isEqualTo: teacherId)
          .get();
      return mapDocuments(snapshot.docs.map(_entry), studyGroupFromMap);
    });
  }

  @override
  Future<StudyGroup?> findById(String id) {
    return _guard(() async {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _groups
          .doc(id)
          .get();
      final Map<String, Object?>? data = doc.data();
      if (!doc.exists || data == null) {
        return null;
      }
      return studyGroupFromMap(doc.id, data);
    });
  }

  @override
  Future<bool> isMember({
    required String groupId,
    required String userId,
  }) {
    return _guard(() async {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _groups
          .doc(groupId)
          .collection(FirestoreCollections.groupMembers)
          .doc(userId)
          .get();
      return doc.exists;
    });
  }

  @override
  Future<StudyGroup> createGroup({
    required String teacherId,
    required String teacherName,
    required GroupDraft draft,
  }) {
    return _guard(() async {
      _ensureValid(draft, seatsTaken: 0);

      final DocumentReference<Map<String, dynamic>> ref = await _groups.add(
        draft.toCreateMap(teacherId: teacherId, teacherName: teacherName),
      );
      final DocumentSnapshot<Map<String, dynamic>> created = await ref.get();
      final Map<String, Object?>? data = created.data();
      final StudyGroup? group = data == null
          ? null
          : studyGroupFromMap(created.id, data);
      if (group == null) {
        throw const AppException(
          AppErrorKind.unknown,
          debugMessage: 'created group document is unreadable',
        );
      }
      return group;
    });
  }

  @override
  Future<StudyGroup> updateGroup({
    required String groupId,
    required String teacherId,
    required GroupDraft draft,
    required bool isActive,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> ref = _groups.doc(groupId);
      final DocumentSnapshot<Map<String, dynamic>> current = await ref.get();
      final Map<String, Object?>? data = current.data();
      if (!current.exists || data == null) {
        throw const AppException.notFound(debugMessage: 'group missing');
      }

      final StudyGroup? existing = studyGroupFromMap(current.id, data);
      if (existing == null) {
        throw const AppException(
          AppErrorKind.unknown,
          debugMessage: 'group document is unreadable',
        );
      }
      if (existing.teacherId != teacherId) {
        throw const AppException.permission(debugMessage: 'not group owner');
      }

      // التحقق يستخدم السعة المشغولة الحقيقية من الخادم لا من الواجهة.
      _ensureValid(draft, seatsTaken: existing.seatsTaken);

      await ref.update(draft.toUpdateMap(isActive: isActive));
      return StudyGroup(
        id: existing.id,
        teacherId: existing.teacherId,
        teacherName: existing.teacherName,
        title: draft.normalizedTitle,
        subject: draft.normalizedSubject,
        stage: draft.normalizedStage,
        seatsTotal: draft.seatsTotal,
        seatsTaken: existing.seatsTaken,
        meetingMode: draft.meetingMode,
        scheduleNote: draft.normalizedScheduleNote,
        isActive: isActive,
      );
    });
  }

  /// تحقق مبكر برسالة عربية — نفس حدود القواعد.
  void _ensureValid(GroupDraft draft, {required int seatsTaken}) {
    final ValidationResult result = GroupRules.validateDraft(
      draft,
      seatsTaken: seatsTaken,
    );
    if (!result.isValid) {
      throw AppException.invalidInput(debugMessage: result.firstMessage);
    }
  }

  @override
  Future<List<GroupMember>> listMembers(String groupId) {
    return _guard(() async {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _groups
          .doc(groupId)
          .collection(FirestoreCollections.groupMembers)
          .get();
      return mapDocuments(snapshot.docs.map(_entry), groupMemberFromMap);
    });
  }

  /// إزالة عضو (P9): حذف العضوية وإنقاص المقعد **في معاملة واحدة**.
  ///
  /// لو نقص المقعد وحده لبقيت عضوية بلا مقعد، ولو حُذفت العضوية وحدها لبقي
  /// مقعد محسوبًا لغير أحد — وكلاهما يفسد فحص السعة في القبول التالي.
  @override
  Future<StudyGroup> removeMember({
    required String groupId,
    required String memberId,
    required String teacherId,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> groupRef = _groups.doc(
        groupId,
      );
      final DocumentReference<Map<String, dynamic>> memberRef = groupRef
          .collection(FirestoreCollections.groupMembers)
          .doc(memberId);

      return _firestore.runTransaction<StudyGroup>((
        Transaction transaction,
      ) async {
        final DocumentSnapshot<Map<String, dynamic>> groupSnapshot =
            await transaction.get(groupRef);
        final DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
            await transaction.get(memberRef);

        final Map<String, Object?>? groupData = groupSnapshot.data();
        if (!groupSnapshot.exists || groupData == null) {
          throw const AppException.notFound(debugMessage: 'group missing');
        }
        final StudyGroup? group = studyGroupFromMap(
          groupSnapshot.id,
          groupData,
        );
        if (group == null) {
          throw const AppException(
            AppErrorKind.unknown,
            debugMessage: 'group document is unreadable',
          );
        }
        if (group.teacherId != teacherId) {
          throw const AppException.permission(debugMessage: 'not group owner');
        }
        if (!memberSnapshot.exists) {
          throw const AppException.notFound(debugMessage: 'member missing');
        }

        final int seatsTaken = group.seatsTaken > 0 ? group.seatsTaken - 1 : 0;
        transaction.delete(memberRef);
        transaction.update(groupRef, <String, Object?>{'seatsTaken': seatsTaken});

        return StudyGroup(
          id: group.id,
          teacherId: group.teacherId,
          teacherName: group.teacherName,
          title: group.title,
          subject: group.subject,
          stage: group.stage,
          seatsTotal: group.seatsTotal,
          seatsTaken: seatsTaken,
          meetingMode: group.meetingMode,
          scheduleNote: group.scheduleNote,
          isActive: group.isActive,
        );
      });
    });
  }

  (String, Map<String, Object?>) _entry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => (doc.id, doc.data());

  // ── P8: طلبات الانضمام ────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _joinRequests =>
      _firestore.collection(FirestoreCollections.groupJoinRequests);

  /// طلب انضمام داخل معاملة: نقرأ المجموعة **طازجة** لا من نسخة الواجهة.
  ///
  /// القواعد تشترط أن يكون الطلب لطالب مسجّل، والمجموعة نشطة، وأن المعرّف
  /// `groupId_studentId`؛ والتحقق هنا يعطي رسالة عربية قبل الوصول للخادم.
  @override
  Future<GroupJoinRequest> requestToJoin({
    required StudyGroup group,
    required String studentId,
    required String studentName,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> groupRef = _groups.doc(
        group.id,
      );
      final DocumentReference<Map<String, dynamic>> requestRef = _joinRequests
          .doc(
            GroupJoinRequest.idFor(groupId: group.id, studentId: studentId),
          );

      // تُلتقط من داخل المعاملة لاستخدامها في الإشعار بعد الالتزام.
      StudyGroup? joinedGroup;

      final GroupJoinRequest created =
          await _firestore.runTransaction<GroupJoinRequest>((
            Transaction transaction,
          ) async {
        final DocumentSnapshot<Map<String, dynamic>> groupSnapshot =
            await transaction.get(groupRef);
        final Map<String, Object?>? groupData = groupSnapshot.data();
        if (!groupSnapshot.exists || groupData == null) {
          throw const AppException.notFound(debugMessage: 'group missing');
        }
        final StudyGroup? current = studyGroupFromMap(
          groupSnapshot.id,
          groupData,
        );
        if (current == null) {
          throw const AppException(
            AppErrorKind.unknown,
            debugMessage: 'group document is unreadable',
          );
        }

        final DocumentSnapshot<Map<String, dynamic>> requestSnapshot =
            await transaction.get(requestRef);
        final JoinRequestStatus? existing = requestSnapshot.exists
            ? JoinRequestStatus.parse(
                requestSnapshot.data()?['status'],
              )
            : null;
        // (P24) تهدئة الإلغاء: القيمة تُقرأ من المستند لا من الواجهة، فلا
        // يستطيع العميل تجاوزها بإرسال طلب «نظيف».
        final DateTime? cooldownUntil = requestSnapshot.exists
            ? _readCooldown(requestSnapshot.data()?['cooldownUntil'])
            : null;

        final String? reason = JoinRules.requestBlockReason(
          group: current,
          viewerId: studentId,
          existingStatus: existing,
          cooldownUntil: cooldownUntil,
        );
        if (reason != null) {
          throw AppException(
            AppErrorKind.invalidInput,
            overrideMessage: reason,
            debugMessage: 'join blocked',
          );
        }

        final GroupJoinRequest request = buildJoinRequest(
          group: current,
          studentId: studentId,
          studentName: studentName,
        );
        final ValidationResult valid = JoinRules.validateRequest(
          groupTitle: request.groupTitle,
          studentName: request.studentName,
          studentId: request.studentId,
          groupId: request.groupId,
        );
        if (!valid.isValid) {
          throw AppException.invalidInput(debugMessage: valid.firstMessage);
        }

        // `set` متعمّد: إعادة الطلب بعد رفض/إلغاء تستبدل المستند نفسه.
        transaction.set(requestRef, request.toCreateMap());
        joinedGroup = current;
        return request;
      });

      // (P25) إشعار المدرس بوصول الطلب — كان الطلب يُكتب بلا أي إشعار، فلا
      // يعلم به المدرس إلا لو فتح شاشة الطلبات بنفسه.
      final StudyGroup? joined = joinedGroup;
      if (joined != null) {
        await _notify(
          type: NotificationType.joinRequested,
          recipientId: joined.teacherId,
          actorId: studentId,
          actorName: studentName,
          targetId: joined.id,
          title: NotificationRules.titleFor(
            type: NotificationType.joinRequested,
            actorName: studentName,
          ),
          body: NotificationRules.bodyFor(
            type: NotificationType.joinRequested,
            actorName: studentName,
            subject: joined.title,
          ),
        );
      }
      return created;
    });
  }

  @override
  Future<GroupJoinRequest?> findMyRequest({
    required String groupId,
    required String studentId,
  }) {
    return _guard(() async {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _joinRequests
          .doc(GroupJoinRequest.idFor(groupId: groupId, studentId: studentId))
          .get();
      final Map<String, Object?>? data = doc.data();
      if (!doc.exists || data == null) {
        return null;
      }
      return joinRequestFromMap(doc.id, data);
    });
  }

  @override
  Future<List<GroupJoinRequest>> listRequestsForGroup(
    String groupId, {
    String? teacherId,
  }) {
    return _guard(() async {
      // القيد على `teacherId` **إلزامي**: قواعد القراءة تقرأ
      // `resource.data.teacherId`، واستعلام لا يقيّد هذا الحقل يُرفض بالكامل.
      // (فلتران متساويان لا يحتاجان فهرسًا مركّبًا في Firestore.)
      Query<Map<String, dynamic>> query = _joinRequests.where(
        'groupId',
        isEqualTo: groupId,
      );
      if (teacherId != null) {
        query = query.where('teacherId', isEqualTo: teacherId);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      return sortJoinRequests(
        mapDocuments(snapshot.docs.map(_entry), joinRequestFromMap),
      );
    });
  }

  @override
  Future<List<GroupJoinRequest>> listMyRequests(String studentId) {
    return _guard(() async {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _joinRequests
          .where('studentId', isEqualTo: studentId)
          .get();
      return sortJoinRequests(
        mapDocuments(snapshot.docs.map(_entry), joinRequestFromMap),
      );
    });
  }

  /// **العملية الذرّية الحاسمة:** القبول يزيد المقعد ويغيّر حالة الطلب وينشئ
  /// العضو في معاملة واحدة. لو حُسب المقعد في الواجهة لكان طلبان متزامنان
  /// يحصلان على المقعد الأخير معًا.
  @override
  Stream<List<GroupJoinRequest>> watchIncomingRequests(String teacherId) {
    if (teacherId.isEmpty) {
      return Stream<List<GroupJoinRequest>>.value(
        const <GroupJoinRequest>[],
      );
    }
    // شرط واحد (`teacherId`) — وهو ما تسمح به القواعد للقراءة، والترتيب في
    // العميل حتى لا نحتاج فهرسًا مركّبًا.
    return _joinRequests
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => sortJoinRequests(
            mapDocuments(snapshot.docs.map(_entry), joinRequestFromMap),
          ),
        );
  }

  @override
  Future<List<String>> listSubjects() {
    return _guard(() async {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _groups
          .where('isActive', isEqualTo: true)
          .get();
      return DiscoveryRules.subjectOptions(
        mapDocuments(snapshot.docs.map(_entry), studyGroupFromMap),
      );
    });
  }

  @override
  Future<GroupJoinRequest> decideJoinRequest({
    required GroupJoinRequest request,
    required String teacherId,
    required bool approve,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> groupRef = _groups.doc(
        request.groupId,
      );
      final DocumentReference<Map<String, dynamic>> requestRef = _joinRequests
          .doc(request.id);
      final DocumentReference<Map<String, dynamic>> memberRef = groupRef
          .collection(FirestoreCollections.groupMembers)
          .doc(request.studentId);

      // تُلتقط من المعاملة للإشعار بعد الالتزام (اسم المدرس وعنوان المجموعة).
      String groupTitle = request.groupTitle;
      String teacherName = '';

      final GroupJoinRequest decided =
          await _firestore.runTransaction<GroupJoinRequest>((
            Transaction transaction,
          ) async {
        final DocumentSnapshot<Map<String, dynamic>> groupSnapshot =
            await transaction.get(groupRef);
        final DocumentSnapshot<Map<String, dynamic>> requestSnapshot =
            await transaction.get(requestRef);

        final Map<String, Object?>? groupData = groupSnapshot.data();
        final Map<String, Object?>? requestData = requestSnapshot.data();
        if (!groupSnapshot.exists ||
            groupData == null ||
            !requestSnapshot.exists ||
            requestData == null) {
          throw const AppException.notFound(
            debugMessage: 'group or request missing',
          );
        }

        final StudyGroup? group = studyGroupFromMap(
          groupSnapshot.id,
          groupData,
        );
        final GroupJoinRequest? current = joinRequestFromMap(
          requestSnapshot.id,
          requestData,
        );
        if (group == null || current == null) {
          throw const AppException(
            AppErrorKind.unknown,
            debugMessage: 'group or request unreadable',
          );
        }
        if (group.teacherId != teacherId) {
          throw const AppException.permission(debugMessage: 'not group owner');
        }
        groupTitle = group.title;
        teacherName = group.teacherName;

        final DateTime now = DateTime.now();

        if (!approve) {
          if (!current.isPending) {
            throw const AppException(
              AppErrorKind.invalidInput,
              overrideMessage: 'هذا الطلب لم يعد معلّقًا.',
            );
          }
          transaction.update(requestRef, <String, Object?>{
            'status': JoinRequestStatus.rejected.name,
            'decidedAt': now,
            'decidedBy': teacherId,
          });
          return current.copyWith(
            status: JoinRequestStatus.rejected,
            decidedAt: now,
            decidedBy: teacherId,
          );
        }

        // فحص السعة على القراءة الطازجة داخل المعاملة.
        final String? reason = JoinRules.acceptBlockReason(
          group: group,
          request: current,
        );
        if (reason != null) {
          throw AppException(
            AppErrorKind.invalidInput,
            overrideMessage: reason,
            debugMessage: 'accept blocked',
          );
        }

        transaction.update(groupRef, <String, Object?>{
          'seatsTaken': JoinRules.seatsAfterAccept(group.seatsTaken),
        });
        transaction.update(requestRef, <String, Object?>{
          'status': JoinRequestStatus.accepted.name,
          'decidedAt': now,
          'decidedBy': teacherId,
        });
        transaction.set(memberRef, <String, Object?>{
          'studentId': current.studentId,
          // الربط الصريح: مستند العضو يحمل مجموعة واحدة، والقواعد تتحقق من
          // مطابقته لمسار المستند.
          'groupId': group.id,
          'name': current.studentName,
          'joinedAt': now,
          'status': 'active',
        });

        return current.copyWith(
          status: JoinRequestStatus.accepted,
          decidedAt: now,
          decidedBy: teacherId,
        );
      });

      // (P25) إشعار الطالب بالقرار — القبول/الرفض كان يبقى في المستند وحده،
      // فلا يعلم الطالب إلا لو أعاد فتح شاشته.
      await _notify(
        type: approve
            ? NotificationType.joinAccepted
            : NotificationType.joinRejected,
        recipientId: decided.studentId,
        actorId: teacherId,
        actorName: teacherName,
        targetId: decided.groupId,
        title: NotificationRules.titleFor(
          type: approve
              ? NotificationType.joinAccepted
              : NotificationType.joinRejected,
          actorName: teacherName,
          subject: groupTitle,
        ),
        body: NotificationRules.bodyFor(
          type: approve
              ? NotificationType.joinAccepted
              : NotificationType.joinRejected,
          actorName: teacherName,
          subject: groupTitle,
        ),
      );
      return decided;
    });
  }


  /// يقرأ حقل تاريخ (Timestamp) من مستند ويُعيده، أو `null` لأي نوع آخر.
  ///
  /// (P24) مُستخدَم لموعد التهدئة: القيمة قد تكون `Timestamp` أو غائبة في
  /// سجلات قديمة، والتحويل الأعمى يرمي استثناءً في منتصف معاملة.
  static DateTime? _readCooldown(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return null;
  }

  @override
  Future<GroupJoinRequest> cancelJoinRequest({
    required GroupJoinRequest request,
    required String studentId,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> requestRef = _joinRequests
          .doc(request.id);

      return _firestore.runTransaction<GroupJoinRequest>((
        Transaction transaction,
      ) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(requestRef);
        final Map<String, Object?>? data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw const AppException.notFound(debugMessage: 'request missing');
        }
        final GroupJoinRequest? current = joinRequestFromMap(
          snapshot.id,
          data,
        );
        if (current == null) {
          throw const AppException(
            AppErrorKind.unknown,
            debugMessage: 'request unreadable',
          );
        }
        if (current.studentId != studentId) {
          throw const AppException.permission(
            debugMessage: 'not request owner',
          );
        }
        if (!current.isPending) {
          throw const AppException(
            AppErrorKind.invalidInput,
            overrideMessage: 'لا يمكن إلغاء طلب تم البتّ فيه.',
          );
        }

        // (P24) الإلغاء يكتب الحالة **وموعد التهدئة** في كتابة واحدة؛
        // القواعد ترفض إلغاءً بلا موعد، فلا يمكن للعميل تجاوز التهدئة بحذفه.
        final DateTime cooldownUntil = DateTime.now().add(
          JoinRules.cancelCooldown,
        );
        transaction.update(
          requestRef,
          current.cancelMap(cooldownUntil: cooldownUntil),
        );
        return current.copyWith(
          status: JoinRequestStatus.cancelled,
          decidedAt: DateTime.now(),
          decidedBy: studentId,
          cooldownUntil: cooldownUntil,
        );
      });
    });
  }

  /// نقل عضو بين مجموعتين في **معاملة واحدة** (A-71، A-73).
  ///
  /// نقرأ المجموعتين والعضوية **وصفوف الانضمام/الانتظار** داخل المعاملة، فلا
  /// يمكن أن يمرّ النقل إلى مجموعة امتلأت بين عرض الشاشة والكتابة. لا توسيع
  /// للسعة هنا إطلاقًا: الهدف بلا مقعد ⇒ رفض برسالة صريحة.
  ///
  /// وفي المعاملة نفسها يُنظَّف ما يتركه النقل من حالات شبح:
  /// - **الهدف:** طلب معلّق ⇒ `accepted`، وصف انتظار ⇒ `promoted` (الطالب صار
  ///   داخلًا فعلًا؛ إبقاء الصف معلّقًا يعني دعوة للمدرس لقبوله مرتين).
  /// - **المصدر:** طلب `pending`/`accepted` وصف انتظار `waiting`/`promoted`
  ///   تُحذف — لا معنى لطلب «مقبول» لطالب خارج المجموعة. السجلات المغلقة
  ///   (مرفوض/ملغى/غادر) تبقى كما هي لأنها تاريخ لا حالة.
  @override
  Future<MemberMove> moveMember({
    required String memberId,
    required String fromGroupId,
    required String toGroupId,
    required String teacherId,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> fromRef = _groups.doc(
        fromGroupId,
      );
      final DocumentReference<Map<String, dynamic>> toRef = _groups.doc(
        toGroupId,
      );
      final DocumentReference<Map<String, dynamic>> fromMemberRef = fromRef
          .collection(FirestoreCollections.groupMembers)
          .doc(memberId);
      final DocumentReference<Map<String, dynamic>> toMemberRef = toRef
          .collection(FirestoreCollections.groupMembers)
          .doc(memberId);

      // معرّفات الصفوف حتمية (`groupId_studentId`)، فلا حاجة إلى استعلام.
      final DocumentReference<Map<String, dynamic>> fromRequestRef = _joinRequests
          .doc(
            GroupJoinRequest.idFor(
              groupId: fromGroupId,
              studentId: memberId,
            ),
          );
      final DocumentReference<Map<String, dynamic>> toRequestRef = _joinRequests
          .doc(
            GroupJoinRequest.idFor(groupId: toGroupId, studentId: memberId),
          );
      final DocumentReference<Map<String, dynamic>> fromWaitlistRef = _waitlist
          .doc(
            GroupWaitlistEntry.idFor(
              groupId: fromGroupId,
              studentId: memberId,
            ),
          );
      final DocumentReference<Map<String, dynamic>> toWaitlistRef = _waitlist
          .doc(
            GroupWaitlistEntry.idFor(groupId: toGroupId, studentId: memberId),
          );

      return _firestore.runTransaction<MemberMove>((
        Transaction transaction,
      ) async {
        final DocumentSnapshot<Map<String, dynamic>> fromSnapshot =
            await transaction.get(fromRef);
        final DocumentSnapshot<Map<String, dynamic>> toSnapshot =
            await transaction.get(toRef);
        final DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
            await transaction.get(fromMemberRef);
        final DocumentSnapshot<Map<String, dynamic>> targetMemberSnapshot =
            await transaction.get(toMemberRef);
        final DocumentSnapshot<Map<String, dynamic>> fromRequestSnapshot =
            await transaction.get(fromRequestRef);
        final DocumentSnapshot<Map<String, dynamic>> toRequestSnapshot =
            await transaction.get(toRequestRef);
        final DocumentSnapshot<Map<String, dynamic>> fromWaitlistSnapshot =
            await transaction.get(fromWaitlistRef);
        final DocumentSnapshot<Map<String, dynamic>> toWaitlistSnapshot =
            await transaction.get(toWaitlistRef);

        final Map<String, Object?>? fromData = fromSnapshot.data();
        final Map<String, Object?>? toData = toSnapshot.data();
        final Map<String, Object?>? memberData = memberSnapshot.data();
        if (!fromSnapshot.exists ||
            fromData == null ||
            !toSnapshot.exists ||
            toData == null ||
            !memberSnapshot.exists ||
            memberData == null) {
          throw const AppException.notFound(
            debugMessage: 'source group, target group or member missing',
          );
        }

        final StudyGroup? from = studyGroupFromMap(fromSnapshot.id, fromData);
        final StudyGroup? to = studyGroupFromMap(toSnapshot.id, toData);
        final GroupMember? member = groupMemberFromMap(
          memberSnapshot.id,
          memberData,
        );
        if (from == null || to == null || member == null) {
          throw const AppException(
            AppErrorKind.unknown,
            debugMessage: 'group or member unreadable',
          );
        }
        if (from.teacherId != teacherId || to.teacherId != teacherId) {
          throw const AppException.permission(debugMessage: 'not group owner');
        }

        final String? reason = MoveRules.blockReason(
          from: from,
          to: to,
          sameOwner: true,
          isMember: true,
          targetAlreadyHasMember: targetMemberSnapshot.exists,
        );
        if (reason != null) {
          throw AppException(
            AppErrorKind.invalidInput,
            overrideMessage: reason,
            debugMessage: 'move blocked',
          );
        }

        final int fromSeats = from.seatsTaken > 0 ? from.seatsTaken - 1 : 0;
        final int toSeats = JoinRules.seatsAfterAccept(to.seatsTaken);
        final DateTime now = DateTime.now();

        // ما ينبغي تنظيفه — يُحسب قبل الكتابة حتى تُعاد النتيجة للواجهة.
        final String? fromRequestStatus =
            fromRequestSnapshot.data()?['status'] as String?;
        final bool clearsFromRequest =
            fromRequestSnapshot.exists &&
            (fromRequestStatus == JoinRequestStatus.pending.name ||
                fromRequestStatus == JoinRequestStatus.accepted.name);
        final String? fromWaitlistStatus =
            fromWaitlistSnapshot.data()?['status'] as String?;
        final bool clearsFromWaitlist =
            fromWaitlistSnapshot.exists &&
            (fromWaitlistStatus == WaitlistStatus.waiting.name ||
                fromWaitlistStatus == WaitlistStatus.promoted.name);
        final bool acceptsToRequest =
            toRequestSnapshot.data()?['status'] == JoinRequestStatus.pending.name;
        final bool promotesToWaitlist =
            toWaitlistSnapshot.data()?['status'] == WaitlistStatus.waiting.name;

        // (1) المصدر ينقص مقعدًا — ولا حقل آخر يتغيّر.
        transaction.update(fromRef, <String, Object?>{'seatsTaken': fromSeats});
        // (2) الهدف يزيد مقعدًا — ولا حقل آخر يتغيّر.
        transaction.update(toRef, <String, Object?>{'seatsTaken': toSeats});
        // (3) الارتباط ينتقل: حذف من المصدر وإنشاء في الهدف بنفس الهوية
        //     وتاريخ الانضمام الأصلي (النقل ليس عضوية جديدة).
        transaction.delete(fromMemberRef);
        transaction.set(toMemberRef, <String, Object?>{
          'studentId': member.id,
          'groupId': to.id,
          'name': member.name,
          'joinedAt': member.joinedAt,
          'status': 'active',
          // أثر النقل: يشرح للمدرس من أين جاء العضو، ويبقى بعد النقل لأن
          // العضوية نفسها تنتقل بتاريخ انضمامها الأصلي (A-73).
          'movedAt': now,
          'movedFromGroupTitle': from.title,
        });

        // (4) الهدف: إغلاق الصفوف المفتوحة بدل تركها معلّقة لعضو صار داخلًا.
        if (acceptsToRequest) {
          transaction.update(toRequestRef, <String, Object?>{
            'status': JoinRequestStatus.accepted.name,
            'decidedAt': now,
            'decidedBy': teacherId,
          });
        }
        if (promotesToWaitlist) {
          transaction.update(toWaitlistRef, <String, Object?>{
            'status': WaitlistStatus.promoted.name,
            'decidedAt': now,
            'decidedBy': teacherId,
          });
        }

        // (5) المصدر: حذف الصفوف التي صارت بلا معنى بعد خروج العضو.
        if (clearsFromRequest) {
          transaction.delete(fromRequestRef);
        }
        if (clearsFromWaitlist) {
          transaction.delete(fromWaitlistRef);
        }

        return MemberMove(
          member: member,
          from: _withSeats(from, fromSeats),
          to: _withSeats(to, toSeats),
          acceptedJoinRequest: acceptsToRequest,
          promotedWaitlist: promotesToWaitlist,
          clearedSourceRecords:
              (clearsFromRequest ? 1 : 0) + (clearsFromWaitlist ? 1 : 0),
        );
      });
    });
  }

  /// تعديل السعة وحدها — بلا لمس `seatsTaken` (A-70).
  @override
  Future<StudyGroup> updateGroupCapacity({
    required String groupId,
    required String teacherId,
    required int seatsTotal,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> ref = _groups.doc(groupId);

      return _firestore.runTransaction<StudyGroup>((
        Transaction transaction,
      ) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
            .get(ref);
        final Map<String, Object?>? data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw const AppException.notFound(debugMessage: 'group missing');
        }
        final StudyGroup? group = studyGroupFromMap(snapshot.id, data);
        if (group == null) {
          throw const AppException(
            AppErrorKind.unknown,
            debugMessage: 'group document is unreadable',
          );
        }
        if (group.teacherId != teacherId) {
          throw const AppException.permission(debugMessage: 'not group owner');
        }

        // الفحص على القراءة الطازجة داخل المعاملة، لا على قيمة الواجهة.
        final String? reason = GroupRules.capacityBlockReason(
          seatsTotal: seatsTotal,
          seatsTaken: group.seatsTaken,
        );
        if (reason != null) {
          throw AppException(
            AppErrorKind.invalidInput,
            overrideMessage: reason,
            debugMessage: 'capacity blocked',
          );
        }

        transaction.update(ref, <String, Object?>{'seatsTotal': seatsTotal});
        return _withSeats(group, group.seatsTaken, seatsTotal: seatsTotal);
      });
    });
  }

  /// نسخة من المجموعة بمقاعد معدّلة — لا نعيد بناء النموذج يدويًا في كل موضع.
  StudyGroup _withSeats(
    StudyGroup group,
    int seatsTaken, {
    int? seatsTotal,
  }) {
    return StudyGroup(
      id: group.id,
      teacherId: group.teacherId,
      teacherName: group.teacherName,
      title: group.title,
      subject: group.subject,
      stage: group.stage,
      seatsTotal: seatsTotal ?? group.seatsTotal,
      seatsTaken: seatsTaken,
      meetingMode: group.meetingMode,
      scheduleNote: group.scheduleNote,
      isActive: group.isActive,
    );
  }

  // ── P9: قائمة الانتظار ───────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _waitlist =>
      _firestore.collection(FirestoreCollections.groupWaitlist);

  /// الانضمام للطابور: نقرأ المجموعة **طازجة**، لأن شرط «مكتملة» قد يتغيّر بين
  /// عرض الشاشة والكتابة.
  @override
  Future<GroupWaitlistEntry> joinWaitlist({
    required StudyGroup group,
    required String studentId,
    required String studentName,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> groupRef = _groups.doc(
        group.id,
      );
      final DocumentReference<Map<String, dynamic>> entryRef = _waitlist.doc(
        GroupWaitlistEntry.idFor(groupId: group.id, studentId: studentId),
      );

      return _firestore.runTransaction<GroupWaitlistEntry>((
        Transaction transaction,
      ) async {
        final DocumentSnapshot<Map<String, dynamic>> groupSnapshot =
            await transaction.get(groupRef);
        final DocumentSnapshot<Map<String, dynamic>> entrySnapshot =
            await transaction.get(entryRef);

        final Map<String, Object?>? groupData = groupSnapshot.data();
        if (!groupSnapshot.exists || groupData == null) {
          throw const AppException.notFound(debugMessage: 'group missing');
        }
        final StudyGroup? current = studyGroupFromMap(
          groupSnapshot.id,
          groupData,
        );
        if (current == null) {
          throw const AppException(
            AppErrorKind.unknown,
            debugMessage: 'group document is unreadable',
          );
        }

        final WaitlistStatus? existing = entrySnapshot.exists
            ? WaitlistStatus.parse(entrySnapshot.data()?['status'])
            : null;

        final String? reason = WaitlistRules.joinBlockReason(
          group: current,
          viewerId: studentId,
          existingStatus: existing,
        );
        if (reason != null) {
          throw AppException(
            AppErrorKind.invalidInput,
            overrideMessage: reason,
            debugMessage: 'waitlist blocked',
          );
        }

        final GroupWaitlistEntry entry = buildWaitlistEntry(
          group: current,
          studentId: studentId,
          studentName: studentName,
        );
        final ValidationResult valid = WaitlistRules.validateEntry(
          groupId: entry.groupId,
          groupTitle: entry.groupTitle,
          studentId: entry.studentId,
          studentName: entry.studentName,
        );
        if (!valid.isValid) {
          throw AppException.invalidInput(debugMessage: valid.firstMessage);
        }

        // `set` متعمّد: العودة بعد المغادرة تستبدل الصف نفسه.
        transaction.set(entryRef, entry.toCreateMap());
        return entry;
      });
    });
  }

  @override
  Future<GroupWaitlistEntry?> findMyWaitlistEntry({
    required String groupId,
    required String studentId,
  }) {
    return _guard(() async {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _waitlist
          .doc(GroupWaitlistEntry.idFor(groupId: groupId, studentId: studentId))
          .get();
      final Map<String, Object?>? data = doc.data();
      if (!doc.exists || data == null) {
        return null;
      }
      return groupWaitlistEntryFromMap(doc.id, data);
    });
  }

  @override
  Future<List<GroupWaitlistEntry>> listWaitlist(
    String groupId, {
    String? teacherId,
  }) {
    return _guard(() async {
      // القيد على `teacherId` إلزامي: القواعد تقرأ `resource.data.teacherId`،
      // والاستعلام الذي لا يقيّده يُرفض كاملًا (نفس درس P8).
      Query<Map<String, dynamic>> query = _waitlist.where(
        'groupId',
        isEqualTo: groupId,
      );
      if (teacherId != null) {
        query = query.where('teacherId', isEqualTo: teacherId);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      return WaitlistRules.ordered(
        mapDocuments(snapshot.docs.map(_entry), groupWaitlistEntryFromMap),
      );
    });
  }

  /// قبول منتظر: مقعد واحد + عضوية + حالة الصف في معاملة واحدة.
  @override
  Future<GroupWaitlistEntry> promoteFromWaitlist({
    required GroupWaitlistEntry entry,
    required String teacherId,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> groupRef = _groups.doc(
        entry.groupId,
      );
      final DocumentReference<Map<String, dynamic>> entryRef = _waitlist.doc(
        entry.id,
      );
      final DocumentReference<Map<String, dynamic>> memberRef = groupRef
          .collection(FirestoreCollections.groupMembers)
          .doc(entry.studentId);

      // نُخرجه من المعاملة لاستخدامه في الإشعار بعد الالتزام.
      String groupTeacherName = '';

      final GroupWaitlistEntry promoted = await _firestore.runTransaction<GroupWaitlistEntry>((
        Transaction transaction,
      ) async {
        final DocumentSnapshot<Map<String, dynamic>> groupSnapshot =
            await transaction.get(groupRef);
        final DocumentSnapshot<Map<String, dynamic>> entrySnapshot =
            await transaction.get(entryRef);

        final Map<String, Object?>? groupData = groupSnapshot.data();
        final Map<String, Object?>? entryData = entrySnapshot.data();
        if (!groupSnapshot.exists ||
            groupData == null ||
            !entrySnapshot.exists ||
            entryData == null) {
          throw const AppException.notFound(
            debugMessage: 'group or waitlist row missing',
          );
        }

        final StudyGroup? group = studyGroupFromMap(
          groupSnapshot.id,
          groupData,
        );
        final GroupWaitlistEntry? current = groupWaitlistEntryFromMap(
          entrySnapshot.id,
          entryData,
        );
        if (group == null || current == null) {
          throw const AppException(
            AppErrorKind.unknown,
            debugMessage: 'group or waitlist row unreadable',
          );
        }
        if (group.teacherId != teacherId) {
          throw const AppException.permission(debugMessage: 'not group owner');
        }
        groupTeacherName = group.teacherName;

        final String? reason = WaitlistRules.promoteBlockReason(
          group: group,
          entry: current,
        );
        if (reason != null) {
          throw AppException(
            AppErrorKind.invalidInput,
            overrideMessage: reason,
            debugMessage: 'promote blocked',
          );
        }

        final DateTime now = DateTime.now();
        transaction.update(groupRef, <String, Object?>{
          'seatsTaken': JoinRules.seatsAfterAccept(group.seatsTaken),
        });
        transaction.update(entryRef, <String, Object?>{
          'status': WaitlistStatus.promoted.name,
          'decidedAt': now,
          'decidedBy': teacherId,
        });
        transaction.set(memberRef, <String, Object?>{
          'studentId': current.studentId,
          'groupId': group.id,
          'name': current.studentName,
          'joinedAt': now,
          'status': 'active',
        });

        return current.copyWith(
          status: WaitlistStatus.promoted,
          decidedAt: now,
          decidedBy: teacherId,
        );
      });

      await _notify(
        type: NotificationType.waitlistPromoted,
        recipientId: promoted.studentId,
        actorId: teacherId,
        actorName: groupTeacherName,
        targetId: promoted.groupId,
        body: NotificationRules.bodyFor(
          type: NotificationType.waitlistPromoted,
          actorName: groupTeacherName,
        ),
      );
      return promoted;
    });
  }
  @override
  Future<GroupWaitlistEntry> leaveWaitlist({
    required GroupWaitlistEntry entry,
    required String studentId,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> entryRef = _waitlist.doc(
        entry.id,
      );

      return _firestore.runTransaction<GroupWaitlistEntry>((
        Transaction transaction,
      ) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(entryRef);
        final Map<String, Object?>? data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw const AppException.notFound(debugMessage: 'waitlist row missing');
        }
        final GroupWaitlistEntry? current = groupWaitlistEntryFromMap(
          snapshot.id,
          data,
        );
        if (current == null) {
          throw const AppException(
            AppErrorKind.unknown,
            debugMessage: 'waitlist row unreadable',
          );
        }
        if (current.studentId != studentId) {
          throw const AppException.permission(debugMessage: 'not entry owner');
        }
        if (!current.isWaiting) {
          throw const AppException(
            AppErrorKind.invalidInput,
            overrideMessage: 'هذا الصف لم يعد في قائمة الانتظار.',
          );
        }

        final DateTime now = DateTime.now();
        // الحالة فقط: القواعد تقبل تغييرًا لا يمسّ بقية الحقول.
        transaction.update(entryRef, <String, Object?>{
          'status': WaitlistStatus.left.name,
        });
        return current.copyWith(
          status: WaitlistStatus.left,
          decidedAt: now,
          decidedBy: studentId,
        );
      });
    });
  }

  /// ينشئ إشعارًا «بأفضل جهد» (P12).
  ///
  /// فشل الإشعار لا يُفشل العملية الأصلية: الحجز أو الرسالة تمّت فعلًا، وإسقاط
  /// نجاحها بسبب إشعار سيكون كذبًا على المستخدم. الخطأ يُسجَّل للتشخيص فقط.
  Future<void> _notify({
    required NotificationType type,
    required String recipientId,
    required String actorId,
    required String actorName,
    required String targetId,
    String? title,
    String? body,
  }) async {
    final NotificationRepository? repo = _notifications;
    if (repo == null || recipientId.isEmpty || recipientId == actorId) {
      return;
    }
    try {
      await repo.push(
        type: type,
        recipientId: recipientId,
        actorId: actorId,
        actorName: actorName,
        targetId: targetId,
        title: title,
        body: body,
      );
    } on Object catch (error) {
      log('notification push failed', name: 'notifications', error: error);
    }
  }
}

/// الجدول الأسبوعي — مجموعة فرعية `studyGroups/{id}/sessions`.
///
/// كل مستند يحمل `groupId` منسوخًا ومكتوبًا عند الإنشاء: يجعل القراءة فحصًا
/// على المستند نفسه بدل `get()` للأب، ويُبقي القواعد قابلة للتحقق على الاستعلام.
class FirestoreScheduleRepository implements ScheduleRepository {
  FirestoreScheduleRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _sessions(String groupId) =>
      _firestore
          .collection(FirestoreCollections.studyGroups)
          .doc(groupId)
          .collection(FirestoreCollections.groupSessions);

  @override
  Future<List<GroupSession>> listForGroup(String groupId) {
    return _guard(() async {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _sessions(
        groupId,
      ).get();
      return SessionRules.sorted(
        mapDocuments(snapshot.docs.map(_entry), groupSessionFromMap),
      );
    });
  }

  @override
  Future<GroupSession> createSession({
    required String groupId,
    required String teacherId,
    required SessionDraft draft,
  }) {
    return _guard(() async {
      final List<GroupSession> existing = await listForGroup(groupId);
      _ensureValid(draft, existing: existing);

      final CollectionReference<Map<String, dynamic>> sessions = _sessions(
        groupId,
      );
      final DocumentReference<Map<String, dynamic>> ref = sessions.doc();
      await ref.set(<String, Object?>{
        ...draft.toUpdateMap(),
        'groupId': groupId,
        'teacherId': teacherId,
        'isCancelled': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return GroupSession(
        id: ref.id,
        groupId: groupId,
        teacherId: teacherId,
        title: draft.normalizedTitle,
        weekday: draft.weekday,
        startMinutes: draft.startMinutes,
        durationMinutes: draft.durationMinutes,
        locationNote: draft.normalizedLocation,
      );
    });
  }

  @override
  Future<GroupSession> updateSession({
    required GroupSession session,
    required String teacherId,
    required SessionDraft draft,
  }) {
    return _guard(() async {
      if (session.teacherId != teacherId) {
        throw const AppException.permission(debugMessage: 'not group owner');
      }
      final List<GroupSession> existing = await listForGroup(session.groupId);
      _ensureValid(draft, existing: existing, ignoreSessionId: session.id);

      await _sessions(session.groupId)
          .doc(session.id)
          .update(draft.toUpdateMap());

      return session.copyWith(
        title: draft.normalizedTitle,
        weekday: draft.weekday,
        startMinutes: draft.startMinutes,
        durationMinutes: draft.durationMinutes,
        locationNote: draft.normalizedLocation,
      );
    });
  }

  @override
  Future<GroupSession> setCancelled({
    required GroupSession session,
    required String teacherId,
    required bool isCancelled,
  }) {
    return _guard(() async {
      if (session.teacherId != teacherId) {
        throw const AppException.permission(debugMessage: 'not group owner');
      }
      await _sessions(session.groupId).doc(session.id).update(
        <String, Object?>{'isCancelled': isCancelled},
      );
      return session.copyWith(isCancelled: isCancelled);
    });
  }

  void _ensureValid(
    SessionDraft draft, {
    required List<GroupSession> existing,
    String? ignoreSessionId,
  }) {
    final ValidationResult result = SessionRules.validateDraft(
      draft,
      existing: existing,
      ignoreSessionId: ignoreSessionId,
    );
    if (!result.isValid) {
      throw AppException(
        AppErrorKind.invalidInput,
        overrideMessage: SessionRules.conflictMessage(
              draft,
              existing,
              ignoreSessionId: ignoreSessionId,
            ) ??
            result.firstMessage,
        debugMessage: 'invalid session draft',
      );
    }
  }

  /// إزالة عضو (P9): حذف العضوية وإنقاص المقعد **في معاملة واحدة**.
  ///
  /// لو نقص المقعد وحده لبقيت عضوية بلا مقعد، ولو حُذفت العضوية وحدها لبقي
  /// مقعد محسوبًا لغير أحد — وكلاهما يفسد فحص السعة في القبول التالي.

  (String, Map<String, Object?>) _entry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => (doc.id, doc.data());
}

/// محادثة المجموعة — مجموعة فرعية `studyGroups/{id}/messages`.
///
/// القراءة مقيّدة بالعضوية في القواعد (`exists()` على مستند العضو)، والكتابة
/// لا تسمح بتعديل رسالة بعد إرسالها ولا بحذفها من التطبيق.
class FirestoreMessageRepository implements MessageRepository {
  FirestoreMessageRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _messages(String groupId) =>
      _firestore
          .collection(FirestoreCollections.studyGroups)
          .doc(groupId)
          .collection(FirestoreCollections.groupMessages);

  @override
  Future<List<GroupMessage>> listForGroup(String groupId) {
    return _guard(() async {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _messages(
        groupId,
      ).orderBy('sentAt').limit(MessageRules.maxMessagesPerLoad).get();

      final List<GroupMessage> messages = mapDocuments(
        snapshot.docs.map(_entry),
        groupMessageFromMap,
      ).toList(growable: false);
      // الاستعلام يضيّق النافذة، والواجهة تعرض الأحدث؛ نُعيدها تصاعدية دائمًا.
      messages.sort((GroupMessage a, GroupMessage b) {
        final int byTime = a.sentAt.compareTo(b.sentAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
      return List<GroupMessage>.unmodifiable(messages);
    });
  }

  @override
  Future<GroupMessage> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required UserRole senderRole,
    required String text,
  }) {
    return _guard(() async {
      final ValidationResult valid = MessageRules.validate(text);
      if (!valid.isValid) {
        throw AppException(
          AppErrorKind.invalidInput,
          overrideMessage: MessageRules.normalize(text).isEmpty
              ? 'لا يمكن إرسال رسالة فارغة.'
              : 'الرسالة أطول من ${MessageRules.maxLength} حرفًا.',
          debugMessage: 'invalid message',
        );
      }

      final GroupMessage message = GroupMessage(
        id: '',
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        text: MessageRules.normalize(text),
        sentAt: DateTime.now(),
      );

      final DocumentReference<Map<String, dynamic>> ref = _messages(
        groupId,
      ).doc();
      await ref.set(<String, Object?>{
        ...message.toCreateMap(),
        'groupId': groupId,
      });

      return GroupMessage(
        id: ref.id,
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        text: message.text,
        sentAt: message.sentAt,
      );
    });
  }

  /// إزالة عضو (P9): حذف العضوية وإنقاص المقعد **في معاملة واحدة**.
  ///
  /// لو نقص المقعد وحده لبقيت عضوية بلا مقعد، ولو حُذفت العضوية وحدها لبقي
  /// مقعد محسوبًا لغير أحد — وكلاهما يفسد فحص السعة في القبول التالي.

  (String, Map<String, Object?>) _entry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => (doc.id, doc.data());
}

/// ترتيب طلبات الانضمام: المعلّقة أولًا (الأقدم أولًا) ثم المقرَّرة.
///
/// لماذا في العميل؟ تجنّب فهرس مركّب آخر مقابل ترتيب بسيط لقائمة قصيرة
/// (طلبات مجموعة واحدة لا تتجاوز عشرات).
List<GroupJoinRequest> sortJoinRequests(List<GroupJoinRequest> requests) {
  final List<GroupJoinRequest> sorted = <GroupJoinRequest>[...requests];
  sorted.sort((GroupJoinRequest a, GroupJoinRequest b) {
    if (a.isPending != b.isPending) {
      return a.isPending ? -1 : 1;
    }
    return a.requestedAt.compareTo(b.requestedAt);
  });
  return List<GroupJoinRequest>.unmodifiable(sorted);
}

/// قراءة طلبات الحجز الخاصة بالمستخدم الحالي.
///
/// الاستعلام يعتمد على الدور:
/// - طالب: `studentId == uid`
/// - مدرس: `teacherId == uid`
///
/// ليست هنا تصفية أمنية: قواعد Firestore تمنع قراءة طلبات الآخرين أصلًا.
class FirestoreBookingRepository implements BookingRepository {
  FirestoreBookingRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Future<String?> Function()? currentUid,
    NotificationRepository? notifications,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _currentUid =
           currentUid ??
           (() async => (auth ?? FirebaseAuth.instance).currentUser?.uid),
       _notifications = notifications;

  final FirebaseFirestore _firestore;
  final Future<String?> Function() _currentUid;

  /// اختياري: كاتب الإشعارات (P12) — يُستدعى بعد نجاح الفعل وبأفضل جهد.
  final NotificationRepository? _notifications;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection(FirestoreCollections.bookingRequests);

  @override
  Future<List<BookingRequest>> listMine() {
    return _guard(() async {
      final String? uid = await _currentUid();
      if (uid == null) {
        // لا مستخدم: قائمة فارغة أصدق من خطأ، فالشاشة تعرض «لا توجد طلبات».
        return const <BookingRequest>[];
      }

      final QuerySnapshot<Map<String, dynamic>> asStudent = await _bookings
          .where('studentId', isEqualTo: uid)
          .get();
      final QuerySnapshot<Map<String, dynamic>> asTeacher = await _bookings
          .where('teacherId', isEqualTo: uid)
          .get();

      final Map<String, BookingRequest> merged = <String, BookingRequest>{};
      for (final BookingRequest booking in mapDocuments(
        <(String, Map<String, Object?>)>[
          ...asStudent.docs.map(_entry),
          ...asTeacher.docs.map(_entry),
        ],
        bookingFromMap,
      )) {
        merged[booking.id] = booking;
      }

      final List<BookingRequest> all = merged.values.toList(growable: false);
      // الأحدث أولًا، حتى يكون الترتيب مستقلًا عن ترتيب الاستعلامات.
      all.sort(
        (BookingRequest a, BookingRequest b) =>
            b.requestedAt.compareTo(a.requestedAt),
      );
      return List<BookingRequest>.unmodifiable(all);
    });
  }

  /// (P25) مراقبة حيّة لطلبات المستخدم من الجهتين.
  ///
  /// استعلامان (كطالب وكمعلم) لا يمكن دمجهما في استعلام واحد بلا `OR`/فهرس
  /// مركّب، فنراقبهما معًا وندمج النتائج. النتيجة نفسها التي يعيدها
  /// [listMine] (بلا تكرار، الأحدث أولًا) لكنها تصل عند كل تغيير — فقبول
  /// المدرس يظهر في شاشة الطالب في اللحظة نفسها.
  @override
  Stream<List<BookingRequest>> watchMine() async* {
    final String? uid = await _currentUid();
    if (uid == null) {
      yield const <BookingRequest>[];
      return;
    }

    List<BookingRequest> merge(
      List<BookingRequest> asStudent,
      List<BookingRequest> asTeacher,
    ) {
      final Map<String, BookingRequest> merged = <String, BookingRequest>{};
      for (final BookingRequest booking in <BookingRequest>[
        ...asStudent,
        ...asTeacher,
      ]) {
        merged[booking.id] = booking;
      }
      final List<BookingRequest> all = merged.values.toList(growable: false);
      all.sort(
        (BookingRequest a, BookingRequest b) =>
            b.requestedAt.compareTo(a.requestedAt),
      );
      return List<BookingRequest>.unmodifiable(all);
    }

    Stream<List<BookingRequest>> side(String field) {
      return _bookings
          .where(field, isEqualTo: uid)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => mapDocuments(
              snapshot.docs.map(_entry),
              bookingFromMap,
            ),
          );
    }

    yield* mergeListStreams<BookingRequest>(
      first: side('studentId'),
      second: side('teacherId'),
      combine: merge,
    );
  }

  @override
  Future<BookingRequest?> findById(String id) {
    return _guard(() async {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _bookings
          .doc(id)
          .get();
      final Map<String, Object?>? data = doc.data();
      if (!doc.exists || data == null) {
        return null;
      }
      return bookingFromMap(doc.id, data);
    });
  }

  /// إزالة عضو (P9): حذف العضوية وإنقاص المقعد **في معاملة واحدة**.
  ///
  /// لو نقص المقعد وحده لبقيت عضوية بلا مقعد، ولو حُذفت العضوية وحدها لبقي
  /// مقعد محسوبًا لغير أحد — وكلاهما يفسد فحص السعة في القبول التالي.

  // ── P10: كتابة الحجوزات ─────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _calendar =>
      _firestore.collection(FirestoreCollections.teacherCalendar);

  CollectionReference<Map<String, dynamic>> get _teacherProfiles =>
      _firestore.collection(FirestoreCollections.teacherProfiles);

  DocumentReference<Map<String, dynamic>> _calendarDoc(
    String teacherId,
    String dateKey,
  ) => _calendar.doc('${teacherId}_$dateKey');

  @override
  Future<BookingRequest> createRequest({
    required String teacherId,
    required String teacherName,
    required String studentId,
    required String studentName,
    required String subject,
    required DateTime startsAt,
    required int durationMinutes,
    String? note,
  }) {
    return _guard(() async {
      final DateTime now = DateTime.now();
      final String? slotReason = BookingRules.slotBlockReason(
        startsAt: startsAt,
        durationMinutes: durationMinutes,
        now: now,
      );
      if (slotReason != null) {
        throw AppException(
          AppErrorKind.invalidInput,
          overrideMessage: slotReason,
          debugMessage: 'invalid booking slot',
        );
      }
      final String trimmedSubject = subject.trim();
      if (trimmedSubject.length < 3) {
        throw const AppException.invalidInput(
          overrideMessage: 'اكتب مادة الحصة (3 أحرف على الأقل).',
        );
      }
      final String? cleanNote = note?.trim();

      final DocumentReference<Map<String, dynamic>> ref = _bookings.doc();
      final String dateKey = BookingRulesLite.keyOf(startsAt);
      final int startMinutes = BookingRulesLite.minutesOf(startsAt);

      final BookingRequest created = await _firestore.runTransaction<BookingRequest>((
        Transaction transaction,
      ) async {
        // الطلب الجديد معلّق لا يشغل وقتًا، لكن نفحص التقويم حتى لا نرسل طلبًا
        // مصيره الرفض. الفحص النهائي عند القبول.
        // (P16) لا طلب حجز لمدرس غير موثّق: الملف غير الموثّق غير قابل للقراءة
        // للطلاب أصلًا، وطلب حجز عليه يفتح باب إزعاج بلا حصة ممكنة. القواعد
        // تفرض الشرط نفسه (`teacherVerified`) فلا يُتجاوَز من عميل آخر.
        final DocumentSnapshot<Map<String, dynamic>> profile = await transaction
            .get(_teacherProfiles.doc(teacherId));
        if ((profile.data() ?? const <String, dynamic>{})['status'] !=
            'verified') {
          throw const AppException.permission(
            overrideMessage: 'لا يمكن إرسال طلب حجز لمدرس لم يُوثّق بعد.',
            debugMessage: 'teacher not verified',
          );
        }

        final DocumentSnapshot<Map<String, dynamic>> calendar = await transaction
            .get(_calendarDoc(teacherId, dateKey));
        final Map<String, Map<String, int>> busy = _readBusy(calendar.data());
        if (_overlapsBusy(busy, startMinutes, durationMinutes)) {
          throw const AppException(
            AppErrorKind.invalidInput,
            overrideMessage: BookingRules.conflictMessage,
            debugMessage: 'booking conflict',
          );
        }

        final Map<String, Object?> data = <String, Object?>{
          'teacherId': teacherId,
          'teacherName': teacherName,
          'studentId': studentId,
          'studentName': studentName,
          'subject': trimmedSubject,
          'status': BookingStatus.pending.name,
          'requestedAt': now,
          'dateKey': dateKey,
          'startMinutes': startMinutes,
          'durationMinutes': durationMinutes,
          if (cleanNote != null && cleanNote.isNotEmpty) 'note': cleanNote,
        };
        transaction.set(ref, data);
        return bookingFromMap(ref.id, data)!;
      });

      await _notify(
        type: NotificationType.bookingRequested,
        recipientId: created.teacherId ?? '',
        actorId: created.studentId ?? '',
        actorName: created.studentName,
        targetId: created.id,
        body: NotificationRules.bodyFor(
          type: NotificationType.bookingRequested,
          actorName: created.studentName,
          subject: created.subject,
        ),
      );
      return created;
    });
  }
  @override
  Future<BookingRequest> decideRequest({
    required BookingRequest request,
    required String teacherId,
    required bool approve,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> ref = _bookings.doc(
        request.id,
      );

      final BookingRequest decided = await _firestore.runTransaction<BookingRequest>((
        Transaction transaction,
      ) async {
        final BookingRequest current = await _readBooking(
          transaction,
          ref,
          teacherId: teacherId,
          byTeacher: true,
        );
        final DateTime now = DateTime.now();
        final String? reason = BookingRules.actionBlockReason(
          booking: current,
          viewer: BookingViewer.teacher,
          action: approve ? BookingAction.accept : BookingAction.reject,
          now: now,
        );
        if (reason != null) {
          throw AppException(
            AppErrorKind.invalidInput,
            overrideMessage: reason,
            debugMessage: 'decision blocked',
          );
        }

        if (!approve) {
          transaction.update(ref, <String, Object?>{
            'status': BookingStatus.rejected.name,
            'decidedAt': now,
            'decidedBy': teacherId,
          });
          return current.copyWith(
            status: BookingStatus.rejected,
            decidedAt: now,
            decidedBy: teacherId,
          );
        }

        final BookingRequest accepted = _accepting(current, now, teacherId);
        await _bookSlot(transaction, accepted);
        return accepted;
      });

      await _notify(
        type: approve
            ? NotificationType.bookingAccepted
            : NotificationType.bookingRejected,
        recipientId: decided.studentId ?? '',
        actorId: decided.teacherId ?? '',
        actorName: decided.teacherName,
        targetId: decided.id,
        body: NotificationRules.bodyFor(
          type: approve
              ? NotificationType.bookingAccepted
              : NotificationType.bookingRejected,
          actorName: decided.teacherName,
          slotLabel: BookingRules.slotLabel(decided),
        ),
      );
      return decided;
    });
  }
  @override
  Future<BookingRequest> cancelRequest({
    required BookingRequest request,
    required String actorId,
    required bool byTeacher,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> ref = _bookings.doc(
        request.id,
      );

      return _firestore.runTransaction<BookingRequest>((
        Transaction transaction,
      ) async {
        final BookingRequest current = await _readBooking(
          transaction,
          ref,
          teacherId: byTeacher ? actorId : null,
          byTeacher: byTeacher,
          studentId: byTeacher ? null : actorId,
        );
        final DateTime now = DateTime.now();
        final String? reason = BookingRules.actionBlockReason(
          booking: current,
          viewer: byTeacher ? BookingViewer.teacher : BookingViewer.student,
          action: BookingAction.cancel,
          now: now,
        );
        if (reason != null) {
          throw AppException(
            AppErrorKind.invalidInput,
            overrideMessage: reason,
            debugMessage: 'cancel blocked',
          );
        }

        final BookingStatus status = BookingRules.cancelStatus(
          booking: current,
          now: now,
        );
        // تحرير الوقت من التقويم في المعاملة نفسها.
        await _releaseSlot(transaction, current);
        transaction.update(ref, <String, Object?>{
          'status': status.name,
          'cancelledAt': now,
          'cancelledBy': actorId,
        });
        return current.copyWith(
          status: status,
          cancelledAt: now,
          cancelledBy: actorId,
        );
      });
    });
  }

  @override
  Future<BookingRequest> proposeReschedule({
    required BookingRequest request,
    required String actorId,
    required bool byTeacher,
    required DateTime startsAt,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> ref = _bookings.doc(
        request.id,
      );

      final BookingRequest proposed = await _firestore.runTransaction<BookingRequest>((
        Transaction transaction,
      ) async {
        final BookingRequest current = await _readBooking(
          transaction,
          ref,
          teacherId: byTeacher ? actorId : null,
          byTeacher: byTeacher,
          studentId: byTeacher ? null : actorId,
        );
        final DateTime now = DateTime.now();
        final String? reason = BookingRules.actionBlockReason(
          booking: current,
          viewer: byTeacher ? BookingViewer.teacher : BookingViewer.student,
          action: BookingAction.proposeReschedule,
          now: now,
        );
        if (reason != null) {
          throw AppException(
            AppErrorKind.invalidInput,
            overrideMessage: reason,
            debugMessage: 'propose blocked',
          );
        }

        final int duration = current.durationMinutes ?? 60;
        final String? slotReason = BookingRules.slotBlockReason(
          startsAt: startsAt,
          durationMinutes: duration,
          now: now,
        );
        if (slotReason != null) {
          throw AppException(
            AppErrorKind.invalidInput,
            overrideMessage: slotReason,
            debugMessage: 'invalid proposal slot',
          );
        }

        final String dateKey = BookingRulesLite.keyOf(startsAt);
        final int startMinutes = BookingRulesLite.minutesOf(startsAt);
        final BookingActor actor = byTeacher
            ? BookingActor.teacher
            : BookingActor.student;

        transaction.update(ref, <String, Object?>{
          'status': BookingStatus.rescheduleProposed.name,
          'proposalDateKey': dateKey,
          'proposalStartMinutes': startMinutes,
          'proposedBy': actor.name,
          'proposedAt': now,
        });
        return current.copyWith(
          status: BookingStatus.rescheduleProposed,
          proposalDateKey: dateKey,
          proposalStartMinutes: startMinutes,
          proposedBy: actor,
          proposedAt: now,
        );
      });

      await _notify(
        type: NotificationType.rescheduleProposed,
        recipientId: byTeacher
            ? (proposed.studentId ?? '')
            : (proposed.teacherId ?? ''),
        actorId: actorId,
        actorName: byTeacher ? proposed.teacherName : proposed.studentName,
        targetId: proposed.id,
        body: NotificationRules.bodyFor(
          type: NotificationType.rescheduleProposed,
          actorName: byTeacher ? proposed.teacherName : proposed.studentName,
          slotLabel: BookingRules.proposalLabel(proposed),
        ),
      );
      return proposed;
    });
  }
  @override
  Future<BookingRequest> respondToProposal({
    required BookingRequest request,
    required String actorId,
    required bool byTeacher,
    required bool accept,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> ref = _bookings.doc(
        request.id,
      );

      final BookingRequest answered = await _firestore.runTransaction<BookingRequest>((
        Transaction transaction,
      ) async {
        final BookingRequest current = await _readBooking(
          transaction,
          ref,
          teacherId: byTeacher ? actorId : null,
          byTeacher: byTeacher,
          studentId: byTeacher ? null : actorId,
        );
        final DateTime now = DateTime.now();

        // رفض الوقت البديل يُنهي الطلب: لا موعد متفق عليه.
        if (!accept) {
          transaction.update(ref, <String, Object?>{
            'status': BookingStatus.rejected.name,
            'decidedAt': now,
            'decidedBy': actorId,
          });
          return current.copyWith(
            status: BookingStatus.rejected,
            decidedAt: now,
            decidedBy: actorId,
          );
        }

        final String? reason = BookingRules.actionBlockReason(
          booking: current,
          viewer: byTeacher ? BookingViewer.teacher : BookingViewer.student,
          action: BookingAction.acceptProposal,
          now: now,
        );
        if (reason != null) {
          throw AppException(
            AppErrorKind.invalidInput,
            overrideMessage: reason,
            debugMessage: 'proposal response blocked',
          );
        }

        final BookingRequest accepted = _accepting(current, now, actorId);
        await _releaseSlot(transaction, current);
        await _bookSlot(transaction, accepted);
        return accepted;
      });

      await _notify(
        type: accept
            ? NotificationType.bookingAccepted
            : NotificationType.bookingRejected,
        recipientId: byTeacher
            ? (answered.studentId ?? '')
            : (answered.teacherId ?? ''),
        actorId: actorId,
        actorName: byTeacher ? answered.teacherName : answered.studentName,
        targetId: answered.id,
        body: NotificationRules.bodyFor(
          type: accept
              ? NotificationType.bookingAccepted
              : NotificationType.bookingRejected,
          actorName: byTeacher ? answered.teacherName : answered.studentName,
          slotLabel: BookingRules.slotLabel(answered),
        ),
      );
      return answered;
    });
  }
  @override
  Future<BookingRequest> completeRequest({
    required BookingRequest request,
    required String teacherId,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> ref = _bookings.doc(
        request.id,
      );

      return _firestore.runTransaction<BookingRequest>((
        Transaction transaction,
      ) async {
        final BookingRequest current = await _readBooking(
          transaction,
          ref,
          teacherId: teacherId,
          byTeacher: true,
        );
        final DateTime now = DateTime.now();
        final String? reason = BookingRules.actionBlockReason(
          booking: current,
          viewer: BookingViewer.teacher,
          action: BookingAction.complete,
          now: now,
        );
        if (reason != null) {
          throw AppException(
            AppErrorKind.invalidInput,
            overrideMessage: reason,
            debugMessage: 'complete blocked',
          );
        }

        await _releaseSlot(transaction, current);
        transaction.update(ref, <String, Object?>{
          'status': BookingStatus.completed.name,
          'decidedAt': now,
          'decidedBy': teacherId,
        });
        return current.copyWith(
          status: BookingStatus.completed,
          decidedAt: now,
          decidedBy: teacherId,
        );
      });
    });
  }

  /// الطلب بعد القبول: إن كان قبولًا لاقتراح فالوقت المقترح يصبح الموعد.
  BookingRequest _accepting(
    BookingRequest current,
    DateTime now,
    String decidedBy,
  ) {
    return current.status.isReschedule
        ? current.applyingProposal(now, decidedBy)
        : current.copyWith(
            status: BookingStatus.accepted,
            decidedAt: now,
            decidedBy: decidedBy,
          );
  }

  /// يحجز الفترة في تقويم اليوم داخل المعاملة الحالية.
  ///
  /// مستند واحد لكل يوم مدرس: قراءته وكتابته في المعاملة تُسلسل القرارات
  /// المتزامنة، فلا يُقبل موعدان متقاطعان (A-76).
  Future<void> _bookSlot(
    Transaction transaction,
    BookingRequest booking,
  ) async {
    final DateTime? start = booking.startsAt;
    if (start == null) {
      throw const AppException.invalidInput(
        overrideMessage: 'الطلب بلا موعد محدد.',
      );
    }
    final int duration = booking.durationMinutes ?? 60;
    final String dateKey = booking.dateKey!;
    final int startMinutes = booking.startMinutes!;
    final String teacherId = booking.teacherId ?? '';
    final DocumentReference<Map<String, dynamic>> calendarRef = _calendarDoc(
      teacherId,
      dateKey,
    );

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
        .get(calendarRef);
    final Map<String, Map<String, int>> busy = _readBusy(snapshot.data());
    if (_overlapsBusy(busy, startMinutes, duration)) {
      throw const AppException(
        AppErrorKind.invalidInput,
        overrideMessage: BookingRules.conflictMessage,
        debugMessage: 'booking conflict',
      );
    }

    final Map<String, Object?> updatedBusy = <String, Object?>{
      ...busy.map(
        (String key, Map<String, int> value) =>
            MapEntry<String, Object?>(key, value),
      ),
      booking.id: <String, Object?>{
        'start': startMinutes,
        'end': startMinutes + duration,
      },
    };

    transaction.set(calendarRef, <String, Object?>{
      'teacherId': teacherId,
      'dateKey': dateKey,
      'busy': updatedBusy,
    });
    transaction.update(_bookings.doc(booking.id), <String, Object?>{
      'status': BookingStatus.accepted.name,
      'dateKey': dateKey,
      'startMinutes': startMinutes,
      'durationMinutes': duration,
      'decidedAt': booking.decidedAt,
      'decidedBy': booking.decidedBy,
    });
  }

  /// يحرّر فترة الطلب من التقويم (إلغاء أو إكمال أو انتقال لوقت جديد).
  Future<void> _releaseSlot(
    Transaction transaction,
    BookingRequest booking,
  ) async {
    final String? dateKey = booking.dateKey;
    final String? teacherId = booking.teacherId;
    if (dateKey == null || teacherId == null) {
      return;
    }
    final DocumentReference<Map<String, dynamic>> calendarRef = _calendarDoc(
      teacherId,
      dateKey,
    );
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
        .get(calendarRef);
    if (!snapshot.exists) {
      return;
    }
    final Map<String, Map<String, int>> busy = _readBusy(snapshot.data());
    if (!busy.containsKey(booking.id)) {
      return;
    }
    final Map<String, Object?> updatedBusy = <String, Object?>{
      for (final MapEntry<String, Map<String, int>> entry in busy.entries)
        if (entry.key != booking.id) entry.key: entry.value,
    };
    transaction.set(calendarRef, <String, Object?>{
      'teacherId': teacherId,
      'dateKey': dateKey,
      'busy': updatedBusy,
    });
  }

  Map<String, Map<String, int>> _readBusy(Map<String, Object?>? data) {
    final Object? raw = data?['busy'];
    if (raw is! Map) {
      return <String, Map<String, int>>{};
    }
    final Map<String, Map<String, int>> result = <String, Map<String, int>>{};
    for (final MapEntry<Object?, Object?> entry in raw.entries) {
      final Object? value = entry.value;
      final Object? rawKey = entry.key;
      if (rawKey is! String || value is! Map) {
        continue;
      }
      final Object? start = value['start'];
      final Object? end = value['end'];
      if (start is int && end is int) {
        result[rawKey] = <String, int>{'start': start, 'end': end};
      }
    }
    return result;
  }

  bool _overlapsBusy(
    Map<String, Map<String, int>> busy,
    int startMinutes,
    int duration,
  ) {
    final int end = startMinutes + duration;
    for (final Map<String, int> slot in busy.values) {
      final int existingStart = slot['start'] ?? 0;
      final int existingEnd = slot['end'] ?? 0;
      if (startMinutes < existingEnd && existingStart < end) {
        return true;
      }
    }
    return false;
  }

  /// يقرأ طلبًا داخل معاملة ويتحقق من الملكية قبل أي كتابة.
  Future<BookingRequest> _readBooking(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> ref, {
    String? teacherId,
    String? studentId,
    required bool byTeacher,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
        .get(ref);
    final Map<String, Object?>? data = snapshot.data();
    final BookingRequest? booking = !snapshot.exists || data == null
        ? null
        : bookingFromMap(snapshot.id, data);
    if (booking == null) {
      throw const AppException.notFound(debugMessage: 'booking missing');
    }
    if (byTeacher) {
      if (teacherId != null && booking.teacherId != teacherId) {
        throw const AppException.permission(debugMessage: 'not the teacher');
      }
    } else if (studentId != null && booking.studentId != studentId) {
      throw const AppException.permission(debugMessage: 'not the student');
    }
    return booking;
  }

  (String, Map<String, Object?>) _entry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => (doc.id, doc.data());

  /// ينشئ إشعارًا «بأفضل جهد» (P12).
  ///
  /// فشل الإشعار لا يُفشل العملية الأصلية: الحجز أو الرسالة تمّت فعلًا، وإسقاط
  /// نجاحها بسبب إشعار سيكون كذبًا على المستخدم. الخطأ يُسجَّل للتشخيص فقط.
  Future<void> _notify({
    required NotificationType type,
    required String recipientId,
    required String actorId,
    required String actorName,
    required String targetId,
    String? title,
    String? body,
  }) async {
    final NotificationRepository? repo = _notifications;
    if (repo == null || recipientId.isEmpty || recipientId == actorId) {
      return;
    }
    try {
      await repo.push(
        type: type,
        recipientId: recipientId,
        actorId: actorId,
        actorName: actorName,
        targetId: targetId,
        title: title,
        body: body,
      );
    } on Object catch (error) {
      log('notification push failed', name: 'notifications', error: error);
    }
  }
}

/// المحادثات المباشرة في Firestore (P11).
///
/// **المعرّف مشتق** (`ChatId` = `{teacherId}_{studentId}`)، فالعثور على الخيط
/// قراءة مستند واحد بلا استعلام ولا فهرس.
///
/// القواعد هي التي تمنع الخيط غير المصرّح به؛ الواجهة تتحقق محليًا فقط لتشرح
/// السبب بالعربية قبل محاولة كتابة ستُرفض.
class FirestoreDirectChatRepository implements DirectChatRepository {
  FirestoreDirectChatRepository({
    FirebaseFirestore? firestore,
    NotificationRepository? notifications,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _notifications = notifications;

  final FirebaseFirestore _firestore;

  /// اختياري: كاتب الإشعارات (P12) — يُخطر الطرف الآخر برسالة جديدة.
  final NotificationRepository? _notifications;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection(FirestoreCollections.directChats);

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _chats.doc(chatId).collection(FirestoreCollections.directChatMessages);

  DocumentReference<Map<String, dynamic>> _settings(String teacherId) =>
      _firestore
          .collection(FirestoreCollections.teacherSettings)
          .doc(teacherId);

  @override
  Future<DirectChat?> findById(String chatId) {
    return _guard(() async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _chats
          .doc(chatId)
          .get();
      final Map<String, Object?>? data = snapshot.data();
      if (data == null) {
        return null;
      }
      return directChatFromMap(snapshot.id, data);
    });
  }

  @override
  Future<List<DirectChat>> listMine(String viewerId) {
    return _guard(() async {
      if (viewerId.isEmpty) {
        return const <DirectChat>[];
      }

      // استعلامان متساويان (لا `OR` ولا فهرس مركّب) ثم دمج في العميل.
      final QuerySnapshot<Map<String, dynamic>> asTeacher = await _chats
          .where('teacherId', isEqualTo: viewerId)
          .get();
      final QuerySnapshot<Map<String, dynamic>> asStudent = await _chats
          .where('studentId', isEqualTo: viewerId)
          .get();

      final Map<String, DirectChat> merged = <String, DirectChat>{};
      for (final DirectChat chat in mapDocuments(
        <(String, Map<String, Object?>)>[
          ...asTeacher.docs.map(_entry),
          ...asStudent.docs.map(_entry),
        ],
        directChatFromMap,
      )) {
        merged[chat.id] = chat;
      }

      final List<DirectChat> all = merged.values.toList(growable: false);
      all.sort((DirectChat a, DirectChat b) {
        final DateTime left = a.lastMessageAt ?? a.createdAt;
        final DateTime right = b.lastMessageAt ?? b.createdAt;
        return right.compareTo(left);
      });
      return List<DirectChat>.unmodifiable(all);
    });
  }

  @override
  Stream<List<DirectChatMessage>> watchMessages(String chatId) {
    // البثّ على نافذة محدودة بدل الاستماع لكل الرسائل: القواعد تحدّ القراءة
    // بالطرفين، والحدّ هنا حماية من محادثة ضخمة على جهاز محدود الموارد.
    return _messages(chatId)
        .orderBy('sentAt')
        .limitToLast(DirectChatRules.maxMessagesPerLoad)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) =>
              List<DirectChatMessage>.unmodifiable(
                mapDocuments(
                  snapshot.docs.map(_entry),
                  (String id, Map<String, Object?> data) =>
                      directChatMessageFromMap(id, data, chatId: chatId),
                ),
              ),
        );
  }

  @override
  Stream<DirectChat?> watchChat(String chatId) {
    return _chats.doc(chatId).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, Object?>? data = snapshot.data();
      if (data == null) {
        return null;
      }
      return directChatFromMap(snapshot.id, data);
    });
  }

  @override
  Future<bool> allowDirectMessages(String teacherId) {
    return _guard(() async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _settings(
        teacherId,
      ).get();
      final Object? value = snapshot.data()?['allowDirectMessages'];
      // غياب المستند أو الحقل = القيمة المتشدّدة (A-78)، لا «مسموح».
      return value is bool ? value : DirectChatRules.defaultAllowDirectMessages;
    });
  }

  @override
  Future<void> setAllowDirectMessages({
    required String teacherId,
    required bool allow,
  }) {
    return _guard(() async {
      // `set` مع `merge` حتى لا يمسح حقولًا أخرى إن أُضيفت للإعدادات لاحقًا.
      await _settings(teacherId).set(<String, Object?>{
        'allowDirectMessages': allow,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<DirectChat> openChat({
    required String teacherId,
    required String teacherName,
    required String studentId,
    required String studentName,
    required DirectChatOrigin origin,
    String? subject,
    String? bookingId,
    String? groupId,
  }) {
    return _guard(() async {
      final String chatId = DirectChat.idFor(
        teacherId: teacherId,
        studentId: studentId,
      );

      final bool allowed = await allowDirectMessages(teacherId);
      final String? blocked = DirectChatRules.startBlockedReason(
        viewerId: studentId,
        // (P24) خيط طلب الانضمام مسموح بسند الطلب نفسه، فلا يحتاج حجزًا ولا
        // عضوية ولا إعداد رسائل — لكنه لا يُنشأ إلا بعد وجود الطلب فعلًا
        // (والقواعد تتحقق من المستند عند الإنشاء).
        hasBooking: origin == DirectChatOrigin.booking,
        isGroupMember:
            origin == DirectChatOrigin.group ||
            origin == DirectChatOrigin.joinRequest,
        allowDirectMessages: allowed,
      );
      if (origin == DirectChatOrigin.inquiry && blocked != null) {
        throw AppException(
          AppErrorKind.permission,
          overrideMessage: blocked,
          debugMessage: 'inquiry not allowed',
        );
      }
      if (origin == DirectChatOrigin.booking &&
          (bookingId == null || bookingId.isEmpty)) {
        throw const AppException.invalidInput(
          debugMessage: 'booking-origin chat without bookingId',
        );
      }
      if ((origin == DirectChatOrigin.group ||
              origin == DirectChatOrigin.joinRequest) &&
          (groupId == null || groupId.isEmpty)) {
        throw const AppException.invalidInput(
          debugMessage: 'group/join-request chat without groupId',
        );
      }

      final DocumentReference<Map<String, dynamic>> ref = _chats.doc(chatId);
      final Map<String, Object?> payload = <String, Object?>{
        'teacherId': teacherId,
        'teacherName': teacherName,
        'studentId': studentId,
        'studentName': studentName,
        if (subject != null && subject.trim().isNotEmpty)
          'subject': subject.trim(),
        'origin': origin.name,
        if (origin == DirectChatOrigin.booking) 'bookingId': bookingId,
        if (origin == DirectChatOrigin.group ||
            origin == DirectChatOrigin.joinRequest)
          'groupId': groupId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // معاملة: قراءة ثم إنشاء. لو سبقنا أحد إلى نفس الزوج، نُعيد الخيط
      // القائم بدل مسح آخر رسالة فيه (والقواعد ترفض أي استبدال من العميل).
      final DirectChat? existing = await _firestore.runTransaction<DirectChat?>(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> snapshot =
              await transaction.get(ref);
          final Map<String, Object?>? data = snapshot.data();
          if (data != null) {
            return directChatFromMap(snapshot.id, data);
          }
          transaction.set(ref, payload);
          return null;
        },
      );
      if (existing != null) {
        return existing;
      }

      final DirectChat? created = await findById(chatId);
      if (created == null) {
        throw const AppException(
          AppErrorKind.unknown,
          debugMessage: 'chat missing right after creation',
        );
      }
      return created;
    });
  }

  @override
  Future<DirectChatMessage> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required UserRole senderRole,
    required String text,
    String? imageId,
  }) {
    return _guard(() async {
      final bool hasImage = imageId != null && imageId.isNotEmpty;
      final ValidationResult valid = MessageRules.validate(text);
      // (P24) رسالة مصوّرة بلا نص مقبولة: الصورة هي المحتوى، والتعليق اختياري.
      if (!valid.isValid && !(hasImage && DirectChatRules.normalize(text).isEmpty)) {
        throw AppException(
          AppErrorKind.invalidInput,
          overrideMessage: DirectChatRules.normalize(text).isEmpty
              ? 'لا يمكن إرسال رسالة فارغة.'
              : 'الرسالة أطول من ${DirectChatRules.maxLength} حرفًا.',
          debugMessage: 'invalid message',
        );
      }

      final DirectChat? chat = await findById(chatId);
      if (chat == null) {
        throw const AppException.notFound(
          debugMessage: 'chat missing',
          overrideMessage: 'المحادثة غير موجودة.',
        );
      }

      final String? blocked = DirectChatRules.sendBlockedReason(
        chat: chat,
        viewerId: senderId,
        allowDirectMessages: await allowDirectMessages(chat.teacherId),
        bookingRejected: await _bookingRejected(chat),
      );
      if (blocked != null) {
        throw AppException(
          AppErrorKind.permission,
          overrideMessage: blocked,
          debugMessage: 'send blocked',
        );
      }

      final String normalized = DirectChatRules.normalize(text);
      final DocumentReference<Map<String, dynamic>> ref = _messages(
        chatId,
      ).doc();
      final DirectChatMessage message = DirectChatMessage(
        id: ref.id,
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        text: normalized,
        sentAt: DateTime.now(),
        imageId: hasImage ? imageId : null,
      );

      // دفعة واحدة: الرسالة وملخّص المحادثة. لو كُتبت الرسالة وحدها لظلّ
      // صندوق المحادثات يعرض نصًا قديمًا بلا إشعار.
      final WriteBatch batch = _firestore.batch();
      batch.set(ref, message.toCreateMap());
      // القواعد تشترط ملخّصًا غير فارغ، ورسالة صورة بلا تعليق نصّها فارغ —
      // فالصندوق يعرض «📷 صورة» بدل سطر فارغ أو فشل كتابة.
      final String summary = normalized.isNotEmpty
          ? normalized
          : (hasImage ? '📷 صورة' : normalized);
      batch.update(_chats.doc(chatId), <String, Object?>{
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': summary,
        'lastSenderId': senderId,
      });
      await batch.commit();

      // إشعار الطرف الآخر (P12). من كان داخل المحادثة نفسها يقرأ الرسالة
      // فورًا ويعلمها مقروءة عند وصول واجهته — الإشعار للسجل والجرس.
      final String recipientId = chat.isTeacherViewer(senderId)
          ? chat.studentId
          : chat.teacherId;
      await _notify(
        type: NotificationType.directMessage,
        recipientId: recipientId,
        actorId: senderId,
        actorName: senderName,
        targetId: chat.id,
        body: NotificationRules.bodyFor(
          type: NotificationType.directMessage,
          actorName: senderName,
        ),
      );

      return message;
    });
  }

  @override
  Future<void> markRead({
    required String chatId,
    required String viewerId,
    required DateTime at,
  }) {
    return _guard(() async {
      final DirectChat? chat = await findById(chatId);
      if (chat == null || !chat.involves(viewerId)) {
        return;
      }
      // لا نكتب قيمة مساوية أو أقدم: القواعد تشترط تغييرًا فعليًا لحقل القارئ.
      final DateTime? current = chat.lastReadAtFor(viewerId);
      if (current != null && !at.isAfter(current)) {
        return;
      }
      final String field = chat.isTeacherViewer(viewerId)
          ? 'teacherLastReadAt'
          : 'studentLastReadAt';
      // حقل واحد فقط — القواعد ترفض أي تعديل آخر من غير المالك.
      await _chats.doc(chatId).update(<String, Object?>{
        field: Timestamp.fromDate(at),
      });
    });
  }

  Future<bool> _bookingRejected(DirectChat chat) async {
    final String? bookingId = chat.bookingId;
    if (bookingId == null) {
      return false;
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection(FirestoreCollections.bookingRequests)
        .doc(bookingId)
        .get();
    final Map<String, Object?>? data = snapshot.data();
    return data != null && data['status'] == 'rejected';
  }

  (String, Map<String, Object?>) _entry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => (doc.id, doc.data());

  /// ينشئ إشعارًا «بأفضل جهد» (P12).
  ///
  /// فشل الإشعار لا يُفشل العملية الأصلية: الحجز أو الرسالة تمّت فعلًا، وإسقاط
  /// نجاحها بسبب إشعار سيكون كذبًا على المستخدم. الخطأ يُسجَّل للتشخيص فقط.
  Future<void> _notify({
    required NotificationType type,
    required String recipientId,
    required String actorId,
    required String actorName,
    required String targetId,
    String? title,
    String? body,
  }) async {
    final NotificationRepository? repo = _notifications;
    if (repo == null || recipientId.isEmpty || recipientId == actorId) {
      return;
    }
    try {
      await repo.push(
        type: type,
        recipientId: recipientId,
        actorId: actorId,
        actorName: actorName,
        targetId: targetId,
        title: title,
        body: body,
      );
    } on Object catch (error) {
      log('notification push failed', name: 'notifications', error: error);
    }
  }
}

/// الإشعارات داخل التطبيق في Firestore (P12).
///
/// **العزل بالقراءة:** كل استعلام مقيّد بـ`recipientId`، والقواعد ترفض قراءة أي
/// مستند لمستلم آخر — العزل ليس تصفية في العميل.
///
/// **الإنشاء من العميل:** لا دوال سحابية في هذه المرحلة، فيكتب الإشعار الطرف
/// الذي نفّذ الفعل، وتتحقق القواعد من العلاقة (حجز/محادثة/عضوية) ومن أن
/// `actorId == request.auth.uid`. البديل (Cloud Function) يحتاج خطة Blaze —
/// خارج نطاق المشروع الآن.
class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _items =>
      _firestore.collection(FirestoreCollections.notifications);

  @override
  Future<List<AppNotification>> listMine(String recipientId) {
    return _guard(() async {
      if (recipientId.isEmpty) {
        return const <AppNotification>[];
      }
      // بلا `orderBy`: الترتيب على عميل (قائمة قصيرة) تفاديًا لفهرس مركّب
      // إضافي — نفس سياسة بقية الشاشات (P8/P9).
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _items
          .where('recipientId', isEqualTo: recipientId)
          .limit(NotificationRules.maxPerLoad)
          .get();
      return NotificationRules.newestFirst(
        mapDocuments(snapshot.docs.map(_entry), notificationFromMap),
      );
    });
  }

  @override
  Stream<List<AppNotification>> watchMine(String recipientId) {
    if (recipientId.isEmpty) {
      return Stream<List<AppNotification>>.value(
        const <AppNotification>[],
      );
    }
    // شرط واحد + ترتيب في العميل (كما في `listMine`): لا فهرس مركّب جديد.
    return _items
        .where('recipientId', isEqualTo: recipientId)
        .limit(NotificationRules.maxPerLoad)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) =>
              NotificationRules.newestFirst(
                mapDocuments(snapshot.docs.map(_entry), notificationFromMap),
              ),
        );
  }

  @override
  Stream<int> watchUnreadCount(String recipientId) {
    if (recipientId.isEmpty) {
      return Stream<int>.value(0);
    }
    // شرطان متساويان ⇒ لا يحتاج فهرسًا مركّبًا (دمج فهارس أحادية).
    return _items
        .where('recipientId', isEqualTo: recipientId)
        .where('readAt', isNull: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) =>
              snapshot.docs.length,
        );
  }

  @override
  Future<void> markRead({
    required String notificationId,
    required String recipientId,
  }) {
    return _guard(() async {
      // حقل واحد فقط (readAt) — القواعد ترفض أي تعديل آخر.
      await _items.doc(notificationId).update(<String, Object?>{
        'readAt': DateTime.now(),
      });
    });
  }

  @override
  Future<void> markAllRead(String recipientId) {
    return _guard(() async {
      if (recipientId.isEmpty) {
        return;
      }
      final QuerySnapshot<Map<String, dynamic>> unread = await _items
          .where('recipientId', isEqualTo: recipientId)
          .where('readAt', isNull: true)
          .get();
      if (unread.docs.isEmpty) {
        return;
      }

      final DateTime now = DateTime.now();
      // دفعات من 400: سقف Firestore 500 عملية في الدفعة الواحدة.
      const int chunk = 400;
      for (int start = 0; start < unread.docs.length; start += chunk) {
        final WriteBatch batch = _firestore.batch();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in unread.docs.skip(start).take(chunk)) {
          batch.update(doc.reference, <String, Object?>{'readAt': now});
        }
        await batch.commit();
      }
    });
  }

  @override
  Future<void> deleteNotification({
    required String notificationId,
    required String recipientId,
  }) {
    return _guard(() async {
      // القواعد تتحقق من المستلم؛ الحذف هنا لا يتجاوزها.
      await _items.doc(notificationId).delete();
    });
  }

  @override
  Future<AppNotification> push({
    required NotificationType type,
    required String recipientId,
    required String actorId,
    required String actorName,
    required String targetId,
    String? title,
    String? body,
  }) {
    return _guard(() async {
      final String cleanActorName = NotificationRules.normalize(
        actorName,
      );
      final String cleanTitle = NotificationRules.normalize(
        title ??
            NotificationRules.titleFor(type: type, actorName: cleanActorName),
      );
      final String? cleanBody = body == null
          ? null
          : NotificationRules.normalize(body);

      final String? problem = NotificationRules.textProblem(
        title: cleanTitle,
        body: cleanBody,
        actorName: cleanActorName,
      );
      if (problem != null) {
        throw AppException(
          AppErrorKind.invalidInput,
          overrideMessage: problem,
          debugMessage: 'invalid notification text',
        );
      }

      final DateTime now = DateTime.now();
      final DocumentReference<Map<String, dynamic>> ref = _items.doc();
      final Map<String, Object?> data = <String, Object?>{
        'recipientId': recipientId,
        'type': type.wireName,
        'actorId': actorId,
        'actorName': cleanActorName,
        'targetId': targetId,
        'title': cleanTitle,
        if (cleanBody != null && cleanBody.isNotEmpty) 'body': cleanBody,
        'createdAt': now,
      };
      await ref.set(data);

      return AppNotification(
        id: ref.id,
        recipientId: recipientId,
        type: type,
        actorId: actorId,
        actorName: cleanActorName,
        targetId: targetId,
        title: cleanTitle,
        body: cleanBody,
        createdAt: now,
      );
    });
  }

  (String, Map<String, Object?>) _entry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => (doc.id, doc.data());
}

/// تقييمات المدرسين على Firestore (P13).
///
/// **لماذا معاملة لا كتابة عادية؟** لأن التقييم والمتوسط يجب أن يتحرّكا معًا:
/// تقييم بلا تراكم يترك متوسطًا كاذبًا، وتراكم بلا تقييم تلاعب. المعاملة تقرأ
/// الحجز والمتوسط الحاليين، ثم تكتب المستندين في **التزام واحد**، والقواعد
/// تقرأ التقييم المنشأ بـ`getAfter` وتقارن به الزيادة (A-85).
class FirestoreReviewRepository implements ReviewRepository {
  FirestoreReviewRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _items =>
      _firestore.collection(FirestoreCollections.reviews);

  CollectionReference<Map<String, dynamic>> get _ratings =>
      _firestore.collection(FirestoreCollections.teacherRatings);

  @override
  Future<List<TeacherReview>> listForTeacher(String teacherId) {
    return _guard(() async {
      if (teacherId.isEmpty) {
        return const <TeacherReview>[];
      }
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _items
          .where('teacherId', isEqualTo: teacherId)
          .limit(50)
          .get();
      return ReviewRules.newestFirst(
        mapDocuments(snapshot.docs.map(_entry), teacherReviewFromMap),
      );
    });
  }

  @override
  Stream<List<TeacherReview>> watchForTeacher(String teacherId) {
    if (teacherId.isEmpty) {
      return Stream<List<TeacherReview>>.value(const <TeacherReview>[]);
    }
    // شرط واحد ⇒ فهرس أحادي، والترتيب في العميل (نفس سياسة P12).
    return _items
        .where('teacherId', isEqualTo: teacherId)
        .limit(50)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) =>
              ReviewRules.newestFirst(
                mapDocuments(snapshot.docs.map(_entry), teacherReviewFromMap),
              ),
        );
  }

  @override
  Future<TeacherRating> ratingFor(String teacherId) {
    return _guard(() async {
      if (teacherId.isEmpty) {
        return TeacherRating.empty(teacherId);
      }
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _ratings
          .doc(teacherId)
          .get();
      final Map<String, Object?>? data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return TeacherRating.empty(teacherId);
      }
      return teacherRatingFromMap(teacherId, data);
    });
  }

  @override
  Stream<TeacherRating> watchRating(String teacherId) {
    if (teacherId.isEmpty) {
      return Stream<TeacherRating>.value(TeacherRating.empty(teacherId));
    }
    return _ratings.doc(teacherId).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, Object?>? data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return TeacherRating.empty(teacherId);
      }
      return teacherRatingFromMap(teacherId, data);
    });
  }

  @override
  Future<TeacherReview?> findForBooking(String bookingId) {
    return _guard(() async {
      if (bookingId.isEmpty) {
        return null;
      }
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _items
          .doc(bookingId)
          .get();
      final Map<String, Object?>? data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return teacherReviewFromMap(bookingId, data);
    });
  }

  @override
  Future<TeacherReview> submit({
    required BookingRequest booking,
    required String studentId,
    required int rating,
    String? comment,
  }) {
    return _guard(() async {
      final String teacherId = booking.teacherId ?? '';
      if (teacherId.isEmpty) {
        throw const AppException.notFound(
          debugMessage: 'booking without teacher id (review)',
          overrideMessage: 'لا يمكن تحديد المدرس من هذا الحجز.',
        );
      }

      final String? cleanComment = comment == null
          ? null
          : ReviewRules.normalize(comment);
      final String trimmedComment = cleanComment ?? '';
      final DateTime now = DateTime.now();

      return _firestore.runTransaction<TeacherReview>((Transaction tx) async {
        final DocumentReference<Map<String, dynamic>> reviewRef = _items.doc(
          booking.id,
        );
        final DocumentReference<Map<String, dynamic>> ratingRef = _ratings.doc(
          teacherId,
        );

        // قراءة طازجة للحجز — لا نثق بالنسخة المعروضة (G7).
        final DocumentReference<Map<String, dynamic>> bookingRef = _firestore
            .collection(FirestoreCollections.bookingRequests)
            .doc(booking.id);
        final DocumentSnapshot<Map<String, dynamic>> bookingSnap = await tx.get(
          bookingRef,
        );
        final Map<String, Object?>? bookingData = bookingSnap.data();
        final BookingRequest fresh = (bookingData == null
                ? null
                : bookingFromMap(booking.id, bookingData)) ??
            booking;

        final DocumentSnapshot<Map<String, dynamic>> reviewSnap = await tx.get(
          reviewRef,
        );

        final String? blocked = ReviewRules.eligibilityProblem(
          booking: fresh,
          studentId: studentId,
          alreadyReviewed: reviewSnap.exists,
        );
        if (blocked != null) {
          throw AppException(
            AppErrorKind.permission,
            overrideMessage: blocked,
            debugMessage: 'review not eligible',
          );
        }

        final String? ratingProblem = ReviewRules.ratingProblem(rating);
        if (ratingProblem != null) {
          throw AppException(
            AppErrorKind.invalidInput,
            overrideMessage: ratingProblem,
            debugMessage: 'invalid rating',
          );
        }
        final String? commentProblem = ReviewRules.commentProblem(
          trimmedComment,
        );
        if (commentProblem != null) {
          throw AppException(
            AppErrorKind.invalidInput,
            overrideMessage: commentProblem,
            debugMessage: 'invalid review comment',
          );
        }

        final DocumentSnapshot<Map<String, dynamic>> ratingSnap = await tx.get(
          ratingRef,
        );
        final Map<String, Object?>? ratingData = ratingSnap.data();
        final TeacherRating current = (ratingData == null)
            ? TeacherRating.empty(teacherId)
            : teacherRatingFromMap(teacherId, ratingData);
        final TeacherRating next = current.plus(rating);

        final TeacherReview review = TeacherReview(
          bookingId: fresh.id,
          teacherId: teacherId,
          studentId: studentId,
          // الاسم منسوخ من الحجز (تقارنه القواعد باسم الحجز حرفيًا).
          studentName: fresh.studentName,
          rating: rating,
          comment: trimmedComment.isEmpty ? null : trimmedComment,
          createdAt: now,
        );

        tx.set(reviewRef, review.toCreateMap());
        tx.set(
          ratingRef,
          next.toMap(lastReviewId: fresh.id, updatedAt: now),
        );
        return review;
      });
    });
  }
}

/// مفضلة الطلاب على Firestore (P13).
///
/// كل استعلام مقيّد بـ`studentId == المستخدم الحالي`، والقواعد تفرض الشيء نفسه،
/// فلا حاجة إلى فهرس مركّب: شرط مساواة واحد.
class FirestoreFavoriteRepository implements FavoriteRepository {
  FirestoreFavoriteRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _items =>
      _firestore.collection(FirestoreCollections.favorites);

  @override
  Future<List<Favorite>> listForStudent(String studentId) {
    return _guard(() async {
      if (studentId.isEmpty) {
        return const <Favorite>[];
      }
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _items
          .where('studentId', isEqualTo: studentId)
          .get();
      return _newestFirst(
        mapDocuments(snapshot.docs.map(_entry), favoriteFromMap),
      );
    });
  }

  @override
  Stream<List<Favorite>> watchForStudent(String studentId) {
    if (studentId.isEmpty) {
      return Stream<List<Favorite>>.value(const <Favorite>[]);
    }
    return _items
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => _newestFirst(
            mapDocuments(snapshot.docs.map(_entry), favoriteFromMap),
          ),
        );
  }

  @override
  Stream<bool> watchIsFavorite({
    required String studentId,
    required FavoriteKind kind,
    required String targetId,
  }) {
    if (studentId.isEmpty || targetId.isEmpty) {
      return Stream<bool>.value(false);
    }
    return _items
        .doc(Favorite.idFor(studentId: studentId, kind: kind, targetId: targetId))
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snapshot) => snapshot.exists);
  }

  @override
  Future<bool> toggle({
    required String studentId,
    required FavoriteKind kind,
    required String targetId,
  }) {
    return _guard(() async {
      if (studentId.isEmpty || targetId.isEmpty) {
        throw const AppException.invalidInput(
          debugMessage: 'favorite without student/target',
          overrideMessage: 'لا يمكن حفظ عنصر بلا معرّف صالح.',
        );
      }
      final DocumentReference<Map<String, dynamic>> ref = _items.doc(
        Favorite.idFor(studentId: studentId, kind: kind, targetId: targetId),
      );
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await ref.get();
      if (snapshot.exists) {
        await ref.delete();
        return false;
      }
      final Favorite favorite = Favorite(
        studentId: studentId,
        kind: kind,
        targetId: targetId,
        createdAt: DateTime.now(),
      );
      await ref.set(favorite.toCreateMap());
      return true;
    });
  }

  List<Favorite> _newestFirst(List<Favorite> favorites) {
    final List<Favorite> sorted = <Favorite>[...favorites];
    sorted.sort((Favorite a, Favorite b) {
      final int byDate = b.createdAt.compareTo(a.createdAt);
      return byDate != 0 ? byDate : a.targetId.compareTo(b.targetId);
    });
    return List<Favorite>.unmodifiable(sorted);
  }
}

/// لوحة الإدارة على Firestore (P14).
///
/// كل كتابة هنا شرطها `request.auth.token.admin == true` في `firestore.rules`
/// (ودور المستخدم في `users/{uid}` لا يمنح شيئًا إضافيًا). أي استدعاء من حساب
/// عادي يعود بـ`permission-denied` ويُترجم إلى رسالة عربية عبر [_guard].
class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection(FirestoreCollections.teacherProfiles);

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection(FirestoreCollections.contentReports);

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection(FirestoreCollections.reviews);

  CollectionReference<Map<String, dynamic>> get _ratings =>
      _firestore.collection(FirestoreCollections.teacherRatings);

  String? get _adminUid => _auth.currentUser?.uid;

  @override
  Future<List<TeacherProfile>> listVerificationQueue() {
    return _guard(() async {
      // شرط واحد على حقل واحد (أحاديّ الفهرسة) ثم ترتيب في العميل.
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _profiles
          .where('status', whereIn: <String>['draft', 'pendingReview'])
          .get();
      return AdminRules.verificationQueue(
        mapDocuments(snapshot.docs.map(_entry), teacherProfileFromMap),
      );
    });
  }

  @override
  Future<List<TeacherProfile>> listAllProfiles() {
    return _guard(() async {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _profiles
          .limit(200)
          .get();
      return mapDocuments(snapshot.docs.map(_entry), teacherProfileFromMap);
    });
  }

  @override
  Future<void> verifyTeacher(String teacherId) {
    return _decide(
      teacherId: teacherId,
      status: TeacherProfileStatus.verified,
    );
  }

  @override
  Future<void> rejectTeacher({
    required String teacherId,
    required String reason,
  }) {
    final String? problem = AdminRules.reasonProblem(reason);
    if (problem != null) {
      return Future<void>.error(
        AppException(
          AppErrorKind.invalidInput,
          overrideMessage: problem,
          debugMessage: 'admin rejection without reason',
        ),
      );
    }
    return _decide(
      teacherId: teacherId,
      status: TeacherProfileStatus.rejected,
      note: reason.trim(),
    );
  }

  /// كتابة القرار: الحالة + وقت المراجعة + هوية المراجع + السبب.
  ///
  /// `reviewNote` تُحذف عند الاعتماد (`FieldValue.delete`) حتى لا يبقى سبب
  /// رفض قديم معلّقًا على ملف صار موثّقًا.
  Future<void> _decide({
    required String teacherId,
    required TeacherProfileStatus status,
    String? note,
  }) {
    return _guard(() async {
      if (teacherId.trim().isEmpty) {
        throw const AppException.invalidInput(
          debugMessage: 'admin decision without teacher id',
          overrideMessage: 'ملف غير معروف.',
        );
      }
      await _profiles.doc(teacherId).update(<String, Object?>{
        'status': status.wireValue,
        // `??` هو الشكل الذي يطلبه المحلّل: قيمة أو حذف الحقل.
        'reviewNote': note ?? FieldValue.delete(),
        'reviewedAt': FieldValue.serverTimestamp(),
        if (_adminUid != null) 'reviewedBy': _adminUid,
      });
    });
  }

  @override
  Future<void> setFeatured({
    required String teacherId,
    required bool isFeatured,
    int order = 0,
  }) {
    return _guard(() async {
      // كتابة حقلي التمييز وحدهما: القواعد تشترط `affectedKeys().hasOnly`
      // عليهما وأن يكون الملف موثّقًا، وترفض أي حقل آخر معهما (P15).
      await _profiles.doc(teacherId).update(<String, Object?>{
        'isFeatured': isFeatured,
        'featuredOrder': isFeatured ? order : 0,
      });
    });
  }

  @override
  Future<List<ContentReport>> listOpenReports() {
    return _guard(() async {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _reports
          .where('status', isEqualTo: ReportStatus.open.wireValue)
          .limit(50)
          .get();
      return AdminRules.newestReportsFirst(
        mapDocuments(snapshot.docs.map(_entry), contentReportFromMap),
      );
    });
  }

  @override
  Future<List<TeacherReview>> listRecentReviews({int limit = 30}) {
    return _guard(() async {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _reviews
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return ReviewRules.newestFirst(
        mapDocuments(snapshot.docs.map(_entry), teacherReviewFromMap),
      );
    });
  }

  @override
  Future<void> resolveReport({
    required String reportId,
    required ReportResolution resolution,
    String? note,
  }) {
    return _guard(() async {
      final String cleanNote = note?.trim() ?? '';
      await _reports.doc(reportId).update(<String, Object?>{
        'status': resolution.wireValue,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolutionNote': cleanNote.isEmpty
            ? FieldValue.delete()
            : cleanNote,
        if (_adminUid != null) 'resolvedBy': _adminUid,
      });
    });
  }

  @override
  Future<void> deleteReview(String reviewId) {
    return _guard(() async {
      // حذف التقييم وتصحيح المجموع في معاملة واحدة: متوسط يقيس تقييمًا
      // محذوفًا أسوأ من عدم وجود تقييم (A-90).
      await _firestore.runTransaction<void>((Transaction tx) async {
        final DocumentReference<Map<String, dynamic>> reviewRef = _reviews.doc(
          reviewId,
        );
        final DocumentSnapshot<Map<String, dynamic>> reviewSnap = await tx.get(
          reviewRef,
        );
        final Map<String, Object?>? reviewData = reviewSnap.data();
        if (reviewData == null) {
          throw const AppException.notFound(
            debugMessage: 'review missing for admin delete',
            overrideMessage: 'التقييم غير موجود أصلًا — حدّث القائمة.',
          );
        }
        final int rating = readInt(reviewData['rating']);
        final String teacherId = readString(reviewData['teacherId']) ?? '';
        if (teacherId.isEmpty) {
          // تقييم بلا مدرس = مستند تالف؛ نحذفه وحده بلا تجميع (لا مسار صالح).
          tx.delete(reviewRef);
          return;
        }

        final DocumentReference<Map<String, dynamic>> ratingRef = _ratings.doc(
          teacherId,
        );
        final DocumentSnapshot<Map<String, dynamic>> ratingSnap = await tx.get(
          ratingRef,
        );
        final Map<String, Object?>? ratingData = ratingSnap.data();

        tx.delete(reviewRef);
        if (ratingData == null) {
          return;
        }
        final TeacherRating current = teacherRatingFromMap(teacherId, ratingData);
        final TeacherRating next = current.minus(rating);
        if (next.totalReviews <= 0) {
          // لا تقييمات متبقية: المستند نفسه يُحذف فلا يبقى صفر مضلّل.
          tx.delete(ratingRef);
          return;
        }
        tx.set(
          ratingRef,
          next.toMap(
            // نبقي شاهد آخر تقييم كما هو: الحذف لا ينشئ تقييمًا جديدًا.
            lastReviewId: readString(ratingData['lastReviewId']) ?? reviewId,
            updatedAt: DateTime.now(),
          ),
        );
      });
    });
  }
}

/// صور الحساب في Firestore (P22).
///
/// **لماذا مستند مستقل `avatars/{uid}`؟** انظر `UserAvatar` والقواعد: الصور
/// تُقرأ فقط عند عرضها، لا في كل تسجيل دخول ولا في كل نتيجة بحث.
///
/// ⚠️ الصورة تُصغَّر وتُضغط على الجهاز **قبل** الوصول إلى هنا (انظر
/// `ImagePickerGateway`)، والسقف هنا خط دفاع ثانٍ برسالة عربية واضحة — لا
/// رسالة Firestore إنجليزية.
class FirestoreAvatarRepository implements AvatarRepository {
  FirestoreAvatarRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collection = 'avatars';

  CollectionReference<Map<String, dynamic>> get _avatars =>
      _firestore.collection(collection);

  @override
  Future<UserAvatar?> getFor(String uid) {
    return _guardAvatar(() async {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _avatars
          .doc(uid)
          .get();
      if (!doc.exists) {
        return null;
      }
      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      // ملاحظة: التصميم الافتراضي (`avatarPreset`) في `users/{uid}` لا هنا —
      // مستند الصورة يخصّ البايتات وحدها، وقواعده ترفض أي حقل آخر.
      return UserAvatar(
        ownerId: uid,
        imageBase64: data['imageBase64'] as String?,
        mimeType: data['mimeType'] as String?,
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
    });
  }

  @override
  Future<UserAvatar> upload({
    required String uid,
    required Uint8List bytes,
    required String mimeType,
  }) {
    return _guardAvatar(() async {
      if (!AvatarLimits.mimeTypes.contains(mimeType)) {
        throw const AppException(
          AppErrorKind.invalidInput,
          overrideTitle: 'صيغة غير مدعومة',
          overrideMessage: 'اختر صورة بصيغة JPG أو PNG.',
          debugMessage: 'unsupported avatar mime type',
        );
      }

      final String encoded = base64Encode(bytes);
      if (encoded.length > AvatarLimits.maxBase64Length) {
        throw const AppException(
          AppErrorKind.invalidInput,
          overrideTitle: 'الصورة كبيرة',
          overrideMessage:
              'حجم الصورة أكبر من المسموح. جرّب صورة أصغر أو أعد التقاطها.',
          debugMessage: 'avatar payload too large',
        );
      }

      await _avatars.doc(uid).set(<String, Object?>{
        'ownerId': uid,
        'imageBase64': encoded,
        'mimeType': mimeType,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // سطر تشخيصي بلا بيانات حسّاسة: الطول والحجم فقط، لا الصورة ولا مقطعًا
      // منها ولا معرّف المستخدم.
      log(
        'avatar upload ok: bytes=${bytes.length} base64=${encoded.length}',
        name: 'avatars',
      );

      return UserAvatar(
        ownerId: uid,
        imageBase64: encoded,
        mimeType: mimeType,
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  Future<void> remove(String uid) {
    return _guardAvatar(() => _avatars.doc(uid).delete());
  }

  @override
  Future<void> ensureDefault(String uid) {
    return _guardAvatar(() async {
      // الرقم يُثبَّت في مستند المستخدم لا هنا: `users/{uid}` هو ما يُقرأ عند
      // الدخول. لو لم يوجد المستند بعد (قبل اختيار الدور) نتركه للحظة
      // الإنشاء، والواجهة تعرض الصورة الحتمية من المعرّف على أي حال.
      final DocumentReference<Map<String, dynamic>> user = _firestore
          .collection('users')
          .doc(uid);
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await user.get();
      if (!snapshot.exists || snapshot.data()?['avatarPreset'] != null) {
        return;
      }
      await user.update(<String, Object?>{
        'avatarPreset': AvatarPresets.forId(uid),
      });
    });
  }

  @override
  Future<void> setPreset({required String uid, required int preset}) {
    return _guardAvatar(() async {
      await _firestore.collection('users').doc(uid).update(
        <String, Object?>{'avatarPreset': AvatarPresets.normalize(preset, uid)},
      );
    });
  }

  /// ترجمة أخطاء Firestore إلى رسائل عربية، مع مهلة زمنية.
  Future<T> _guardAvatar<T>(Future<T> Function() body) async {
    try {
      return await withRequestTimeout(body);
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw firebaseCodeToException(
        error.code,
        debugMessage: error.message,
      );
    }
  }
}

/// صور المحادثة المؤقتة (P24) — `directChats/{chatId}/images/{imageId}`.
///
/// **لماذا مجموعة فرعية لا حقلاً في الرسالة؟** لأن الرسالة تُقرأ في كل فتح
/// للمحادثة، والصورة تُقرأ عند عرضها فقط. والفصل يجعل حذف الصورة بعد خمسة
/// أيام لا يمسّ نص الرسالة ولا ترتيبها.
///
/// **المنع في القواعد لا هنا:** القواعد ترفض قراءة مستند بعد `expiresAt`،
/// وترفض حذف صورة سارية. هذه الطبقة تُترجم ذلك إلى رسالة عربية وتُدير التنظيف
/// التدريجي (حذف المستند لحظة اكتشاف انتهائه).
class FirestoreChatImageRepository implements ChatImageRepository {
  FirestoreChatImageRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _images(String chatId) => _firestore
      .collection(FirestoreCollections.directChats)
      .doc(chatId)
      .collection(FirestoreCollections.directChatImages);

  @override
  Future<ChatImage> upload({
    required String chatId,
    required String senderId,
    required Uint8List bytes,
    required String mimeType,
  }) {
    return _guard(() async {
      if (!ChatImageLimits.mimeTypes.contains(mimeType)) {
        throw const AppException(
          AppErrorKind.invalidInput,
          overrideTitle: 'صيغة غير مدعومة',
          overrideMessage: 'اختر صورة بصيغة JPG أو PNG.',
          debugMessage: 'unsupported chat image mime type',
        );
      }
      final String encoded = base64Encode(bytes);
      if (encoded.length > ChatImageLimits.maxBase64Length) {
        throw const AppException(
          AppErrorKind.invalidInput,
          overrideTitle: 'الصورة كبيرة',
          overrideMessage:
              'حجم الصورة أكبر من المسموح في المحادثة. اختر صورة أصغر.',
          debugMessage: 'chat image payload too large',
        );
      }
      if (encoded.length < ChatImageLimits.minBase64Length) {
        throw const AppException(
          AppErrorKind.invalidInput,
          overrideMessage: 'الصورة غير صالحة. اختر صورة أخرى.',
          debugMessage: 'chat image payload too small',
        );
      }

      final DateTime now = DateTime.now();
      final String imageId = ChatImage.newId(now, senderId: senderId);
      final ChatImage image = ChatImage(
        id: imageId,
        chatId: chatId,
        senderId: senderId,
        bytes: bytes,
        mimeType: mimeType,
        createdAt: now,
        expiresAt: now.add(ChatImageLimits.lifetime),
      );

      await _images(chatId).doc(imageId).set(image.toCreateMap());

      // سطر تشخيصي بلا محتوى الصورة: الحجم والنوع فقط.
      log(
        'chat image upload ok: bytes=${bytes.length} mime=$mimeType',
        name: 'chat-images',
      );
      return image;
    });
  }

  @override
  Future<ChatImage?> findById({
    required String chatId,
    required String imageId,
  }) {
    return _guard(() async {
      final DocumentReference<Map<String, dynamic>> ref = _images(
        chatId,
      ).doc(imageId);
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await ref.get();
      final Map<String, dynamic>? data = snapshot.data();
      if (data == null) {
        return null;
      }
      final DateTime? expiresAt = _toDate(data['expiresAt']);
      final DateTime? createdAt = _toDate(data['createdAt']);
      final Object? raw = data['imageBase64'];
      final String? mimeType = data['mimeType'] as String?;
      if (expiresAt == null ||
          createdAt == null ||
          raw is! String ||
          mimeType == null) {
        return null;
      }

      final ChatImage image = ChatImage(
        id: snapshot.id,
        chatId: chatId,
        senderId: (data['senderId'] as String?) ?? '',
        bytes: base64Decode(raw),
        mimeType: mimeType,
        createdAt: createdAt,
        expiresAt: expiresAt,
      );

      if (image.isExpired()) {
        // تنظيف تدريجي: المستند انتهى، فنحذفه هنا ليتحرر التخزين بدل أن يبقى
        // نسخة لا يمكن قراءتها أصلًا.
        await deleteExpired(chatId: chatId, imageId: imageId);
        return null;
      }
      return image;
    });
  }

  @override
  Future<void> deleteExpired({
    required String chatId,
    required String imageId,
  }) {
    return _guard(
      () => _images(chatId).doc(imageId).delete(),
    );
  }

  static DateTime? _toDate(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return null;
  }
}
