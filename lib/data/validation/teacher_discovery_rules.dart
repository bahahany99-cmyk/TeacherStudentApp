import 'package:teacher_student_app/core/utils/arabic_text.dart';
import 'package:teacher_student_app/data/models/teacher_filter.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// قواعد استكشاف المدرسين وشريط المميزين (P15) — **دوال نقية** بلا Flutter.
///
/// تفصل هذه القواعد بين:
/// - **ما يفرضه الخادم:** الملف الموثّق وحده يُقرأ للطلاب (`status == 'verified'`)،
///   والتمييز لا يكتبه صاحب الملف. هذا في `firestore.rules` لا هنا.
/// - **ما يُطبَّق في العميل:** البحث النصي، والمادة/المرحلة، والترتيب، وفلتر
///   «حضوري فقط» لأن `!isOnline` غير قابل للتعبير في استعلام مساواة.
///
/// الفصل مقصود: لو نقلنا أي شرط منهما إلى الآخر لتغيّر السلوك بين البيئة
/// التجريبية وFirestore.
abstract final class TeacherDiscoveryRules {
  /// يطبّق الفلتر كاملًا على قائمة مُقروءة من المصدر.
  ///
  /// **تعريف `total`:** عدد الملفات التي تمرّ بشروط **الخادم** (موثّق + طريقة
  /// التقديم + المحافظة) قبل فلاتر العميل (النص/المادة/المرحلة/الترتيب). التعريف
  /// نفسه يُطبَّق في `FirestoreTeacherRepository` حيث تُدفع شروط الخادم إلى
  /// الاستعلام — فتظهر «2 من 5» في الوضعين بالمعنى ذاته.
  static TeacherSearchResult search(
    List<TeacherProfile> source,
    TeacherFilter filter,
  ) {
    // دفاع لا استعلام: الملف غير الموثّق لا يُعرض مهما أرسل المستودع.
    final List<TeacherProfile> scoped = source
        .where((TeacherProfile teacher) => teacher.isVisibleToStudents)
        .where((TeacherProfile teacher) => matchesServerSide(teacher, filter))
        .toList(growable: false);

    final String needle = ArabicText.normalize(filter.query);
    final List<TeacherProfile> matches = scoped
        .where(
          (TeacherProfile teacher) =>
              matchesClientSide(teacher, filter, needle),
        )
        .toList();

    sort(matches, filter.sort);

    return TeacherSearchResult(
      teachers: List<TeacherProfile>.unmodifiable(matches),
      total: scoped.length,
    );
  }

  /// الشروط التي تُدفع إلى استعلام Firestore: مساواة على حقل واحد لكل شرط.
  ///
  /// `!isOnline` غير قابل للتعبير في استعلام، لكن `isOnline == false` مساواة
  /// صريحة — لذلك نطلب من المدرس اختيار قيمة واحدة بدل حقل ناقص.
  static bool matchesServerSide(TeacherProfile teacher, TeacherFilter filter) {
    switch (filter.delivery) {
      case TeacherDeliveryFilter.any:
        break;
      case TeacherDeliveryFilter.online:
        if (!teacher.isOnline) {
          return false;
        }
      case TeacherDeliveryFilter.inPerson:
        if (teacher.isOnline) {
          return false;
        }
    }
    return filter.governorate == null ||
        teacher.governorate == filter.governorate;
  }

  /// الشروط التي تُطبَّق في العميل: النص، والمادة، والمرحلة.
  static bool matchesClientSide(
    TeacherProfile teacher,
    TeacherFilter filter,
    String normalizedQuery,
  ) {
    if (filter.subject != null && teacher.subject != filter.subject) {
      return false;
    }
    if (filter.stage != null && teacher.stage != filter.stage) {
      return false;
    }
    if (normalizedQuery.isEmpty) {
      return true;
    }
    return _matchesText(teacher, normalizedQuery);
  }

  /// البحث النصي يشمل الاسم والمادة والمرحلة والمكان (بما فيه المحافظة).
  ///
  /// (P29) المقارنة عبر `ArabicText.matches` لا `contains` خام: تتجاوز همزات
  /// الألف (أ/إ/آ/ا)، والتاء المربوطة (ة/ه)، والياء (ى/ي)، والتشكيل والتطويل،
  /// و«ال» التعريف — فبحث «رياضيات» يجد «الرياضيات» (وهو من أكثر أسباب ظهور
  /// «لا نتائج» مع وجود نتيجة مطابقة).
  static bool _matchesText(TeacherProfile teacher, String needle) {
    return ArabicText.matches(teacher.displayName, needle) ||
        ArabicText.matches(teacher.subject, needle) ||
        ArabicText.matches(teacher.stage, needle) ||
        ArabicText.matches(teacher.locationLabel, needle) ||
        ArabicText.matches(teacher.governorate ?? '', needle) ||
        ArabicText.matches(teacher.district ?? '', needle);
  }

  /// الترتيب في المكان (نفس القائمة) — لا يعيد نسخة جديدة.
  ///
  /// الترتيب حتمي بالكامل: المقارنة الأخيرة دائمًا الاسم ثم المعرّف، فلا يتغيّر
  /// ترتيب نتيجتين متساويتين بين قراءتين.
  static void sort(List<TeacherProfile> teachers, TeacherSort sort) {
    switch (sort) {
      case TeacherSort.recommended:
        teachers.sort((TeacherProfile a, TeacherProfile b) {
          final int byRating = b.rating.compareTo(a.rating);
          if (byRating != 0) {
            return byRating;
          }
          final int byReviews = b.reviewsCount.compareTo(a.reviewsCount);
          return byReviews != 0 ? byReviews : _byName(a, b);
        });
      case TeacherSort.rating:
        teachers.sort((TeacherProfile a, TeacherProfile b) {
          final int byRating = b.rating.compareTo(a.rating);
          return byRating != 0 ? byRating : _byName(a, b);
        });
      case TeacherSort.name:
        teachers.sort(_byName);
    }
  }

  static int _byName(TeacherProfile a, TeacherProfile b) {
    final int byName = a.displayName.compareTo(b.displayName);
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  /// شريط «مدرسون مميزون»: الموثّقون المميزون فقط، بترتيب حتمي.
  ///
  /// الترتيب: `featuredOrder` تصاعديًا (0 = أولًا)، ثم التقييم تنازليًا، ثم
  /// الاسم. لذلك يستطيع المسؤول تثبيت ترتيب الشريط بالكامل دون أن يتحرك
  /// الشريط وحده مع كل تقييم جديد.
  static List<TeacherProfile> featured(List<TeacherProfile> source) {
    final List<TeacherProfile> items = source
        .where(
          (TeacherProfile teacher) =>
              teacher.isFeatured && teacher.isVisibleToStudents,
        )
        .toList(growable: false);
    final List<TeacherProfile> ordered = <TeacherProfile>[...items]
      ..sort((TeacherProfile a, TeacherProfile b) {
        final int byOrder = a.featuredOrder.compareTo(b.featuredOrder);
        if (byOrder != 0) {
          return byOrder;
        }
        final int byRating = b.rating.compareTo(a.rating);
        return byRating != 0 ? byRating : _byName(a, b);
      });
    return List<TeacherProfile>.unmodifiable(ordered);
  }

  /// المحافظات الموجودة فعلًا في البيانات المعروضة — لا قائمة نظرية.
  ///
  /// [extra] اختياري: نتائج البحث الحالية. السبب (P29) أن مصدر الشاشة كان
  /// استعلامًا منفصلًا (`listVerified`)؛ فإن تعثّر هذا الاستعلام وحده بقي
  /// الصف يقول «لا توجد محافظات مسجّلة بعد» بينما قائمة المدرسين أمام
  /// المستخدم مليئة ببيانات فيها محافظات. دمج المصدرين يُبطل هذا التناقض.
  static List<String> governorateOptions(
    List<TeacherProfile> teachers, {
    List<TeacherProfile> extra = const <TeacherProfile>[],
  }) {
    final List<String> unique = <String>[];
    for (final TeacherProfile teacher in <TeacherProfile>[
      ...teachers,
      ...extra,
    ]) {
      final String gov = teacher.governorate?.trim() ?? '';
      if (gov.isEmpty || unique.contains(gov)) {
        continue;
      }
      unique.add(gov);
    }
    unique.sort();
    return List<String>.unmodifiable(unique);
  }

  /// المواد الموجودة فعلًا.
  static List<String> subjectOptions(List<TeacherProfile> teachers) =>
      _distinct(teachers.map((TeacherProfile t) => t.subject));

  /// المراحل الموجودة فعلًا.
  static List<String> stageOptions(List<TeacherProfile> teachers) =>
      _distinct(teachers.map((TeacherProfile t) => t.stage));

  static List<String> _distinct(Iterable<String> values) {
    final List<String> unique = <String>[];
    for (final String value in values) {
      final String clean = value.trim();
      if (clean.isEmpty || unique.contains(clean)) {
        continue;
      }
      unique.add(clean);
    }
    unique.sort();
    return List<String>.unmodifiable(unique);
  }

  /// سطر النتائج: «3 من 12 مدرسًا» — يوضّح أثر الفلترة.
  static String resultsLine(TeacherSearchResult result) {
    if (result.total == 0) {
      return 'لا يوجد مدرسون موثّقون بعد';
    }
    if (result.teachers.length == result.total) {
      return '${result.total} مدرسًا';
    }
    return '${result.teachers.length} من ${result.total} مدرسًا';
  }

  /// رسالة «لا نتائج» تشرح السبب بدل صمت مربك.
  static String emptyMessage(TeacherFilter filter) {
    if (filter.delivery == TeacherDeliveryFilter.online) {
      return 'لا يوجد مدرس متاح عن بُعد بهذه الفلاتر. جرّب «الكل» أو '
          '«حضوري فقط» حسب محافظتك.';
    }
    if (filter.governorate != null) {
      return 'لا يوجد مدرس حضوري في ${filter.governorate} بهذه الفلاتر. '
          'جرّب محافظة مجاورة أو المدرسين المتاحين عن بُعد.';
    }
    if (filter.isActive) {
      return 'لا يوجد مدرس يطابق هذه الفلاتر. جرّب تقليل عددها.';
    }
    return 'يظهر هنا كل مدرس وثّقت الإدارة ملفه.';
  }

  // ─── (P29) الفراغ الحقيقي مقابل فشل التحميل ────────────────────────────────
  //
  // «لا يوجد مدرسون» خبر عن البيانات، ولا يجوز عرضه حين يكون الفشل في
  // التحميل: المستخدم يقرؤه على أنه «التطبيق لا يحتوي مدرسين وثّقتهم الإدارة»،
  // وهو اتهام للبيانات لمجرد انقطاع شبكة. النصوص هنا — لا في الشاشة — حتى
  // يمكن اختبار التمييز بلا رفع واجهة.

  /// عنوان «لا نتائج»: صريح في حالة الفشل، ومحايد في حالة الفراغ الحقيقي.
  static String emptyTitle({required bool dataFailed}) =>
      dataFailed ? 'تعذّر إكمال تحميل القائمة' : 'لا نتائج';

  /// نص «لا نتائج» — لا يدّعي خلو التطبيق من المدرسين عند فشل القراءة.
  static String emptyBody({
    required bool dataFailed,
    required TeacherFilter filter,
  }) {
    if (!dataFailed) {
      return emptyMessage(filter);
    }
    return 'لم تكتمل قراءة بيانات المدرسين من الخادم، فلا نعرف بعد هل توجد '
        'نتائج مطابقة. أعد المحاولة بعد التأكد من الاتصال.';
  }

  /// إجراء «لا نتائج»: إعادة المحاولة عند الفشل، وتفريغ الفلتر عند الفراغ.
  static String? emptyActionLabel({
    required bool dataFailed,
    required TeacherFilter filter,
  }) {
    if (dataFailed) {
      return 'إعادة المحاولة';
    }
    return filter.isActive ? 'إعادة ضبط البحث' : null;
  }
}
