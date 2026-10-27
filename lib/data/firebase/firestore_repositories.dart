import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/errors/firebase_error_mapper.dart';
import 'package:teacher_student_app/data/firebase/mappers/firestore_mappers.dart';
import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/group_filter.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/group_message.dart';
import 'package:teacher_student_app/data/models/group_session.dart';
import 'package:teacher_student_app/data/models/group_waitlist_entry.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/booking_repository.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';
import 'package:teacher_student_app/data/services/message_repository.dart';
import 'package:teacher_student_app/data/services/schedule_repository.dart';
import 'package:teacher_student_app/data/services/teacher_repository.dart';
import 'package:teacher_student_app/data/validation/discovery_rules.dart';
import 'package:teacher_student_app/data/validation/group_rules.dart';
import 'package:teacher_student_app/data/validation/join_rules.dart';
import 'package:teacher_student_app/data/validation/message_rules.dart';
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

      return _firestore.runTransaction<GroupJoinRequest>((
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

        final String? reason = JoinRules.requestBlockReason(
          group: current,
          viewerId: studentId,
          existingStatus: existing,
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
        return request;
      });
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

      return _firestore.runTransaction<GroupJoinRequest>((
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
    });
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

        final DateTime now = DateTime.now();
        // الإلغاء يكتب الحالة فقط: القواعد تقبل تغييرًا لا يمسّ بقية الحقول.
        transaction.update(requestRef, <String, Object?>{
          'status': JoinRequestStatus.cancelled.name,
        });
        return current.copyWith(
          status: JoinRequestStatus.cancelled,
          decidedAt: now,
          decidedBy: studentId,
        );
      });
    });
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

      return _firestore.runTransaction<GroupWaitlistEntry>((
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

  /// إزالة عضو (P9): حذف العضوية وإنقاص المقعد **في معاملة واحدة**.
  ///
  /// لو نقص المقعد وحده لبقيت عضوية بلا مقعد، ولو حُذفت العضوية وحدها لبقي
  /// مقعد محسوبًا لغير أحد — وكلاهما يفسد فحص السعة في القبول التالي.

  (String, Map<String, Object?>) _entry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => (doc.id, doc.data());
}
