import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/firebase/mappers/firestore_mappers.dart';
import 'package:teacher_student_app/data/models/content_report.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/teacher_review.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/validation/admin_rules.dart';
import 'package:teacher_student_app/features/admin/domain/admin_roles.dart';

void main() {
  group('AdminRoles — من هو المسؤول؟ (P14)', () {
    test('الادعاء الإداري يكفي وحده', () {
      expect(
        AdminRoles.isAdmin(role: UserRole.student, hasAdminClaim: true),
        isTrue,
      );
      expect(
        AdminRoles.canAccessAdminPanel(
          role: UserRole.teacher,
          hasAdminClaim: true,
        ),
        isTrue,
      );
    });

    test('الدور الإداري المحلي يكفي (معاينة تجريبية)', () {
      expect(
        AdminRoles.isAdmin(role: UserRole.admin, hasAdminClaim: false),
        isTrue,
      );
    });

    test('طالب أو مدرس بلا ادعاء ليس مسؤولًا', () {
      for (final UserRole role in <UserRole>[
        UserRole.student,
        UserRole.teacher,
      ]) {
        expect(
          AdminRoles.isAdmin(role: role, hasAdminClaim: false),
          isFalse,
          reason: 'الدور ${role.name} لا يمنح صلاحية إدارية',
        );
      }
      expect(AdminRoles.isAdmin(role: null, hasAdminClaim: false), isFalse);
    });
  });

  group('AdminRules — سبب الرفض', () {
    test('سبب قصير جدًا مرفوض', () {
      expect(AdminRules.reasonProblem(''), isNotNull);
      expect(AdminRules.reasonProblem('  لا  '), isNotNull);
    });

    test('سبب طويل جدًا مرفوض', () {
      final String long = 'س' * (AdminRules.maxReasonLength + 1);
      expect(AdminRules.reasonProblem(long), isNotNull);
    });

    test('سبب واضح مقبول (والمسافات تُقصّ)', () {
      expect(AdminRules.reasonProblem('  بيانات تواصل داخل النبذة  '), isNull);
    });
  });

  group('AdminRules — ترتيب الطابور والبلاغات', () {
    test('الطابور يستبعد الموثّق والمرفوض', () {
      final List<TeacherProfile> queue = AdminRules.verificationQueue(
        <TeacherProfile>[
          _profile('a', TeacherProfileStatus.verified),
          _profile('b', TeacherProfileStatus.pendingReview),
          _profile('c', TeacherProfileStatus.rejected),
          _profile('d', TeacherProfileStatus.draft),
        ],
      );

      expect(queue.map((TeacherProfile p) => p.id), <String>['b', 'd']);
    });

    test('البلاغات المفتوحة أولًا، والأحدث أولًا', () {
      final List<ContentReport> reports = AdminRules.newestReportsFirst(
        <ContentReport>[
          _report('old', DateTime(2026, 10, 1)),
          _report(
            'resolved',
            DateTime(2026, 10, 9),
            status: ReportStatus.resolved,
          ),
          _report('new', DateTime(2026, 10, 8)),
        ],
      );

      expect(reports.map((ContentReport r) => r.id), <String>['new', 'old']);
    });
  });

  group('DemoAdminRepository — قرارات اللوحة', () {
    late List<TeacherProfile> profiles;
    late List<TeacherReview> reviews;
    late DemoAdminRepository admin;
    late DemoTeacherRepository teachers;

    setUp(() {
      profiles = <TeacherProfile>[...DemoData.teachers];
      reviews = <TeacherReview>[...DemoData.reviews];
      admin = DemoAdminRepository(profiles: profiles, reviews: reviews);
      // نفس القائمة: قرار التوثيق يجب أن يظهر في البحث فورًا.
      teachers = DemoTeacherRepository(source: profiles);
    });

    test('الطابور يعرض غير المراجَع فقط', () async {
      final List<TeacherProfile> queue = await admin.listVerificationQueue();

      expect(
        queue.every((TeacherProfile p) => p.status.awaitsReview),
        isTrue,
      );
      expect(
        queue.map((TeacherProfile p) => p.id),
        containsAll(<String>['demo-teacher-6-review', 'demo-teacher-7-draft']),
      );
      expect(
        queue.map((TeacherProfile p) => p.id),
        isNot(contains('demo-teacher-8-rejected')),
      );
    });

    test('التوثيق يفتح الملف للطلاب في نفس القائمة', () async {
      expect(
        (await teachers.listVerified()).any(
          (TeacherProfile p) => p.id == 'demo-teacher-6-review',
        ),
        isFalse,
      );

      await admin.verifyTeacher('demo-teacher-6-review');

      final List<TeacherProfile> visible = await teachers.listVerified();
      expect(
        visible.any((TeacherProfile p) => p.id == 'demo-teacher-6-review'),
        isTrue,
      );
      expect(
        (await admin.listVerificationQueue()).any(
          (TeacherProfile p) => p.id == 'demo-teacher-6-review',
        ),
        isFalse,
      );
    });

    test('الرفض بسبب قصير مرفوض، وبسبب واضح يُحفظ السبب', () async {
      await expectLater(
        admin.rejectTeacher(teacherId: 'demo-teacher-7-draft', reason: 'لا'),
        throwsA(isA<AppException>()),
      );

      await admin.rejectTeacher(
        teacherId: 'demo-teacher-7-draft',
        reason: 'النبذة تحتوي على بيانات تواصل خارج التطبيق.',
      );

      final TeacherProfile stored = profiles.firstWhere(
        (TeacherProfile p) => p.id == 'demo-teacher-7-draft',
      );
      expect(stored.status, TeacherProfileStatus.rejected);
      expect(stored.reviewNote, contains('بيانات تواصل'));
      expect(stored.isVisibleToStudents, isFalse);
    });

    test('ملف غير موجود يُبلَّغ عنه برسالة عربية', () async {
      await expectLater(
        admin.verifyTeacher('ghost'),
        throwsA(isA<AppException>()),
      );
    });

    test('حسم بلاغ يخرجه من قائمة المفتوحة', () async {
      final List<ContentReport> open = await admin.listOpenReports();
      expect(open, isNotEmpty);

      final ContentReport first = open.first;
      await admin.resolveReport(
        reportId: first.id,
        resolution: ReportResolution.dismissed,
        note: 'لا مخالفة',
      );

      final List<ContentReport> after = await admin.listOpenReports();
      expect(after.any((ContentReport r) => r.id == first.id), isFalse);
    });

    test('حذف تقييم يزيله من قائمة المراجعة', () async {
      final String id = reviews.first.bookingId;
      await admin.deleteReview(id);

      expect(
        reviews.any((TeacherReview r) => r.bookingId == id),
        isFalse,
      );
      expect(
        (await admin.listRecentReviews()).any(
          (TeacherReview r) => r.bookingId == id,
        ),
        isFalse,
      );
    });

    test('أحدث التقييمات مرتّبة تنازليًا', () async {
      final List<TeacherReview> recent = await admin.listRecentReviews();
      for (int i = 1; i < recent.length; i++) {
        expect(
          recent[i - 1].createdAt.isBefore(recent[i].createdAt),
          isFalse,
        );
      }
    });
  });

  group('الحالة الجديدة verified (P14)', () {
    test('القيمة المخزّنة والنص العربي', () {
      expect(TeacherProfileStatus.verified.wireValue, 'verified');
      expect(TeacherProfileStatus.verified.label, 'موثّق');
      expect(TeacherProfileStatus.verified.awaitsReview, isFalse);
      expect(TeacherProfileStatus.pendingReview.awaitsReview, isTrue);
    });

    test('القيمة القديمة approved تُقرأ كـverified (توافق خلفي)', () {
      expect(parseTeacherStatus('approved'), TeacherProfileStatus.verified);
      expect(parseTeacherStatus('verified'), TeacherProfileStatus.verified);
    });

    test('سبب الرفض يُقرأ من المستند', () {
      final TeacherProfile? profile = teacherProfileFromMap(
        't1',
        <String, Object?>{
          'displayName': 'أ. عمرو',
          'status': 'rejected',
          'reviewNote': 'بيانات تواصل داخل النبذة.',
        },
      );

      expect(profile?.status, TeacherProfileStatus.rejected);
      expect(profile?.reviewNote, 'بيانات تواصل داخل النبذة.');
    });

    test('الموثّق وحده يظهر للطلاب', () {
      expect(_profile('a', TeacherProfileStatus.verified).isVisibleToStudents, isTrue);
      expect(_profile('b', TeacherProfileStatus.pendingReview).isVisibleToStudents, isFalse);
      expect(_profile('c', TeacherProfileStatus.draft).isVisibleToStudents, isFalse);
      expect(_profile('d', TeacherProfileStatus.rejected).isVisibleToStudents, isFalse);
    });
  });

  group('الجلسة الإدارية التجريبية', () {
    test('جلسة الإدارة تحمل الادعاء محليًا وتُعلَّم تجريبية', () {
      final SessionController session = SessionController(
        const DemoAuthService(),
      )..startDemoSession(UserRole.admin);

      expect(session.role, UserRole.admin);
      expect(session.isAdmin, isTrue);
      expect(session.hasAdminClaim, isTrue);
      expect(session.isDemoSession, isTrue);
      expect(session.user?.id, 'demo-admin');
    });

    test('جلسة الطالب والمدرس ليست إدارية', () {
      final SessionController session = SessionController(
        const DemoAuthService(),
      )..startDemoSession(UserRole.student);
      expect(session.isAdmin, isFalse);

      session.switchDemoRole(UserRole.teacher);
      expect(session.isAdmin, isFalse);

      session.switchDemoRole(UserRole.admin);
      expect(session.isAdmin, isTrue, reason: 'تبديل المعاينة إلى الإدارة يعمل');
    });
  });
}

TeacherProfile _profile(String id, TeacherProfileStatus status) => TeacherProfile(
  id: id,
  displayName: 'أ. $id',
  subject: 'الرياضيات',
  stage: 'الثانوية العامة',
  area: 'أسيوط',
  bio: '',
  status: status,
);

ContentReport _report(String id, DateTime createdAt, {ReportStatus? status}) =>
    ContentReport(
      id: id,
      targetType: ReportTargetType.review,
      targetId: 'b1',
      reporterId: 'student-1',
      reason: 'سبب',
      createdAt: createdAt,
      status: status ?? ReportStatus.open,
    );
