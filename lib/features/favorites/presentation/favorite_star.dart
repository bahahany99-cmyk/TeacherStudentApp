import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/data/models/favorite.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';

/// نجمة المفضلة على أي عنصر قابل للحفظ (P13).
///
/// **لا تظهر لغير الطالب:** إخفاء هنا لتجربة نظيفة لا كإجراء أمني — القواعد هي
/// التي ترفض أي كتابة على مفضلة غير صاحبها.
///
/// الحالة تُقرأ من **تدفّق** لا من لقطة: النجمة تتغيّر في كل مكان تظهر فيه
/// فورًا (ملف المدرس، بطاقة المجموعة، شاشة المفضلة).
class FavoriteStar extends StatefulWidget {
  const FavoriteStar({
    super.key,
    required this.kind,
    required this.targetId,
    this.size = 20,
  });

  final FavoriteKind kind;
  final String targetId;
  final double size;

  @override
  State<FavoriteStar> createState() => _FavoriteStarState();
}

class _FavoriteStarState extends State<FavoriteStar> {
  String? _studentId;
  Stream<bool>? _state;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_state != null) {
      return;
    }
    final SessionController session = SessionScope.of(context);
    if (session.role != UserRole.student) {
      return;
    }
    _studentId = CurrentStudent.idOf(session);
    _state = AppServicesScope.of(context).favorites.watchIsFavorite(
      studentId: _studentId!,
      kind: widget.kind,
      targetId: widget.targetId,
    );
  }

  Future<void> _toggle() async {
    final String? studentId = _studentId;
    if (studentId == null) {
      return;
    }
    // نلتقط الخدمات قبل `await` (قاعدة معلومة في المشروع).
    final AppServices services = AppServicesScope.of(context);
    setState(() => _busy = true);
    try {
      final bool added = await services.favorites.toggle(
        studentId: studentId,
        kind: widget.kind,
        targetId: widget.targetId,
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        added ? 'أُضيف إلى المفضلة.' : 'أُزيل من المفضلة.',
        type: AppMessageType.success,
      );
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        error.overrideMessage ?? error.message,
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Stream<bool>? state = _state;
    if (state == null) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);

    return StreamBuilder<bool>(
      stream: state,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        final bool saved = snapshot.data ?? false;
        return IconButton(
          tooltip: saved ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
          onPressed: _busy ? null : _toggle,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            saved ? Icons.favorite_rounded : Icons.favorite_border,
            size: widget.size,
            color: saved
                ? AppColors.statusRejected
                : theme.colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}
