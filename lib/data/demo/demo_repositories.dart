import 'dart:async';

import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/group_message.dart';
import 'package:teacher_student_app/data/models/group_session.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';
import 'package:teacher_student_app/data/services/booking_repository.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';
import 'package:teacher_student_app/data/services/message_repository.dart';
import 'package:teacher_student_app/data/services/schedule_repository.dart';
import 'package:teacher_student_app/data/services/teacher_repository.dart';
import 'package:teacher_student_app/data/validation/group_rules.dart';
import 'package:teacher_student_app/data/validation/join_rules.dart';
import 'package:teacher_student_app/data/validation/message_rules.dart';
import 'package:teacher_student_app/data/validation/session_rules.dart';
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
  DemoGroupRepository({List<StudyGroup>? source})
    : _groups = <StudyGroup>[...(source ?? DemoData.groups)];

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
    final List<GroupMember> accepted =
        _acceptedMembers[groupId] ?? const <GroupMember>[];
    final StudyGroup? group = _findGroup(groupId);
    // الأعضاء الوهميون يملؤون ما تبقّى من المقاعد، فلا يتجاوز العدد
    // `seatsTaken` بعد قبول عضو حقيقي في وضع المعاينة.
    final int remaining = group == null
        ? 0
        : group.seatsTaken - accepted.length;
    final int generated = remaining < 0 ? 0 : remaining;
    final List<GroupMember> base = DemoData.membersFor(groupId);
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
  DemoBookingRepository({List<BookingRequest>? source})
    : _source = source ?? DemoData.bookings;

  final List<BookingRequest> _source;

  late final Future<List<BookingRequest>> _cache =
      Future<List<BookingRequest>>.value(
        List<BookingRequest>.unmodifiable(_source),
      );

  @override
  Future<List<BookingRequest>> listMine() => _cache;

  @override
  Future<BookingRequest?> findById(String id) {
    for (final BookingRequest booking in _source) {
      if (booking.id == id) {
        return Future<BookingRequest?>.value(booking);
      }
    }
    return Future<BookingRequest?>.value(null);
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
