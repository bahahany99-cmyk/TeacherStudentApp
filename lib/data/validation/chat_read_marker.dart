/// (إصلاح 3) تتبّع حالتَي «تعليم القراءة» في المحادثة المباشرة — **منطق نقي**.
///
/// **المشكلة:** تعليم المحادثة مقروءة (مستند `directChats/{id}`) وتعليم
/// **إشعاراتها** مقروءة (`notifications` بحالة `readAt == null`) عمليتان
/// مستقلتان على الخادم. الشاشة كانت تحتفظ بعلم واحد (`_markedReadFor`) يُضبط
/// قبل المحاولة، فإذا نجحت الأولى وفشلت الثانية (شبكة/صلاحيات) لم تُجرَّب
/// الثانية أبدًا: المحادثة صارت مقروءة، فلم يعد شرط «يوجد غير مقروء» يتحقق،
/// وبقي الجرس يعدّ إشعارًا قُرئت رسالته فعلًا.
///
/// **الحل:** حالتان منفصلتان، ولا تُعتبر أي منهما تمّت إلا بعد نجاح عمليتها هي:
///
/// * `_chatMarked` — نجحت كتابة علامة قراءة **المحادثة**.
/// * `_notificationsCleared` — نجحت كتابة **الإشعارات** (`markChatMessagesRead`).
///
/// فشل أي خطوة لا يُثبّت حالتها، فتُعاد المحاولة. ومحاولة واحدة لا تتكرر في كل
/// إعادة بناء: بعد فشل يُغلق الباب (`_awaitingRetry`) حتى **تَسمح** الشاشة
/// بمحاولة جديدة بعد [retryDelay] عبر [allowRetry]. لذلك لا يعتمد المنطق على
/// ساعة جهاز: التوقيت عند الشاشة (مؤقّت)، والحالة هنا حتمية وقابلة للاختبار.
class ChatReadMarker {
  ChatReadMarker({this.retryDelay = const Duration(seconds: 5)});

  /// أقصر فاصل تنتظره الشاشة بين محاولة فاشلة وأخرى — يمنع حلقة كتابة.
  final Duration retryDelay;

  /// المحادثات التي نجح تعليم رسائلها.
  final Set<String> _chatMarked = <String>{};

  /// المحادثات التي نجحت كتابة إشعاراتها.
  final Set<String> _notificationsCleared = <String>{};

  /// المحادثة التي تجري محاولتها الآن (منع تزامن محاولتين لنفس المحادثة).
  String? _inFlightFor;

  /// محادثة فشلت محاولتها وتنتظر إذنًا صريحًا بمحاولة جديدة.
  String? _awaitingRetryFor;

  bool _chatDone(String chatId, bool chatUnread) =>
      !chatUnread || _chatMarked.contains(chatId);

  bool _notificationsDone(String chatId) =>
      _notificationsCleared.contains(chatId);

  /// هل بقي شيء يحتاج كتابة لهذه المحادثة؟
  bool isPending({required String chatId, required bool chatUnread}) =>
      !(_chatDone(chatId, chatUnread) && _notificationsDone(chatId));

  /// هل يجوز أن نبدأ محاولة الآن؟ (لا شيء معلّق، أو محاولة جارية، أو فشل سابق
  /// لم تُسمح بعده محاولة ⇒ لا).
  bool shouldAttempt({required String chatId, required bool chatUnread}) {
    if (!isPending(chatId: chatId, chatUnread: chatUnread)) {
      return false;
    }
    if (_inFlightFor == chatId) {
      return false;
    }
    return _awaitingRetryFor != chatId;
  }

  /// تسمح بمحاولة جديدة بعد فشل — تناديها الشاشة عند انقضاء [retryDelay].
  void allowRetry({required String chatId}) {
    if (_awaitingRetryFor == chatId) {
      _awaitingRetryFor = null;
    }
  }

  /// ينفّذ ما تبقّى بالترتيب: المحادثة أولًا، ثم إشعاراتها — وكل خطوة في
  /// `try` مستقلة حتى لا يُلغي فشل إحداهما الأخرى.
  ///
  /// يعيد `true` إن بقي شيء معلّق (أي: على الشاشة أن تسمح بمحاولة بعد
  /// [retryDelay]).
  Future<bool> run({
    required String chatId,
    required bool chatUnread,
    required Future<void> Function() markChat,
    required Future<void> Function() clearNotifications,
  }) async {
    if (!shouldAttempt(chatId: chatId, chatUnread: chatUnread)) {
      return isPending(chatId: chatId, chatUnread: chatUnread);
    }

    _inFlightFor = chatId;
    try {
      if (!_chatDone(chatId, chatUnread)) {
        try {
          await markChat();
          _chatMarked.add(chatId);
        } catch (_) {
          // أفضل جهد: علامة القراءة ليست شرطًا لعرض الرسائل، وفقدانها بسبب
          // شبكة متعثرة لا يستحق إزعاج المستخدم برسالة خطأ. الحالة **لم**
          // تُثبَّت، فتُعاد المحاولة.
        }
      }

      // الإشعارات لا تُعدّ مقروءة إلا بعد نجاح كتابتها هي، لا بنجاح تعليم
      // المحادثة.
      if (_chatDone(chatId, chatUnread) && !_notificationsDone(chatId)) {
        try {
          await clearNotifications();
          _notificationsCleared.add(chatId);
        } catch (_) {
          // الحالة تبقى غير مكتملة ⇒ محاولة لاحقة.
        }
      }
    } finally {
      _inFlightFor = null;
    }

    final bool pending = isPending(chatId: chatId, chatUnread: chatUnread);
    // فشل ⇒ الباب مغلق حتى تسمح الشاشة. نجاح كامل ⇒ لا شيء ينتظر.
    _awaitingRetryFor = pending ? chatId : null;
    return pending;
  }
}
