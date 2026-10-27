import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';
import 'package:teacher_student_app/data/services/booking_repository.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';
import 'package:teacher_student_app/data/services/teacher_repository.dart';
import 'package:teacher_student_app/data/validation/group_rules.dart';
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
    return DemoData.membersFor(groupId);
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
