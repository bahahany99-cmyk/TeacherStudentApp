#!/usr/bin/env python3
"""فحص بنيوي لقواعد Firestore.

السبب: لا يوجد `firebase` CLI في بيئة التطوير (ولا مشروع للنشر)، ولا يمكن
تشغيل محاكي Firestore هنا. هذا الفحص **لا يثبت صحة القواعد منطقيًا** — يمنع
فقط الأخطاء الشائعة التي تُبطل الأمان أو تُفشل النشر:

1. أقواس متوازنة (خطأ صياغة يُفشل النشر كله).
2. وجود قاعدة رفض افتراضية لكل ما لم يُذكر.
3. عدم وجود `allow read, write: if true` (فتح كامل).
4. أن `users` يقيّد الدور و`teacherProfiles` يثبّت `status`.
5. أن كل `match` لمجموعة معروفة موجود.
6. أن إزالة العضو تحرّر مقعدًا واحدًا، وأن قائمة الانتظار للمكتملة فقط.

الفحص المنطقي الحقيقي يحتاج `firebase emulators:exec` مع
`@firebase/rules-unit-testing`، وهو عمل لاحق (T-09) بعد إنشاء المشروع.
"""

from __future__ import annotations

import pathlib
import re
import sys

RULES_PATH = pathlib.Path('firestore.rules')

REQUIRED_MATCHES = (
    'match /users/{uid}',
    'match /teacherProfiles/{uid}',
    'match /studyGroups/{groupId}',
    'match /groupJoinRequests/{requestId}',
    'match /sessions/{sessionId}',
    'match /groupWaitlist/{entryId}',
    'match /messages/{messageId}',
    'match /bookingRequests/{bookingId}',
)

FORBIDDEN_PATTERNS = (
    (r'allow\s+read\s*,\s*write\s*:\s*if\s+true', 'فتح قراءة/كتابة كامل'),
    (r'allow\s+write\s*:\s*if\s+true', 'فتح كتابة كامل'),
    (r'allow\s+update\s*:\s*if\s+true', 'فتح تحديث كامل'),
)


def strip_comments(src: str) -> str:
    lines = []
    for line in src.splitlines():
        if line.lstrip().startswith('//'):
            continue
        lines.append(line)
    return '\n'.join(lines)


def main() -> int:
    if not RULES_PATH.exists():
        print('::error::firestore.rules غير موجود')
        return 1

    raw = RULES_PATH.read_text(encoding='utf-8')
    code = strip_comments(raw)
    problems: list[str] = []

    # 1) الأقواس
    if code.count('{') != code.count('}'):
        problems.append(
            f'أقواس غير متوازنة: {code.count("{")} فتح مقابل {code.count("}")} إغلاق'
        )

    # 2) الرفض الافتراضي
    if not re.search(
        r'match\s+/\{document=\*\*\}\s*\{\s*allow\s+read\s*,\s*write\s*:\s*if\s+false',
        code,
    ):
        problems.append('لا توجد قاعدة رفض افتراضية match /{document=**}')

    # 3) أنماط خطرة
    for pattern, label in FORBIDDEN_PATTERNS:
        for hit in re.finditer(pattern, code):
            line = code[: hit.start()].count('\n') + 1
            problems.append(f'سطر {line}: {label}')

    # 4) المجموعات المتوقعة
    for match in REQUIRED_MATCHES:
        if match not in code:
            problems.append(f'قاعدة مفقودة: {match}')

    # 5) ثبات الدور والحالة
    if 'request.resource.data.role == resource.data.role' not in code:
        problems.append('users: لا يوجد شرط لثبات الدور عند التحديث')
    if code.count("request.resource.data.status == resource.data.status") < 1:
        problems.append('teacherProfiles: لا يوجد شرط لثبات الحالة (status)')
    if "request.resource.data.status == 'pendingReview'" not in code:
        problems.append('teacherProfiles: الإنشاء غير مقيّد بحالة pendingReview')

    # 6) المجموعات: الكتابة للمالك فقط، والسعة مقيّدة، والمقاعد المشغولة ثابتة
    if 'validSeats()' not in code:
        problems.append('studyGroups: لا توجد دالة تحقق للسعة (validSeats)')
    if 'request.resource.data.seatsTotal <= 50' not in code:
        problems.append('studyGroups: الحد الأعلى للسعة غير مفروض')
    if 'request.resource.data.seatsTaken == 0' not in code:
        problems.append('studyGroups: الإنشاء غير مقيّد بـseatsTaken = 0')
    if 'request.resource.data.seatsTaken == resource.data.seatsTaken' not in code:
        problems.append('studyGroups: التعديل يمكنه تغيير المقاعد المشغولة')
    if 'request.resource.data.teacherId == request.auth.uid' not in code:
        problems.append('studyGroups: الإنشاء غير مقيّد بمالك المجموعة')
    if "request.resource.data.meetingMode in ['online', 'home', 'center']" not in code:
        problems.append('studyGroups: طريقة الحضور غير مقيّدة بقائمة')
    if "'scheduleNote'" not in code or '.size() <= 120' not in code:
        problems.append('studyGroups: طول وصف الموعد غير مقيّد')

    # 7) الانضمام (P8): حجز المقعد ذرّي وزيادة واحدة، والطلب للطالب نفسه
    if "affectedKeys().hasOnly(['seatsTaken'])" not in code:
        problems.append(
            'studyGroups: قبول الطلب يمكنه تغيير حقول غير seatsTaken'
        )
    if 'request.resource.data.seatsTaken == resource.data.seatsTaken + 1' not in code:
        problems.append('studyGroups: الزيادة عند القبول ليست مقعدًا واحدًا')
    if 'request.resource.data.seatsTaken <= resource.data.seatsTotal' not in code:
        problems.append('studyGroups: القبول لا يمنع تجاوز السعة')
    if "request.resource.data.status == 'pending'" not in code:
        problems.append('groupJoinRequests: الإنشاء غير مقيّد بحالة pending')
    if 'request.resource.data.studentId == request.auth.uid' not in code:
        problems.append('groupJoinRequests: الطلب غير مقيّد بصاحبه')
    if 'memberId == request.resource.data.studentId' not in code:
        problems.append('members: معرّف العضو لا يطابق معرّف الطالب')
    if "resource.data.status == 'pending'" not in code:
        problems.append('groupJoinRequests: التحديث لا يشترط أن يكون الطلب معلّقًا')
    if "['rejected', 'cancelled']" not in code:
        problems.append('groupJoinRequests: لا قاعدة لإعادة الطلب بعد الرفض/الإلغاء')
    if 'groupIsJoinable(' not in code:
        problems.append('groupJoinRequests: السعة/النشر غير مفحوصين قبل الطلب')

    # 8) P9: الجدول والمحادثة للأعضاء فقط، والكتابة للمالك
    if 'exists(/databases/$(database)/documents/studyGroups/$(groupId)/members/$(request.auth.uid))' not in code:
        problems.append('sessions/messages: فحص العضوية (exists) غير موجود')
    if 'request.resource.data.startMinutes + request.resource.data.durationMinutes <= 1440' not in code:
        problems.append('sessions: الحصة قد تعبر منتصف الليل')
    if "request.resource.data.weekday in [" not in code:
        problems.append('sessions: اليوم غير مقيّد بقائمة')
    if 'request.resource.data.senderId == request.auth.uid' not in code:
        problems.append('messages: لا يوجد منع لانتحال المرسل')
    if 'request.resource.data.text.size() <= 500' not in code:
        problems.append('messages: طول الرسالة غير مقيّد')
    if 'allow update, delete: if isAdmin();' not in code:
        problems.append('messages: الرسائل قابلة للتعديل/الحذف من التطبيق')

    # 9) P9: إدارة الأعضاء وقائمة الانتظار
    if "request.resource.data.seatsTaken == resource.data.seatsTaken - 1" not in code:
        problems.append('studyGroups: إزالة العضو لا تنقص المقعد')
    if 'request.resource.data.seatsTaken >= 0' not in code:
        problems.append('studyGroups: المقعد يمكن أن يصبح سالبًا')
    if 'allow delete: if isAdmin() || (signedIn() && request.auth.uid == parentTeacherId());' not in code:
        problems.append('members: المالك لا يستطيع إزالة عضو')
    if 'groupIsFull(' not in code:
        problems.append('groupWaitlist: القائمة غير مقيّدة بالمجموعة المكتملة')
    if "entryId == request.resource.data.groupId + '_' + request.auth.uid" not in code:
        problems.append('groupWaitlist: المعرّف المشتق غير مفروض')
    if "request.resource.data.status == 'promoted'" not in code:
        problems.append('groupWaitlist: لا قاعدة لقبول منتظر')
    if "request.resource.data.status == 'left'" not in code:
        problems.append('groupWaitlist: لا قاعدة لمغادرة القائمة')
    if "resource.data.status == 'left'" not in code:
        problems.append('groupWaitlist: لا قاعدة للعودة بعد المغادرة')

    # 10) منع الحقول الإدارية في ملف المدرس
    for field in ('isFeatured', 'rating', 'reviewsCount'):
        block = code.split('match /teacherProfiles/{uid}')[1].split('// ── 3)')[0]
        if field in block:
            problems.append(f'teacherProfiles: الحقل الإداري «{field}» مذكور في القواعد')

    print(f'أسطر القواعد: {len(raw.splitlines())}')
    if problems:
        print(f'مشاكل: {len(problems)}')
        for problem in problems:
            print(f'::error::{problem}')
        return 1

    print('OK: القواعد متوازنة، والرفض الافتراضي موجود، والدور والحالة ثابتان.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
