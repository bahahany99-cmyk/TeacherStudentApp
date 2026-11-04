import 'dart:async';

import 'package:flutter/material.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/current_student.dart';
import 'package:teacher_student_app/app/session/current_teacher.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/app_snack_bar.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/info_note.dart';
import 'package:teacher_student_app/core/widgets/responsive_content.dart';
import 'package:teacher_student_app/core/widgets/section_header.dart';
import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/notification_page.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/notification_rules.dart';

/// شاشة الإشعارات (P12) — **مُصفَّحة** منذ P32.
///
/// **القراءة فقط لما يخصّك:** القائمة تُقرأ بمستلم الجلسة، والقواعد ترفض أي
/// مستند لغيره — العزل في الخادم لا في هذه الشاشة.
///
/// **الفتح يقود إلى مكانه:** كل نوع إشعار يعرف وجهته (حجز/محادثة/مجموعة/ملف
/// مدرس)، والضغط يعلّمه مقروءًا ثم يفتح الشاشة المناسبة.
///
/// ## (P32) لماذا تغيّرت طريقة القراءة؟
/// كانت الشاشة تعتمد `watchMine` وحدها، وهي تقرأ ما يصل إلى 50 إشعارًا ثم
/// تتوقف: ما قبلها **غير قابل للوصول**، ويُحمَّل كل ما هو متاح دفعة واحدة.
///
/// الآن:
/// * **نافذة حيّة للأحدث** (`watchMine`, بحجم صفحة): الإشعار الجديد يظهر فورًا
///   كما في P25، وتعليم «مقروء» من جهاز آخر يصل أيضًا.
/// * **صفحات أقدم تُطلب عند الحاجة** (`listPage` بمؤشر `createdAt` + معرّف):
///   لا يُقرأ ما لم يطلبه المستخدم بالوصول إلى نهاية القائمة.
/// * **العدّاد مستقل:** شارة الجرس تقرأ عدّادها الخاص (`watchUnreadCount`) ولا
///   تنتظر تحميل أي صفحة ولا تتأثر بها.
///
/// **لا حذف تلقائي:** لا تمسح الشاشة إشعارًا، ولا تُطبّق سياسة 90 يومًا (لم
/// تُعتمد بعد ولا توجد خدمة مجدولة تنفّذها).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _markingAll = false;

  /// كل ما وصل لهذه الشاشة، بالمعرّف: النافذة الحيّة + الصفحات المطلوبة.
  ///
  /// **لماذا خريطة لا قائمة؟** لأن المصدرين يتقاطعان (إشعار جديد يزيح أقدم عنصر
  /// خارج النافذة الحيّة). الخريطة تجعل الإضافة **دمجًا**: لا يتكرر عنصر، ولا
  /// يختفي عنصر عُرض للمستخدم لمجرد وصول إشعار أحدث.
  final Map<String, AppNotification> _items = <String, AppNotification>{};

  StreamSubscription<List<AppNotification>>? _subscription;
  String? _subscribedFor;

  bool _firstLoadDone = false;
  bool _streamFailed = false;

  bool _loadingMore = false;
  bool _hasMore = false;

  /// هل طُلب من الخادم صفحة أقدم من قبل؟ يمنع أن تُلغي تحديثاتُ النافذة الحيّة
  /// نتيجةَ «هل بقي أكثر؟» التي حسبها المستودع.
  bool _paged = false;
  Object? _moreError;

  String _viewerId(SessionController session) {
    return session.role == UserRole.teacher
        ? CurrentTeacher.idOf(session)
        : CurrentStudent.idOf(session);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String viewerId = _viewerId(SessionScope.of(context));
    if (viewerId == _subscribedFor) {
      return;
    }
    _subscribedFor = viewerId;
    _items.clear();
    _firstLoadDone = false;
    _streamFailed = false;
    _paged = false;
    _hasMore = false;
    _moreError = null;
    _loadingMore = false;
    _subscribe(viewerId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribe(String viewerId) {
    _subscription?.cancel();
    _subscription = AppServicesScope.of(context)
        .notifications
        .watchMine(viewerId)
        .listen(
          (List<AppNotification> items) {
            if (!mounted) {
              return;
            }
            setState(() {
              _firstLoadDone = true;
              _streamFailed = false;
              for (final AppNotification item in items) {
                _items[item.id] = item;
              }
              // النافذة ممتلئة ⇒ غالبًا يوجد أقدم منها. لا نُلغي نتيجة الصفحة
              // السابقة إن كان قد طُلب شيء بالفعل.
              if (!_paged) {
                _hasMore = items.length >= NotificationRules.pageSize;
              }
            });
          },
          onError: (Object _) {
            if (!mounted) {
              return;
            }
            setState(() => _streamFailed = true);
          },
        );
  }

  /// يعيد الاشتراك بعد فشل (زر «إعادة المحاولة» في حالة الخطأ).
  void _retryStream() {
    final String? viewerId = _subscribedFor;
    if (viewerId == null) {
      return;
    }
    setState(() {
      _streamFailed = false;
      _firstLoadDone = false;
    });
    _subscribe(viewerId);
  }

  /// يطلب صفحة أقدم من آخر عنصر معروض.
  ///
  /// المؤشر هو **آخر عنصر في الترتيب المعروض** (الأقدم، ثم أكبر معرّف عند تساوي
  /// الوقت) — وهو بالضبط ما يتوقعه المستودع (`before` + `beforeId`).
  Future<void> _loadMore() async {
    final String? viewerId = _subscribedFor;
    if (viewerId == null ||
        _loadingMore ||
        !_hasMore ||
        _moreError != null) {
      return;
    }
    final List<AppNotification> sorted = _sorted();
    if (sorted.isEmpty) {
      setState(() => _hasMore = false);
      return;
    }
    final AppNotification oldest = sorted.last;
    setState(() => _loadingMore = true);
    try {
      final NotificationPage page = await AppServicesScope.of(context)
          .notifications
          .listPage(
            recipientId: viewerId,
            limit: NotificationRules.pageSize,
            before: oldest.createdAt,
            beforeId: oldest.id,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _paged = true;
        _loadingMore = false;
        _moreError = null;
        _hasMore = page.hasMore;
        for (final AppNotification item in page.items) {
          _items.putIfAbsent(item.id, () => item);
        }
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingMore = false;
        _moreError = error;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingMore = false;
        _moreError = error;
      });
    }
  }

  List<AppNotification> _sorted() =>
      NotificationRules.newestFirst(_items.values.toList(growable: false));

  Future<void> _open(AppNotification notification, String viewerId) async {
    final String route = switch (notification.target) {
      NotificationTarget.booking => RoutePaths.bookingDetails,
      NotificationTarget.chat => RoutePaths.directChat,
      NotificationTarget.group => RoutePaths.groupDetails,
      // (P30) إشعارات المزاد تفتح شاشة المزاد نفسها (مقعدي ومهلتي).
      NotificationTarget.auction => RoutePaths.auction,
      // (P32) قرار التوثيق يفتح ملف المدرس نفسه ليرى الحالة والملاحظة.
      NotificationTarget.teacherProfile => RoutePaths.myTeacherProfile,
    };

    try {
      if (!notification.isRead) {
        await AppServicesScope.of(context).notifications.markRead(
          notificationId: notification.id,
          recipientId: viewerId,
        );
        if (mounted) {
          // تحديث فوري للصف المعروض: البثّ الحيّ يغطي النافذة الجديدة وحدها،
          // وقد يكون هذا الإشعار من صفحة أقدم.
          setState(() {
            final AppNotification current =
                _items[notification.id] ?? notification;
            _items[notification.id] = current.copyWith(readAt: DateTime.now());
          });
        }
      }
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        error.overrideMessage ?? error.message,
        type: AppMessageType.error,
      );
      return;
    }

    if (!mounted) {
      return;
    }
    await Navigator.of(
      context,
    ).pushNamed(route, arguments: notification.targetId);
  }

  Future<void> _markAll(String viewerId) async {
    setState(() => _markingAll = true);
    try {
      await AppServicesScope.of(
        context,
      ).notifications.markAllRead(viewerId);
      if (mounted) {
        // `markAllRead` تُعلّم **كل** غير المقروء في الخادم، فتصحيح الصفحات
        // المحمّلة محليًا مطابق للواقع لا تجميلًا له.
        final DateTime now = DateTime.now();
        setState(() {
          for (final MapEntry<String, AppNotification> entry
              in _items.entries.toList(growable: false)) {
            if (!entry.value.isRead) {
              _items[entry.key] = entry.value.copyWith(readAt: now);
            }
          }
        });
      }
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
        setState(() => _markingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = SessionScope.of(context);
    final String viewerId = _viewerId(session);
    final List<AppNotification> items = _sorted();

    return Scaffold(
      // شفاف لعرض تدرّج الخلفية العالمي (نسخة 3).
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: <Widget>[
          IconButton(
            tooltip: 'تعليم الكل مقروءًا',
            onPressed: _markingAll ? null : () => _markAll(viewerId),
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: SafeArea(
        // Slivers لا `Column`: التحميل الكسول هو ما يجعل «نهاية القائمة»
        // قابلة للكشف — لو بُنيت كل الصفوف دفعة لبُدئ تحميل كل الصفحات فورًا.
        child: CustomScrollView(
          slivers: <Widget>[
            const SliverToBoxAdapter(
              child: ResponsiveContent(
                child: SectionHeader(
                  title: 'آخر التحديثات',
                  subtitle: 'حجوزاتك ورسائلك ومقاعدك — في مكان واحد',
                ),
              ),
            ),
            if (!_firstLoadDone && !_streamFailed)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            if (_streamFailed && items.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'تعذّر تحميل الإشعارات',
                  message: 'تحقّق من الاتصال، ثم أعد المحاولة.',
                  actionLabel: 'إعادة المحاولة',
                  onActionTap: _retryStream,
                ),
              ),
            if (_firstLoadDone && items.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.notifications_none,
                  title: 'لا إشعارات',
                  message:
                      'سيصلك إشعار عند تحرّك طلب حجز أو وصول رسالة '
                      'أو توفّر مقعد في مجموعة.',
                ),
              ),
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (BuildContext context, int index) {
                final AppNotification item = items[index];
                return ResponsiveContent(
                  child: Padding(
                    padding: AppSpacing.listGap,
                    child: _NotificationTile(
                      notification: item,
                      onTap: () => _open(item, viewerId),
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(child: _footer(items.length)),
            const SliverToBoxAdapter(
              child: ResponsiveContent(
                child: Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: InfoNote(
                    icon: Icons.lock_outline,
                    text:
                        'لا يرى أحد إشعاراتك، ولا يمكن لأحد إنشاء إشعار لك إلا '
                        'بناءً على حجز أو محادثة أو عضوية مجموعة بينكما.',
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.lg),
            ),
          ],
        ),
      ),
    );
  }

  /// ذيل القائمة: تحميل تلقائي عند بلوغ النهاية، أو خطأ مع إعادة محاولة، أو
  /// إعلان النهاية. الحالات الثلاث صريحة — لا دوّامة ولا شريط لا ينتهي.
  Widget _footer(int itemCount) {
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }
    if (_moreError != null) {
      return ResponsiveContent(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            children: <Widget>[
              Text(
                'تعذّر تحميل إشعارات أقدم.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () {
                  setState(() => _moreError = null);
                  unawaited(_loadMore());
                },
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_hasMore) {
      // يُبنى فقط عند وصول المستخدم إلى النهاية (تحميل كسول للشرائح).
      return _LoadMoreSentinel(
        key: ValueKey<int>(itemCount),
        onVisible: () => unawaited(_loadMore()),
      );
    }
    if (_paged) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: Text(
            'وصلت إلى نهاية الإشعارات.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// يطلب الصفحة التالية مرة واحدة عند أول بناء (أي عند بلوغ نهاية القائمة).
class _LoadMoreSentinel extends StatefulWidget {
  const _LoadMoreSentinel({super.key, required this.onVisible});

  final VoidCallback onVisible;

  @override
  State<_LoadMoreSentinel> createState() => _LoadMoreSentinelState();
}

class _LoadMoreSentinelState extends State<_LoadMoreSentinel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onVisible();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.type) {
    NotificationType.bookingRequested => Icons.event_available_outlined,
    NotificationType.bookingAccepted => Icons.check_circle_outline,
    NotificationType.bookingRejected => Icons.cancel_outlined,
    // (P32) إلغاء الحجز: الموعد تحرّر، والأيقونة تقول ذلك بلا قراءة النص.
    NotificationType.bookingCancelled => Icons.event_busy_outlined,
    NotificationType.rescheduleProposed => Icons.swap_horiz,
    NotificationType.directMessage => Icons.forum_outlined,
    NotificationType.waitlistPromoted => Icons.groups_outlined,
    NotificationType.joinRequested => Icons.person_add_alt_1_outlined,
    NotificationType.joinAccepted => Icons.how_to_reg_outlined,
    NotificationType.joinRejected => Icons.person_off_outlined,
    // (P30) إشعارات المزاد: كأس للفوز، ومقعد متاح، ومهلة منتهية.
    NotificationType.auctionWon => Icons.emoji_events_outlined,
    NotificationType.auctionReplacement => Icons.event_seat_outlined,
    NotificationType.auctionPaymentExpired => Icons.timer_off_outlined,
    // (P32) قرار الإدارة على ملف المدرس.
    NotificationType.teacherApproved => Icons.verified_outlined,
    NotificationType.teacherRejected => Icons.report_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool unread = !notification.isRead;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: AppSpacing.avatarMd / 2.8,
            backgroundColor: unread
                ? theme.colorScheme.primaryContainer
                : AppColors.statusNeutral.withAlpha(60),
            child: Icon(
              _icon,
              size: 20,
              color: unread
                  ? theme.colorScheme.onPrimaryContainer
                  : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        notification.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsetsDirectional.only(
                          start: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (notification.body != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    notification.body!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  NotificationRules.relativeTime(
                    notification.createdAt,
                    now: DateTime.now(),
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
