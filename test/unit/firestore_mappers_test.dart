import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/firebase/mappers/firestore_mappers.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// بديل بسيط لـ`Timestamp` في Firestore (يكفي أن يوفّر `toDate`).
class _FakeTimestamp {
  const _FakeTimestamp(this._value);

  final DateTime _value;

  DateTime toDate() => _value;
}

void main() {
  group('قراءة القيم بأمان', () {
    test('النصوص الفارغة والمسافات تُعاد null', () {
      expect(readString('  '), isNull);
      expect(readString(42), isNull);
      expect(readString(' سارة '), 'سارة');
    });

    test('الأرقام تُقرأ من int وdouble ونص رقمي', () {
      expect(readInt(5), 5);
      expect(readInt(5.9), 5);
      expect(readInt('7'), 7);
      expect(readInt('غير رقم'), 0);
      expect(readDouble(4), 4.0);
      expect(readDouble('4.5'), 4.5);
    });

    test('التواريخ تُقرأ من Timestamp وDateTime ورقم', () {
      final DateTime when = DateTime(2026, 10, 1, 12);
      expect(readDate(_FakeTimestamp(when)), when);
      expect(readDate(when), when);
      expect(
        readDate(when.millisecondsSinceEpoch),
        DateTime.fromMillisecondsSinceEpoch(when.millisecondsSinceEpoch),
      );
      expect(readDate('نص'), isNull);
      expect(readDate(null), isNull);
    });
  });

  group('ملف المدرس', () {
    test('مستند كامل يُحوَّل بكل حقوله', () {
      final TeacherProfile? profile = teacherProfileFromMap(
        't1',
        <String, Object?>{
          'displayName': 'أ. سارة الخطيب',
          'subject': 'الرياضيات',
          'stage': 'الثانوية العامة',
          'area': 'المعادي',
          'bio': 'شرح مبسّط',
          'status': 'approved',
          'isFeatured': true,
          'rating': 4.8,
          'reviewsCount': 126,
          'priceHint': '150 ج.م',
        },
      );

      expect(profile, isNotNull);
      expect(profile!.displayName, 'أ. سارة الخطيب');
      expect(profile.status, TeacherProfileStatus.approved);
      expect(profile.isVisibleToStudents, isTrue);
      expect(profile.isFeatured, isTrue);
      expect(profile.rating, 4.8);
      expect(profile.reviewsCount, 126);
    });

    test('مستند بلا اسم غير قابل للعرض', () {
      expect(teacherProfileFromMap('t1', <String, Object?>{}), isNull);
      expect(
        teacherProfileFromMap('t1', <String, Object?>{'displayName': '   '}),
        isNull,
      );
    });

    test('حالة غير معروفة تُعتبر «قيد المراجعة» فلا تظهر للطلاب', () {
      final TeacherProfile? profile = teacherProfileFromMap(
        't1',
        <String, Object?>{'displayName': 'أ. أحمد', 'status': 'somethingNew'},
      );

      expect(profile!.status, TeacherProfileStatus.pendingReview);
      expect(profile.isVisibleToStudents, isFalse);
    });

    test('الحقول الناقصة تأخذ قيمًا آمنة بدل الانهيار', () {
      final TeacherProfile profile = teacherProfileFromMap(
        't1',
        <String, Object?>{'displayName': 'أ. منى'},
      )!;

      expect(profile.subject, 'غير محدد');
      expect(profile.stage, 'غير محدد');
      expect(profile.area, 'غير محدد');
      expect(profile.bio, '');
      expect(profile.rating, 0);
      expect(profile.reviewsCount, 0);
      expect(profile.priceHint, isNull);
    });
  });

  group('المجموعة الدراسية', () {
    test('مستند كامل يُحوَّل، والأرقام السالبة تُصحَّح', () {
      final StudyGroup? group = studyGroupFromMap('g1', <String, Object?>{
        'teacherId': 't1',
        'teacherName': 'أ. سارة',
        'title': 'التفاضل',
        'subject': 'الرياضيات',
        'stage': 'الثانوية',
        'seatsTotal': 12,
        'seatsTaken': 9,
        'meetingMode': 'center',
        'scheduleNote': 'السبت 5 م',
      });

      expect(group, isNotNull);
      expect(group!.seatsAvailable, 3);
      expect(group.meetingMode, GroupMeetingMode.center);
      expect(group.isActive, isTrue);

      final StudyGroup negative = studyGroupFromMap('g2', <String, Object?>{
        'teacherId': 't1',
        'title': 'مجموعة',
        'seatsTotal': -5,
        'seatsTaken': -2,
      })!;
      expect(negative.seatsTotal, 0);
      expect(negative.seatsTaken, 0);
      expect(negative.seatsAvailable, 0);
    });

    test('بلا عنوان أو بلا مالك غير قابل للعرض', () {
      expect(
        studyGroupFromMap('g1', <String, Object?>{'title': 'مجموعة'}),
        isNull,
      );
      expect(
        studyGroupFromMap('g1', <String, Object?>{'teacherId': 't1'}),
        isNull,
      );
    });

    test('isActive=false يُقرأ صريحًا (المجموعة موقوفة)', () {
      final StudyGroup group = studyGroupFromMap('g1', <String, Object?>{
        'teacherId': 't1',
        'title': 'مجموعة موقوفة',
        'isActive': false,
      })!;

      expect(group.isActive, isFalse);
    });
  });

  group('عضو المجموعة', () {
    test('عضو نشط وعضو قائمة انتظار', () {
      final GroupMember active = groupMemberFromMap('m1', <String, Object?>{
        'name': 'محمد سامي',
        'joinedAt': _FakeTimestamp(DateTime(2026, 9, 1)),
      })!;
      final GroupMember waiting = groupMemberFromMap('m2', <String, Object?>{
        'name': 'مريم أشرف',
        'status': 'waitlist',
      })!;

      expect(active.status, GroupMemberStatus.active);
      expect(active.joinedAt, DateTime(2026, 9, 1));
      expect(waiting.status, GroupMemberStatus.waitlist);
      expect(groupMemberFromMap('m3', <String, Object?>{}), isNull);
    });
  });

  group('طلب الحجز', () {
    test('يُقرأ بمعرّفات الأطراف والحالة والتاريخ', () {
      final BookingRequest? booking = bookingFromMap(
        'b1',
        <String, Object?>{
          'teacherId': 't1',
          'teacherName': 'أ. سارة',
          'studentId': 's1',
          'studentName': 'طالب',
          'subject': 'الرياضيات',
          'requestedAt': _FakeTimestamp(DateTime(2026, 10, 24, 18, 30)),
          'status': 'accepted',
          'note': 'ملاحظة',
        },
      );

      expect(booking, isNotNull);
      expect(booking!.teacherId, 't1');
      expect(booking.studentId, 's1');
      expect(booking.status, BookingStatus.accepted);
      expect(booking.requestedAt, DateTime(2026, 10, 24, 18, 30));
      expect(booking.note, 'ملاحظة');
    });

    test('تاريخ غائب يعود إلى createdAt ثم إلى تاريخ صفري', () {
      final BookingRequest withCreated = bookingFromMap('b1', <String, Object?>{
        'teacherName': 'أ. سارة',
        'studentName': 'طالب',
        'createdAt': _FakeTimestamp(DateTime(2026, 10, 1)),
      })!;
      expect(withCreated.requestedAt, DateTime(2026, 10, 1));

      final BookingRequest withoutAny = bookingFromMap('b2', <String, Object?>{
        'teacherName': 'أ. سارة',
        'studentName': 'طالب',
      })!;
      expect(withoutAny.requestedAt.millisecondsSinceEpoch, 0);
      expect(withoutAny.status, BookingStatus.pending);
    });

    test('بلا اسم طالب أو مدرس غير قابل للعرض', () {
      expect(
        bookingFromMap('b1', <String, Object?>{'teacherName': 'أ. سارة'}),
        isNull,
      );
    });
  });

  group('تحويل القوائم', () {
    test('يتجاهل المستندات غير الصالحة ويحفظ الترتيب', () {
      final List<TeacherProfile> teachers = mapDocuments(
        <(String, Map<String, Object?>)>[
          ('t1', <String, Object?>{'displayName': 'أول'}),
          ('bad', <String, Object?>{}),
          ('t2', <String, Object?>{'displayName': 'ثاني'}),
        ],
        teacherProfileFromMap,
      );

      expect(teachers.length, 2);
      expect(teachers.first.displayName, 'أول');
      expect(teachers.last.displayName, 'ثاني');
      expect(() => teachers.add(teachers.first), throwsUnsupportedError);
    });
  });
}
