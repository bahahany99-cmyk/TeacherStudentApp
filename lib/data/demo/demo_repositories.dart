import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';
import 'package:teacher_student_app/data/services/booking_repository.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';
import 'package:teacher_student_app/data/services/teacher_repository.dart';

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
    : _source = source ?? DemoData.groups;

  final List<StudyGroup> _source;

  late final Future<List<StudyGroup>> _allCache = Future<List<StudyGroup>>.value(
    List<StudyGroup>.unmodifiable(_source),
  );

  @override
  Future<List<StudyGroup>> listDiscoverable() => _allCache;

  @override
  Future<List<StudyGroup>> listForTeacher(String teacherId) {
    return Future<List<StudyGroup>>.value(
      _source
          .where((StudyGroup g) => g.teacherId == teacherId)
          .toList(growable: false),
    );
  }

  @override
  Future<StudyGroup?> findById(String id) {
    for (final StudyGroup group in _source) {
      if (group.id == id) {
        return Future<StudyGroup?>.value(group);
      }
    }
    return Future<StudyGroup?>.value(null);
  }

  @override
  Future<List<GroupMember>> listMembers(String groupId) {
    return Future<List<GroupMember>>.value(DemoData.membersFor(groupId));
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
