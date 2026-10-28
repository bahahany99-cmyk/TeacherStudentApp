import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/favorite.dart';
import 'package:teacher_student_app/data/models/teacher_rating.dart';
import 'package:teacher_student_app/data/models/teacher_review.dart';
import 'package:teacher_student_app/data/validation/review_rules.dart';

const String _studentId = DemoData.demoStudentId;
const String _teacherId = DemoData.demoTeacherId;

BookingRequest _booking({
  required String id,
  required BookingStatus status,
  String studentId = _studentId,
  String teacherId = _teacherId,
}) {
  return BookingRequest(
    id: id,
    teacherId: teacherId,
    teacherName: 'أ. سارة الخطيب',
    studentId: studentId,
    studentName: 'طالب تجريبي',
    subject: 'الرياضيات',
    requestedAt: DateTime(2026, 10, 15, 20),
    status: status,
    dateKey: '2026-10-18',
    startMinutes: 17 * 60,
    durationMinutes: 60,
  );
}

/// مستودع تقييمات مربوط بمستودع الحجوزات التجريبي نفسه (كما في التطبيق).
DemoReviewRepository _reviews() {
  final DemoBookingRepository bookings = DemoBookingRepository();
  return DemoReviewRepository(findBooking: bookings.findById);
}

void main() {
  group('حدود التقييم', () {
    test('النجوم من 1 إلى 5 والغياب يعني «اختر»', () {
      expect(ReviewRules.ratingProblem(null), contains('اختر'));
      expect(ReviewRules.ratingProblem(0), isNotNull);
      expect(ReviewRules.ratingProblem(6), isNotNull);
      for (int stars = 1; stars <= 5; stars++) {
        expect(ReviewRules.ratingProblem(stars), isNull);
      }
    });

    test('التعليق اختياري ومحدود الطول', () {
      expect(ReviewRules.commentProblem(null), isNull);
      expect(ReviewRules.commentProblem('   '), isNull);
      expect(ReviewRules.commentProblem('ممتاز'), isNull);
      expect(
        ReviewRules.commentProblem('ا' * ReviewRules.maxCommentLength),
        isNull,
      );
      expect(
        ReviewRules.commentProblem('ا' * (ReviewRules.maxCommentLength + 1)),
        isNotNull,
      );
    });

    test('التنظيف يوحد الفراغات ويقصّ الأطراف', () {
      expect(ReviewRules.normalize('  شرح   ممتاز  '), 'شرح ممتاز');
    });
  });

  group('بوابة الأهلية G7', () {
    test('الحجز المنفّذ لصاحبه هو الوحيد المؤهل', () {
      expect(
        ReviewRules.canReview(
          booking: _booking(id: 'b1', status: BookingStatus.completed),
          studentId: _studentId,
          alreadyReviewed: false,
        ),
        isTrue,
      );
    });

    test('كل حالة غير «منفّذ» تمنع التقييم بسبب عربي واضح', () {
      for (final BookingStatus status in <BookingStatus>[
        BookingStatus.pending,
        BookingStatus.accepted,
        BookingStatus.rejected,
        BookingStatus.cancelled,
        BookingStatus.cancelledLate,
        BookingStatus.rescheduleProposed,
      ]) {
        final String? reason = ReviewRules.eligibilityProblem(
          booking: _booking(id: 'b1', status: status),
          studentId: _studentId,
          alreadyReviewed: false,
        );
        expect(reason, isNotNull, reason: 'الحالة ${status.name}');
        expect(reason!.length, greaterThan(5));
      }
    });

    test('حجز طالب آخر لا يُقيَّم ولو كان منفّذًا', () {
      expect(
        ReviewRules.eligibilityProblem(
          booking: _booking(
            id: 'b1',
            status: BookingStatus.completed,
            studentId: 'student-2',
          ),
          studentId: _studentId,
          alreadyReviewed: false,
        ),
        contains('ليس لك'),
      );
    });

    test('التقييم المكرر مرفوض', () {
      expect(
        ReviewRules.eligibilityProblem(
          booking: _booking(id: 'b1', status: BookingStatus.completed),
          studentId: _studentId,
          alreadyReviewed: true,
        ),
        contains('بالفعل'),
      );
    });

    test('غياب هوية الطالب يمنع التقييم', () {
      expect(
        ReviewRules.eligibilityProblem(
          booking: _booking(id: 'b1', status: BookingStatus.completed),
          studentId: '   ',
          alreadyReviewed: false,
        ),
        isNotNull,
      );
    });
  });

  group('حساب المتوسط', () {
    test('الفراغ لا يقسم على صفر', () {
      const TeacherRating empty = TeacherRating.empty(_teacherId);
      expect(empty.isEmpty, isTrue);
      expect(empty.average, 0);
      expect(empty.averageLabel, 'لا توجد تقييمات بعد');
    });

    test('المتوسط مشتق من المجموع والعدد', () {
      const TeacherRating rating = TeacherRating(
        teacherId: _teacherId,
        totalReviews: 2,
        ratingSum: 9,
      );
      expect(rating.average, 4.5);
      expect(rating.averageLabel, '4.5 من 5 (تقييمان)');
      expect(rating.isConsistent, isTrue);
    });

    test('صيغة العدد العربي سليمة', () {
      expect(
        const TeacherRating(
          teacherId: 't',
          totalReviews: 1,
          ratingSum: 5,
        ).averageLabel,
        contains('تقييم واحد'),
      );
      expect(
        const TeacherRating(
          teacherId: 't',
          totalReviews: 3,
          ratingSum: 12,
        ).averageLabel,
        contains('3 تقييمات'),
      );
      expect(
        const TeacherRating(
          teacherId: 't',
          totalReviews: 12,
          ratingSum: 48,
        ).averageLabel,
        contains('12 تقييمًا'),
      );
    });

    test('الإضافة تزيد العدد واحدًا والمجموع بالتقييم', () {
      final TeacherRating next = const TeacherRating(
        teacherId: 't',
        totalReviews: 2,
        ratingSum: 9,
      ).plus(4);
      expect(next.totalReviews, 3);
      expect(next.ratingSum, 13);
      expect(next.average, closeTo(4.33, 0.01));
    });

    test('مجموع خارج النطاق يُكشف كبيانات غير متسقة', () {
      expect(
        const TeacherRating(
          teacherId: 't',
          totalReviews: 2,
          ratingSum: 99,
        ).isConsistent,
        isFalse,
      );
    });
  });

  group('ترتيب التقييمات', () {
    test('الأحدث أولًا وبثبات عند تساوي التاريخ', () {
      final List<TeacherReview> sorted = ReviewRules.newestFirst(<TeacherReview>[
        TeacherReview(
          bookingId: 'b1',
          teacherId: 't',
          studentId: 's1',
          rating: 5,
          createdAt: DateTime(2026, 10, 1),
        ),
        TeacherReview(
          bookingId: 'b3',
          teacherId: 't',
          studentId: 's3',
          rating: 5,
          createdAt: DateTime(2026, 10, 3),
        ),
        TeacherReview(
          bookingId: 'b2',
          teacherId: 't',
          studentId: 's2',
          rating: 4,
          createdAt: DateTime(2026, 10, 2),
        ),
      ]);

      expect(
        sorted.map((TeacherReview review) => review.bookingId),
        <String>['b3', 'b2', 'b1'],
      );
    });
  });

  group('مستودع التقييمات التجريبي', () {
    test('يقرأ تقييمات المدرس ومتوسطها من البيانات نفسها', () async {
      final DemoReviewRepository repo = _reviews();

      final List<TeacherReview> list = await repo.listForTeacher(
        'demo-teacher-2',
      );
      expect(list.length, DemoData.reviews.where(
        (TeacherReview review) => review.teacherId == 'demo-teacher-2',
      ).length);

      final TeacherRating rating = await repo.ratingFor('demo-teacher-2');
      expect(rating.totalReviews, list.length);
      expect(
        rating.ratingSum,
        list.fold<int>(0, (int sum, TeacherReview r) => sum + r.rating),
      );
      // مدرس بلا تقييمات: عدّاد صفري لا متوسط كاذب.
      expect((await repo.ratingFor('demo-teacher-5')).isEmpty, isTrue);
    });

    test('تقييم حجز منفّذ يُقبل ويحدّث المتوسط فورًا', () async {
      final DemoReviewRepository repo = _reviews();
      final DemoBookingRepository bookings = DemoBookingRepository();
      final BookingRequest booking = (await bookings.findById(
        'demo-booking-4',
      ))!;
      expect(booking.status, BookingStatus.completed);

      final TeacherRating before = await repo.ratingFor(_teacherId);

      final TeacherReview review = await repo.submit(
        booking: booking,
        studentId: _studentId,
        rating: 4,
        comment: 'شرح واضح',
      );

      expect(review.bookingId, 'demo-booking-4');
      expect(review.teacherId, _teacherId);
      expect(review.rating, 4);

      final TeacherRating after = await repo.ratingFor(_teacherId);
      expect(after.totalReviews, before.totalReviews + 1);
      expect(after.ratingSum, before.ratingSum + 4);
      expect(await repo.findForBooking('demo-booking-4'), isNotNull);
      expect(
        (await repo.listForTeacher(_teacherId)).first.bookingId,
        'demo-booking-4',
      );
    });

    test('التقييم المكرر لنفس الحصة مرفوض', () async {
      final DemoReviewRepository repo = _reviews();
      final DemoBookingRepository bookings = DemoBookingRepository();
      final BookingRequest booking = (await bookings.findById(
        'demo-booking-4',
      ))!;

      await repo.submit(
        booking: booking,
        studentId: _studentId,
        rating: 5,
      );

      await expectLater(
        repo.submit(
          booking: booking,
          studentId: _studentId,
          rating: 1,
        ),
        throwsA(
          isA<AppException>(),
        ),
      );
      // المتوسط لم يتغيّر بفعل المحاولة الثانية.
      final TeacherRating after = await repo.ratingFor(_teacherId);
      expect(after.totalReviews, 1);
      expect(after.ratingSum, 5);
    });

    test('حجز غير منفّذ أو لطالب آخر لا يُقيَّم', () async {
      final DemoReviewRepository repo = _reviews();
      final DemoBookingRepository bookings = DemoBookingRepository();
      final BookingRequest pending = (await bookings.findById(
        'demo-booking-1',
      ))!;
      expect(pending.status, BookingStatus.pending);

      await expectLater(
        repo.submit(
          booking: pending,
          studentId: _studentId,
          rating: 5,
        ),
        throwsA(isA<AppException>()),
      );

      final BookingRequest completed = (await bookings.findById(
        'demo-booking-4',
      ))!;
      await expectLater(
        repo.submit(
          booking: completed,
          studentId: 'student-last',
          rating: 5,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('نجوم خارج النطاق وتعليق طويل مرفوضان', () async {
      final DemoReviewRepository repo = _reviews();
      final DemoBookingRepository bookings = DemoBookingRepository();
      final BookingRequest booking = (await bookings.findById(
        'demo-booking-4',
      ))!;

      await expectLater(
        repo.submit(
          booking: booking,
          studentId: _studentId,
          rating: 9,
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repo.submit(
          booking: booking,
          studentId: _studentId,
          rating: 5,
          comment: 'ا' * (ReviewRules.maxCommentLength + 1),
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('البثّ يعكس التقييم الجديد والمتوسط', () async {
      final DemoReviewRepository repo = _reviews();
      final DemoBookingRepository bookings = DemoBookingRepository();
      final BookingRequest booking = (await bookings.findById(
        'demo-booking-4',
      ))!;

      final Stream<TeacherRating> ratings = repo.watchRating(_teacherId);
      final Future<TeacherRating> updated = ratings.firstWhere(
        (TeacherRating rating) => rating.totalReviews > 0,
      );

      await repo.submit(
        booking: booking,
        studentId: _studentId,
        rating: 3,
      );

      expect((await updated).totalReviews, greaterThan(0));
    });
  });

  group('مستودع المفضلة التجريبي', () {
    test('التبديل يضيف ثم يزيل', () async {
      final DemoFavoriteRepository repo = DemoFavoriteRepository();

      expect(
        await repo.watchIsFavorite(
          studentId: _studentId,
          kind: FavoriteKind.teacher,
          targetId: _teacherId,
        ).first,
        isFalse,
      );

      expect(
        await repo.toggle(
          studentId: _studentId,
          kind: FavoriteKind.teacher,
          targetId: _teacherId,
        ),
        isTrue,
      );
      expect((await repo.listForStudent(_studentId)).length, 1);
      expect(
        await repo.watchIsFavorite(
          studentId: _studentId,
          kind: FavoriteKind.teacher,
          targetId: _teacherId,
        ).first,
        isTrue,
      );

      expect(
        await repo.toggle(
          studentId: _studentId,
          kind: FavoriteKind.teacher,
          targetId: _teacherId,
        ),
        isFalse,
      );
      expect(await repo.listForStudent(_studentId), isEmpty);
    });

    test('لا تتسرّب مفضلة طالب إلى طالب آخر', () async {
      final DemoFavoriteRepository repo = DemoFavoriteRepository();
      await repo.toggle(
        studentId: 'student-1',
        kind: FavoriteKind.group,
        targetId: 'demo-group-1',
      );

      expect(await repo.listForStudent('student-2'), isEmpty);
      expect(await repo.listForStudent('student-1'), hasLength(1));
    });

    test('النوعان منفصلان: مدرس ومجموعة بنفس المعرّف', () async {
      final DemoFavoriteRepository repo = DemoFavoriteRepository();
      await repo.toggle(
        studentId: _studentId,
        kind: FavoriteKind.teacher,
        targetId: 'x',
      );
      await repo.toggle(
        studentId: _studentId,
        kind: FavoriteKind.group,
        targetId: 'x',
      );

      final List<Favorite> mine = await repo.listForStudent(_studentId);
      expect(mine, hasLength(2));
      expect(
        mine.map((Favorite favorite) => favorite.kind).toSet(),
        <FavoriteKind>{FavoriteKind.teacher, FavoriteKind.group},
      );
    });

    test('معرّف مشتق ثابت لكل (طالب، نوع، هدف)', () {
      expect(
        Favorite.idFor(
          studentId: 's1',
          kind: FavoriteKind.teacher,
          targetId: 't1',
        ),
        's1_teacher_t1',
      );
      expect(
        Favorite.idFor(
          studentId: 's1',
          kind: FavoriteKind.group,
          targetId: 'g1',
        ),
        's1_group_g1',
      );
    });

    test('معرّف فارغ يرفض الحفظ', () async {
      final DemoFavoriteRepository repo = DemoFavoriteRepository();
      await expectLater(
        repo.toggle(
          studentId: '',
          kind: FavoriteKind.teacher,
          targetId: 't1',
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repo.toggle(
          studentId: _studentId,
          kind: FavoriteKind.group,
          targetId: ' ',
        ),
        throwsA(isA<AppException>()),
      );
    });
  });
}
