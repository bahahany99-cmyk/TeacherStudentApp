import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/teacher_review.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/review_rules.dart';

/// ورقة كتابة تقييم (P13) — تُفتح من حجز **منفّذ** فقط.
///
/// تعيد `true` إن أُرسل التقييم فعلًا، حتى تُحدّث الشاشة التي فتحتها.
Future<bool> showReviewSheet(
  BuildContext context, {
  required BookingRequest booking,
}) async {
  final bool? submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) =>
        _ReviewSheet(booking: booking),
  );
  return submitted ?? false;
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.booking});

  final BookingRequest booking;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final TextEditingController _comment = TextEditingController();
  int _rating = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppServices services = AppServicesScope.of(context);
    final SessionController session = SessionScope.read(context);
    final String studentId = CurrentStudent.idOf(session);

    final String? ratingProblem = ReviewRules.ratingProblem(
      _rating == 0 ? null : _rating,
    );
    if (ratingProblem != null) {
      setState(() => _error = ratingProblem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await services.reviews.submit(
        booking: widget.booking,
        studentId: studentId,
        rating: _rating,
        comment: _comment.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = error.overrideMessage ?? error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = 'تعذّر إرسال التقييم الآن. حاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      // يرفع الورقة فوق لوحة المفاتيح.
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(AppSpacing.radiusXl),
            topEnd: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: AppSpacing.pagePadding,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'تقييم الحصة',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${widget.booking.teacherName} • ${widget.booking.subject}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (int star = 1; star <= ReviewRules.maxStars; star++)
                    IconButton(
                      tooltip: '$star من ${ReviewRules.maxStars}',
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _rating = star;
                              _error = null;
                            }),
                      icon: Icon(
                        star <= _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 36,
                        color: star <= _rating
                            ? const Color(0xFFB26A00)
                            : AppColors.textMuted,
                      ),
                    ),
                ],
              ),
              Text(
                _rating == 0
                    ? 'اختر عدد النجوم'
                    : '$_rating من ${ReviewRules.maxStars}',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _comment,
                maxLength: ReviewRules.maxCommentLength,
                maxLines: 3,
                minLines: 2,
                textInputAction: TextInputAction.newline,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'تعليق (اختياري)',
                  hintText: 'ما الذي أفادك في الحصة؟',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.statusRejected,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: AppSpacing.buttonHeight,
                child: FilledButton(
                  onPressed: _busy || _rating == 0 ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('إرسال التقييم'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const InfoNote(
                text:
                    'يُكتب التقييم مرة واحدة بعد حصة منفّذة، ولا يمكن تعديله أو '
                    'حذفه من التطبيق — لأنه شهادة على حصة عُقدت لا رأي عابر.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// زر/حالة التقييم داخل شاشة الحجز (P13).
///
/// - حجز غير منفّذ ⇒ لا شيء (لا زر معطّل بلا معنى).
/// - حجز منفّذ ولم يُقيَّم ⇒ زر «قيّم الحصة».
/// - حجز قُيِّم ⇒ بطاقة تعرض التقييم المكتوب بدل زر يعيد الكتابة.
///
/// الشروط الثلاثة تُفحص في `ReviewRules.eligibilityProblem` — نفس الدالة التي
/// يستخدمها المستودع، فما يراه المستخدم يطابق ما يقرره الخادم.
class ReviewActionButton extends StatefulWidget {
  const ReviewActionButton({super.key, required this.booking});

  final BookingRequest booking;

  @override
  State<ReviewActionButton> createState() => _ReviewActionButtonState();
}

class _ReviewActionButtonState extends State<ReviewActionButton> {
  bool _loading = true;
  bool _eligible = false;
  TeacherReview? _review;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _review == null) {
      _load();
    }
  }

  Future<void> _load() async {
    final AppServices services = AppServicesScope.of(context);
    final SessionController session = SessionScope.read(context);
    final String studentId = CurrentStudent.idOf(session);
    final bool isStudent = session.role == UserRole.student;

    if (!isStudent || widget.booking.status != BookingStatus.completed) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    TeacherReview? existing;
    try {
      existing = await services.reviews.findForBooking(widget.booking.id);
    } on AppException {
      existing = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _review = existing;
      _eligible = ReviewRules.canReview(
        booking: widget.booking,
        studentId: studentId,
        alreadyReviewed: existing != null,
      );
      _loading = false;
    });
  }

  Future<void> _open() async {
    final bool submitted = await showReviewSheet(
      context,
      booking: widget.booking,
    );
    if (!mounted || !submitted) {
      return;
    }
    setState(() => _loading = true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }

    final TeacherReview? review = _review;
    if (review != null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.star_rounded,
                  size: 20,
                  color: Color(0xFFB26A00),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  'تقييمك: ${review.rating} من ${ReviewRules.maxStars}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            if (review.hasComment) ...<Widget>[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                review.comment!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (!_eligible) {
      return const SizedBox.shrink();
    }

    return OutlinedButton.icon(
      onPressed: _open,
      icon: const Icon(Icons.rate_review_outlined, size: 18),
      label: const Text('قيّم الحصة'),
    );
  }
}
