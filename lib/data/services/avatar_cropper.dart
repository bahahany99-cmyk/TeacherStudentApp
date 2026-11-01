import 'package:flutter/widgets.dart';

import 'package:teacher_student_app/data/services/image_picker_gateway.dart';

/// عرض شاشة قصّ الصورة (P31) كعقد قابل للاستبدال.
///
/// **لماذا عقد؟** لأن شاشة القصّ تفكّ ترميز الصورة عبر `dart:ui`، وهذا لا يكتمل
/// داخل اختبار ويدجت إلا بـ`runAsync` (فخّ مقيس في هذا المشروع: انظر
/// `test/unit/app_icon_assets_test.dart`). بعقد صغير تحقن اختبارات التدفّق
/// عرضًا وهميًا (تمرير/إلغاء) فتبقى **حتمية**، بينما التطبيق الحقيقي يعرض
/// الشاشة الفعلية. هذا لا يغيّر سلوك الإنتاج: القيمة الافتراضية هي الشاشة
/// الحقيقية.
typedef AvatarCropPresenter =
    Future<PickedImage?> Function(BuildContext context, PickedImage source);
