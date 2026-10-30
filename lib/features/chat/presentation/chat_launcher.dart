import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/direct_chat_rules.dart';

/// مداخل المحادثة المباشرة (P11).
///
/// كل مدخل يمرّ بالمسار نفسه:
/// 1. إن كانت هناك محادثة قائمة بين الطرفين → تُفتح فورًا (تُحترم العلاقة
///    القائمة حتى لو أطفأ المدرس الاستفسارات لاحقًا).
/// 2. وإلا يُحدَّد الأصل: حجز قائم، أو عضوية مجموعة، أو استفسار يسمح به
///    المدرس صراحةً.
/// 3. وإن لم يكن أي أصل متاحًا → رسالة عربية تشرح السبب، لا زر بلا أثر.
Future<void> openChatWithTeacher(
  BuildContext context, {
  required String teacherId,
  required String teacherName,
  String? subject,
}) async {
  final AppServices services = AppServicesScope.of(context);
  final SessionController session = SessionScope.read(context);

  if (session.role != UserRole.student) {
    AppSnackBar.show(
      context,
      'هذه الخدمة للطلاب؛ المدرس يردّ من شاشة المحادثات في حسابه.',
      type: AppMessageType.info,
    );
    return;
  }

  final String studentId = CurrentStudent.idOf(session);
  final String studentName = CurrentStudent.nameOf(session);

  try {
    final String chatId = DirectChat.idFor(
      teacherId: teacherId,
      studentId: studentId,
    );
    final DirectChat? existing = await services.chats.findById(chatId);
    if (!context.mounted) {
      return;
    }
    if (existing != null) {
      await _pushChat(context, existing.id);
      return;
    }

    // هل هناك حجز قائم؟ إن وُجد فالأصل «حجز» لا «استفسار» — أدق للسجل.
    final List<BookingRequest> bookings = await services.bookings.listMine();
    BookingRequest? booking;
    for (final BookingRequest candidate in bookings) {
      final bool sameTeacher = candidate.teacherId == teacherId;
      final bool usable =
          candidate.status != BookingStatus.rejected &&
          candidate.status != BookingStatus.cancelled &&
          candidate.status != BookingStatus.cancelledLate;
      if (sameTeacher && usable) {
        booking = candidate;
        break;
      }
    }

    if (!context.mounted) {
      return;
    }

    final bool allowed = await services.chats.allowDirectMessages(teacherId);
    if (!context.mounted) {
      return;
    }

    final String? blocked = DirectChatRules.startBlockedReason(
      viewerId: studentId,
      hasBooking: booking != null,
      isGroupMember: false,
      allowDirectMessages: allowed,
    );
    if (blocked != null) {
      AppSnackBar.show(context, blocked, type: AppMessageType.warning);
      return;
    }

    final DirectChat chat = await services.chats.openChat(
      teacherId: teacherId,
      teacherName: teacherName,
      studentId: studentId,
      studentName: studentName,
      origin: booking == null
          ? DirectChatOrigin.inquiry
          : DirectChatOrigin.booking,
      subject: booking?.subject ?? subject,
      bookingId: booking?.id,
    );
    if (!context.mounted) {
      return;
    }
    await _pushChat(context, chat.id);
  } on AppException catch (error) {
    if (!context.mounted) {
      return;
    }
    AppSnackBar.show(
      context,
      error.overrideMessage ?? error.message,
      type: AppMessageType.error,
    );
  }
}

/// (P24) يفتح — أو يُنشئ — خيط المحادثة المرتبط بطلب انضمام أرسله الطالب.
///
/// **المشكلة التي يحلّها:** بعد إرسال طلب انضمام (وقبل قبوله) لم يكن للطالب أي
/// طريق لمراسلة المدرس: `group` يشترط عضوية مقبولة، و`inquiry` يشترط أن يفعّل
/// المدرس استقبال الرسائل. النتيجة «لا توجد محادثات» رغم وجود طلب قائم.
///
/// الخيط يُنشأ بأصل `joinRequest`، ويسنده على الخادم مستند الطلب نفسه
/// (`groupJoinRequests/{groupId}_{studentId}`) بحالة `pending` أو `accepted`.
///
/// تُعيد `true` إن فُتحت المحادثة، و`false` إن تعذّر (بعد عرض السبب للمستخدم).
Future<bool> openChatForJoinRequest(
  BuildContext context, {
  required StudyGroup group,
  required GroupJoinRequest request,
}) async {
  final AppServices services = AppServicesScope.of(context);
  final SessionController session = SessionScope.read(context);

  if (session.role != UserRole.student) {
    AppSnackBar.show(
      context,
      'المحادثة مع الطالب تُفتح من صفّه في «طلبات الانضمام».',
      type: AppMessageType.info,
    );
    return false;
  }

  try {
    final DirectChat chat = await services.chats.openChat(
      teacherId: group.teacherId,
      teacherName: group.teacherName,
      studentId: CurrentStudent.idOf(session),
      studentName: CurrentStudent.nameOf(session),
      origin: DirectChatOrigin.joinRequest,
      subject: group.subject,
      groupId: group.id,
    );
    if (!context.mounted) {
      return false;
    }
    await _pushChat(context, chat.id);
    return true;
  } on AppException catch (error) {
    if (!context.mounted) {
      return false;
    }
    AppSnackBar.show(
      context,
      error.overrideMessage ?? error.message,
      type: AppMessageType.warning,
    );
    return false;
  }
}

/// محادثة مرتبطة بطلب حجز — من شاشة التفاصيل.
Future<void> openChatForBooking(
  BuildContext context,
  BookingRequest booking,
) async {
  final AppServices services = AppServicesScope.of(context);
  final SessionController session = SessionScope.read(context);
  final bool isTeacher = session.role == UserRole.teacher;

  final String studentId = booking.studentId ?? CurrentStudent.idOf(session);
  final String teacherId = booking.teacherId ?? CurrentTeacher.idOf(session);
  final String studentName = booking.studentName;
  final String teacherName = booking.teacherName;

  // الطرف الذي يفتح الشاشة يجب أن يكون طرفًا في الحجز.
  final String viewerId = isTeacher
      ? CurrentTeacher.idOf(session)
      : CurrentStudent.idOf(session);
  if (viewerId != teacherId && viewerId != studentId) {
    AppSnackBar.show(
      context,
      'هذا الحجز ليس لك، فلا يمكن فتح محادثته.',
      type: AppMessageType.error,
    );
    return;
  }

  try {
    final DirectChat chat = await services.chats.openChat(
      teacherId: teacherId,
      teacherName: teacherName,
      studentId: studentId,
      studentName: studentName,
      origin: DirectChatOrigin.booking,
      subject: booking.subject,
      bookingId: booking.id,
    );
    if (!context.mounted) {
      return;
    }
    await _pushChat(context, chat.id);
  } on AppException catch (error) {
    if (!context.mounted) {
      return;
    }
    AppSnackBar.show(
      context,
      error.overrideMessage ?? error.message,
      type: AppMessageType.error,
    );
  }
}

Future<void> _pushChat(BuildContext context, String chatId) {
  return Navigator.of(
    context,
  ).pushNamed(RoutePaths.directChat, arguments: chatId);
}

/// زر يفتح المحادثة ويعطّل نفسه أثناء العمل (التحقق قد يقرأ الخادم).
class ChatActionButton extends StatefulWidget {
  const ChatActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.forum_outlined,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final bool filled;

  /// تُستدعى مرة واحدة لكل ضغطة، والزر يبقى معطّلًا حتى تنتهي.
  final Future<void> Function(BuildContext context) onPressed;

  @override
  State<ChatActionButton> createState() => _ChatActionButtonState();
}

class _ChatActionButtonState extends State<ChatActionButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed(context);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget icon = _busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(widget.icon, size: 18);

    if (widget.filled) {
      return FilledButton.icon(
        onPressed: _busy ? null : _run,
        icon: icon,
        label: Text(widget.label),
      );
    }
    return OutlinedButton.icon(
      onPressed: _busy ? null : _run,
      icon: icon,
      label: Text(widget.label),
    );
  }
}

/// (P28) يضمن وجود خيط محادثة لطلب حجز **بلا فتح شاشة وبلا رسائل**.
///
/// ## العطل الذي أُصلح
///
/// الخيط لم يكن يُنشأ إلا حين يضغط الطالب «مراسلة المدرس» بنفسه. فالمدرس الذي
/// وصله طلب حجز حديثًا لا يجد في «المحادثات» أي صف — لأن الصف يمثّل مستند
/// محادثة لم يُكتب بعد. النتيجة: «المحادثات لا تظهر عند المدرس» رغم وجود علاقة
/// حقيقية (حجز قائم). الآن يُنشأ الخيط لحظة إرسال الطلب (الطالب هو من يملك
/// الصلاحية بحسب القواعد)، فيراه الطرفان في قائمتهما فورًا.
///
/// **لا يغيّر السياسة:** الأصل `booking` ما زال يتحقق منه الخادم من مستند
/// الحجز نفسه. الفشل هنا صامت عن قصد (لا رسالة خطأ): إرسال الطلب نجح، وإنشاء
/// الخيط التجميلي لا يجوز أن يُقلق الطالب أو يظهر كخطأ في عملية ناجحة.
Future<void> ensureThreadForBooking({
  required AppServices services,
  required BookingRequest booking,
}) async {
  try {
    await services.chats.openChat(
      teacherId: booking.teacherId ?? '',
      teacherName: booking.teacherName,
      studentId: booking.studentId ?? '',
      studentName: booking.studentName,
      origin: DirectChatOrigin.booking,
      subject: booking.subject,
      bookingId: booking.id,
    );
  } on AppException {
    // لا شيء: الخيط اختياري، والطلب نفسه حُفظ بنجاح.
  }
}

/// (P28) نفس المبدأ لطلب الانضمام: يُنشأ الخيط بأصل `joinRequest` بعد إرسال
/// الطلب، فيرى المدرس صفًّا في المحادثات يستطيع الردّ منه مباشرة.
Future<void> ensureThreadForJoinRequest({
  required AppServices services,
  required StudyGroup group,
  required GroupJoinRequest request,
}) async {
  try {
    await services.chats.openChat(
      teacherId: group.teacherId,
      teacherName: group.teacherName,
      studentId: request.studentId,
      studentName: request.studentName,
      origin: DirectChatOrigin.joinRequest,
      subject: group.subject,
      groupId: group.id,
    );
  } on AppException {
    // اختياري كما في الحجز.
  }
}
