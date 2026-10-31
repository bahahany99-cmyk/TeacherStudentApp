/// عضو في مجموعة دراسية.
///
/// ⚠️ نموذج عرض فقط في هذه المرحلة: لا انضمام، ولا إزالة، ولا تغيير حالة.
/// الحالة الحقيقية (عضو نشِط / قائمة انتظار) تُكتب على الخادم عند تنفيذ
/// طلبات الانضمام (Phase 8).
class GroupMember {
  const GroupMember({
    required this.id,
    required this.name,
    required this.joinedAt,
    this.status = GroupMemberStatus.active,
    this.movedAt,
    this.movedFromGroupTitle,
  });

  final String id;
  final String name;
  final DateTime joinedAt;
  final GroupMemberStatus status;

  /// لحظة النقل من مجموعة أخرى — `null` للعضوية العادية.
  ///
  /// **لماذا حقل على العضو؟** لأن النقل لا ينشئ عضوية جديدة: العضو نفسه ينتقل
  /// بتاريخ انضمامه الأصلي. هذا الحقل هو الأثر الوحيد الذي يشرح للمدرس أن
  /// العضو جاء من مجموعة أخرى (P9 — لا إشعارات ولا دوال خادم، A-67).
  final DateTime? movedAt;

  /// عنوان المجموعة التي جاء منها العضو — للنص فقط، ويُحفظ وقت النقل لأن
  /// عنوان المجموعة المصدري قد يتغيّر أو تُوقَف لاحقًا.
  final String? movedFromGroupTitle;

  /// هل وصل هذا العضو إلى المجموعة بنقل من مجموعة أخرى؟
  bool get wasMoved => movedAt != null;

  String get initials {
    final String trimmed = name.trim();
    return trimmed.isEmpty ? '؟' : trimmed.substring(0, 1);
  }
}

/// حالة العضوية كما يعرضها التطبيق.
enum GroupMemberStatus {
  /// عضو مقبول ويشغل مقعدًا.
  active,

  /// طلب انضمام لم يُقبل بعد؛ لا يشغل مقعدًا.
  waitlist;

  String get label => switch (this) {
    GroupMemberStatus.active => 'عضو',
    GroupMemberStatus.waitlist => 'قائمة الانتظار',
  };
}
