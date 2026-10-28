import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/error_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/data/models/favorite.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/teacher_rating.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/favorites/presentation/favorite_star.dart';

/// شاشة المفضلة (P13): تبويبان — المدرسون والمجموعات.
///
/// **لماذا تبويبان لا قائمة واحدة مخلوطة؟** لأن العنصرين مختلفان في الشكل
/// والسلوك (مدرس يُفتح على ملفه، مجموعة تُفتح على تفاصيلها)، وخلطهما يجعل
/// القائمة تُقرأ مرتين.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String studentId = CurrentStudent.idOf(SessionScope.of(context));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('المفضلة'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'المدرسون'),
              Tab(text: 'المجموعات'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: <Widget>[
              _FavoritesList(
                studentId: studentId,
                kind: FavoriteKind.teacher,
              ),
              _FavoritesList(studentId: studentId, kind: FavoriteKind.group),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesList extends StatefulWidget {
  const _FavoritesList({required this.studentId, required this.kind});

  final String studentId;
  final FavoriteKind kind;

  @override
  State<_FavoritesList> createState() => _FavoritesListState();
}

class _FavoritesListState extends State<_FavoritesList> {
  Stream<List<Favorite>>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= AppServicesScope.of(
      context,
    ).favorites.watchForStudent(widget.studentId);
  }

  /// يعيد الاشتراك من المصدر — لا يكتفي بإعادة بناء الواجهة على نفس الخطأ.
  void _retry() {
    setState(() {
      _stream = AppServicesScope.of(
        context,
      ).favorites.watchForStudent(widget.studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return StreamBuilder<List<Favorite>>(
      stream: _stream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<Favorite>> snapshot,
          ) {
            if (snapshot.hasError) {
              return ErrorState(
                error: snapshot.error!,
                onRetry: _retry,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<Favorite> mine = snapshot.data!
                .where((Favorite favorite) => favorite.kind == widget.kind)
                .toList(growable: false);

            if (mine.isEmpty) {
              return ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  ResponsiveContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const DemoBanner(),
                        EmptyState(
                          icon: Icons.favorite_border,
                          title: widget.kind == FavoriteKind.teacher
                              ? 'لا مدرسين في المفضلة'
                              : 'لا مجموعات في المفضلة',
                          message:
                              'اضغط النجمة على ملف مدرس أو بطاقة مجموعة '
                              'ليظهر هنا.',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                ResponsiveContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const DemoBanner(),
                      for (final Favorite favorite in mine)
                        Padding(
                          padding: AppSpacing.listGap,
                          child: widget.kind == FavoriteKind.teacher
                              ? _TeacherFavoriteTile(
                                  targetId: favorite.targetId,
                                )
                              : _GroupFavoriteTile(targetId: favorite.targetId),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      InfoNote(
                        text:
                            'المفضلة خاصة بك وحدها؛ لا يراها المدرس ولا غيره من '
                            'الطلاب، وحفظ ${widget.kind.label} لا يحجز مقعدًا ولا '
                            'يضمن قبولًا.',
                        icon: theme.brightness == Brightness.dark
                            ? Icons.visibility_off_outlined
                            : Icons.lock_outline,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ],
            );
          },
    );
  }
}

class _TeacherFavoriteTile extends StatelessWidget {
  const _TeacherFavoriteTile({required this.targetId});

  final String targetId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return FutureBuilder<TeacherProfile?>(
      future: AppServicesScope.of(context).teachers.findById(targetId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<TeacherProfile?> snapshot,
          ) {
            final TeacherProfile? teacher = snapshot.data;
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppCard(
                child: SizedBox(
                  height: 24,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }
            if (teacher == null) {
              return const AppCard(
                child: Text('ملف المدرس لم يعد متاحًا (غير معتمد أو محذوف).'),
              );
            }
            return AppCard(
              onTap: () => Navigator.of(
                context,
              ).pushNamed(RoutePaths.teacherProfile, arguments: teacher.id),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: AppSpacing.avatarSm / 2.4,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      teacher.initials,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          teacher.displayName,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${teacher.subject} • ${teacher.stage}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _RatingHint(teacherId: teacher.id),
                  FavoriteStar(
                    kind: FavoriteKind.teacher,
                    targetId: teacher.id,
                  ),
                ],
              ),
            );
          },
    );
  }
}

/// متوسط التقييم الحقيقي داخل التطبيق (أو لا شيء إن لم يوجد بعد).
class _RatingHint extends StatelessWidget {
  const _RatingHint({required this.teacherId});

  final String teacherId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TeacherRating>(
      stream: AppServicesScope.of(context).reviews.watchRating(teacherId),
      builder: (BuildContext context, AsyncSnapshot<TeacherRating> snapshot) {
        final TeacherRating rating = snapshot.data ?? TeacherRating.empty(teacherId);
        if (rating.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.star_rounded,
                size: 16,
                color: Color(0xFFB26A00),
              ),
              Text(
                rating.average.toStringAsFixed(1),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupFavoriteTile extends StatelessWidget {
  const _GroupFavoriteTile({required this.targetId});

  final String targetId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return FutureBuilder<StudyGroup?>(
      future: AppServicesScope.of(context).groups.findById(targetId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<StudyGroup?> snapshot,
          ) {
            final StudyGroup? group = snapshot.data;
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppCard(
                child: SizedBox(
                  height: 24,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }
            if (group == null) {
              return const AppCard(
                child: Text('المجموعة لم تعد متاحة (موقوفة أو محذوفة).'),
              );
            }
            return AppCard(
              onTap: () => Navigator.of(
                context,
              ).pushNamed(RoutePaths.groupDetails, arguments: group.id),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          group.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${group.teacherName} • ${group.subject}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          group.isFull
                              ? 'مكتملة — يمكن الانضمام لقائمة الانتظار'
                              : '${group.seatsAvailable} مقعد متاح',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FavoriteStar(
                    kind: FavoriteKind.group,
                    targetId: group.id,
                  ),
                ],
              ),
            );
          },
    );
  }
}
