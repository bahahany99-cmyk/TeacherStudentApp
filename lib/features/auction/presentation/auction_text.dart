import 'package:teacher_student_app/data/models/weekly_auction.dart';

/// صياغة نصوص المزاد (أرقام، أوقات، عدّاد) بلا حزم خارجية.
///
/// **لماذا ملف مستقل؟** لأن التنسيق يُستخدم في شاشة المدرّس وشاشة الإدارة
/// وشاشة المميزين، وتكراره في ثلاثة أماكن يجعل «مهلة الدفع» تُقرأ بصيغ مختلفة —
/// وهو أسوأ ما يمكن أن يحدث في نظام مواعيد مالية.
abstract final class AuctionText {
  static const List<String> _weekdays = <String>[
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  /// `1234` ⇒ `1,234 جنيه`.
  static String money(int amount) => '${thousands(amount)} جنيه';

  /// فاصل آلاف يدوي (لا `intl` في التبعيات).
  static String thousands(int value) {
    final String digits = value.abs().toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i += 1) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '${value < 0 ? '-' : ''}$buffer';
  }

  /// `11:05 م` — ساعة 12 بالعربية المصرية.
  static String clock(DateTime time) {
    final int hour24 = time.hour;
    final int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$hour12:$minute ${hour24 < 12 ? 'ص' : 'م'}';
  }

  /// `الأربعاء 11:59 م`.
  static String dayTime(DateTime time) =>
      '${_weekdays[time.weekday - 1]} ${clock(time)}';

  /// `الأربعاء 14 أكتوبر` — للتواريخ البعيدة (نهاية العرض).
  static String dayDate(DateTime time) {
    const List<String> months = <String>[
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${_weekdays[time.weekday - 1]} ${time.day} ${months[time.month - 1]}';
  }

  /// `2 يوم و5 ساعة` — لأقرب وحدة معقولة.
  static String duration(Duration remaining) {
    if (remaining.isNegative || remaining == Duration.zero) return 'انتهى';
    final int days = remaining.inDays;
    final int hours = remaining.inHours % 24;
    final int minutes = remaining.inMinutes % 60;
    if (days > 0) return '$days يوم و$hours ساعة';
    if (hours > 0) return '$hours ساعة و$minutes دقيقة';
    if (minutes > 0) return '$minutes دقيقة';
    return '${remaining.inSeconds} ثانية';
  }

  /// نص العدّاد التنازلي حتى [target] **بحسب ساعة الخادم**.
  ///
  /// [serverNow] ساعة الخادم عند آخر قراءة، والفرق بينها وبين ساعة الجهاز
  /// يُحسب في [ServerClockView] — فلا يؤثر تغيير ساعة الهاتف في العدّاد.
  static String remainingUntil(DateTime target, DateTime serverNow) =>
      duration(target.difference(serverNow));

  /// مرحلة الأسبوع بصياغة أوضح للطالب/المدرّس.
  static String phaseCaption(AuctionState state) => switch (state.phase) {
    AuctionPhase.scheduled =>
      'يفتح الاثنين ${clock(state.opensAt)} — ${dayDate(state.opensAt)}',
    AuctionPhase.open => 'يُغلق ${dayTime(state.bidCutoffAt)}',
    AuctionPhase.gracePeriod => 'أُغلق باب المزايدة — جارٍ الاحتساب',
    AuctionPhase.awaitingFinalize =>
      'تُعلن النتائج ${dayTime(state.announcesAt)}',
    AuctionPhase.paymentWindow =>
      'مهلة دفع الفائزين حتى ${dayTime(state.paymentDeadline)}',
    AuctionPhase.replacement =>
      'دورة البديل حتى ${dayTime(state.replacementDeadline ?? state.paymentDeadline)}',
    AuctionPhase.awaitingPublish => 'يبدأ العرض ${dayDate(state.displayStartsAt)}',
    AuctionPhase.ended => 'انتهى عرض هذا الأسبوع',
  };

  /// حالة مقعد الفائز.
  static String seatStatus(AuctionSeat seat) => switch (seat.status) {
    'paid' => 'تم تأكيد الدفع',
    'unpaid' => 'انتهت المهلة بلا دفع',
    'unfilled' => 'مقعد غير مُسنَد',
    _ => 'بانتظار تأكيد الدفع',
  };
}

/// ساعت الخادم أثناء تصفّح الشاشة.
///
/// **المشكلة:** العدّاد التنازلي يحتاج «الآن»، و«الآن» في الهاتف قد تكون
/// مغيّرة قصدًا (أو خاطئة). **الحل:** نحسب الفرق بين ساعة الخادم وساعة الجهاز
/// مرة واحدة عند القراءة، ونضيفه إلى ساعة الجهاز كل ثانية. النتيجة تقريبية
/// بالثواني — وهذا كافٍ للعرض، لأن القرار الفعلي (هل تُقبل مزايدة؟) يُحسب على
/// الخادم بساعته دائمًا، ولا يعتمد على أي رقم يُعرض هنا.
class ServerClockView {
  ServerClockView({required AuctionState state, DateTime Function()? deviceNow})
    : _deviceNow = deviceNow ?? DateTime.now,
      _offset = state.serverNow.difference((deviceNow ?? DateTime.now)());

  final DateTime Function() _deviceNow;
  final Duration _offset;

  /// الوقت الحالي كما تراه الخدمة (للعرض فقط).
  DateTime get now => _deviceNow().add(_offset);

  /// المتبقي حتى [target] (سالب بعد انتهائه).
  Duration remainingUntil(DateTime target) => target.difference(now);
}
