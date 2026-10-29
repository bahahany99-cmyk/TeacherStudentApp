import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/app/shell/teacher_search_request.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/data/models/teacher_filter.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/teacher_discovery_rules.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/featured_teachers_carousel.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_card.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_filter_bar.dart';

/// صفحة استعراض المدرسين (P15): شريط مميزين + بحث وفلاتر تعمل فعلًا.
///
/// ما تُطبّقه الشاشة وما لا:
/// - **المستودع** يقرأ الموثّقين فقط، ويطبّق شرط «عن بُعد/حضوري» والمحافظة في
///   الاستعلام (`TeacherRepository.search`).
/// - **الشاشة** تعرض، وتترك النص والمادة والترتيب لقواعد نقيّة في
///   `TeacherDiscoveryRules`، فلا منطق فلترة مكتوب في الودجت.
///
/// ## (P18) استقبال طلب البحث من الرئيسية
///
/// حقل البحث المعطّل في الرئيسية استُبدل بزر ينتقل إلى هنا ويُسلّم النص عبر
/// [ShellController.teacherSearch]. الطبقة هنا تستهلك الطلب مرة واحدة:
/// تُطبّقه ثم تصفّره، فلا يُعاد عند كل بناء أو عند العودة للقسم لاحقًا.
///
/// ## (P18) ثبات البيانات في الجلسة الحقيقية
///
/// `_universe` (مصدر خيارات المحافظة) تُقرأ مرة واحدة؛ لذلك:
/// - أثناء القراءة `_universeLoading` صحيح ⇒ الشريط يعرض سطر انتظار بنفس
///   الارتفاع، فلا تظهر المحافظات فجأة وتقفز الصفحة.
/// - الفشل لم يعد يُبتلع بصمت: `_universeFailed` صحيح ويُعرض «إعادة المحاولة».
/// - السحب للتحديث يُعيد قراءة الكل (خيارات + نتائج)، فالتحديث الحقيقي متاح
///   بلا إعادة فتح التطبيق.
class TeachersScreen extends StatefulWidget {
  const TeachersScreen({super.key});

  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends State<TeachersScreen> {
  TeacherFilter _filter = TeacherFilter.empty;

  /// كل الموثّقين — تُشتق منها خيارات الفلاتر (لا خيارات نظرية).
  List<TeacherProfile> _universe = const <TeacherProfile>[];

  bool _universeLoading = true;
  bool _universeFailed = false;

  /// هل بدأنا القراءة مرة واحدة على الأقل؟ يمنع تكرار القراءة لنتيجة فارغة
  /// صحيحة عند كل تغيّر في التبعيات.
  bool _universeRequested = false;

  /// يُغيَّر عند السحب للتحديث لإجبار إعادة جلب النتائج أيضًا.
  int _refreshToken = 0;

  /// اشتراك طلبات البحث القادمة من شاشة أخرى (الرئيسية).
  ValueNotifier<TeacherSearchRequest?>? _searchRequests;

  /// آخر طلب بُحث عنه — يمنع إعادة تطبيق الطلب نفسه عند كل استدعاء.
  ///
  /// لا نصفّر النوتیفاير من هنا: التصفير داخل مستمع يُطلق إشعارًا متداخلًا بلا
  /// داعٍ. التسلسل المتزايد في [TeacherSearchRequest] يكفي للتمييز.
  int _handledSequence = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // (P18) ربط طلبات البحث الخارجية. `ShellScope.maybeOf` لأن الشاشة تُستضاف
    // في اختبارات ويدجت منفردة بلا هيكل تنقّل.
    final ValueNotifier<TeacherSearchRequest?>? requests =
        ShellScope.maybeOf(context)?.teacherSearch;
    if (requests != _searchRequests) {
      _searchRequests?.removeListener(_consumeSearchRequest);
      _searchRequests = requests;
      _searchRequests?.addListener(_consumeSearchRequest);
    }

    // (P18) لا نُعدّل الحالة داخل `didChangeDependencies` مباشرة: قد تُستدعى
    // أثناء طور البناء (تبعية تغيّرت)، فالـ`setState` هنا يُرفض. نؤجّل العمل
    // إلى ما بعد الإطار الأولى.
    if (!_universeRequested) {
      _universeRequested = true;
      _universeLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadUniverse();
        }
      });
    }
    if (requests != null && requests.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _consumeSearchRequest();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchRequests?.removeListener(_consumeSearchRequest);
    super.dispose();
  }

  /// يستهلك الطلب المعلّق **مرة واحدة فقط** (لكل تسلسل).
  void _consumeSearchRequest() {
    final TeacherSearchRequest? request = _searchRequests?.value;
    if (request == null || request.sequence <= _handledSequence) {
      return;
    }
    _handledSequence = request.sequence;
    if (!mounted) {
      return;
    }
    setState(() => _filter = _filter.copyWith(query: request.query));
  }

  Future<void> _loadUniverse() async {
    final AppServices services = AppServicesScope.of(context);
    setState(() {
      _universeLoading = true;
      _universeFailed = false;
    });
    try {
      final List<TeacherProfile> teachers = await services.teachers
          .listVerified();
      if (!mounted) {
        return;
      }
      setState(() {
        _universe = teachers;
        _universeLoading = false;
        _universeFailed = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      // (P16) لا نُفشل الشاشة بسبب خيارات الفلترة: البحث نفسه يعرض خطأه.
      // لكن الفشل لم يعد صامتًا — سطر المحافظات يقول ذلك ويسمح بإعادة
      // المحاولة بدل أن يبقى الشريط ناقصًا إلى الأبد.
      setState(() {
        _universe = const <TeacherProfile>[];
        _universeLoading = false;
        _universeFailed = true;
      });
    }
  }

  /// سحب للتحديث: يُعيد قراءة الخيارات والنتائج معًا.
  Future<void> _refresh() async {
    setState(() => _refreshToken++);
    await _loadUniverse();
  }

  void _openProfile(TeacherProfile teacher) {
    Navigator.of(context).pushNamed(
      RoutePaths.teacherProfile,
      arguments: teacher.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        // السحب للتحديث يعمل حتى لو كان المحتوى أقصر من الشاشة.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: <Widget>[
          ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const DemoBanner(),
                const SectionHeader(
                  title: 'مدرسون مميزون',
                  subtitle: 'يُدار التمييز من الإدارة فقط',
                ),
                AsyncView<List<TeacherProfile>>(
                  load: () =>
                      AppServicesScope.of(context).teachers.listFeatured(),
                  builder:
                      (BuildContext context, List<TeacherProfile> featured) {
                        if (featured.isEmpty) {
                          return const EmptyState(
                            icon: Icons.workspace_premium_outlined,
                            title: 'لا يوجد مدرسون مميزون حاليًا',
                          );
                        }
                        return FeaturedTeachersCarousel(
                          teachers: featured,
                          onTeacherTap: _openProfile,
                        );
                      },
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                const SectionHeader(
                  title: 'كل المدرسين',
                  subtitle: 'الملفات الموثّقة فقط',
                ),
                TeacherFilterBar(
                  filter: _filter,
                  governorates: TeacherDiscoveryRules.governorateOptions(
                    _universe,
                  ),
                  governoratesLoading: _universeLoading,
                  onChanged: (TeacherFilter next) {
                    setState(() => _filter = next);
                  },
                ),
                if (_universeFailed) ...<Widget>[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => _universeFailed = false);
                        _loadUniverse();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('تعذّر تحميل خيارات المحافظات — إعادة'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                AsyncView<TeacherSearchResult>(
                  // (P18) `reloadKey` بدل `key`: تغيير الفلتر يُعيد الجلب مع
                  // إبقاء الحالة، فتظهر النتائج السابقة مع مؤشر رقيق بدل أن
                  // تُمسح القائمة كلها (كان ذلك سبب «القفزة» الثانية).
                  reloadKey: (_filter, _refreshToken),
                  keepPreviousData: true,
                  load: () =>
                      AppServicesScope.of(context).teachers.search(_filter),
                  isEmpty: (TeacherSearchResult result) => result.isEmpty,
                  emptyBuilder: (BuildContext context) => EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'لا نتائج',
                    message: TeacherDiscoveryRules.emptyMessage(_filter),
                  ),
                  builder:
                      (BuildContext context, TeacherSearchResult result) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            // سطر العدد الوحيد في الشاشة — مصدره قواعد الفلترة
                            // نفسها، فلا يتناقض مع نص فوقه.
                            Text(
                              TeacherDiscoveryRules.resultsLine(result),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            for (final TeacherProfile teacher
                                in result.teachers)
                              TeacherCard(
                                teacher: teacher,
                                onTap: () => _openProfile(teacher),
                              ),
                          ],
                        );
                      },
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
