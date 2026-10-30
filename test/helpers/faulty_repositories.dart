import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/teacher_filter.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/teacher_rating.dart';
import 'package:teacher_student_app/data/models/teacher_review.dart';
import 'package:teacher_student_app/data/models/user_role.dart';

/// حقن أعطال في المستودعات التجريبية (P16).
///
/// الغرض اختبار سلوك الشاشات عند **فشل الخادم**: انقطاع الشبكة، انقطاع البثّ،
/// ورفض الصلاحية. لا نضيف أي «وضع فشل» إلى كود الإنتاج: التنفيذ التجريبي يبقى
/// نظيفًا، والعطل يُحقن من الاختبار بوراثة المستودع التجريبي وتجاوز دالة واحدة.
///
/// الاستخدام:
/// ```dart
/// final FaultPlan plan = FaultPlan();
/// services = AppServices(teachers: FaultyTeacherRepository(plan: plan), …);
/// // اجعل كل استدعاء يفشل ثم أوقف العطل قبل «إعادة المحاولة»:
/// plan.alwaysFail = false;
/// ```
enum FaultMode {
  /// انقطاع شبكة (المتوقع في معظم الحالات).
  network,

  /// المستخدم لا يملك صلاحية (قاعدة رفضت العملية).
  permission,
}

/// خطّة عطل قابلة للتعديل أثناء الاختبار.
class FaultPlan {
  FaultPlan({
    this.mode = FaultMode.network,
    this.failuresLeft = 0,
    this.alwaysFail = true,
  });

  /// عطل واحد ثم تعود الخدمة (لاختبار «إعادة المحاولة» التي تنجح).
  factory FaultPlan.once({FaultMode mode = FaultMode.network}) =>
      FaultPlan(mode: mode, failuresLeft: 1, alwaysFail: false);

  FaultMode mode;

  /// كم استدعاءً إضافيًا يفشل قبل أن تعمل الخدمة.
  int failuresLeft;

  /// كل الاستدعاءات تفشل ما دامت `true` (وضع «الشبكة مقطوعة تمامًا»).
  bool alwaysFail;

  /// عدد الاستدعاءات التي وصلت إلى المستودع — يُستخدم للتحقق من إعادة المحاولة.
  int calls = 0;

  /// هل يفشل هذا الاستدعاء؟ (يسجّل الاستدعاء دائمًا).
  bool take() {
    calls++;
    if (alwaysFail) {
      return true;
    }
    if (failuresLeft > 0) {
      failuresLeft--;
      return true;
    }
    return false;
  }

  AppException get exception => switch (mode) {
    FaultMode.network => const AppException.network(
      debugMessage: 'fault injected (network)',
    ),
    FaultMode.permission => const AppException.permission(
      debugMessage: 'fault injected (permission)',
    ),
  };
}

/// مدرسون: أعطال في القراءة والبحث.
class FaultyTeacherRepository extends DemoTeacherRepository {
  FaultyTeacherRepository({required this.plan, super.source});

  final FaultPlan plan;

  @override
  Future<List<TeacherProfile>> listVerified() async {
    if (plan.take()) {
      throw plan.exception;
    }
    return super.listVerified();
  }

  @override
  Future<List<TeacherProfile>> listFeatured() async {
    if (plan.take()) {
      throw plan.exception;
    }
    return super.listFeatured();
  }

  @override
  Future<TeacherSearchResult> search(TeacherFilter filter) async {
    if (plan.take()) {
      throw plan.exception;
    }
    return super.search(filter);
  }
}

/// حجوزات: أعطال في الإنشاء والقرار.
class FaultyBookingRepository extends DemoBookingRepository {
  FaultyBookingRepository({required this.plan, super.source, super.notifications});

  final FaultPlan plan;

  @override
  Future<BookingRequest> createRequest({
    required String teacherId,
    required String teacherName,
    required String studentId,
    required String studentName,
    required String subject,
    required DateTime startsAt,
    required int durationMinutes,
    String? note,
  }) async {
    if (plan.take()) {
      throw plan.exception;
    }
    return super.createRequest(
      teacherId: teacherId,
      teacherName: teacherName,
      studentId: studentId,
      studentName: studentName,
      subject: subject,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
      note: note,
    );
  }

  @override
  Future<BookingRequest> decideRequest({
    required BookingRequest request,
    required String teacherId,
    required bool approve,
  }) async {
    if (plan.take()) {
      throw plan.exception;
    }
    return super.decideRequest(
      request: request,
      teacherId: teacherId,
      approve: approve,
    );
  }
}

/// محادثات: انقطاع البثّ وفشل الإرسال.
class FaultyDirectChatRepository extends DemoDirectChatRepository {
  FaultyDirectChatRepository({
    required this.plan,
    super.source,
    super.messages,
    super.settings,
    super.notifications,
    super.findBooking,
    super.isMember,
  });

  final FaultPlan plan;

  @override
  Stream<List<DirectChatMessage>> watchMessages(String chatId) {
    // عطل البثّ مربوط بـ`alwaysFail` وحده: عدّاد الطلبات مخصّص للعمليات
    // (الإرسال/الفتح)، ولو استهلكه الاشتراك لفشل الإرسال اللاحق بلا سبب.
    if (plan.alwaysFail) {
      // خطأ في التدفّق نفسه: هذا ما يحدث فعلًا عند سقوط الشبكة أثناء البثّ.
      return Stream<List<DirectChatMessage>>.error(plan.exception);
    }
    return super.watchMessages(chatId);
  }

  @override
  Future<DirectChatMessage> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required UserRole senderRole,
    required String text,
    String? imageId,
  }) async {
    if (plan.take()) {
      throw plan.exception;
    }
    return super.sendMessage(
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      text: text,
      imageId: imageId,
    );
  }
}

/// تقييمات: انقطاع البثّ وفشل الإرسال.
class FaultyReviewRepository extends DemoReviewRepository {
  FaultyReviewRepository({required this.plan, super.source, super.findBooking});

  final FaultPlan plan;

  @override
  Stream<List<TeacherReview>> watchForTeacher(String teacherId) {
    if (plan.alwaysFail) {
      return Stream<List<TeacherReview>>.error(plan.exception);
    }
    return super.watchForTeacher(teacherId);
  }

  @override
  Stream<TeacherRating> watchRating(String teacherId) {
    if (plan.alwaysFail) {
      return Stream<TeacherRating>.error(plan.exception);
    }
    return super.watchRating(teacherId);
  }

  @override
  Future<TeacherReview> submit({
    required BookingRequest booking,
    required String studentId,
    required int rating,
    String? comment,
  }) async {
    if (plan.take()) {
      throw plan.exception;
    }
    return super.submit(
      booking: booking,
      studentId: studentId,
      rating: rating,
      comment: comment,
    );
  }
}
