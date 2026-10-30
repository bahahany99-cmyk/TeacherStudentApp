import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/featured_rules.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_showcase_card.dart';

/// شاشة «المدرسون المميزون» الكاملة (P25) — وجهة زر «عرض الكل».
///
/// **الاسم `FeaturedTutorsScreen` لا `FeaturedTeachersScreen`:** الأخير مستخدم
/// في لوحة الإدارة (`features/admin`) لقائمة إدارة التمييز، واستيراد الاسمين
/// معًا في `AppRouter` كان تنازعًا حقيقيًا (`AMBIGUOUS_IMPORT`). الاسم هنا يصف
/// الوجهة كما يراها الطالب: قائمة المميزين.
///
/// **الفرق عن شريط الرئيسية:** الشريط يعرض خمسة لكل شريحة (مساحة الشاشة
/// الأولى)، وهذه الشاشة تعرض **كل** المرشّحين في الشريحتين بنفس الاختيار
/// الأسبوعي — فالطالب يستطيع رؤية ما لم تتّسع له الرئيسية بلا بحث جديد.
///
/// المصدر واحد للاثنين: [FeaturedRules.selectWeekly] على نفس المجموعة
/// (المميزون + الموثّقون). لا نسخة ثانية من منطق الاختيار هنا.
class FeaturedTutorsScreen extends StatefulWidget {
  const FeaturedTutorsScreen({super.key, this.now});

  /// حقن الوقت للاختبار: الاختيار أسبوعي، فيجب أن يكون حتميًا في الاختبار.
  final DateTime? now;

  @override
  State<FeaturedTutorsScreen> createState() => _FeaturedTutorsScreenState();
}

class _FeaturedTutorsScreenState extends State<FeaturedTutorsScreen> {
  DateTime get _now => widget.now ?? DateTime.now();

  /// المميزون + كل الموثّقين: خمس بطاقات لكل شريحة قد لا تكتمل من المميزين
  /// وحدهم (خاصة الأوفلاين)، والموثّق مرشّح شرعي — التمييز هنا **اختيار**
  /// إبراز لا شرط ظهور.
  Future<List<TeacherProfile>> _load() async {
    final services = AppServicesScope.of(context);
    final (List<TeacherProfile> verified, List<TeacherProfile> featured) = await (
      services.teachers.listVerified(),
      services.teachers.listFeatured(),
    ).wait;

    final Map<String, TeacherProfile> byId = <String, TeacherProfile>{
      for (final TeacherProfile teacher in verified) teacher.id: teacher,
      // الملف المميّز يفوز عند التكرار (يحمل `isFeatured` الصحيح إن اختلف).
      for (final TeacherProfile teacher in featured) teacher.id: teacher,
    };
    return byId.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('مدرسون مميزون'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'أونلاين'),
              Tab(text: 'أوفلاين'),
            ],
          ),
        ),
        body: SafeArea(
          child: AsyncView<List<TeacherProfile>>(
            load: _load,
            builder: (BuildContext context, List<TeacherProfile> pool) {
              final FeaturedSelection selection = FeaturedRules.selectWeekly(
                pool,
                now: _now,
              );
              return TabBarView(
                children: <Widget>[
                  _FeaturedList(
                    teachers: selection.allOnline,
                    emptyMessage: 'لا يوجد مدرسون أونلاين موثّقون الآن.',
                  ),
                  _FeaturedList(
                    teachers: selection.allOffline,
                    emptyMessage: 'لا يوجد مدرسون حضوريًا موثّقون الآن.',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FeaturedList extends StatelessWidget {
  const _FeaturedList({required this.teachers, required this.emptyMessage});

  final List<TeacherProfile> teachers;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (teachers.isEmpty) {
      return EmptyState(
        icon: Icons.person_search_outlined,
        title: 'لا نتائج في هذه الشريحة',
        message: emptyMessage,
      );
    }

    final ThemeData theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: teachers.length + 1,
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return ResponsiveContent(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                // صياغة صريحة للدورية: الطالب يعرف أن القائمة تتغيّر أسبوعيًا
                // فلا يظن أن مدرّسًا «اختفى» بلا سبب.
                'قائمة هذا الأسبوع — تتجدّد كل أسبوع',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          );
        }
        final TeacherProfile teacher = teachers[index - 1];
        return ResponsiveContent(
          child: Padding(
            padding: AppSpacing.listGap,
            child: Column(
              children: <Widget>[
                TeacherShowcaseCard(
                  key: ValueKey<String>(teacher.id),
                  teacher: teacher,
                  compact: false,
                  onTap: () => Navigator.of(context).pushNamed(
                    RoutePaths.teacherProfile,
                    arguments: teacher.id,
                  ),
                ),
                // فاصل بسيط بدل بطاقة أخرى — القائمة كثيفة بما يكفي.
                if (index < teachers.length)
                  const SizedBox(height: AppSpacing.xxs),
              ],
            ),
          ),
        );
      },
    );
  }
}
