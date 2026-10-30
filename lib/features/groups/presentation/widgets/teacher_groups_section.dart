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
/// ## زر واحد لا ثلاثة (P23)
///
/// كان القسم يعرض **ثلاثة** مداخل للفعل نفسه: زر صغير في عنوان القسم، ورابط
/// داخل حالة الفراغ، وزر عريض أسفل القائمة — نفس الفعل بثلاثة أشكال، فيبدو
/// التطبيق غير مضبوط ويحتار المستخدم أيّها «الصحيح». الآن:
///
/// - **زر أساسي واحد** (`FilledButton.icon` بعنوان «إنشاء مجموعة جديدة»)
///   ثابت أعلى القسم، ظاهر في الحالتين (قائمة فارغة أو ممتلئة).
/// - حالة الفراغ **تشرح** ولا تُكرّر الزر: لا رابط فيها، بل إشارة إلى الزر
///   نفسه، فلا يفعل المستخدم الفعل من مكانين مختلفين.
/// - عنوان القسم بلا زر إجراء: لا شيء مكرّر.
///
/// ويُستخدم القسم في مكانين (الرئيسية + تبويب المجموعات) بسلوك واحد، بدل
/// نسخ منطق الإنشاء والتحديث مرتين.
class TeacherGroupsSection extends StatefulWidget {
  const TeacherGroupsSection({
    super.key,
    this.maxItems,
    this.showHeader = true,
    this.showCreateButton = true,
    this.createButtonKey = const Key('groups-create'),
  });

  /// حدّ العرض في الرئيسية (null = كل المجموعات في تبويب المجموعات).
  final int? maxItems;

  final bool showHeader;

  /// إظهار الزر الأساسي الوحيد. تُخفيه الشاشة الأم فقط إن كانت تعرض فعلًا
  /// أولى بنفسه (لا يوجد حاليًا مكان يفعل ذلك).
  final bool showCreateButton;

  /// مفتاح الزر — يستخدمه الاختبار ويضمن أن الزر **واحد** لا أكثر.
  final Key createButtonKey;

  @override
  State<TeacherGroupsSection> createState() => _TeacherGroupsSectionState();
}

class _TeacherGroupsSectionState extends State<TeacherGroupsSection> {
  /// عدّاد إصدار يُمرَّر إلى `AsyncView.reloadKey`: إعادة قراءة **بلا** فقدان
  /// الحالة (لا وميض تحميل).
  int _revision = 0;

  bool _opening = false;

  /// الإشارة المشتركة (P23): كل حفظ ناجح في أي مكان يزيدها فتُحدَّث كل
  /// الأقسام الحيّة، لا القسم الذي أطلق الحفظ وحده.
  ValueNotifier<int>? _signal;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ValueNotifier<int> signal = AppServicesScope.of(context).groupsRevision;
    if (!identical(signal, _signal)) {
      _signal?.removeListener(_refresh);
      _signal = signal..addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _signal?.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() => _revision++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String teacherId = CurrentTeacher.idOf(SessionScope.read(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showHeader)
          const SectionHeader(
            title: 'مجموعاتي',
            subtitle: 'السعة والمواعيد تحددها أنت · الأعضاء يُحدَّثون فورًا',
            icon: Icons.groups_outlined,
          ),
        // ⚠️ **الزر الوحيد** في هذا القسم. أي زر آخر للإنشاء (في العنوان أو
        // حالة الفراغ أو أسفل القائمة) تكرار مقصود رفضه.
        if (widget.showCreateButton) ...<Widget>[
          FilledButton.icon(
            key: widget.createButtonKey,
            onPressed: _opening ? null : _create,
            icon: const Icon(Icons.add),
            label: const Text('إنشاء مجموعة جديدة'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AsyncView<List<StudyGroup>>(
          // `reloadKey` لا `key`: إعادة القراءة بلا هدم الحالة (P23).
          reloadKey: _revision,
          keepPreviousData: true,
          load: () => AppServicesScope.of(
            context,
          ).groups.listForTeacher(teacherId),
          builder: (BuildContext context, List<StudyGroup> groups) {
            if (groups.isEmpty) {
              // بلا زر: الفعل له مدخل واحد (الزر أعلاه).
              return const EmptyState(
                icon: Icons.groups_outlined,
                title: 'لم تُنشئ مجموعات بعد',
                message:
                    'اضغط «إنشاء مجموعة جديدة» وحدّد المادة والمرحلة والسعة '
                    'والموعد — تظهر المجموعة هنا فور الحفظ.',
              );
            }

            final List<StudyGroup> visible = widget.maxItems == null
                ? groups
                : groups.take(widget.maxItems!).toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final StudyGroup group in visible) _editableCard(group),
              ],
            );
          },
        ),
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
        // التعديل داخل التفاصيل يمرّ عبر النموذج نفسه الذي يُبلّغ الإشارة؛
        // نقرأ مرة أخرى احتياطًا لأي تغيير آخر (إيقاف/أرشفة).
        _refresh();
      },
      onEditTap: () => _openForm(groupId: group.id),
    );
  }

  /// يفتح النموذج الحقيقي (إنشاء أو تعديل) ويعيد القراءة عند الحفظ.
  ///
  /// النموذج نفسه يكتب في `studyGroups` عبر `GroupRepository` (Firestore في
  /// الإنتاج)، ولا يعرض رسالة وهمية.
  Future<void> _openForm({String? groupId}) async {
    if (_opening) {
      return;
    }
    setState(() => _opening = true);
    try {
      final bool? saved = await Navigator.of(
        context,
      ).pushNamed<bool>(RoutePaths.groupForm, arguments: groupId);
      if (saved == true) {
        _refresh();
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  Future<void> _create() => _openForm();

  /// يُستخدم خارجيًا لإظهار تلميح موحّد (غير مستخدم حاليًا).
  void showInfo(String message) {
    AppSnackBar.show(context, message);
  }
}
