import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/errors/firebase_error_mapper.dart';
import 'package:teacher_student_app/core/errors/request_timeout.dart';
import 'package:teacher_student_app/data/firebase/firestore_repositories.dart';
import 'package:teacher_student_app/data/migration/account_hidden_backfill.dart';

/// تنفيذ [AccountHiddenBackfillGateway] على Firestore — **للمسؤول فقط**.
///
/// ## لماذا لا يُستدعى من واجهة المستخدم؟
///
/// قراءة كل الملفات وكتابة علم الظهور عليها تصرّف إداري، وقواعد Firestore تسمح
/// به للمسؤول وحده (`isAdmin()` / `isAdminDoc()`)، فيفشل أي استدعاء من حساب
/// عادي بـ`permission-denied` تترجمه [_mapError] إلى رسالة عربية مفهومة.
///
/// ## حدود معروفة (ولذلك الترحيل الحقيقي عبر Admin SDK)
///
/// تحديث إداري على `teacherProfiles` يشترط في القواعد أن تكون **كل** مفاتيح
/// المستند الناتج ضمن `adminDecisionKeys` (انظر `validAdminDecision`). ملف
/// عليه `isFeatured`/`featuredOrder` (مدرس مميز) أو أي حقل قديم خارج القائمة
/// يرفضه الخادم. لا نعدّل القواعد في P29، فالسكربت الخارجي
/// (`tool/migrations/backfill_account_hidden.js`) هو الطريق الموصى به للإنتاج،
/// وهذا التنفيذ يخدم ما تسمح به القواعد (ومنه ملفات المجموعات الظاهرة في
/// الشكوى: لا تمييز عليها).
class FirestoreAccountHiddenBackfill implements AccountHiddenBackfillGateway {
  FirestoreAccountHiddenBackfill({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection(FirestoreCollections.teacherProfiles);

  @override
  Future<List<TeacherProfileFlagRecord>> listTeacherProfiles() async {
    try {
      // بلا فلاتر: نريد **كل** الملفات، بما فيها ما لا يظهر للطلاب.
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await withRequestTimeout(_profiles.get);
      return <TeacherProfileFlagRecord>[
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs)
          TeacherProfileFlagRecord(
            id: doc.id,
            hasAccountHiddenFlag: doc.data().containsKey('accountHidden'),
          ),
      ];
    } on Object catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> setAccountHiddenFalse(String teacherId) async {
    if (teacherId.trim().isEmpty) {
      throw const AppException.invalidInput(
        debugMessage: 'backfill without teacher id',
        overrideMessage: 'معرّف ملف غير صالح.',
      );
    }
    try {
      // حقل واحد فقط. `update` ترفض المستند الغائب — وهو ما نريده: لا نُنشئ
      // ملفات وهمية أثناء الترحيل.
      await withRequestTimeout(
        () => _profiles.doc(teacherId).update(<String, Object?>{
          'accountHidden': false,
        }),
      );
    } on Object catch (error) {
      throw _mapError(error);
    }
  }

  Object _mapError(Object error) {
    if (error is AppException) {
      return error;
    }
    if (error is FirebaseException) {
      return firebaseCodeToException(
        error.code,
        debugMessage: error.message,
      );
    }
    return AppException(
      AppErrorKind.network,
      debugMessage: error.toString(),
      overrideMessage:
          'تعذّر إتمام الترحيل. تحقّق من الاتصال والصلاحيات ثم أعد المحاولة.',
    );
  }
}
