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
  });

  final String id;
  final String name;
  final DateTime joinedAt;
  final GroupMemberStatus status;

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
