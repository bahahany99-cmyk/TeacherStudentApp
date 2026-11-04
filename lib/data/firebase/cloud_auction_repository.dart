import 'package:cloud_functions/cloud_functions.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/errors/request_timeout.dart';
import 'package:teacher_student_app/data/models/weekly_auction.dart';
import 'package:teacher_student_app/data/services/auction_repository.dart';

/// تنفيذ [AuctionRepository] على **Cloud Functions** — لا قراءة Firestore مباشرة.
///
/// **لماذا كل شيء عبر الدوال؟**
///   - المزايدة تحتاج قراءة-ثم-كتابة ذرّية على مستند الدورة + مزايدة المدرّس +
///     بصمة الطلب. هذا لا يُؤمَّن من عميل.
///   - القواعد تمنع قراءة مستند الدورة أصلًا (يحمل `highestBid` وعدد
///     المزايدين)، فحتى العرض يمرّ من دالة تُنقّي البيانات قبل إرجاعها.
///   - النتائج العامة تُقرأ من `featuredAuctionResults` بدل استعلام يحتاج فهرسًا
///     ويُعيد مستندات ماضية لا تخصّ العرض الحالي.
///
/// **المنطقة:** الدوال منشورة في `europe-west1` (قريبة من مصر)؛ نداء بمنطقة
/// أخرى يردّ `not-found`. الثابت [_region] هو المصدر الوحيد لهذه القيمة.
class CloudAuctionRepository implements AuctionRepository {
  CloudAuctionRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: _region);

  /// يجب أن يطابق `setGlobalOptions({ region })` في `functions/index.js`.
  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  /// ينادي دالة ويُعيد خريطتها، ويترجم أخطاءها إلى [AppException] عربية.
  Future<Map<Object?, Object?>> _call(
    String name, [
    Map<String, Object?>? payload,
  ]) async {
    try {
      final HttpsCallableResult<Object?> result = await withRequestTimeout(
        () => _functions.httpsCallable(name).call<Object?>(payload),
      );
      final Object? data = result.data;
      return data is Map ? data : const <Object?, Object?>{};
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsError(error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(
        AppErrorKind.network,
        debugMessage: error.toString(),
        overrideMessage:
            'تعذّر الوصول إلى خادم المزاد. تحقّق من الاتصال ثم أعد المحاولة.',
      );
    }
  }

  /// يحوّل خطأ الدالة إلى رسالة مفهومة.
  ///
  /// الرسائل العربية تأتي **من الخادم** (`HttpsError(message)`)، فنعرضها كما هي
  /// إن كانت مقصودة للمستخدم. ولا نعرض `internal` بتفاصيله أبدًا.
  AppException _mapFunctionsError(FirebaseFunctionsException error) {
    final String? serverMessage = error.message?.trim();
    final bool hasServerMessage =
        serverMessage != null && serverMessage.isNotEmpty && _looksArabic(serverMessage);

    switch (error.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return AppException(
          AppErrorKind.permission,
          debugMessage: error.message,
          overrideMessage: hasServerMessage ? serverMessage : null,
        );
      case 'invalid-argument':
      case 'failed-precondition':
        return AppException(
          AppErrorKind.invalidInput,
          debugMessage: error.message,
          overrideMessage: hasServerMessage ? serverMessage : null,
        );
      case 'unavailable':
      case 'deadline-exceeded':
      case 'not-found':
        return AppException(
          AppErrorKind.unavailable,
          debugMessage: error.message,
          overrideMessage: hasServerMessage ? serverMessage : null,
        );
      case 'internal':
        return AppException(
          AppErrorKind.unknown,
          debugMessage: error.message,
          overrideMessage: 'تعذّر إتمام العملية في المزاد. أعد المحاولة لاحقًا.',
        );
      default:
        return AppException(
          AppErrorKind.unknown,
          debugMessage: '${error.code}: ${error.message}',
          overrideMessage: hasServerMessage ? serverMessage : null,
        );
    }
  }

  /// هل النص عربي؟ (نتجنّب عرض رسائل إنجليزية تقنية للمستخدم)
  static bool _looksArabic(String value) {
    for (final int rune in value.runes) {
      if (rune >= 0x0600 && rune <= 0x06FF) return true;
    }
    return false;
  }

  @override
  Future<AuctionState> loadMyState() async {
    final Map<Object?, Object?> data = await _call('myAuctionState');
    return AuctionState.fromMap(data);
  }

  @override
  Future<AuctionBidOutcome> placeBid({
    required AuctionCategory category,
    required int amount,
    required String requestId,
  }) async {
    final Map<Object?, Object?> data = await _call('placeBid', <String, Object?>{
      'category': category.wireName,
      'amount': amount,
      'requestId': requestId,
    });
    return AuctionBidOutcome.fromMap(data);
  }

  @override
  Future<Map<AuctionCategory, AuctionResultsView?>> loadPublishedResults() async {
    final Map<Object?, Object?> data = await _call('featuredAuctionResults');
    final Object? categories = data['categories'];
    final Map<AuctionCategory, AuctionResultsView?> result =
        <AuctionCategory, AuctionResultsView?>{};
    for (final AuctionCategory category in AuctionCategory.values) {
      result[category] = categories is Map
          ? AuctionResultsView.fromMap(categories[category.wireName])
          : null;
    }
    return result;
  }

  @override
  Future<AuctionAdminOverview> loadAdminOverview({String? cycleKey}) async {
    final Map<Object?, Object?> data = await _call(
      'adminAuctionOverview',
      cycleKey == null ? null : <String, Object?>{'cycleKey': cycleKey},
    );
    return AuctionAdminOverview.fromMap(data);
  }

  @override
  Future<void> updateConfig(AuctionConfig config) async {
    await _call('adminUpdateAuctionConfig', config.toMap());
  }

  @override
  Future<void> ensureCycles() async {
    await _call('adminEnsureWeeklyCycles');
  }

  @override
  Future<void> finalizeAuction({
    required String cycleKey,
    required AuctionCategory category,
  }) async {
    await _call('adminFinalizeAuction', _cycleEvent(cycleKey, category));
  }

  @override
  Future<void> confirmWinnerPayment({
    required String cycleKey,
    required AuctionCategory category,
    required String teacherId,
    required bool paid,
    String? note,
  }) async {
    await _call('adminConfirmWinnerPayment', <String, Object?>{
      ..._cycleEvent(cycleKey, category),
      'teacherId': teacherId,
      'paid': paid,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  @override
  Future<void> runReplacement({
    required String cycleKey,
    required AuctionCategory category,
  }) async {
    await _call('adminRunReplacement', _cycleEvent(cycleKey, category));
  }

  @override
  Future<void> publishFeatured({
    required String cycleKey,
    required AuctionCategory category,
  }) async {
    await _call('adminPublishFeatured', _cycleEvent(cycleKey, category));
  }

  @override
  Future<void> expireFeatured({
    required String cycleKey,
    required AuctionCategory category,
  }) async {
    await _call('adminExpireFeatured', _cycleEvent(cycleKey, category));
  }

  /// الحمولة المشتركة لكل عملية إدارية على دورة بعينها.
  ///
  /// الخادم يبني `auctionId` بنفسه من (الأسبوع، الفئة) ولا يقبل معرّفًا جاهزًا،
  /// فلا يمكن توجيه إجراء إلى مستند آخر.
  static Map<String, Object?> _cycleEvent(
    String cycleKey,
    AuctionCategory category,
  ) => <String, Object?>{'cycleKey': cycleKey, 'category': category.wireName};
}
