import 'package:flutter/foundation.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/data/models/group_filter.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/services/group_repository.dart';

/// حالة شاشة استكشاف المجموعات (P9).
///
/// **لماذا `ChangeNotifier` لا `FutureBuilder`؟**
/// الفلتر يتغيّر عشرات المرات في الجلسة (كل نقرة على «حبة» فلتر)، وكل تغيير
/// يعني قراءة جديدة. الفصل بين «الحالة» (هذا الصنف) و«العرض» (الشاشة) يجعل
/// الاختبار مباشرًا: نغيّر الفلتر ونتحقق من النتيجة بلا بناء واجهة.
///
/// الترتيب الحاسم: كل طلب يحمل رقم جيل؛ نتيجة طلب قديم تصل بعد طلب أحدث
/// **تُهمَل**. بدون ذلك يظهر للمستخدم نتيجة فلتر سابق بعد أن غيّر رأيه.
class GroupDiscoveryController extends ChangeNotifier {
  GroupDiscoveryController({
    required GroupRepository repository,
    GroupFilter initialFilter = GroupFilter.empty,
  }) : _repository = repository,
       _filter = initialFilter;

  final GroupRepository _repository;

  GroupFilter _filter;
  List<StudyGroup> _groups = const <StudyGroup>[];
  int _total = 0;
  bool _loading = true;
  AppException? _error;
  bool _disposed = false;
  int _generation = 0;

  GroupFilter get filter => _filter;
  List<StudyGroup> get groups => _groups;
  int get total => _total;
  bool get isLoading => _loading;
  AppException? get error => _error;
  bool get hasLoadedOnce => !_loading && _error == null;

  /// نص السطر التعريفي: عدد المجموعات الظاهرة من الإجمالي.
  String get resultsLabel => isLoading
      ? 'جارٍ البحث…'
      : (_error != null ? 'تعذّر تحميل المجموعات' : '$total');

  /// قراءة أولى (أو إعادة قراءة بعد فشل).
  Future<void> load() async {
    await _run(_filter);
  }

  /// تغيير الفلتر: يحدّث الحالة فورًا (لتستجيب الحبات) ثم يقرأ من جديد.
  ///
  /// لا نعيد القراءة إذا كان الفلتر الجديد مساويًا للحالي — نقرة على حبة مختارة
  /// أصلًا ليست حدثًا.
  Future<void> applyFilter(GroupFilter next) async {
    if (next == _filter) {
      return;
    }
    _filter = next;
    notifyListeners();
    await _run(next);
  }

  Future<void> reset() => applyFilter(_filter.cleared());

  Future<void> _run(GroupFilter filter) async {
    final int generation = ++_generation;
    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final GroupSearchResult result = await _repository.searchDiscoverable(
        filter,
      );
      if (generation != _generation) {
        return;
      }
      _groups = result.groups;
      _total = result.total;
    } on AppException catch (error) {
      if (generation != _generation) {
        return;
      }
      _error = error;
      _groups = const <StudyGroup>[];
      _total = 0;
    } finally {
      if (generation == _generation) {
        _loading = false;
        _safeNotify();
      }
    }
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
