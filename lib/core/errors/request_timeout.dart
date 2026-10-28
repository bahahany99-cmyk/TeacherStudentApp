import 'dart:async';

import 'package:teacher_student_app/core/errors/app_exception.dart';

/// مهلة الطلب الافتراضية (P16).
///
/// Firestore يعيد المحاولة تلقائيًا عند انقطاع الشبكة، فقد يبقى الطلب معلّقًا
/// دقائق بلا نتيجة: الشاشة تظل «تحميل» بلا نهاية، والمستخدم لا يعرف أن عليه
/// التحرك. حدٌّ زمني صريح يحوّل الانتظار الصامت إلى رسالة عربية + «إعادة
/// المحاولة».
///
/// 20 ثانية: أطول من أي طلب طبيعي على شبكة هاتف، وأقصر من صبر مستخدم أمام
/// شاشة تحميل.
const Duration kRequestTimeout = Duration(seconds: 20);

/// ينفّذ [action] بمهلة، ويحوّل انتهاءها إلى [AppException] شبكي.
///
/// **لماذا هنا لا في كل مستودع؟** لأن السلوك يجب أن يكون واحدًا في كل
/// الشاشات؛ تكرار `.timeout` في كل دالة ينسى واحدة منهنّ فتبقى معلّقة.
///
/// الأخطاء الأخرى تمرّ كما هي: التحويل إلى رسائل عربية مسؤولية
/// `firebaseCodeToException`/`toAppException`، لا هذه الدالة.
Future<T> withRequestTimeout<T>(
  Future<T> Function() action, {
  Duration timeout = kRequestTimeout,
}) async {
  try {
    return await action().timeout(timeout);
  } on TimeoutException {
    // لا نكشف مدة المهلة ولا اسم الخدمة: المستخدم يحتاج ما يفعله الآن.
    throw const AppException.network(
      debugMessage: 'request timed out',
      overrideTitle: 'انتهت مهلة الاتصال',
      overrideMessage:
          'لم يصل ردّ من الخادم في الوقت المتوقع. تحقّق من الاتصال ثم أعد '
          'المحاولة.',
    );
  }
}
