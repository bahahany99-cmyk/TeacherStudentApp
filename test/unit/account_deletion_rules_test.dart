import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/data/models/account_status.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/validation/account_deletion_rules.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 10, 28, 12);

  group('AccountStatus — قراءة وكتابة القيمة المخزّنة', () {
    test('القيم النصية ثابتة وتطابق firestore.rules', () {
      expect(AccountStatus.active.wire, 'active');
      expect(AccountStatus.pendingDeletion.wire, 'pending_deletion');
    });

    test('الغياب أو القيمة غير المعروفة = نشط (لا حذف ضمني)', () {
      expect(AccountStatus.fromWire(null), AccountStatus.active);
      expect(AccountStatus.fromWire(''), AccountStatus.active);
      expect(AccountStatus.fromWire('deleted'), AccountStatus.active);
      expect(
        AccountStatus.fromWire('pending_deletion'),
        AccountStatus.pendingDeletion,
      );
    });
  });

  group('مهلة السماح (7 أيام)', () {
    test('الموعد = وقت الطلب + 7 أيام بالضبط', () {
      expect(
        AccountDeletionRules.scheduledAt(now),
        now.add(const Duration(days: 7)),
      );
      expect(AccountDeletionRules.gracePeriod, const Duration(days: 7));
    });

    test('داخل المهلة: قبل الموعد فقط', () {
      final DateTime scheduledAt = AccountDeletionRules.scheduledAt(now);
      expect(
        AccountDeletionRules.isWithinGrace(scheduledAt: scheduledAt, now: now),
        isTrue,
      );
      expect(
        AccountDeletionRules.isWithinGrace(
          scheduledAt: scheduledAt,
          now: scheduledAt.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );
      // الموعد نفسه = انتهت المهلة (لا لحظة سماح إضافية).
      expect(
        AccountDeletionRules.isWithinGrace(scheduledAt: scheduledAt, now: scheduledAt),
        isFalse,
      );
      expect(
        AccountDeletionRules.isExpired(scheduledAt: scheduledAt, now: scheduledAt),
        isTrue,
      );
    });

    test('انتهت المهلة: بعد الموعد', () {
      final DateTime scheduledAt = AccountDeletionRules.scheduledAt(now);
      expect(
        AccountDeletionRules.isExpired(
          scheduledAt: scheduledAt,
          now: scheduledAt.add(const Duration(minutes: 1)),
        ),
        isTrue,
      );
    });

    test('لا موعد ⇒ لا مهلة (لا استعادة ولا انتهاء)', () {
      expect(
        AccountDeletionRules.isWithinGrace(scheduledAt: null, now: now),
        isFalse,
      );
      expect(
        AccountDeletionRules.isExpired(scheduledAt: null, now: now),
        isFalse,
      );
    });
  });

  group('الأيام المتبقية وصياغتها', () {
    test('التقريب لأعلى: ساعات قليلة = يوم واحد', () {
      expect(
        AccountDeletionRules.daysLeft(
          scheduledAt: now.add(const Duration(hours: 2)),
          now: now,
        ),
        1,
      );
      expect(
        AccountDeletionRules.daysLeft(
          scheduledAt: now.add(const Duration(days: 7)),
          now: now,
        ),
        7,
      );
    });

    test('لا ينزل تحت الصفر بعد انتهاء المهلة', () {
      expect(
        AccountDeletionRules.daysLeft(
          scheduledAt: now.subtract(const Duration(days: 3)),
          now: now,
        ),
        0,
      );
    });

    test('صياغة عربية سليمة (مفرد/مثنى/جمع)', () {
      expect(AccountDeletionRules.daysLabel(0), 'أقل من يوم');
      expect(AccountDeletionRules.daysLabel(1), 'يوم واحد');
      expect(AccountDeletionRules.daysLabel(2), 'يومان');
      expect(AccountDeletionRules.daysLabel(5), '5 أيام');
      expect(AccountDeletionRules.daysLabel(12), '12 يومًا');
    });

    test('التاريخ بصيغة dd/MM/yyyy', () {
      expect(AccountDeletionRules.dateLabel(DateTime(2026, 11, 4)), '04/11/2026');
    });
  });

  group('من يستطيع الاستعادة؟', () {
    test('حساب نشط: لا', () {
      expect(
        AccountDeletionRules.canRestore(
          status: AccountStatus.active,
          scheduledAt: AccountDeletionRules.scheduledAt(now),
          now: now,
        ),
        isFalse,
      );
    });

    test('معلّق داخل المهلة: نعم', () {
      expect(
        AccountDeletionRules.canRestore(
          status: AccountStatus.pendingDeletion,
          scheduledAt: AccountDeletionRules.scheduledAt(now),
          now: now,
        ),
        isTrue,
      );
    });

    test('معلّق بعد انتهاء المهلة: لا (يفتح الباب للدعم)', () {
      expect(
        AccountDeletionRules.canRestore(
          status: AccountStatus.pendingDeletion,
          scheduledAt: now.subtract(const Duration(days: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('معلّق بلا موعد: لا', () {
      expect(
        AccountDeletionRules.canRestore(
          status: AccountStatus.pendingDeletion,
          scheduledAt: null,
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('نصوص الواجهة', () {
    test('تحذير الحذف يذكر المهلة والتاريخ والإجراء', () {
      final DateTime scheduledAt = AccountDeletionRules.scheduledAt(now);
      final String warning = AccountDeletionRules.deleteWarning(scheduledAt);

      expect(warning, contains('7 أيام'));
      expect(warning, contains('04/11/2026'));
      expect(warning, contains(AccountDeletionRules.restoreAction));
      // الوعد الصادق: لا يُقال إن الحذف فوري.
      expect(AccountDeletionRules.deleteNotice, contains('لا يُحذف أي شيء الآن'));
    });

    test('ملخص الحالة يعكس المرحلة', () {
      AppUser user(AccountStatus status, DateTime? scheduledAt) => AppUser(
        id: 'u1',
        displayName: 'سارة',
        role: UserRole.teacher,
        status: status,
        scheduledDeletionAt: scheduledAt,
      );

      expect(
        AccountDeletionRules.statusSummary(user(AccountStatus.active, null), now),
        'نشط',
      );
      expect(
        AccountDeletionRules.statusSummary(
          user(
            AccountStatus.pendingDeletion,
            AccountDeletionRules.scheduledAt(now),
          ),
          now,
        ),
        contains('7 أيام'),
      );
      expect(
        AccountDeletionRules.statusSummary(
          user(AccountStatus.pendingDeletion, now.subtract(const Duration(days: 2))),
          now,
        ),
        'بانتظار الحذف النهائي',
      );
    });
  });

  group('AppUser.withAccountStatus — الحقول المترابطة', () {
    const AppUser pending = AppUser(
      id: 'u1',
      displayName: 'سارة',
      role: UserRole.teacher,
      email: 's@example.com',
      status: AccountStatus.pendingDeletion,
    );

    test('الاستعادة تُصفّر الموعد وتُبقي بقية الحقول', () {
      final AppUser active = pending.withAccountStatus(AccountStatus.active);

      expect(active.status, AccountStatus.active);
      expect(active.scheduledDeletionAt, isNull);
      expect(active.id, pending.id);
      expect(active.displayName, pending.displayName);
      expect(active.email, pending.email);
      expect(active.role, UserRole.teacher);
      expect(active.isPendingDeletion, isFalse);
    });

    test('الحالة النشطة لا تحمل موعدًا ولو مُرّر', () {
      final AppUser active = pending.withAccountStatus(
        AccountStatus.active,
        scheduledDeletionAt: now,
      );
      expect(active.scheduledDeletionAt, isNull);
    });
  });
}
