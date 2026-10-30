import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/detail_row.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/core/widgets/status_chip.dart';
import 'package:teacher_student_app/data/models/favorite.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_rating.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/bookings/presentation/booking_request_sheet.dart';
import 'package:teacher_student_app/features/chat/presentation/chat_launcher.dart';
import 'package:teacher_student_app/features/favorites/presentation/favorite_star.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/group_card.dart';
import 'package:teacher_student_app/features/reviews/presentation/teacher_reviews_section.dart';

/// ملف مدرس واحد — الصفحة التي يفتحها الطالب من قائمة المدرسين.
///
/// عرض فقط: لا حجز، ولا محادثة، ولا مراجعات فعلية في هذه المرحلة. نُظهر ما
/// تعرفه البيانات فعلًا، ونقول صراحةً ما لم يُنفَّذ بدل أزرار بلا أثر.
class TeacherProfileScreen extends StatelessWidget {
  const TeacherProfileScreen({super.key, required this.teacherId});

  final String teacherId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // شفاف لعرض تدرّج الخلفية العالمي (نسخة 3).
        backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('ملف المدرس')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            ResponsiveContent(
              child: AsyncView<TeacherProfile?>(
                load: () => AppServicesScope.of(
                  context,
                ).teachers.findById(teacherId),
                emptyBuilder: (BuildContext context) => const EmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'الملف غير موجود',
                  message:
                      'ربما لم يُعتمد هذا الملف بعد أو تم حذفه. الملفات غير '
                      'المعتمدة لا تظهر للطلاب.',
                ),
                builder: (BuildContext context, TeacherProfile? teacher) {
                  if (teacher == null) {
                    return const EmptyState(
                      icon: Icons.person_off_outlined,
                      title: 'الملف غير موجود',
                      message: 'ربما لم يُعتمد هذا الملف بعد أو تم حذفه.',
                    );
                  }
                  return _TeacherProfileBody(teacher: teacher);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherProfileBody extends StatelessWidget {
  const _TeacherProfileBody({required this.teacher});

  final TeacherProfile teacher;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    radius: AppSpacing.avatarLg / 2.6,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      teacher.initials,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          teacher.displayName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${teacher.subject} • ${teacher.stage}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xxs,
                          runSpacing: AppSpacing.xxs,
                          children: <Widget>[
                            StatusChip(
                              label: 'معتمد',
                              color: theme.colorScheme.primary,
                            ),
                            if (teacher.isFeatured)
                              const StatusChip(
                                label: 'مميز',
                                color: Color(0xFFB26A00),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // المفضلة (P13): النجمة تُخفي نفسها لغير الطالب.
                  FavoriteStar(
                    kind: FavoriteKind.teacher,
                    targetId: teacher.id,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // (P15) طريقة التقديم أولًا ثم المكان: أهم معلومة قرار لمن
              // يبحث عن مدرس حضوري في محافظته.
              DetailRow(
                icon: teacher.isOnline
                    ? Icons.public_rounded
                    : Icons.place_outlined,
                label: 'طريقة التقديم',
                value: teacher.isOnline
                    ? 'عن بُعد${_locationSuffix(teacher)}'
                    : 'حضوري — ${teacher.locationLabel}',
              ),
              _RatingSummaryRow(teacher: teacher),
              if (teacher.priceHint != null)
                DetailRow(
                  icon: Icons.payments_outlined,
                  label: 'السعر',
                  value: teacher.priceHint!,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        const SectionHeader(
          title: 'نبذة',
          subtitle: 'كما كتبها المدرس في ملفه',
          icon: Icons.article_outlined,
        ),
        AppCard(
          child: Text(
            teacher.bio,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        const SectionHeader(
          title: 'التقييمات',
          subtitle: 'من طلاب حصلوا على حصة منفّذة مع هذا المدرس فقط',
          icon: Icons.reviews_outlined,
        ),
        TeacherReviewsSection(teacherId: teacher.id),
        const SizedBox(height: AppSpacing.sectionGap),
        const SectionHeader(
          title: 'مجموعات هذا المدرس',
          subtitle: 'افتح المجموعة لإرسال طلب انضمام ينتظر موافقة المدرس',
          icon: Icons.groups_outlined,
        ),
        AsyncView<List<StudyGroup>>(
          load: () => AppServicesScope.of(
            context,
          ).groups.listForTeacher(teacher.id),
          isEmpty: (List<StudyGroup> groups) => groups.isEmpty,
          emptyBuilder: (BuildContext context) => const EmptyState(
            icon: Icons.groups_outlined,
            title: 'لا توجد مجموعات متاحة',
            message: 'لم ينشر هذا المدرس مجموعات بعد.',
          ),
          builder: (BuildContext context, List<StudyGroup> groups) {
            return Column(
              children: groups
                  .map(
                    (StudyGroup group) => GroupCard(
                      group: group,
                      favoriteAction: FavoriteStar(
                        kind: FavoriteKind.group,
                        targetId: group.id,
                      ),
                      onTap: () => Navigator.of(context).pushNamed(
                        RoutePaths.groupDetails,
                        arguments: group.id,
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            // طلب حجز فعلي (P10): يفتح ورقة الموعد ويكتب للمستودع.
            onPressed: () => showBookingRequestSheet(context, teacher: teacher),
            icon: const Icon(Icons.event_available_outlined, size: 18),
            label: const Text('طلب حجز'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // محادثة مباشرة (P11): تُحترم خصوصية المدرس — إن لم يكن بينكما حجز
        // ولم يفعّل استقبال الرسائل، تظهر رسالة تشرح السبب بدل خطأ خادم.
        ChatActionButton(
          label: 'محادثة',
          filled: true,
          onPressed: (BuildContext context) => openChatWithTeacher(
            context,
            teacherId: teacher.id,
            teacherName: teacher.displayName,
            subject: teacher.subject,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const InfoNote(
          text:
              'تفتح المحادثة بعد حجز مؤكَّد أو انضمام إلى مجموعة. الدفع '
              'والاتفاق على السعر يتمان بينك وبين المدرس خارج التطبيق.',
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// سطر «التقييم» في بطاقة الرأس (P13).
///
/// يعرض **المتوسط الحقيقي المحسوب داخل التطبيق** حين يوجد، ولا يعرض رقمًا
/// مختلقًا: التقييم الذي يكتبه الطلاب هو مصدره مجموع + عدد في `teacherRatings`.
/// وإذا لم يوجد تقييم حقيقي نقع على الرقم التعريفي في الملف (بيانات قديمة أو
/// تجريبية) بدل ادّعاء «لا تقييمات» عن مدرس مُقيَّم سابقًا.
class _RatingSummaryRow extends StatelessWidget {
  const _RatingSummaryRow({required this.teacher});

  final TeacherProfile teacher;

  @override
  Widget build(BuildContext context) {
    final String fallback = teacher.reviewsCount == 0
        ? 'لا توجد تقييمات بعد'
        : '${teacher.rating.toStringAsFixed(1)} من 5 '
              '(${teacher.reviewsCount} تقييم)';

    return StreamBuilder<TeacherRating>(
      stream: AppServicesScope.of(context).reviews.watchRating(teacher.id),
      builder: (BuildContext context, AsyncSnapshot<TeacherRating> snapshot) {
        // (P16) انقطاع البثّ يُقال صراحةً، فلا يُعرض رقم قديم أو «لا توجد
        // تقييمات» كأنها حقيقة.
        if (snapshot.hasError) {
          return const DetailRow(
            icon: Icons.star_rounded,
            label: 'التقييم',
            value: 'تعذّر تحميل التقييم الآن',
          );
        }
        final TeacherRating? rating = snapshot.data;
        return DetailRow(
          icon: Icons.star_rounded,
          label: 'التقييم',
          value: rating == null || rating.isEmpty
              ? fallback
              : rating.averageLabel,
        );
      },
    );
  }
}

/// لاحقة المكان لمدرس «عن بُعد»: قد يذكر محافظته اختياريًا، وقد لا يذكر.
String _locationSuffix(TeacherProfile teacher) {
  final String governorate = teacher.governorate?.trim() ?? '';
  return governorate.isEmpty ? '' : ' · متاح أيضًا حضوريًا في $governorate';
}
