import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/teacher_profile_draft.dart';

/// (P18) كتابة ملف المدرس — على التنفيذ التجريبي (نفس العقد الذي ينفّذه
/// Firestore). الهدف: تثبيت القواعد التي لا يجوز أن ينحرف عنها أي تنفيذ.
void main() {
  TeacherProfileDraft draft({
    String name = 'أ. منى عبد الرحمن',
    String bio = 'مدرسة رياضيات بخبرة عشر سنوات في المناهج المصرية.',
    String uid = 'uid-new-teacher',
  }) {
    return TeacherProfileDraft(
      displayName: name,
      subject: 'الرياضيات',
      stage: 'الثانوية العامة',
      area: 'المعادي',
      bio: bio,
      isOnline: true,
      priceHint: '150 ج.م',
      // (P22) الصورة إلزامية: كل ملف مدرس يحمل مسار صورته.
      photoPath: TeacherProfile.photoPathFor(uid),
    );
  }

  group('TeacherProfileDraft — الحقول الإلزامية (P23)', () {
    test('الاسم/المادة/المرحلة الفارغة تُبلَّغ برسالة عربية محددة', () {
      const TeacherProfileDraft empty = TeacherProfileDraft(
        displayName: 'أ. سارة',
        subject: '',
        stage: '',
        area: 'القاهرة',
        bio: 'نبذة كافية للاختبار هنا.',
      );

      expect(empty.academicProblem, 'أدخل المادة');
    });

    test('مرحلة فارغة بعد مادة صالحة تُبلَّغ باسمها', () {
      const TeacherProfileDraft noStage = TeacherProfileDraft(
        displayName: 'أ. سارة',
        subject: 'الفيزياء',
        stage: ' ',
        area: 'القاهرة',
        bio: 'نبذة كافية للاختبار هنا.',
      );

      expect(noStage.academicProblem, contains('المرحلة'));
    });

    test('قيمة مخصّصة صالحة تمرّ (2..40)', () {
      const TeacherProfileDraft custom = TeacherProfileDraft(
        displayName: 'أ. سارة',
        subject: 'العلوم المتكاملة',
        stage: 'رياض الأطفال',
        area: 'القاهرة',
        bio: 'نبذة كافية للاختبار هنا.',
      );

      expect(custom.academicProblem, isNull);
    });

    test('أكثر من 40 حرفًا مرفوض بنفس حد القواعد', () {
      final TeacherProfileDraft long = TeacherProfileDraft(
        displayName: 'أ. سارة',
        subject: 'ر'.padRight(41, 'ي'),
        stage: 'الثانوية العامة',
        area: 'القاهرة',
        bio: 'نبذة كافية للاختبار هنا.',
      );

      expect(long.academicProblem, contains('طويل'));
    });
  });

  group('TeacherProfileDraft', () {
    test('الفراغ يُطبَّع إلى حذف المفتاح لا سلسلة فارغة', () {
      const TeacherProfileDraft empty = TeacherProfileDraft(
        displayName: 'أ. سارة',
        subject: 'الفيزياء',
        stage: 'الثانوية العامة',
        area: 'القاهرة',
        bio: 'نبذة كافية للاختبار هنا.',
        priceHint: '   ',
        governorate: '',
        photoPath: 'avatars/uid-x',
      );

      final Map<String, Object?> map = empty.toWriteMap();
      expect(map.containsKey('priceHint'), isFalse);
      expect(map.containsKey('governorate'), isFalse);
      // الحقول الإدارية لا تُكتب أبدًا من النموذج.
      expect(map.containsKey('status'), isFalse);
      expect(map.containsKey('ownerId'), isFalse);
      expect(map.containsKey('isFeatured'), isFalse);
    });

    test('fromProfile يعيد نفس الحقول الوصفية', () {
      final TeacherProfile profile = TeacherProfile(
        id: 't1',
        displayName: 'أ. هدى',
        subject: 'الكيمياء',
        stage: 'الثانوية العامة',
        area: 'أسيوط',
        bio: 'نبذة اختبارية كافية الطول.',
        status: TeacherProfileStatus.verified,
        isOnline: false,
        governorate: 'أسيوط',
        district: 'الوليدية',
        priceHint: '120 ج.م',
      );

      final TeacherProfileDraft from = TeacherProfileDraft.fromProfile(
        profile,
      );
      expect(from.displayName, 'أ. هدى');
      expect(from.governorate, 'أسيوط');
      expect(from.district, 'الوليدية');
      expect(from.isOnline, isFalse);
    });
  });

  group('حفظ الملف (العقد)', () {
    test('ملف جديد يبدأ «قيد المراجعة» ولا يظهر للطلاب', () async {
      final DemoTeacherRepository repo = DemoTeacherRepository();
      const String uid = 'uid-new-teacher';

      final TeacherProfile saved = await repo.saveMyProfile(
        uid: uid,
        draft: draft(name: 'أ. مدرس جديد'),
      );

      expect(saved.id, uid);
      expect(saved.status, TeacherProfileStatus.pendingReview);
      expect(saved.isVisibleToStudents, isFalse);

      // لا يظهر في البحث ولا للطلاب قبل التوثيق…
      final List<TeacherProfile> verified = await repo.listVerified();
      expect(verified.any((TeacherProfile t) => t.id == uid), isFalse);
      // …لكن صاحبه يراه دائمًا.
      final TeacherProfile? mine = await repo.findMine(uid);
      expect(mine?.displayName, 'أ. مدرس جديد');
    });

    test('التعديل يحفظ الحقول الوصفية ويعيد الملف للمراجعة', () async {
      final DemoTeacherRepository repo = DemoTeacherRepository();
      final TeacherProfile? original = await repo.findMine('demo-teacher-1');
      expect(original, isNotNull);
      expect(original!.status, TeacherProfileStatus.verified);

      final TeacherProfile saved = await repo.saveMyProfile(
        uid: 'demo-teacher-1',
        draft: draft(name: 'اسم محدَّث'),
      );

      expect(saved.displayName, 'اسم محدَّث');
      expect(saved.subject, 'الرياضيات');
      // (P22) تعديل ملف موثّق = إعادة تحقق: يعود `pendingReview` حتى تراجعه
      // الإدارة، ولا يبقى ظاهرًا للطلاب بتوثيق قديم.
      expect(saved.status, TeacherProfileStatus.pendingReview);
      expect(saved.isVisibleToStudents, isFalse);
      // الحقول التي يملكها الخادم/الإدارة لا تتغيّر بالحفظ.
      expect(saved.isFeatured, original.isFeatured);
      expect(saved.rating, original.rating);
    });

    test('ملف بلا صورة مرفوض قبل أي كتابة (P22)', () async {
      final DemoTeacherRepository repo = DemoTeacherRepository();
      const String uid = 'uid-no-photo';

      await expectLater(
        repo.saveMyProfile(
          uid: uid,
          draft: const TeacherProfileDraft(
            displayName: 'أ. بلا صورة',
            subject: 'الرياضيات',
            stage: 'الثانوية العامة',
            area: 'المعادي',
            bio: 'نبذة كافية للاختبار هنا بلا صورة.',
          ),
        ),
        throwsA(
          isA<AppException>().having(
            (AppException error) => error.kind,
            'kind',
            AppErrorKind.invalidInput,
          ),
        ),
      );

      // لم يُنشأ ملف: الرفض قبل الكتابة لا بعدها.
      expect(await repo.findMine(uid), isNull);
    });

    test('ملف بلا مادة أو بلا مرحلة مرفوض قبل أي كتابة (P23)', () async {
      final DemoTeacherRepository repo = DemoTeacherRepository();

      // المادة فارغة.
      await expectLater(
        repo.saveMyProfile(
          uid: 'uid-no-subject',
          draft: TeacherProfileDraft(
            displayName: 'أ. بلا مادة',
            subject: '   ',
            stage: 'الثانوية العامة',
            area: 'المعادي',
            bio: 'نبذة كافية للاختبار هنا بلا مادة.',
            photoPath: TeacherProfile.photoPathFor('uid-no-subject'),
          ),
        ),
        throwsA(
          isA<AppException>().having(
            (AppException error) => error.overrideMessage ?? '',
            'رسالة',
            contains('المادة'),
          ),
        ),
      );

      // المرحلة حرف واحد: أقل من الحد الأدنى (نفس حد القواعد).
      await expectLater(
        repo.saveMyProfile(
          uid: 'uid-bad-stage',
          draft: TeacherProfileDraft(
            displayName: 'أ. بمرحلة قصيرة',
            subject: 'الرياضيات',
            stage: 'ث',
            area: 'المعادي',
            bio: 'نبذة كافية للاختبار هنا بمرحلة قصيرة.',
            photoPath: TeacherProfile.photoPathFor('uid-bad-stage'),
          ),
        ),
        throwsA(isA<AppException>()),
      );

      // لا مستندات أُنشئت: الرفض قبل الكتابة.
      expect(await repo.findMine('uid-no-subject'), isNull);
      expect(await repo.findMine('uid-bad-stage'), isNull);
    });

    test('الصورة تُحفظ في الملف وتُعاد معه', () async {
      final DemoTeacherRepository repo = DemoTeacherRepository();

      final TeacherProfile saved = await repo.saveMyProfile(
        uid: 'uid-with-photo',
        draft: draft(uid: 'uid-with-photo'),
      );

      expect(saved.hasPhoto, isTrue);
      expect(saved.photoPath, TeacherProfile.photoPathFor('uid-with-photo'));
    });

    test('تفريغ حقل اختياري يمحوه فعلًا (لا يُبقي القديم)', () async {
      final DemoTeacherRepository repo = DemoTeacherRepository();
      const String uid = 'uid-blank-price';

      await repo.saveMyProfile(uid: uid, draft: draft());
      final TeacherProfile withPrice = (await repo.findMine(uid))!;
      expect(withPrice.priceHint, '150 ج.م');

      final TeacherProfile cleared = await repo.saveMyProfile(
        uid: uid,
        draft: const TeacherProfileDraft(
          displayName: 'أ. منى عبد الرحمن',
          subject: 'الرياضيات',
          stage: 'الثانوية العامة',
          area: 'المعادي',
          bio: 'مدرسة رياضيات بخبرة عشر سنوات في المناهج المصرية.',
          isOnline: true,
          photoPath: 'avatars/uid-blank-price',
          // السعر فارغ: يجب أن يُمحى.
        ),
      );

      expect(cleared.priceHint, isNull);
    });
  });
}
