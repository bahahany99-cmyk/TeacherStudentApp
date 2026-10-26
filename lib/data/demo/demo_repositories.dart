import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
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

  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<AppUser> signInWithGoogle(UserRole requestedRole) {
    throw UnsupportedError(
      'تسجيل الدخول عبر Google غير منفّذ في المرحلة 2. '
      'يتطلب مشروع Firebase + إعداد OAuth (انظر docs/FIREBASE_SETUP.md).',
    );
  }
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
}
