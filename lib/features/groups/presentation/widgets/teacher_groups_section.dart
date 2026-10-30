import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/group_card.dart';

/// قسم «مجموعاتي» في واجهة المدرس، مع إنشاء وتعديل (P7).
///
/// لماذا مكوّن حالة مستقل؟
/// - `AsyncView` يقرأ مرة واحدة عند البناء. بعد إنشاء مجموعة أو تعديلها نعود
///   إلى هذه الشاشة، فنحتاج إعادة قراءة صريحة. الحل: عدّاد إصدار يُمرَّر
///   كـ`key` لـ`AsyncView`، فيُعاد بناؤه وقراءة البيانات من جديد.
/// - المكوّن يُستخدم في مكانين (الرئيسية + تبويب المجموعات) بسلوك واحد، بدل
///   نسخ منطق التحديث مرتين.
class TeacherGroupsSection extends StatefulWidget {
  const TeacherGroupsSection({
    super.key,
    this.maxItems,
    this.showHeader = true,
    this.headerActionLabel,
    this.showCreateButton = true,
  });

  /// حدّ العرض في الرئيسية (null = كل المجموعات في تبويب المجموعات).
  final int? maxItems;

  final bool showHeader;
  final String? headerActionLabel;

  /// زر «مجموعة جديدة» داخل القسم (يُخفى حين توفّره الشاشة الأم بنفسها).
  final bool showCreateButton;

  @override
  State<TeacherGroupsSection> createState() => _TeacherGroupsSectionState();
}

class _TeacherGroupsSectionState extends State<TeacherGroupsSection> {
  int _revision = 0;

  void _refresh() {
    if (mounted) {
      setState(() => _revision++);
    }
  }

  Future<void> _openForm({String? groupId}) async {
    final bool? saved = await Navigator.of(
      context,
    ).pushNamed<bool>(RoutePaths.groupForm, arguments: groupId);
    if (saved == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String teacherId = CurrentTeacher.idOf(SessionScope.read(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showHeader)
          SectionHeader(
            title: 'مجموعاتي',
            subtitle: 'السعة والمواعيد تحددها أنت · الأعضاء يُحدَّثون فورًا',
            icon: Icons.groups_outlined,
            actionLabel: widget.headerActionLabel,
            onActionTap: widget.headerActionLabel == null ? null : _create,
          ),
        AsyncView<List<StudyGroup>>(
          key: ValueKey<int>(_revision),
          load: () => AppServicesScope.of(
            context,
          ).groups.listForTeacher(teacherId),
          builder: (BuildContext context, List<StudyGroup> groups) {
            if (groups.isEmpty) {
              return EmptyState(
                icon: Icons.groups_outlined,
                title: 'لم تُنشئ مجموعات بعد',
                message: 'أنشئ مجموعتك الأولى وحدّد السعة والموعد.',
                actionLabel: 'إنشاء مجموعة',
                onActionTap: _create,
              );
            }

            final List<StudyGroup> visible = widget.maxItems == null
                ? groups
                : groups.take(widget.maxItems!).toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final StudyGroup group in visible)
                  _editableCard(group),
              ],
            );
          },
        ),
        if (widget.showCreateButton) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('مجموعة جديدة'),
          ),
        ],
      ],
    );
  }

  Widget _editableCard(StudyGroup group) {
    return GroupCard(
      group: group,
      onTap: () async {
        await Navigator.of(
          context,
        ).pushNamed(RoutePaths.groupDetails, arguments: group.id);
        // التعديل قد يحدث داخل التفاصيل؛ نعيد القراءة عند العودة.
        _refresh();
      },
      onEditTap: () => _openForm(groupId: group.id),
    );
  }

  Future<void> _create() async {
    if (!mounted) {
      return;
    }
    await _openForm();
  }

  /// يُستخدم خارجيًا لإظهار تلميح موحّد (غير مستخدم حاليًا).
  void showInfo(String message) {
    AppSnackBar.show(context, message);
  }
}
