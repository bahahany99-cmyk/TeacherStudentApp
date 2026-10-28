import 'dart:async';
import 'dart:developer';

import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/group_filter.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/group_message.dart';
import 'package:teacher_student_app/data/models/group_session.dart';
import 'package:teacher_student_app/data/models/group_waitlist_entry.dart';
import 'package:teacher_student_app/data/models/member_move.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/favorite.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/teacher_rating.dart';
import 'package:teacher_student_app/data/models/teacher_review.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';
import 'package:teacher_student_app/data/services/booking_repository.dart';
import 'package:teacher_student_app/data/services/direct_chat_repository.dart';
import 'package:teacher_student_app/data/services/notification_repository.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';
import 'package:teacher_student_app/data/services/message_repository.dart';
import 'package:teacher_student_app/data/services/schedule_repository.dart';
import 'package:teacher_student_app/data/services/favorite_repository.dart';
import 'package:teacher_student_app/data/services/review_repository.dart';
import 'package:teacher_student_app/data/services/teacher_repository.dart';
import 'package:teacher_student_app/data/validation/booking_rules.dart';
import 'package:teacher_student_app/data/validation/direct_chat_rules.dart';
import 'package:teacher_student_app/data/validation/notification_rules.dart';
import 'package:teacher_student_app/data/validation/review_rules.dart';
import 'package:teacher_student_app/data/validation/discovery_rules.dart';
import 'package:teacher_student_app/data/validation/group_rules.dart';
import 'package:teacher_student_app/data/validation/join_rules.dart';
import 'package:teacher_student_app/data/validation/message_rules.dart';
import 'package:teacher_student_app/data/validation/move_rules.dart';
import 'package:teacher_student_app/data/validation/session_rules.dart';
import 'package:teacher_student_app/data/validation/waitlist_rules.dart';
import 'package:teacher_student_app/data/validation/model_validators.dart';

/// تنفيذات تجريبية محلية (بدون Firebase) لعقود طبقة الخدمات.
///
/// الهدف: تشغيل الواجهات والتنقل قبل وجود مشروع Firebase، مع الحفاظ على نفس
/// التوقيعات التي سيستخدمها التنفيذ الحقيقي لاحقًا (Futures).
///
/// كل هذه الملفات تُحذف أو تُعطّل عند تنفيذ Firestore في المراحل القادمة.

class DemoAuthService implements AuthService {
  const DemoAuthService();

  /// رسالة موحّدة: المصادقة الحقيقية تحتاج مشروع Firebase مُهيَّأ.
  static const AppException _notConnected = AppException.unavailable(
    debugMessage: 'Firebase not initialized (demo mode)',
  );

  @override
  Future<AuthResult?> restoreSession() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResult> signInWithGoogle() => throw _notConnected;

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) => throw _notConnected;

  @override
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) => throw _notConnected;

  @override
  Future<AppUser> assignRole({
    required String uid,
    required String displayName,
    required UserRole role,
    String? email,
  }) => throw _notConnected;
}

class DemoTeacherRepository implements TeacherRepository {
  DemoTeacherRepository({List<TeacherProfile>? source})
    : _source = source ?? DemoData.teachers;

  final List<TeacherProfile> _source;

  late final Future<List<TeacherProfile>> _approvedCache =
      Future<List<TeacherProfile>>.value(
        _source
            .where((TeacherProfile t) => t.isVisibleToStudents)
            .toList(growable: false),
      );

  late final Future<List<TeacherProfile>> _featuredCache =
      Future<List<TeacherProfile>>.value(
        _source
            .where(
              (TeacherProfile t) => t.isVisibleToStudents && t.isFeatured,
            )
            .toList(growable: false),
      );

  @override
  Future<List<TeacherProfile>> listApproved() => _approvedCache;

  @override
  Future<List<TeacherProfile>> listFeatured() => _featuredCache;

  @override
  Future<TeacherProfile?> findById(String id) {
    for (final TeacherProfile teacher in _source) {
      // نفس قاعدة الظهور: الملف غير المعتمد لا يُكشف للطلاب.
      if (teacher.id == id && teacher.isVisibleToStudents) {
        return Future<TeacherProfile?>.value(teacher);
      }
    }
    return Future<TeacherProfile?>.value(null);
  }
}

class DemoGroupRepository implements GroupRepository {
  DemoGroupRepository({
    List<StudyGroup>? source,
    NotificationRepository? notifications,
  }) : _groups = <StudyGroup>[...(source ?? DemoData.groups)],
       _notifications = notifications;

  /// اختياري: كاتب الإشعارات (P12) — يُستدعى بعد نجاح الفعل فقط.
  final NotificationRepository? _notifications;

  /// قائمة **قابلة للتغيير** محليًا: تسمح بتجربة الإنشاء والتعديل في وضع
  /// الزائر بلا خادم. تُفقد عند إغلاق التطبيق — وهذا مقصود ومعلن في الشاشة.
  final List<StudyGroup> _groups;

  int _nextId = 1;

  /// طلبات الانضمام المحلية (P8) — تُفقد عند إغلاق التطبيق، مثل بقية الوضع
  /// التجريبي، ويتضح ذلك للمستخدم في الشاشة.
  final List<GroupJoinRequest> _joinRequests = <GroupJoinRequest>[];

  /// أعضاء أُضيفوا فعليًا بالقبول (لا الأعضاء الوهميين المولَّدين من `seatsTaken`).
  final Map<String, List<GroupMember>> _acceptedMembers =
      <String, List<GroupMember>>{};

  /// أعضاء أُزيلوا من العرض التجريبي. لا نحذف من `DemoData` (ثابتة) بل نتخطاهم
  /// عند التوليد، فتبقى الأسماء الأخرى كما هي.
  final Map<String, Set<String>> _removedMemberIds = <String, Set<String>>{};

  /// قائمة الانتظار المحلية (P9) — تُفقد عند إغلاق التطبيق مثل بقية الوضع
  /// التجريبي.
  final List<GroupWaitlistEntry> _waitlist = <GroupWaitlistEntry>[
    ...DemoData.waitlist,
  ];

  /// «قفل» يحاكي ذرّية المعاملة: كل عملية تُغيّر السعة تُنفَّذ بعد انتهاء ما
  /// قبلها بالترتيب. بدون هذا، قراءتان متزامنتان ترى كلتاهما مقعدًا متاحًا
  /// فتُقبلان معًا — وهي المشكلة نفسها التي تحلّها المعاملة في Firestore.
  Future<void> _tail = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final Completer<T> completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  Future<List<StudyGroup>> listDiscoverable() async {
    return List<StudyGroup>.unmodifiable(
      _groups.where((StudyGroup g) => g.isActive),
    );
  }

  @override
  Future<GroupSearchResult> searchDiscoverable(GroupFilter filter) async {
    final List<StudyGroup> active = _groups
        .where((StudyGroup g) => g.isActive)
        .toList(growable: false);
    return DiscoveryRules.search(active, filter);
  }

  @override
  Future<List<StudyGroup>> listForTeacher(String teacherId) async {
    return List<StudyGroup>.unmodifiable(
      _groups.where((StudyGroup g) => g.teacherId == teacherId),
    );
  }

  @override
  Future<StudyGroup?> findById(String id) async {
    for (final StudyGroup group in _groups) {
      if (group.id == id) {
        return group;
      }
    }
    return null;
  }

  @override
  Future<List<GroupMember>> listMembers(String groupId) async {
    final Set<String> removed = _removedMemberIds[groupId] ?? const <String>{};
    final List<GroupMember> accepted = (_acceptedMembers[groupId] ??
            const <GroupMember>[])
        .where((GroupMember m) => !removed.contains(m.id))
        .toList(growable: false);
    final StudyGroup? group = _findGroup(groupId);
    // الأعضاء الوهميون يملؤون ما تبقّى من المقاعد، فلا يتجاوز العدد
    // `seatsTaken` بعد قبول عضو حقيقي في وضع المعاينة.
    final int remaining = group == null
        ? 0
        : group.seatsTaken - accepted.length;
    final int generated = remaining < 0 ? 0 : remaining;
    final List<GroupMember> base = DemoData.membersFor(groupId)
        .where((GroupMember m) => !removed.contains(m.id))
        .toList(growable: false);
    return List<GroupMember>.unmodifiable(<GroupMember>[
      ...accepted,
      if (base.isNotEmpty) ...base.take(generated),
    ]);
  }

  @override
  Future<StudyGroup> createGroup({
    required String teacherId,
    required String teacherName,
    required GroupDraft draft,
  }) async {
    _ensureValid(draft, seatsTaken: 0);

    final StudyGroup group = StudyGroup(
      id: 'demo-new-${_nextId++}',
      teacherId: teacherId,
      teacherName: teacherName,
      title: draft.normalizedTitle,
      subject: draft.normalizedSubject,
      stage: draft.normalizedStage,
      seatsTotal: draft.seatsTotal,
      seatsTaken: 0,
      meetingMode: draft.meetingMode,
      scheduleNote: draft.normalizedScheduleNote,
      isActive: true,
    );
    _groups.add(group);
    return group;
  }

  @override
  Future<StudyGroup> updateGroup({
    required String groupId,
    required String teacherId,
    required GroupDraft draft,
    required bool isActive,
  }) async {
    final int index = _groups.indexWhere((StudyGroup g) => g.id == groupId);
    if (index == -1) {
      throw const AppException.notFound(debugMessage: 'demo group missing');
    }

    final StudyGroup current = _groups[index];
    if (current.teacherId != teacherId) {
      // نفس سلوك القواعد: غير المالك لا يعدّل.
      throw const AppException.permission(debugMessage: 'not group owner');
    }

    _ensureValid(draft, seatsTaken: current.seatsTaken);

    final StudyGroup updated = StudyGroup(
      id: current.id,
      teacherId: current.teacherId,
      teacherName: current.teacherName,
      title: draft.normalizedTitle,
      subject: draft.normalizedSubject,
      stage: draft.normalizedStage,
      seatsTotal: draft.seatsTotal,
      seatsTaken: current.seatsTaken,
      meetingMode: draft.meetingMode,
      scheduleNote: draft.normalizedScheduleNote,
      isActive: isActive,
    );
    _groups[index] = updated;
    return updated;
  }

  /// نفس تحقق القواعد، لكن برسالة عربية مبكرة بدل خطأ شبكة غامض.
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
  Future<bool> isMember({
    required String groupId,
    required String userId,
  }) async {
    final List<GroupMember> members =
        _acceptedMembers[groupId] ?? const <GroupMember>[];
    return members.any((GroupMember m) => m.id == userId);
  }

  // ── P8: طلبات الانضمام ────────────────────────────────────────────────────

  StudyGroup? _findGroup(String groupId) {
    for (final StudyGroup group in _groups) {
      if (group.id == groupId) {
        return group;
      }
    }
    return null;
  }

  GroupJoinRequest? _findRequest(String groupId, String studentId) {
    final String id = GroupJoinRequest.idFor(
      groupId: groupId,
      studentId: studentId,
    );
    for (final GroupJoinRequest request in _joinRequests) {
      if (request.id == id) {
        return request;
      }
    }
    return null;
  }

  @override
  Future<GroupJoinRequest> requestToJoin({
    required StudyGroup group,
    required String studentId,
    required String studentName,
  }) {
    return _serialized(() async {
      final StudyGroup? current = _findGroup(group.id);
      if (current == null) {
        throw const AppException.notFound(debugMessage: 'demo group missing');
      }

      final GroupJoinRequest? existing = _findRequest(group.id, studentId);
      final String? reason = JoinRules.requestBlockReason(
        group: current,
        viewerId: studentId,
        existingStatus: existing?.status,
      );
      if (reason != null) {
        throw AppException(
          AppErrorKind.invalidInput,
          overrideMessage: reason,
          debugMessage: 'join blocked: ${existing?.status.name}',
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

      // إعادة المحاولة بعد رفض/إلغاء تستبدل الطلب القديم بنفس المعرّف.
      _joinRequests.removeWhere((GroupJoinRequest r) => r.id == request.id);
      _joinRequests.add(request);
      return request;
    });
  }

  @override
  Future<GroupJoinRequest?> findMyRequest({
    required String groupId,
    required String studentId,
  }) async => _findRequest(groupId, studentId);

  @override
  Future<List<GroupJoinRequest>> listRequestsForGroup(
    String groupId, {
    String? teacherId,
  }) async {
    final List<GroupJoinRequest> mine = _joinRequests
        .where((GroupJoinRequest r) => r.groupId == groupId)
        .where((GroupJoinRequest r) => teacherId == null || r.teacherId == teacherId)
        .toList(growable: false);
    return List<GroupJoinRequest>.unmodifiable(_sortRequests(mine));
  }

  @override
  Future<List<GroupJoinRequest>> listMyRequests(String studentId) async {
    final List<GroupJoinRequest> mine = _joinRequests
        .where((GroupJoinRequest r) => r.studentId == studentId)
        .toList(growable: false);
    return List<GroupJoinRequest>.unmodifiable(_sortRequests(mine));
  }

  /// المعلّقة أولًا (الأقدم طلبًا أولًا)، ثم المقرَّرة (الأحدث أولًا).
  List<GroupJoinRequest> _sortRequests(List<GroupJoinRequest> requests) {
    final List<GroupJoinRequest> sorted = <GroupJoinRequest>[...requests];
    sorted.sort((GroupJoinRequest a, GroupJoinRequest b) {
      if (a.isPending != b.isPending) {
        return a.isPending ? -1 : 1;
      }
      return a.requestedAt.compareTo(b.requestedAt);
    });
    return sorted;
  }

  @override
  Future<GroupJoinRequest> decideJoinRequest({
    required GroupJoinRequest request,
    required String teacherId,
    required bool approve,
  }) {
    // المعاملة: قراءة المجموعة + الطلب، ثم الكتابة — كلها داخل القفل.
    return _serialized(() async {
      final int groupIndex = _groups.indexWhere(
        (StudyGroup g) => g.id == request.groupId,
      );
      if (groupIndex == -1) {
        throw const AppException.notFound(debugMessage: 'demo group missing');
      }
      final StudyGroup group = _groups[groupIndex];
      if (group.teacherId != teacherId) {
        throw const AppException.permission(debugMessage: 'not group owner');
      }

      final int requestIndex = _joinRequests.indexWhere(
        (GroupJoinRequest r) => r.id == request.id,
      );
      if (requestIndex == -1) {
        throw const AppException.notFound(debugMessage: 'demo request missing');
      }
      final GroupJoinRequest existing = _joinRequests[requestIndex];

      if (!approve) {
        if (!existing.isPending) {
          throw const AppException(
            AppErrorKind.invalidInput,
            overrideMessage: 'هذا الطلب لم يعد معلّقًا.',
          );
        }
        final GroupJoinRequest rejected = existing.copyWith(
          status: JoinRequestStatus.rejected,
          decidedAt: DateTime.now(),
          decidedBy: teacherId,
        );
        _joinRequests[requestIndex] = rejected;
        return rejected;
      }

      // القبول: نفس فحص الدالة النقية على **القراءة الطازجة**.
      final String? reason = JoinRules.acceptBlockReason(
        group: group,
        request: existing,
      );
      if (reason != null) {
        throw AppException(
          AppErrorKind.invalidInput,
          overrideMessage: reason,
          debugMessage: 'accept blocked',
        );
      }

      final DateTime now = DateTime.now();
      _groups[groupIndex] = StudyGroup(
        id: group.id,
        teacherId: group.teacherId,
        teacherName: group.teacherName,
        title: group.title,
        subject: group.subject,
        stage: group.stage,
        seatsTotal: group.seatsTotal,
        seatsTaken: JoinRules.seatsAfterAccept(group.seatsTaken),
        meetingMode: group.meetingMode,
        scheduleNote: group.scheduleNote,
        isActive: group.isActive,
      );

      final GroupJoinRequest accepted = existing.copyWith(
        status: JoinRequestStatus.accepted,
        decidedAt: now,
        decidedBy: teacherId,
      );
      _joinRequests[requestIndex] = accepted;

      final List<GroupMember> members =
          _acceptedMembers[group.id] ?? <GroupMember>[];
      if (!members.any((GroupMember m) => m.id == existing.studentId)) {
        members.add(
          GroupMember(
            id: existing.studentId,
            name: existing.studentName,
            joinedAt: now,
          ),
        );
      }
      _acceptedMembers[group.id] = members;

      return accepted;
    });
  }

  // ── P9: إدارة الأعضاء وقائمة الانتظار ───────────────────────────────────

  /// حذف عضو + إنقاص المقعد في خطوة واحدة — تحاكي معاملة Firestore.
  @override
  Future<StudyGroup> removeMember({
    required String groupId,
    required String memberId,
    required String teacherId,
  }) {
    return _serialized(() async {
      final int index = _groups.indexWhere((StudyGroup g) => g.id == groupId);
      if (index == -1) {
        throw const AppException.notFound(debugMessage: 'demo group missing');
      }
      final StudyGroup group = _groups[index];
      if (group.teacherId != teacherId) {
        throw const AppException.permission(debugMessage: 'not group owner');
      }

      final Set<String> removed = _removedMemberIds.putIfAbsent(
        groupId,
        () => <String>{},
      );
      final List<GroupMember> accepted =
          _acceptedMembers[groupId] ?? <GroupMember>[];
      final bool wasAccepted = accepted.any(
        (GroupMember m) => m.id == memberId,
      );
      final bool wasGenerated = !wasAccepted &&
          DemoData.membersFor(groupId).any(
            (GroupMember m) => m.id == memberId && !removed.contains(m.id),
          );
      if (!wasAccepted && !wasGenerated) {
        throw const AppException.notFound(debugMessage: 'member missing');
      }

      if (wasAccepted) {
        accepted.removeWhere((GroupMember m) => m.id == memberId);
        _acceptedMembers[groupId] = accepted;
      } else {
        removed.add(memberId);
      }

      // المقعد لا يصبح سالبًا مهما تكررت الإزالة.
      final int seatsTaken = group.seatsTaken > 0 ? group.seatsTaken - 1 : 0;
      final StudyGroup updated = _copyWithSeats(group, seatsTaken);
      _groups[index] = updated;
      return updated;
    });
  }

  /// نقل عضو بين مجموعتين — بنفس ضمانات المعاملة في Firestore، بما فيها تنظيف
  /// صفوف الانضمام والانتظار (A-73).
  @override
  Future<MemberMove> moveMember({
    required String memberId,
    required String fromGroupId,
    required String toGroupId,
    required String teacherId,
  }) {
    return _serialized(() async {
      final int fromIndex = _groups.indexWhere(
        (StudyGroup g) => g.id == fromGroupId,
      );
      final int toIndex = _groups.indexWhere(
        (StudyGroup g) => g.id == toGroupId,
      );
      if (fromIndex == -1 || toIndex == -1) {
        throw const AppException.notFound(debugMessage: 'demo group missing');
      }

      final StudyGroup from = _groups[fromIndex];
      final StudyGroup to = _groups[toIndex];
      final DateTime now = DateTime.now();
      if (from.teacherId != teacherId || to.teacherId != teacherId) {
        throw const AppException.permission(debugMessage: 'not group owner');
      }

      // العضو قد يكون مقبولًا فعلًا أو من الأعضاء المولّدين للتجربة.
      final List<GroupMember> fromAccepted =
          _acceptedMembers[from.id] ?? <GroupMember>[];
      GroupMember? member;
      for (final GroupMember candidate in fromAccepted) {
        if (candidate.id == memberId) {
          member = candidate;
          break;
        }
      }
      final Set<String> removedFromSource =
          _removedMemberIds[from.id] ?? <String>{};
      if (member == null) {
        for (final GroupMember candidate in DemoData.membersFor(from.id)) {
          if (candidate.id == memberId &&
              !removedFromSource.contains(candidate.id)) {
            member = candidate;
            break;
          }
        }
      }

      final bool targetHasMember =
          (await listMembers(to.id)).any((GroupMember m) => m.id == memberId);
      final String? reason = MoveRules.blockReason(
        from: from,
        to: to,
        sameOwner: true,
        isMember: member != null,
        targetAlreadyHasMember: targetHasMember,
      );
      if (reason != null) {
        throw AppException(
          AppErrorKind.invalidInput,
          overrideMessage: reason,
          debugMessage: 'move blocked',
        );
      }

      // ── الكتابة «الذرّية»: المصدر والهدف والارتباط معًا ────────────────
      final GroupMember moving = member!;
      if (fromAccepted.any((GroupMember m) => m.id == memberId)) {
        fromAccepted.removeWhere((GroupMember m) => m.id == memberId);
        _acceptedMembers[from.id] = fromAccepted;
      } else {
        _removedMemberIds.putIfAbsent(from.id, () => <String>{}).add(memberId);
      }

      final List<GroupMember> toAccepted =
          _acceptedMembers[to.id] ?? <GroupMember>[];
      toAccepted.add(
        GroupMember(
          id: moving.id,
          name: moving.name,
          // تاريخ الانضمام الأصلي محفوظ: النقل ليس عضوية جديدة.
          joinedAt: moving.joinedAt,
          movedAt: now,
          movedFromGroupTitle: from.title,
        ),
      );
      _acceptedMembers[to.id] = toAccepted;
      // نقل ذهابًا وإيابًا: لو كان العضو قد أُزيل من الهدف سابقًا فلا بد أن
      // يعود للظهور فيه.
      _removedMemberIds[to.id]?.remove(memberId);

      final StudyGroup fromAfter = _copyWithSeats(
        from,
        from.seatsTaken > 0 ? from.seatsTaken - 1 : 0,
      );
      final StudyGroup toAfter = _copyWithSeats(
        to,
        JoinRules.seatsAfterAccept(to.seatsTaken),
      );
      _groups[fromIndex] = fromAfter;
      _groups[toIndex] = toAfter;

      // ── تنظيف صفوف الانضمام/الانتظار (A-73) ────────────────────────────
      // الهدف: إغلاق الصفوف المفتوحة. المصدر: حذف الصفوف التي صارت بلا معنى.
      final bool acceptedRequest = _resolveRequestInTarget(
        groupId: to.id,
        studentId: memberId,
        now: now,
        teacherId: teacherId,
      );
      final bool promotedWaitlist = _resolveWaitlistInTarget(
        groupId: to.id,
        studentId: memberId,
        now: now,
        teacherId: teacherId,
      );
      final int cleared = _clearSourceRecords(from.id, memberId);

      return MemberMove(
        member: moving,
        from: fromAfter,
        to: toAfter,
        acceptedJoinRequest: acceptedRequest,
        promotedWaitlist: promotedWaitlist,
        clearedSourceRecords: cleared,
      );
    });
  }

  @override
  Future<StudyGroup> updateGroupCapacity({
    required String groupId,
    required String teacherId,
    required int seatsTotal,
  }) {
    return _serialized(() async {
      final int index = _groups.indexWhere((StudyGroup g) => g.id == groupId);
      if (index == -1) {
        throw const AppException.notFound(debugMessage: 'demo group missing');
      }
      final StudyGroup group = _groups[index];
      if (group.teacherId != teacherId) {
        throw const AppException.permission(debugMessage: 'not group owner');
      }

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

      final StudyGroup updated = _copyWithSeats(
        group,
        group.seatsTaken,
        seatsTotal: seatsTotal,
      );
      _groups[index] = updated;
      return updated;
    });
  }

  @override
  Future<GroupWaitlistEntry> joinWaitlist({
    required StudyGroup group,
    required String studentId,
    required String studentName,
  }) {
    return _serialized(() async {
      final StudyGroup? current = _findGroup(group.id);
      if (current == null) {
        throw const AppException.notFound(debugMessage: 'demo group missing');
      }
      final GroupWaitlistEntry? existing = _findWaitlistEntry(
        current.id,
        studentId,
      );
      final String? reason = WaitlistRules.joinBlockReason(
        group: current,
        viewerId: studentId,
        existingStatus: existing?.status,
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

      // المغادرة السابقة تُستبدل بصف جديد من تاريخ اليوم.
      _waitlist.removeWhere((GroupWaitlistEntry e) => e.id == entry.id);
      _waitlist.add(entry);
      return entry;
    });
  }

  @override
  Future<GroupWaitlistEntry?> findMyWaitlistEntry({
    required String groupId,
    required String studentId,
  }) async => _findWaitlistEntry(groupId, studentId);

  @override
  Future<List<GroupWaitlistEntry>> listWaitlist(
    String groupId, {
    String? teacherId,
  }) async {
    final List<GroupWaitlistEntry> mine = _waitlist
        .where((GroupWaitlistEntry e) => e.groupId == groupId)
        .where(
          (GroupWaitlistEntry e) =>
              teacherId == null || e.teacherId == teacherId,
        )
        .toList(growable: false);
    return WaitlistRules.ordered(mine);
  }

  @override
  Future<GroupWaitlistEntry> promoteFromWaitlist({
    required GroupWaitlistEntry entry,
    required String teacherId,
  }) {
    // المعاملة: قراءة المجموعة + الصف، ثم قبول مقعد واحد — كله داخل القفل.
    return _serialized(() async {
      final int groupIndex = _groups.indexWhere(
        (StudyGroup g) => g.id == entry.groupId,
      );
      if (groupIndex == -1) {
        throw const AppException.notFound(debugMessage: 'demo group missing');
      }
      final StudyGroup group = _groups[groupIndex];
      if (group.teacherId != teacherId) {
        throw const AppException.permission(debugMessage: 'not group owner');
      }

      final int index = _waitlist.indexWhere(
        (GroupWaitlistEntry e) => e.id == entry.id,
      );
      if (index == -1) {
        throw const AppException.notFound(debugMessage: 'waitlist row missing');
      }
      final GroupWaitlistEntry current = _waitlist[index];

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
      _groups[groupIndex] = _copyWithSeats(
        group,
        JoinRules.seatsAfterAccept(group.seatsTaken),
      );

      final GroupWaitlistEntry promoted = current.copyWith(
        status: WaitlistStatus.promoted,
        decidedAt: now,
        decidedBy: teacherId,
      );
      _waitlist[index] = promoted;

      final List<GroupMember> members =
          _acceptedMembers[group.id] ?? <GroupMember>[];
      if (!members.any((GroupMember m) => m.id == current.studentId)) {
        members.add(
          GroupMember(
            id: current.studentId,
            name: current.studentName,
            joinedAt: now,
          ),
        );
      }
      _acceptedMembers[group.id] = members;

      await _notify(
        type: NotificationType.waitlistPromoted,
        recipientId: promoted.studentId,
        actorId: teacherId,
        actorName: group.teacherName,
        targetId: promoted.groupId,
        body: NotificationRules.bodyFor(
          type: NotificationType.waitlistPromoted,
          actorName: group.teacherName,
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
    return _serialized(() async {
      final int index = _waitlist.indexWhere(
        (GroupWaitlistEntry e) => e.id == entry.id,
      );
      if (index == -1) {
        throw const AppException.notFound(debugMessage: 'waitlist row missing');
      }
      final GroupWaitlistEntry current = _waitlist[index];
      if (current.studentId != studentId) {
        throw const AppException.permission(debugMessage: 'not entry owner');
      }
      if (!current.isWaiting) {
        throw const AppException(
          AppErrorKind.invalidInput,
          overrideMessage: 'هذا الصف لم يعد في قائمة الانتظار.',
        );
      }

      final GroupWaitlistEntry left = current.copyWith(
        status: WaitlistStatus.left,
        decidedAt: DateTime.now(),
        decidedBy: studentId,
      );
      _waitlist[index] = left;
      return left;
    });
  }

  GroupWaitlistEntry? _findWaitlistEntry(String groupId, String studentId) {
    final String id = GroupWaitlistEntry.idFor(
      groupId: groupId,
      studentId: studentId,
    );
    for (final GroupWaitlistEntry entry in _waitlist) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  /// نسخة من المجموعة بمقاعد مشغولة مختلفة — تُستخدم في الإزالة والقبول.
  /// طلب معلّق في المجموعة الهدف ⇒ `accepted` (الطالب صار داخلًا فعلًا).
  bool _resolveRequestInTarget({
    required String groupId,
    required String studentId,
    required DateTime now,
    required String teacherId,
  }) {
    final String id = GroupJoinRequest.idFor(
      groupId: groupId,
      studentId: studentId,
    );
    for (int i = 0; i < _joinRequests.length; i++) {
      if (_joinRequests[i].id != id || !_joinRequests[i].isPending) {
        continue;
      }
      _joinRequests[i] = _joinRequests[i].copyWith(
        status: JoinRequestStatus.accepted,
        decidedAt: now,
        decidedBy: teacherId,
      );
      return true;
    }
    return false;
  }

  /// صف انتظار `waiting` في المجموعة الهدف ⇒ `promoted`.
  bool _resolveWaitlistInTarget({
    required String groupId,
    required String studentId,
    required DateTime now,
    required String teacherId,
  }) {
    final String id = GroupWaitlistEntry.idFor(
      groupId: groupId,
      studentId: studentId,
    );
    for (int i = 0; i < _waitlist.length; i++) {
      if (_waitlist[i].id != id || !_waitlist[i].isWaiting) {
        continue;
      }
      _waitlist[i] = _waitlist[i].copyWith(
        status: WaitlistStatus.promoted,
        decidedAt: now,
        decidedBy: teacherId,
      );
      return true;
    }
    return false;
  }

  /// حذف صفوف المجموعة المصدر التي لم تعد تعبّر عن حالة حقيقية.
  ///
  /// نُبقي السجلات المغلقة (مرفوض/ملغى/غادر) لأنها تاريخ، ونحذف فقط ما يظهر
  /// كحالة قائمة: طلب `pending`/`accepted` لم يعد عضوًا، وانتظار
  /// `waiting`/`promoted` لطالب خارج المجموعة.
  int _clearSourceRecords(String groupId, String studentId) {
    final String requestId = GroupJoinRequest.idFor(
      groupId: groupId,
      studentId: studentId,
    );
    final String waitlistId = GroupWaitlistEntry.idFor(
      groupId: groupId,
      studentId: studentId,
    );

    final int before = _joinRequests.length + _waitlist.length;
    _joinRequests.removeWhere(
      (GroupJoinRequest r) =>
          r.id == requestId &&
          (r.status == JoinRequestStatus.pending ||
              r.status == JoinRequestStatus.accepted),
    );
    _waitlist.removeWhere(
      (GroupWaitlistEntry e) =>
          e.id == waitlistId &&
          (e.status == WaitlistStatus.waiting ||
              e.status == WaitlistStatus.promoted),
    );
    return before - (_joinRequests.length + _waitlist.length);
  }

  StudyGroup _copyWithSeats(StudyGroup group, int seatsTaken, {int? seatsTotal}) {
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

  @override
  Future<GroupJoinRequest> cancelJoinRequest({
    required GroupJoinRequest request,
    required String studentId,
  }) {
    return _serialized(() async {
      final int index = _joinRequests.indexWhere(
        (GroupJoinRequest r) => r.id == request.id,
      );
      if (index == -1) {
        throw const AppException.notFound(debugMessage: 'demo request missing');
      }
      final GroupJoinRequest existing = _joinRequests[index];
      if (existing.studentId != studentId) {
        throw const AppException.permission(debugMessage: 'not request owner');
      }
      if (!existing.isPending) {
        throw const AppException(
          AppErrorKind.invalidInput,
          overrideMessage: 'لا يمكن إلغاء طلب تم البتّ فيه.',
        );
      }

      final GroupJoinRequest cancelled = existing.copyWith(
        status: JoinRequestStatus.cancelled,
        decidedAt: DateTime.now(),
        decidedBy: studentId,
      );
      _joinRequests[index] = cancelled;
      return cancelled;
    });
  }

  /// ينشئ إشعارًا «بأفضل جهد» (P12): فشله لا يُفشل الفعل الأصلي.
  Future<void> _notify({
    required NotificationType type,
    required String recipientId,
    required String actorId,
    required String actorName,
    required String targetId,
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
        body: body,
      );
    } on Object catch (error) {
      // الإشعار إضافة: لا نُسقط نجاح الحجز/الرسالة بسببه.
      log('demo notification push failed', name: 'notifications', error: error);
    }
  }


}

/// محادثة المجموعة في وضع الزائر (P9): قائمة في الذاكرة تُفقد عند الإغلاق.
class DemoMessageRepository implements MessageRepository {
  DemoMessageRepository({List<GroupMessage>? source})
    : _messages = <GroupMessage>[...(source ?? DemoData.messages)];

  final List<GroupMessage> _messages;

  int _nextId = 1;

  @override
  Future<List<GroupMessage>> listForGroup(String groupId) async {
    final List<GroupMessage> mine = _messages
        .where((GroupMessage m) => m.groupId == groupId)
        .toList(growable: false);
    // الأقدم أولًا (الواجهة تعرضها مقلوبة)، والترتيب ثابت عند تساوي الوقت.
    mine.sort((GroupMessage a, GroupMessage b) {
      final int byTime = a.sentAt.compareTo(b.sentAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return List<GroupMessage>.unmodifiable(mine);
  }

  @override
  Future<GroupMessage> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required UserRole senderRole,
    required String text,
  }) async {
    final ValidationResult valid = MessageRules.validate(text);
    if (!valid.isValid) {
      throw AppException(
        AppErrorKind.invalidInput,
        overrideMessage: valid.problems.first.issue == FieldIssue.tooLong
            ? 'الرسالة أطول من ${MessageRules.maxLength} حرفًا.'
            : 'لا يمكن إرسال رسالة فارغة.',
        debugMessage: 'invalid message',
      );
    }

    final GroupMessage message = GroupMessage(
      id: 'demo-message-${_nextId++}',
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      text: MessageRules.normalize(text),
      sentAt: DateTime.now(),
    );
    _messages.add(message);
    return message;
  }
}

class DemoBookingRepository implements BookingRepository {
  DemoBookingRepository({
    List<BookingRequest>? source,
    NotificationRepository? notifications,
  }) : _bookings = <BookingRequest>[...(source ?? DemoData.bookings)],
       _notifications = notifications;

  /// اختياري: كاتب الإشعارات (P12).
  final NotificationRepository? _notifications;

  /// قائمة **قابلة للتغيير** محليًا: تسمح بتجربة الحجز والقبول في وضع الزائر
  /// بلا خادم. تُفقد عند إغلاق التطبيق مثل بقية الوضع التجريبي (P10).
  final List<BookingRequest> _bookings;

  int _nextId = 1;

  /// «قفل» يحاكي ذرّية المعاملة: كل قرار يقرأ التقويم ويكتبه بالترتيب، فلا
  /// يقبل قراران متزامنان موعدين متقاطعين — نفس دور مستند التقويم اليومي في
  /// Firestore (A-76).
  Future<void> _tail = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final Completer<T> completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  List<BookingRequest> _sorted() {
    final List<BookingRequest> all = <BookingRequest>[..._bookings];
    all.sort((BookingRequest a, BookingRequest b) {
      final DateTime? left = a.startsAt;
      final DateTime? right = b.startsAt;
      if (left != null && right != null && left != right) {
        return right.compareTo(left);
      }
      if (left != null && right == null) {
        return -1;
      }
      if (left == null && right != null) {
        return 1;
      }
      return b.requestedAt.compareTo(a.requestedAt);
    });
    return all;
  }

  BookingRequest? _find(String id) {
    for (final BookingRequest booking in _bookings) {
      if (booking.id == id) {
        return booking;
      }
    }
    return null;
  }

  void _replace(BookingRequest updated) {
    final int index = _bookings.indexWhere(
      (BookingRequest b) => b.id == updated.id,
    );
    if (index != -1) {
      _bookings[index] = updated;
    }
  }

  /// كل الحجوزات المؤكدة لمدرس — هي وحدها ما يشغل وقته.
  List<BookingRequest> _acceptedFor(String teacherId) => _bookings
      .where(
        (BookingRequest b) => b.teacherId == teacherId && b.status.holdsSlot,
      )
      .toList(growable: false);

  /// يرفع خطأ التعارض إن كان الموعد مشغولًا (مع تجاهل الطلب نفسه).
  void _ensureNoConflict({
    required String teacherId,
    required DateTime startsAt,
    required int durationMinutes,
    required String bookingId,
  }) {
    final BookingRequest? conflict = BookingRules.findConflict(
      start: startsAt,
      durationMinutes: durationMinutes,
      existing: _acceptedFor(teacherId),
      ignoreId: bookingId,
    );
    if (conflict != null) {
      throw const AppException(
        AppErrorKind.invalidInput,
        overrideMessage: BookingRules.conflictMessage,
        debugMessage: 'booking conflict',
      );
    }
  }

  void _ensureSlot({
    required DateTime startsAt,
    required int durationMinutes,
    required DateTime now,
  }) {
    final String? reason = BookingRules.slotBlockReason(
      startsAt: startsAt,
      durationMinutes: durationMinutes,
      now: now,
    );
    if (reason != null) {
      throw AppException(
        AppErrorKind.invalidInput,
        overrideMessage: reason,
        debugMessage: 'invalid booking slot',
      );
    }
  }

  @override
  Future<List<BookingRequest>> listMine() async =>
      List<BookingRequest>.unmodifiable(_sorted());

  @override
  Future<BookingRequest?> findById(String id) async => _find(id);

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
    return _serialized(() async {
      final DateTime now = DateTime.now();
      _ensureSlot(startsAt: startsAt, durationMinutes: durationMinutes, now: now);

      final String trimmedSubject = subject.trim();
      if (trimmedSubject.length < 3) {
        throw const AppException.invalidInput(
          overrideMessage: 'اكتب مادة الحصة (3 أحرف على الأقل).',
        );
      }
      final String? cleanNote = note?.trim();
      if (cleanNote != null && cleanNote.length > BookingRules.noteMax) {
        throw AppException.invalidInput(
          overrideMessage:
              'الملاحظة أطول من ${BookingRules.noteMax} حرفًا.',
        );
      }

      _ensureNoConflict(
        teacherId: teacherId,
        startsAt: startsAt,
        durationMinutes: durationMinutes,
        bookingId: '',
      );

      final BookingRequest request = BookingRequest(
        id: 'demo-booking-new-${_nextId++}',
        teacherId: teacherId,
        teacherName: teacherName,
        studentId: studentId,
        studentName: studentName,
        subject: trimmedSubject,
        requestedAt: now,
        status: BookingStatus.pending,
        note: cleanNote == null || cleanNote.isEmpty ? null : cleanNote,
        dateKey: BookingRulesLite.keyOf(startsAt),
        startMinutes: BookingRulesLite.minutesOf(startsAt),
        durationMinutes: durationMinutes,
      );
      _bookings.add(request);
      await _notify(
        type: NotificationType.bookingRequested,
        recipientId: teacherId,
        actorId: studentId,
        actorName: studentName,
        targetId: request.id,
        body: NotificationRules.bodyFor(
          type: NotificationType.bookingRequested,
          actorName: studentName,
          subject: request.subject,
        ),
      );
      return request;
    });
  }

  @override
  Future<BookingRequest> decideRequest({
    required BookingRequest request,
    required String teacherId,
    required bool approve,
  }) {
    return _serialized(() async {
      final BookingRequest current = _require(request.id);
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
      if (current.teacherId != teacherId) {
        throw const AppException.permission(debugMessage: 'not teacher');
      }

      if (!approve) {
        final BookingRequest rejected = current.copyWith(
          status: BookingStatus.rejected,
          decidedAt: now,
          decidedBy: teacherId,
        );
        _replace(rejected);
        await _notify(
          type: NotificationType.bookingRejected,
          recipientId: rejected.studentId ?? '',
          actorId: teacherId,
          actorName: rejected.teacherName,
          targetId: rejected.id,
          body: NotificationRules.bodyFor(
            type: NotificationType.bookingRejected,
            actorName: rejected.teacherName,
          ),
        );
        return rejected;
      }

      // قبول اقتراح الطالب يعني اعتماد موعده المقترح.
      final BookingRequest accepted = current.status.isReschedule
          ? current.applyingProposal(now, teacherId)
          : current.copyWith(
              status: BookingStatus.accepted,
              decidedAt: now,
              decidedBy: teacherId,
            );
      final DateTime? start = accepted.startsAt;
      if (start == null) {
        throw const AppException.invalidInput(
          overrideMessage: 'الطلب بلا موعد محدد.',
        );
      }
      _ensureNoConflict(
        teacherId: teacherId,
        startsAt: start,
        durationMinutes: accepted.durationMinutes ?? 60,
        bookingId: accepted.id,
      );

      _replace(accepted);
      await _notify(
        type: NotificationType.bookingAccepted,
        recipientId: accepted.studentId ?? '',
        actorId: teacherId,
        actorName: accepted.teacherName,
        targetId: accepted.id,
        body: NotificationRules.bodyFor(
          type: NotificationType.bookingAccepted,
          actorName: accepted.teacherName,
          slotLabel: BookingRules.slotLabel(accepted),
        ),
      );
      return accepted;
    });
  }

  @override
  Future<BookingRequest> cancelRequest({
    required BookingRequest request,
    required String actorId,
    required bool byTeacher,
  }) {
    return _serialized(() async {
      final BookingRequest current = _require(request.id);
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

      final BookingRequest cancelled = current.copyWith(
        status: BookingRules.cancelStatus(booking: current, now: now),
        cancelledAt: now,
        cancelledBy: actorId,
      );
      _replace(cancelled);
      return cancelled;
    });
  }

  @override
  Future<BookingRequest> proposeReschedule({
    required BookingRequest request,
    required String actorId,
    required bool byTeacher,
    required DateTime startsAt,
  }) {
    return _serialized(() async {
      final BookingRequest current = _require(request.id);
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
      _ensureSlot(
        startsAt: startsAt,
        durationMinutes: current.durationMinutes ?? 60,
        now: now,
      );

      final BookingRequest proposed = current.copyWith(
        status: BookingStatus.rescheduleProposed,
        proposalDateKey: BookingRulesLite.keyOf(startsAt),
        proposalStartMinutes: BookingRulesLite.minutesOf(startsAt),
        proposedBy: byTeacher ? BookingActor.teacher : BookingActor.student,
        proposedAt: now,
      );
      _replace(proposed);
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
    return _serialized(() async {
      final BookingRequest current = _require(request.id);
      final DateTime now = DateTime.now();

      if (!accept) {
        // رفض الوقت البديل يُنهي الطلب: لا موعد متفق عليه بين الطرفين.
        final BookingRequest rejected = current.copyWith(
          status: BookingStatus.rejected,
          decidedAt: now,
          decidedBy: actorId,
        );
        _replace(rejected);
        await _notify(
          type: NotificationType.bookingRejected,
          recipientId: byTeacher
              ? (rejected.studentId ?? '')
              : (rejected.teacherId ?? ''),
          actorId: actorId,
          actorName: byTeacher ? rejected.teacherName : rejected.studentName,
          targetId: rejected.id,
          body: NotificationRules.bodyFor(
            type: NotificationType.bookingRejected,
            actorName: byTeacher ? rejected.teacherName : rejected.studentName,
          ),
        );
        return rejected;
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

      final BookingRequest accepted = current.applyingProposal(now, actorId);
      final DateTime? start = accepted.startsAt;
      if (start == null) {
        throw const AppException.invalidInput(
          overrideMessage: 'الاقتراح بلا موعد محدد.',
        );
      }
      _ensureNoConflict(
        teacherId: accepted.teacherId ?? '',
        startsAt: start,
        durationMinutes: accepted.durationMinutes ?? 60,
        bookingId: accepted.id,
      );
      _replace(accepted);
      await _notify(
        type: NotificationType.bookingAccepted,
        recipientId: byTeacher
            ? (accepted.studentId ?? '')
            : (accepted.teacherId ?? ''),
        actorId: actorId,
        actorName: byTeacher ? accepted.teacherName : accepted.studentName,
        targetId: accepted.id,
        body: NotificationRules.bodyFor(
          type: NotificationType.bookingAccepted,
          actorName: byTeacher ? accepted.teacherName : accepted.studentName,
          slotLabel: BookingRules.slotLabel(accepted),
        ),
      );
      return accepted;
    });
  }

  @override
  Future<BookingRequest> completeRequest({
    required BookingRequest request,
    required String teacherId,
  }) {
    return _serialized(() async {
      final BookingRequest current = _require(request.id);
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

      final BookingRequest completed = current.copyWith(
        status: BookingStatus.completed,
        decidedAt: now,
        decidedBy: teacherId,
      );
      _replace(completed);
      return completed;
    });
  }

  BookingRequest _require(String id) {
    final BookingRequest? booking = _find(id);
    if (booking == null) {
      throw const AppException.notFound(debugMessage: 'demo booking missing');
    }
    return booking;
  }

  /// ينشئ إشعارًا «بأفضل جهد» (P12): فشله لا يُفشل الفعل الأصلي.
  Future<void> _notify({
    required NotificationType type,
    required String recipientId,
    required String actorId,
    required String actorName,
    required String targetId,
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
        body: body,
      );
    } on Object catch (error) {
      // الإشعار إضافة: لا نُسقط نجاح الحجز/الرسالة بسببه.
      log('demo notification push failed', name: 'notifications', error: error);
    }
  }


}

/// الجدول الأسبوعي في وضع الزائر (P9).
///
/// مستودع مستقل عن `DemoGroupRepository` حتى تبقى العقود منفصلة كما في
/// Firestore (مجموعة فرعية `sessions`)، لكنه يحمل نفس بيانات العرض.
class DemoScheduleRepository implements ScheduleRepository {
  DemoScheduleRepository({List<GroupSession>? source})
    : _sessions = <GroupSession>[...(source ?? DemoData.sessions)];

  final List<GroupSession> _sessions;

  int _nextId = 1;

  List<GroupSession> _of(String groupId) => _sessions
      .where((GroupSession s) => s.groupId == groupId)
      .toList(growable: false);

  @override
  Future<List<GroupSession>> listForGroup(String groupId) async {
    return List<GroupSession>.unmodifiable(SessionRules.sorted(_of(groupId)));
  }

  @override
  Future<GroupSession> createSession({
    required String groupId,
    required String teacherId,
    required SessionDraft draft,
  }) async {
    final ValidationResult valid = SessionRules.validateDraft(
      draft,
      existing: _of(groupId),
    );
    if (!valid.isValid) {
      throw AppException(
        AppErrorKind.invalidInput,
        overrideMessage: _draftMessage(draft, groupId, valid),
        debugMessage: 'invalid session draft',
      );
    }

    final GroupSession session = GroupSession(
      id: 'demo-session-new-${_nextId++}',
      groupId: groupId,
      teacherId: teacherId,
      title: draft.normalizedTitle,
      weekday: draft.weekday,
      startMinutes: draft.startMinutes,
      durationMinutes: draft.durationMinutes,
      locationNote: draft.normalizedLocation,
    );
    _sessions.add(session);
    return session;
  }

  @override
  Future<GroupSession> updateSession({
    required GroupSession session,
    required String teacherId,
    required SessionDraft draft,
  }) async {
    final int index = _sessions.indexWhere(
      (GroupSession s) => s.id == session.id,
    );
    if (index == -1) {
      throw const AppException.notFound(debugMessage: 'demo session missing');
    }
    if (_sessions[index].teacherId != teacherId) {
      throw const AppException.permission(debugMessage: 'not group owner');
    }

    final ValidationResult valid = SessionRules.validateDraft(
      draft,
      existing: _of(session.groupId),
      ignoreSessionId: session.id,
    );
    if (!valid.isValid) {
      throw AppException(
        AppErrorKind.invalidInput,
        overrideMessage: _draftMessage(draft, session.groupId, valid),
        debugMessage: 'invalid session draft',
      );
    }

    final GroupSession updated = _sessions[index].copyWith(
      title: draft.normalizedTitle,
      weekday: draft.weekday,
      startMinutes: draft.startMinutes,
      durationMinutes: draft.durationMinutes,
      locationNote: draft.normalizedLocation,
    );
    _sessions[index] = updated;
    return updated;
  }

  @override
  Future<GroupSession> setCancelled({
    required GroupSession session,
    required String teacherId,
    required bool isCancelled,
  }) async {
    final int index = _sessions.indexWhere(
      (GroupSession s) => s.id == session.id,
    );
    if (index == -1) {
      throw const AppException.notFound(debugMessage: 'demo session missing');
    }
    if (_sessions[index].teacherId != teacherId) {
      throw const AppException.permission(debugMessage: 'not group owner');
    }
    final GroupSession updated = _sessions[index].copyWith(
      isCancelled: isCancelled,
    );
    _sessions[index] = updated;
    return updated;
  }

  /// رسالة التداخل أهم من رسالة النطاق لأنها الأكثر حدوثًا في الاستخدام.
  String? _draftMessage(
    SessionDraft draft,
    String groupId,
    ValidationResult result,
  ) {
    final String? conflict = SessionRules.conflictMessage(
      draft,
      _of(groupId),
      ignoreSessionId: null,
    );
    return conflict ?? result.firstMessage;
  }
}

/// محادثات مباشرة في وضع الزائر (P11).
///
/// تُنفّذ **نفس** شروط القواعد محليًا (الأصل الموثّق، منع غير الطرفين، إيقاف
/// الإرسال عند رفض الحجز أو إطفاء استقبال الرسائل)، لأن الوضع التجريبي بلا خادم:
/// لو اكتفينا بالواجهة لاختلف سلوك المعاينة عن الإنتاج.
///
/// البثّ: مشغّل لكل محادثة مفتوحة ([watchMessages])، ويُغلق مع التطبيق.
class DemoDirectChatRepository implements DirectChatRepository {
  DemoDirectChatRepository({
    List<DirectChat>? source,
    List<DirectChatMessage>? messages,
    Map<String, bool>? settings,
    NotificationRepository? notifications,
    Future<BookingRequest?> Function(String id)? findBooking,
    Future<bool> Function({required String groupId, required String userId})?
    isMember,
  }) : _chats = <DirectChat>[...(source ?? DemoData.directChats)],
       _messages = <DirectChatMessage>[...(messages ?? DemoData.directMessages)],
       _settings = <String, bool>{
         ...DemoData.directMessageSettings,
         ...?settings,
       },
       _findBooking = findBooking,
       _isMember = isMember,
       _notifications = notifications;

  final List<DirectChat> _chats;
  final List<DirectChatMessage> _messages;
  final Map<String, bool> _settings;

  /// ربط اختياري بمستودع الحجوزات: يجعل «الأصل الموثّق» حقيقيًا لا توقيعًا.
  final Future<BookingRequest?> Function(String id)? _findBooking;
  final Future<bool> Function({required String groupId, required String userId})?
  _isMember;

  /// اختياري: كاتب الإشعارات (P12) — يُخطر الطرف الآخر بالرسائل.
  final NotificationRepository? _notifications;

  final Map<String, StreamController<List<DirectChatMessage>>> _streams =
      <String, StreamController<List<DirectChatMessage>>>{};
  final Map<String, StreamController<DirectChat?>> _chatStreams =
      <String, StreamController<DirectChat?>>{};
  int _nextMessageId = 1;

  StreamController<DirectChat?> _chatStreamFor(String chatId) {
    return _chatStreams.putIfAbsent(
      chatId,
      () => StreamController<DirectChat?>.broadcast(),
    );
  }

  void _publishChat(String chatId) {
    _chatStreamFor(chatId).add(_find(chatId));
  }

  StreamController<List<DirectChatMessage>> _streamFor(String chatId) {
    return _streams.putIfAbsent(
      chatId,
      () => StreamController<List<DirectChatMessage>>.broadcast(),
    );
  }

  List<DirectChatMessage> _messagesOf(String chatId) {
    final List<DirectChatMessage> mine = _messages
        .where((DirectChatMessage m) => m.chatId == chatId)
        .toList(growable: false)
      ..sort((DirectChatMessage a, DirectChatMessage b) {
        final int byTime = a.sentAt.compareTo(b.sentAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return List<DirectChatMessage>.unmodifiable(mine);
  }

  DirectChat? _find(String chatId) {
    for (final DirectChat chat in _chats) {
      if (chat.id == chatId) {
        return chat;
      }
    }
    return null;
  }

  int _indexOf(String chatId) =>
      _chats.indexWhere((DirectChat chat) => chat.id == chatId);

  void _replace(DirectChat chat) {
    final int index = _indexOf(chat.id);
    if (index >= 0) {
      _chats[index] = chat;
    }
  }

  @override
  Future<DirectChat?> findById(String chatId) async => _find(chatId);

  @override
  Future<List<DirectChat>> listMine(String viewerId) async {
    final List<DirectChat> mine = _chats
        .where((DirectChat chat) => chat.involves(viewerId))
        .toList(growable: false)
      ..sort((DirectChat a, DirectChat b) {
        final DateTime left = a.lastMessageAt ?? a.createdAt;
        final DateTime right = b.lastMessageAt ?? b.createdAt;
        return right.compareTo(left);
      });
    return List<DirectChat>.unmodifiable(mine);
  }

  @override
  Stream<List<DirectChatMessage>> watchMessages(String chatId) async* {
    yield _messagesOf(chatId);
    yield* _streamFor(chatId).stream;
  }

  @override
  Stream<DirectChat?> watchChat(String chatId) async* {
    yield _find(chatId);
    yield* _chatStreamFor(chatId).stream;
  }

  @override
  Future<bool> allowDirectMessages(String teacherId) async =>
      _settings[teacherId] ?? DirectChatRules.defaultAllowDirectMessages;

  @override
  Future<void> setAllowDirectMessages({
    required String teacherId,
    required bool allow,
  }) async {
    _settings[teacherId] = allow;
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
  }) async {
    final String chatId = DirectChat.idFor(
      teacherId: teacherId,
      studentId: studentId,
    );
    final DirectChat? existing = _find(chatId);
    if (existing != null) {
      return existing;
    }

    switch (origin) {
      case DirectChatOrigin.booking:
        if (bookingId == null || bookingId.trim().isEmpty) {
          throw const AppException.invalidInput(
            debugMessage: 'booking-origin chat without bookingId',
            overrideMessage: 'المحادثة المرتبطة بحجز تحتاج رقم الحجز.',
          );
        }
        final BookingRequest? booking = await _findBooking?.call(bookingId);
        if (_findBooking != null) {
          if (booking == null) {
            throw const AppException.notFound(
              debugMessage: 'booking missing',
              overrideMessage: 'لا يوجد حجز بهذا الرقم.',
            );
          }
          if (booking.teacherId != teacherId ||
              booking.studentId != studentId) {
            throw const AppException.permission(
              debugMessage: 'booking does not belong to both parties',
              overrideMessage: 'هذا الحجز لا يخصّكما معًا.',
            );
          }
        }
      case DirectChatOrigin.group:
        if (groupId == null || groupId.trim().isEmpty) {
          throw const AppException.invalidInput(
            debugMessage: 'group-origin chat without groupId',
            overrideMessage: 'المحادثة المرتبطة بمجموعة تحتاج رقم المجموعة.',
          );
        }
        final bool member =
            await _isMember?.call(groupId: groupId, userId: studentId) ?? false;
        if (_isMember != null && !member) {
          throw const AppException.permission(
            debugMessage: 'not a group member',
            overrideMessage: 'المحادثة متاحة لأعضاء المجموعة فقط.',
          );
        }
      case DirectChatOrigin.inquiry:
        if (!await allowDirectMessages(teacherId)) {
          throw AppException(
            AppErrorKind.permission,
            overrideMessage: DirectChatRules.startBlockedReason(
              viewerId: studentId,
              hasBooking: false,
              isGroupMember: false,
              allowDirectMessages: false,
            ),
            debugMessage: 'inquiry not allowed',
          );
        }
    }

    final DirectChat chat = DirectChat(
      id: chatId,
      teacherId: teacherId,
      teacherName: teacherName,
      studentId: studentId,
      studentName: studentName,
      subject: subject,
      origin: origin,
      bookingId: origin == DirectChatOrigin.booking ? bookingId : null,
      groupId: origin == DirectChatOrigin.group ? groupId : null,
      createdAt: DateTime.now(),
    );
    _chats.add(chat);
    _publishChat(chatId);
    return chat;
  }

  Future<bool> _bookingRejected(DirectChat chat) async {
    final String? bookingId = chat.bookingId;
    if (bookingId == null) {
      return false;
    }
    final BookingRequest? booking = await _findBooking?.call(bookingId);
    return booking?.status == BookingStatus.rejected;
  }

  @override
  Future<DirectChatMessage> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required UserRole senderRole,
    required String text,
  }) async {
    final DirectChat? chat = _find(chatId);
    if (chat == null) {
      throw const AppException.notFound(
        debugMessage: 'chat missing',
        overrideMessage: 'المحادثة غير موجودة.',
      );
    }

    final ValidationResult valid = MessageRules.validate(text);
    if (!valid.isValid) {
      throw AppException(
        AppErrorKind.invalidInput,
        overrideMessage: valid.problems.first.issue == FieldIssue.tooLong
            ? 'الرسالة أطول من ${DirectChatRules.maxLength} حرفًا.'
            : 'لا يمكن إرسال رسالة فارغة.',
        debugMessage: 'invalid message',
      );
    }

    final bool allowed = await allowDirectMessages(chat.teacherId);
    final String? blocked = DirectChatRules.sendBlockedReason(
      chat: chat,
      viewerId: senderId,
      allowDirectMessages: allowed,
      bookingRejected: await _bookingRejected(chat),
    );
    if (blocked != null) {
      throw AppException(
        AppErrorKind.permission,
        overrideMessage: blocked,
        debugMessage: 'send blocked',
      );
    }

    final DirectChatMessage message = DirectChatMessage(
      id: 'demo-direct-message-${100 + _nextMessageId++}',
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      text: MessageRules.normalize(text),
      sentAt: DateTime.now(),
    );
    _messages.add(message);
    _replace(
      chat.copyWith(
        lastMessageAt: message.sentAt,
        lastMessageText: message.text,
        lastSenderId: senderId,
      ),
    );
    _streamFor(chatId).add(_messagesOf(chatId));
    _publishChat(chatId);
    await _notify(
      type: NotificationType.directMessage,
      recipientId: chat.isTeacherViewer(senderId)
          ? chat.studentId
          : chat.teacherId,
      actorId: senderId,
      actorName: senderName,
      targetId: chatId,
      body: NotificationRules.bodyFor(
        type: NotificationType.directMessage,
        actorName: senderName,
      ),
    );
    return message;
  }

  @override
  Future<void> markRead({
    required String chatId,
    required String viewerId,
    required DateTime at,
  }) async {
    final DirectChat? chat = _find(chatId);
    if (chat == null || !chat.involves(viewerId)) {
      return;
    }
    final DateTime? current = chat.lastReadAtFor(viewerId);
    if (current != null && !at.isAfter(current)) {
      return;
    }
    _replace(
      chat.isTeacherViewer(viewerId)
          ? chat.copyWith(teacherLastReadAt: at)
          : chat.copyWith(studentLastReadAt: at),
    );
    _publishChat(chatId);
  }

  /// ينشئ إشعارًا «بأفضل جهد» (P12): فشله لا يُفشل الفعل الأصلي.
  Future<void> _notify({
    required NotificationType type,
    required String recipientId,
    required String actorId,
    required String actorName,
    required String targetId,
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
        body: body,
      );
    } on Object catch (error) {
      // الإشعار إضافة: لا نُسقط نجاح الحجز/الرسالة بسببه.
      log('demo notification push failed', name: 'notifications', error: error);
    }
  }


}

/// إشعارات داخل التطبيق في وضع الزائر (P12).
///
/// تعمل بنفس عقد Firestore: القائمة للمستلم فقط، والتعليم/الحذف لمستلمه،
/// والعدّاد يُبثّ حيًّا (مشغّل لكل مستلم).
class DemoNotificationRepository implements NotificationRepository {
  DemoNotificationRepository({List<AppNotification>? source})
    : _items = <AppNotification>[...(source ?? DemoData.notifications)];

  final List<AppNotification> _items;
  final Map<String, StreamController<int>> _streams =
      <String, StreamController<int>>{};
  int _nextId = 1;

  StreamController<int> _streamFor(String recipientId) {
    return _streams.putIfAbsent(
      recipientId,
      () => StreamController<int>.broadcast(),
    );
  }

  int _unread(String recipientId) => _items
      .where(
        (AppNotification item) =>
            item.recipientId == recipientId && !item.isRead,
      )
      .length;

  void _publish(String recipientId) {
    _streamFor(recipientId).add(_unread(recipientId));
  }

  @override
  Future<List<AppNotification>> listMine(String recipientId) async {
    return NotificationRules.newestFirst(
      _items
          .where((AppNotification item) => item.recipientId == recipientId)
          .toList(growable: false),
    );
  }

  @override
  Stream<int> watchUnreadCount(String recipientId) async* {
    yield _unread(recipientId);
    yield* _streamFor(recipientId).stream;
  }

  @override
  Future<void> markRead({
    required String notificationId,
    required String recipientId,
  }) async {
    final int index = _items.indexWhere(
      (AppNotification item) => item.id == notificationId,
    );
    if (index < 0) {
      return;
    }
    final AppNotification item = _items[index];
    if (item.recipientId != recipientId || item.isRead) {
      return;
    }
    _items[index] = item.copyWith(readAt: DateTime.now());
    _publish(recipientId);
  }

  @override
  Future<void> markAllRead(String recipientId) async {
    final DateTime now = DateTime.now();
    bool changed = false;
    for (int i = 0; i < _items.length; i++) {
      final AppNotification item = _items[i];
      if (item.recipientId == recipientId && !item.isRead) {
        _items[i] = item.copyWith(readAt: now);
        changed = true;
      }
    }
    if (changed) {
      _publish(recipientId);
    }
  }

  @override
  Future<void> deleteNotification({
    required String notificationId,
    required String recipientId,
  }) async {
    final int index = _items.indexWhere(
      (AppNotification item) => item.id == notificationId,
    );
    if (index < 0) {
      return;
    }
    if (_items[index].recipientId != recipientId) {
      throw const AppException.permission(
        debugMessage: 'delete others notification',
        overrideMessage: 'لا يمكنك حذف إشعار لا يخصّك.',
      );
    }
    _items.removeAt(index);
    _publish(recipientId);
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
  }) async {
    if (recipientId == actorId) {
      throw const AppException.permission(
        debugMessage: 'self notification',
        overrideMessage: 'لا يمكن إرسال إشعار لنفسك.',
      );
    }
    final String cleanActorName = NotificationRules.normalize(actorName);
    final String cleanTitle = NotificationRules.normalize(
      title ?? NotificationRules.titleFor(type: type, actorName: cleanActorName),
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

    final AppNotification item = AppNotification(
      id: 'demo-notification-new-${_nextId++}',
      recipientId: recipientId,
      type: type,
      actorId: actorId,
      actorName: cleanActorName,
      targetId: targetId,
      title: cleanTitle,
      body: cleanBody == null || cleanBody.isEmpty ? null : cleanBody,
      createdAt: DateTime.now(),
    );
    _items.add(item);
    _publish(recipientId);
    return item;
  }
}

/// تقييمات المدرسين في الوضع التجريبي (P13).
///
/// يحاكي التنفيذ الحقيقي في نقطتين مهمتين:
/// 1. **G7 قبل الكتابة:** يقرأ الحجز طازجًا من المستودع (لا يثق بالنسخة
///    المعروضة) ويرفض التقييم إن لم يكن منفّذًا أو لم يكن للطالب نفسه.
/// 2. **المتوسط مشتق لا مكتوب:** `TeacherRating` يُحسب من قائمة التقييمات
///    نفسها، فلا يمكن أن يتقدّم على التقييمات أو يتخلّف عنها.
class DemoReviewRepository implements ReviewRepository {
  DemoReviewRepository({
    List<TeacherReview>? source,
    Future<BookingRequest?> Function(String id)? findBooking,
  }) : _reviews = <TeacherReview>[...(source ?? DemoData.reviews)],
       _findBooking = findBooking;

  final List<TeacherReview> _reviews;

  /// قراءة الحجز الطازج — يمنع تقييم حجز لم يُنفَّذ فعلًا.
  final Future<BookingRequest?> Function(String id)? _findBooking;

  final Map<String, StreamController<List<TeacherReview>>> _streams =
      <String, StreamController<List<TeacherReview>>>{};

  StreamController<List<TeacherReview>> _streamFor(String teacherId) {
    return _streams.putIfAbsent(
      teacherId,
      () => StreamController<List<TeacherReview>>.broadcast(),
    );
  }

  TeacherRating _ratingOf(String teacherId) {
    int sum = 0;
    int count = 0;
    for (final TeacherReview review in _reviews) {
      if (review.teacherId == teacherId) {
        sum += review.rating;
        count++;
      }
    }
    return TeacherRating(
      teacherId: teacherId,
      totalReviews: count,
      ratingSum: sum,
    );
  }

  List<TeacherReview> _ofTeacher(String teacherId) => ReviewRules.newestFirst(
    _reviews
        .where((TeacherReview review) => review.teacherId == teacherId)
        .toList(growable: false),
  );

  void _publish(String teacherId) => _streamFor(teacherId).add(
    _ofTeacher(teacherId),
  );

  @override
  Future<List<TeacherReview>> listForTeacher(String teacherId) async =>
      _ofTeacher(teacherId);

  @override
  Stream<List<TeacherReview>> watchForTeacher(String teacherId) async* {
    yield _ofTeacher(teacherId);
    yield* _streamFor(teacherId).stream;
  }

  @override
  Future<TeacherRating> ratingFor(String teacherId) async =>
      _ratingOf(teacherId);

  @override
  Stream<TeacherRating> watchRating(String teacherId) async* {
    yield _ratingOf(teacherId);
    yield* _streamFor(teacherId).stream.map(
      (List<TeacherReview> _) => _ratingOf(teacherId),
    );
  }

  @override
  Future<TeacherReview?> findForBooking(String bookingId) async {
    for (final TeacherReview review in _reviews) {
      if (review.bookingId == bookingId) {
        return review;
      }
    }
    return null;
  }

  @override
  Future<TeacherReview> submit({
    required BookingRequest booking,
    required String studentId,
    required String studentName,
    required int rating,
    String? comment,
  }) async {
    final BookingRequest fresh =
        await _findBooking?.call(booking.id) ?? booking;
    final bool alreadyReviewed =
        await findForBooking(fresh.id) != null;

    final String? blocked = ReviewRules.eligibilityProblem(
      booking: fresh,
      studentId: studentId,
      alreadyReviewed: alreadyReviewed,
    );
    if (blocked != null) {
      throw AppException(
        AppErrorKind.permission,
        overrideMessage: blocked,
        debugMessage: 'review not eligible (demo)',
      );
    }

    final String? ratingProblem = ReviewRules.ratingProblem(rating);
    if (ratingProblem != null) {
      throw AppException(
        AppErrorKind.invalidInput,
        overrideMessage: ratingProblem,
        debugMessage: 'invalid rating (demo)',
      );
    }

    final String? cleanComment = comment == null
        ? null
        : ReviewRules.normalize(comment);
    final String? commentProblem = ReviewRules.commentProblem(cleanComment);
    if (commentProblem != null) {
      throw AppException(
        AppErrorKind.invalidInput,
        overrideMessage: commentProblem,
        debugMessage: 'invalid review comment (demo)',
      );
    }

    final String teacherId = fresh.teacherId ?? '';
    if (teacherId.isEmpty) {
      throw const AppException.notFound(
        debugMessage: 'booking without teacher (demo review)',
        overrideMessage: 'لا يمكن تحديد المدرس من هذا الحجز.',
      );
    }

    final TeacherReview review = TeacherReview(
      bookingId: fresh.id,
      teacherId: teacherId,
      studentId: studentId,
      studentName: ReviewRules.normalize(studentName),
      rating: rating,
      comment: cleanComment == null || cleanComment.isEmpty
          ? null
          : cleanComment,
      createdAt: DateTime.now(),
    );
    _reviews.add(review);
    _publish(teacherId);
    return review;
  }
}

/// مفضلة الطالب في الوضع التجريبي (P13) — نفس بنية المعرّف المشتق.
class DemoFavoriteRepository implements FavoriteRepository {
  DemoFavoriteRepository({List<Favorite>? source})
    : _items = <Favorite>[...(source ?? const <Favorite>[])];

  final List<Favorite> _items;
  final Map<String, StreamController<List<Favorite>>> _streams =
      <String, StreamController<List<Favorite>>>{};

  StreamController<List<Favorite>> _streamFor(String studentId) {
    return _streams.putIfAbsent(
      studentId,
      () => StreamController<List<Favorite>>.broadcast(),
    );
  }

  List<Favorite> _ofStudent(String studentId) {
    final List<Favorite> mine = _items
        .where((Favorite favorite) => favorite.studentId == studentId)
        .toList(growable: false);
    mine.sort((Favorite a, Favorite b) => b.createdAt.compareTo(a.createdAt));
    return List<Favorite>.unmodifiable(mine);
  }

  void _publish(String studentId) =>
      _streamFor(studentId).add(_ofStudent(studentId));

  int _indexOf(String studentId, FavoriteKind kind, String targetId) {
    return _items.indexWhere(
      (Favorite favorite) =>
          favorite.studentId == studentId &&
          favorite.kind == kind &&
          favorite.targetId == targetId,
    );
  }

  @override
  Future<List<Favorite>> listForStudent(String studentId) async =>
      _ofStudent(studentId);

  @override
  Stream<List<Favorite>> watchForStudent(String studentId) async* {
    yield _ofStudent(studentId);
    yield* _streamFor(studentId).stream;
  }

  @override
  Stream<bool> watchIsFavorite({
    required String studentId,
    required FavoriteKind kind,
    required String targetId,
  }) async* {
    yield _indexOf(studentId, kind, targetId) >= 0;
    yield* _streamFor(studentId).stream.map(
      (List<Favorite> _) => _indexOf(studentId, kind, targetId) >= 0,
    );
  }

  @override
  Future<bool> toggle({
    required String studentId,
    required FavoriteKind kind,
    required String targetId,
  }) async {
    if (studentId.trim().isEmpty || targetId.trim().isEmpty) {
      throw const AppException.invalidInput(
        debugMessage: 'favorite without student/target',
        overrideMessage: 'لا يمكن حفظ عنصر بلا معرّف صالح.',
      );
    }
    final int index = _indexOf(studentId, kind, targetId);
    if (index >= 0) {
      _items.removeAt(index);
      _publish(studentId);
      return false;
    }
    _items.add(
      Favorite(
        studentId: studentId,
        kind: kind,
        targetId: targetId,
        createdAt: DateTime.now(),
      ),
    );
    _publish(studentId);
    return true;
  }
}
