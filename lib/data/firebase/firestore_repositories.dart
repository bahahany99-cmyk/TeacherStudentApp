import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/errors/firebase_error_mapper.dart';
import 'package:teacher_student_app/data/firebase/mappers/firestore_mappers.dart';
import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/booking_repository.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';
import 'package:teacher_student_app/data/services/teacher_repository.dart';
import 'package:teacher_student_app/data/validation/group_rules.dart';
import 'package:teacher_student_app/data/validation/model_validators.dart';

/// أسماء المجموعات في Firestore — مكان واحد، مطابقة لـ`firestore.rules`.
abstract final class FirestoreCollections {
  static const String users = 'users';
  static const String teacherProfiles = 'teacherProfiles';
  static const String studyGroups = 'studyGroups';
  static const String groupMembers = 'members';
  static const String bookingRequests = 'bookingRequests';
}

/// أخطاء Firestore → [AppException] عربية.
///
/// نلتقط `FirebaseException` فقط؛ أي خطأ آخر يبقى كما هو ليُصنَّف «غير متوقع»
/// في `toAppException` بدل أن نُخفيه كخطأ شبكة.
Future<T> _guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on FirebaseException catch (error) {
    throw firebaseCodeToException(error.code, debugMessage: error.message);
  }
}

/// قراءة ملفات المدرسين من `teacherProfiles`.
///
/// ⚠️ الفلترة على `status == 'approved'` مكرّرة هنا **وعلى الخادم** (قواعد
/// Firestore + فهارس). تكرارها في التطبيق ليس إجراءً أمنيًا؛ هو فقط يمنع إرسال
/// بيانات غير لازمة إلى الواجهة، ويجعل الاستعلام قابلاً للفهرسة.
class FirestoreTeacherRepository implements TeacherRepository {
  FirestoreTeacherRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection(FirestoreCollections.teacherProfiles);

  @override
  Future<List<TeacherProfile>> listApproved() {
    return _guard(() async {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _profiles
          .where('status', isEqualTo: 'approved')
          .get();
      return mapDocuments(snapshot.docs.map(_entry), teacherProfileFromMap);
    });
  }

  @override
  Future<List<TeacherProfile>> listFeatured() {
    return _guard(() async {
      // ⚠️ لا ترتيب هنا: آلية اختيار/ترتيب المميزين لم تُحسم (Q-01..Q-03)،
      // فإضافة `orderBy` كانت ستُثبّت قرارًا غير معتمد.
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _profiles
          .where('status', isEqualTo: 'approved')
          .where('isFeatured', isEqualTo: true)
          .get();
      return mapDocuments(snapshot.docs.map(_entry), teacherProfileFromMap);
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

  (String, Map<String, Object?>) _entry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => (doc.id, doc.data());
}

/// قراءة المجموعات وأعضائها.
class FirestoreGroupRepository implements GroupRepository {
  FirestoreGroupRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
        throw const AppException.unknown(
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
        throw const AppException.unknown(
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

  (String, Map<String, Object?>) _entry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => (doc.id, doc.data());
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
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _currentUid =
           currentUid ??
           (() async => (auth ?? FirebaseAuth.instance).currentUser?.uid);

  final FirebaseFirestore _firestore;
  final Future<String?> Function() _currentUid;

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

  (String, Map<String, Object?>) _entry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => (doc.id, doc.data());
}
