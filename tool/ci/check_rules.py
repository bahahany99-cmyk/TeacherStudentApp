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
7. أن سعة المجموعة محدودة بـ40، وأن العضو يحمل `groupId` مطابقًا لمساره.
8. أن حذف صفوف الطلبات/الانتظار للمالك مقيّد بالصفوف المفتوحة فقط.
9. أن الحجوزات تبدأ بحالة pending وأن كل انتقال يحدد حقوله، وأن تقويم المدرس
   اليومي لا يزيده غير المالك.
10. أن المحادثات المباشرة (P11) مشدودة بمعرّف مشتق من الطرفين، وأن كل أصل
    (حجز/مجموعة/استفسار) مفحوص، وأن الكتابة على المحادثة محدودة بحقل القارئ
    أو بملخّص رسالة يكتبها مرسلها.
11-ب. أن التقييم (P13) لا يُكتب إلا لحجز منفّذ، وأن المتوسط مجموع+عدد لا
    يتحرك بلا تقييم في نفس الكتابة، وأن المفضلة بمعرّف مشتق لصاحبها.
12-ب. أن كتل `teacherProfiles`/`reviews`/`favorites`/`contentReports` تُقرأ
    بالقوس المتوازن لا بعلامة تعليق (كان الحارس القديم يمتد إلى نهاية الملف).
14. أن كل إجراء إداري (P14/P19) مشروط بـ`isAdminWriter()` (الادعاء أو دور
    المستند `role == 'admin'`) ومقيّد بحقول معلنة، وأن
    المدرس غير الموثّق لا يقبل حجزًا ولا طلب انضمام ولا ترقية منتظر، وأن
    البلاغ يُنشأ مفتوحًا ولا يُحذف، وأن الحالة المخزّنة صارت `verified`.
15. أن الاكتشاف (P15) لا يُقرأ إلا للموثّقين، وأن حقول طريقة التقديم والمكان
    يكتبها صاحب الملف، وأن التمييز (`isFeatured`/`featuredOrder`) إداري وحده:
    لا يتغيّر إلا بحقلَي التمييز وحدهما، وأن صاحب الملف لا يغيّرهما.
17. أن حذف الحساب (P17) يبقى **ناعمًا ومؤقتًا**: انتقالان فقط لحالة الحساب
    (طلب بموعد داخل سقف المهلة، واستعادة قبل انتهائه بحذف الحقل)، وأن الملف
    المخفي (`accountHidden`) يخرج من الاكتشاف ومن `teacherVerified()` — بعلم على
    الملف لا بقراءة `users` من داخل قاعدة (القواعد تعدّ `get()` على مستند غائب
    خطأً لا `false`، فيختفي كل ملف بلا مستند مستخدم).

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
    'match /teacherCalendar/{calendarId}',
    'match /teacherSettings/{teacherId}',
    'match /notifications/{notificationId}',
    'match /reviews/{reviewId}',
    'match /teacherRatings/{teacherId}',
    'match /favorites/{favoriteId}',
    'match /contentReports/{reportId}',
    'match /directChats/{chatId}',
    'match /messages/{messageId}',
    # (P30) مزاد التمييز الأسبوعي.
    'match /auctions/{auctionId}',
    'match /auctionResults/{auctionId}',
    'match /auctionConfig/{docId}',
    'match /auctionAudit/{entryId}',
    'match /auctionIdempotency/{key}',
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


def match_block(code: str, header: str) -> str | None:
    """يستخرج جسم `match` بتوازن الأقواس (الحدّ الحقيقي لا أول تعليق بعده)."""
    start = code.find(header)
    if start < 0:
        return None
    # آخر `{` في سطر العنوان هو جسم القاعدة؛ `{x}` في العنوان اسم متغيّر لا قوس.
    line_end = code.find('\n', start)
    if line_end < 0:
        line_end = len(code)
    opening = code.rfind('{', start, line_end)
    if opening < 0:
        return None
    depth = 0
    for index in range(opening, len(code)):
        if code[index] == '{':
            depth += 1
        elif code[index] == '}':
            depth -= 1
            if depth == 0:
                return code[start:index + 1]
    return None



def block_starting_at(code: str, needle: str) -> str:
    """يستخرج من موضع [needle] حتى إغلاق القوس المتوازن.

    الفحص القديم كان يقسم الملف على علامة تعليق (`// ── 3)`)، والتعليقات تُحذف
    قبل الفحص، فكان «البلوك» يمتد إلى نهاية الملف: حارسٌ لا يحرس شيئًا. الحدّ
    الحقيقي هو القوس المتوازن (كشفه P15 عند إضافة حقول إدارية للقواعد).
    """
    start = code.find(needle)
    if start < 0:
        return ''
    # آخر `{` في سطر العنوان هو جسم القاعدة؛ `{uid}` في العنوان اسم متغيّر لا قوس.
    line_end = code.find('\n', start)
    if line_end < 0:
        line_end = len(code)
    first = code.rfind('{', start, line_end)
    if first < 0:
        return ''
    depth = 0
    for index in range(first, len(code)):
        if code[index] == '{':
            depth += 1
        elif code[index] == '}':
            depth -= 1
            if depth == 0:
                return code[start:index + 1]
    return ''


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

    # 4-ب) لغة القواعد **تعبيرية فقط**: لا `if`/`for`/`while` كأوامر.
    #
    # هذه فئة خطأ مقيسة: كُتبت دالة بـ`if (...) { return …; }` فمرّ الفحص
    # المحلي ثم رفضها المحاكي بـ«Unexpected 'if'» — فسقطت اختبارات القواعد
    # كلها (265). `return <تعبير>;` وحده مسموح داخل الدوال، و`allow … : if`
    # هي الصيغة الوحيدة المشروعة لكلمة `if`.
    stripped = re.sub(r'//[^\n]*', '', code)
    for match in re.finditer(r'^(\s*)(if|for|while)\b', stripped, re.MULTILINE):
        line = stripped[: match.start()].count('\n') + 1
        problems.append(f'سطر {line}: «{match.group(2)}» كأمر غير مدعوم في لغة القواعد')

    # 5) ثبات الدور والحالة
    if 'request.resource.data.role == resource.data.role' not in code:
        problems.append('users: لا يوجد شرط لثبات الدور عند التحديث')
    # (P22) الحالة لم تعد ثابتة مطلقًا: صاحب ملف **موثّق** يعيدها إلى
    # pendingReview عند التعديل (إعادة تحقق). الشرط الصحيح الآن هو وجود دالة
    # الانتقال المقيّدة واستخدامها في قاعدة التحديث.
    if 'function ownerStatusTransitionAllowed()' not in code:
        problems.append('teacherProfiles: لا دالة انتقال حالة لصاحب الملف')
    if '&& ownerStatusTransitionAllowed()' not in code:
        problems.append('teacherProfiles: دالة الانتقال غير مستخدمة في التحديث')
    if "request.resource.data.status == 'pendingReview'" not in code:
        problems.append('teacherProfiles: الإنشاء غير مقيّد بحالة pendingReview')

    # 6) المجموعات: الكتابة للمالك فقط، والسعة مقيّدة، والمقاعد المشغولة ثابتة
    if 'validSeats()' not in code:
        problems.append('studyGroups: لا توجد دالة تحقق للسعة (validSeats)')
    if 'request.resource.data.seatsTotal <= 40' not in code:
        problems.append('studyGroups: الحد الأعلى للسعة (40) غير مفروض')
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
    if 'allow update, delete: if isAdminWriter();' not in code:
        problems.append('messages: الرسائل قابلة للتعديل/الحذف من التطبيق')

    # 9) P9: إدارة الأعضاء وقائمة الانتظار
    if "request.resource.data.seatsTaken == resource.data.seatsTaken - 1" not in code:
        problems.append('studyGroups: إزالة العضو لا تنقص المقعد')
    if 'request.resource.data.seatsTaken >= 0' not in code:
        problems.append('studyGroups: المقعد يمكن أن يصبح سالبًا')
    if 'allow delete: if isAdminWriter() || (signedIn() && request.auth.uid == parentTeacherId());' not in code:
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

    # 10) P9: نقل الأعضاء وسعة المجموعة
    if "request.resource.data.groupId == groupId" not in code:
        problems.append('members: ربط العضو بالمجموعة (groupId) غير مفروض')
    if 'parentWithinCapacity()' not in code:
        problems.append('members: لا فحص لسعة المجموعة عند إنشاء عضوية')
    if "request.resource.data.seatsTaken == resource.data.seatsTaken - 1" not in code:
        problems.append('studyGroups: لا قاعدة لتحرير مقعد عند النقل/الإزالة')
    if "request.resource.data.seatsTaken == resource.data.seatsTaken + 1" not in code:
        problems.append('studyGroups: لا قاعدة لزيادة مقعد عند النقل/القبول')
    if 'validSeats()' not in code or 'request.resource.data.seatsTotal >= request.resource.data.seatsTaken' not in code:
        problems.append('studyGroups: السعة قد تقل عن المنضمين')
    if "'movedAt', 'movedFromGroupTitle'" not in code:
        problems.append('members: حقول أثر النقل غير مسموح بها')
    if "resource.data.status in ['pending', 'accepted']" not in code:
        problems.append('حذف طلبات الانضمام غير مقيّد بالصفوف المفتوحة')
    if "resource.data.status in ['waiting', 'promoted']" not in code:
        problems.append('حذف صفوف الانتظار غير مقيّد بالصفوف المفتوحة')

    # 11) P10: الحجوزات وتقويم المدرس
    if 'match /bookingRequests/{bookingId}' not in code:
        problems.append('لا قواعد للحجوزات')
    if "request.resource.data.status == 'pending'" not in code:
        problems.append('الحجز لا يبدأ بحالة pending')
    for fragment, message in (
        ("'status', 'decidedAt', 'decidedBy'", 'الحقول المسموح تغييرها بقرار المدرس غير محددة'),
        ("'status', 'cancelledAt', 'cancelledBy'", 'الحقول المسموح تغييرها بالإلغاء غير محددة'),
        ("'status', 'proposalDateKey', 'proposalStartMinutes'", 'حقول اقتراح الوقت البديل غير محددة'),
    ):
        if fragment not in code:
            problems.append(f'الحجوزات: {message}')
    if 'request.resource.data.durationMinutes in [30, 45, 60, 90, 120]' not in code:
        problems.append('الحجوزات: مدد الحصة غير مقيّدة')
    if 'resource.data.proposedBy == \'teacher\'' not in code:
        problems.append('الحجوزات: ردّ الطالب على الاقتراح غير مقيّد بمصدره')
    if 'match /teacherCalendar/{calendarId}' not in code:
        problems.append('لا قواعد لتقويم المدرس اليومي')
    if 'request.resource.data.busy.size() <= resource.data.busy.size()' not in code:
        problems.append('تقويم المدرس: الإزالة من غير المالك غير مقيّدة')

    # 11-ب) P11: المحادثات المباشرة وخصوصية المدرس
    if "request.resource.data.allowDirectMessages is bool" not in code:
        problems.append('teacherSettings: الخيار غير مقيّد بنوع منطقي')
    if "chatId == request.resource.data.teacherId + '_'" not in code:
        problems.append('directChats: معرّف المحادثة غير مشتق من الطرفين')
    if "request.resource.data.studentId == request.auth.uid" not in code:
        problems.append('directChats: الاستفسار غير مقيّد بصاحبه')
    if 'teacherSettingsDoc().allowDirectMessages == true' not in code:
        problems.append('directChats: الاستفسار لا يشترط تفعيل المدرس للرسائل')
    if 'exists(/databases/$(database)/documents/studyGroups/$(request.resource.data.groupId)/members/$(request.resource.data.studentId))' not in code:
        problems.append('directChats: خيط المجموعة لا يفحص العضوية')
    if 'bookingOfChat().teacherId == request.resource.data.teacherId' not in code:
        problems.append('directChats: خيط الحجز لا يفحص الطرفين')
    if "request.resource.data.diff(resource.data).affectedKeys().hasOnly(['studentLastReadAt'])" not in code:
        problems.append('directChats: حالة القراءة قابلة لتعديل غير صاحبها')
    if "'lastMessageAt', 'lastMessageText', 'lastSenderId'" not in code:
        problems.append('directChats: حقول ملخّص آخر رسالة غير محددة')
    if 'channelAllowsSending()' not in code:
        problems.append('directChats/messages: إيقاف الإرسال غير مفروض')
    if "request.resource.data.chatId == chatId" not in code:
        problems.append('directChats/messages: الرسالة قد تُكتب في خيط آخر')
    if code.count('request.resource.data.senderId == request.auth.uid') < 2:
        problems.append('directChats/messages: لا يوجد منع لانتحال المرسل')

    # 11-ج) P12: الإشعارات للمستلم فقط، والإنشاء بعلاقة موثّقة
    if 'isSelf(resource.data.recipientId)' not in code:
        problems.append('notifications: القراءة/التعليم غير مقيّدة بالمستلم')
    if 'request.resource.data.actorId == request.auth.uid' not in code:
        problems.append('notifications: الإنشاء غير مقيّد بالمُحدِث نفسه')
    if 'request.resource.data.recipientId != request.auth.uid' not in code:
        problems.append('notifications: يمكن إرسال إشعار لنفسك')
    if 'bookingTypeMatchesStatus()' not in code:
        problems.append('notifications: النوع لا يطابق حالة الحجز')
    if 'chatPartiesMatch()' not in code:
        problems.append('notifications: رسالة الإشعار لا تشترط وجود محادثة')
    if 'groupOfNotification().teacherId == request.auth.uid' not in code:
        problems.append('notifications: إشعار الترقية ليس من مالك المجموعة')
    if "request.resource.data.diff(resource.data).affectedKeys().hasOnly(['readAt'])" not in code:
        problems.append('notifications: التعليم يمكنه تغيير حقول أخرى')

    # 12) منع الحقول الإدارية في ملف المدرس (P14/P15)
    teacher_block = block_starting_at(code, 'match /teacherProfiles/{uid}')
    if not teacher_block:
        problems.append('teacherProfiles: تعذّر تحديد كتلة القاعدة')
    else:
        for field in ('rating', 'reviewsCount'):
            if field in teacher_block:
                problems.append(
                    f'teacherProfiles: الحقل الإداري «{field}» مذكور في القواعد'
                )
        # القراءة للطلاب مشروطة بالتوثيق — وهو شرط الاكتشاف الحقيقي (P15).
        if "resource.data.status == 'verified'" not in teacher_block:
            problems.append('teacherProfiles: القراءة غير مقيّدة بالموثّقين')
        # قرار الإدارة مقيّد بحقول معلنة، والحالة من مجموعة مغلقة.
        if 'validAdminDecision()' not in teacher_block:
            problems.append('teacherProfiles: لا دالة قرار إدارية (validAdminDecision)')
        if "['draft', 'pendingReview', 'verified', 'rejected']" not in teacher_block:
            problems.append('teacherProfiles: الحالة الإدارية غير مقيّدة بمجموعة')
        if 'request.resource.data.reviewNote.size() >= 5' not in teacher_block:
            problems.append('teacherProfiles: سبب الرفض غير مقيّد بطول أدنى')
        # صاحب الملف: لا يغيّر المالك، والحالة تنتقل عبر الدالة المقيّدة فقط،
        # والملف المنتظر مراجعةً **مقفل** أمامه (P22).
        if 'request.resource.data.ownerId == resource.data.ownerId' not in teacher_block:
            problems.append('teacherProfiles: صاحب الملف يستطيع تغيير المالك')
        if "resource.data.status != 'pendingReview'" not in teacher_block:
            problems.append('teacherProfiles: الملف قيد المراجعة غير مقفل أمام صاحبه')
        if 'photoSatisfiedFor(' not in teacher_block:
            problems.append('teacherProfiles: الصورة غير مطلوبة عند الإرسال')
        # (P23) المادة والمرحلة إلزاميتان عند الإرسال للمراجعة.
        if 'academicFieldsSatisfiedFor(' not in teacher_block:
            problems.append(
                'teacherProfiles: المادة/المرحلة غير مشترطتين عند الإرسال'
            )
        # (P15) الاكتشاف: طريقة التقديم والمكان يكتبها المالك ضمن حقوله.
        profile_keys = block_starting_at(code, 'function profileKeys()')
        if not profile_keys:
            problems.append('teacherProfiles: لا قائمة حقول للمالك (profileKeys)')
        else:
            for field in ('isOnline', 'governorate', 'district'):
                if field not in profile_keys:
                    problems.append(f'teacherProfiles: حقل «{field}» غير مسموح للمالك')
        # (P15) التمييز: حقول إدارية لا تتغيّر في مسار المالك.
        if 'noAdminFields()' not in teacher_block:
            problems.append('teacherProfiles: الإنشاء قد يحمل حقول التمييز')
        if 'unchangedAdminFields()' not in teacher_block:
            problems.append('teacherProfiles: صاحب الملف قد يغيّر حقول التمييز')
        curation = block_starting_at(code, 'function validAdminCuration()')
        if not curation:
            problems.append('teacherProfiles: لا مسار تمييز إداري (validAdminCuration)')
        else:
            if "'isFeatured', 'featuredOrder'" not in curation:
                problems.append('teacherProfiles: التمييز قد يغيّر حقولًا أخرى')
            # لا بد من diff على المستند السابق: `request.resource.data`
            # وحدها ليست MapDiff، واستدعاء affectedKeys عليها خطأ وقت التنفيذ
            # (أفشل مسار التمييز الناجح في 2026-10-28).
            compact = curation.replace(' ', '').replace('\n', '')
            if 'request.resource.data.diff(resource.data).affectedKeys().hasOnly' \
                    not in compact:
                problems.append('teacherProfiles: التمييز بلا diff().affectedKeys')
            if "resource.data.status == 'verified'" not in curation:
                problems.append('teacherProfiles: تمييز ملف غير موثّق غير ممنوع')
            if 'featuredOrder <= 999' not in curation:
                problems.append('teacherProfiles: ترتيب التمييز بلا حد أعلى')

    # 13) P13: التقييم ببوابة G7، والمتوسط لا يتحرك بلا تقييم، والمفضلة مشتقة
    if "bookingOfReview().status == 'completed'" not in code:
        problems.append('reviews: التقييم غير مقيّد بحجز منفّذ (G7)')
    if 'request.resource.data.bookingId == reviewId' not in code:
        problems.append('reviews: معرّف التقييم ليس معرّف الحجز (ضد التكرار)')
    if 'bookingOfReview().teacherId == request.resource.data.teacherId' not in code:
        problems.append('reviews: التقييم قد يخص مدرسًا آخر')
    reviews_block = block_starting_at(code, 'match /reviews/{reviewId}')
    if not reviews_block:
        problems.append('reviews: تعذّر تحديد كتلة القاعدة')
    elif 'allow update: if false;' not in reviews_block:
        problems.append('reviews: التقييم قابل للتعديل بعد الكتابة')

    if 'getAfter(' not in code:
        problems.append('teacherRatings: الزيادة لا تُطابق تقييمًا في نفس الكتابة')
    if 'request.resource.data.totalReviews == resource.data.totalReviews + 1' not in code:
        problems.append('teacherRatings: العدّاد يزيد بأكثر من واحد')
    if 'reviewOfAggregate().rating' not in code:
        problems.append('teacherRatings: الزيادة لا تأخذ تقييم التقييم نفسه')
    if 'request.resource.data.totalReviews == resource.data.totalReviews - 1' not in code:
        problems.append('teacherRatings: لا مسار للنقصان الإداري (حذف تقييم)')
    if 'resource.data.ratingSum - request.resource.data.ratingSum >= 1' not in code:
        problems.append('teacherRatings: النقصان الإداري قد ينفخ المتوسط')

    favorites_block = block_starting_at(code, 'match /favorites/{favoriteId}')
    if not favorites_block:
        problems.append('favorites: تعذّر تحديد كتلة القاعدة')
    else:
        if 'isSelf(resource.data.studentId)' not in favorites_block:
            problems.append('favorites: القراءة/الحذف لغير صاحب المفضلة')
        if "request.resource.data.kind in ['teacher', 'group']" not in code:
            problems.append('favorites: نوع الهدف غير مقيّد بقائمة')

    # 14) P14: البلاغات لا تُحذف وتُحسم إداريًا، والقبول مشروط بالتوثيق
    reports_block = block_starting_at(code, 'match /contentReports/{reportId}')
    if not reports_block:
        problems.append('contentReports: تعذّر تحديد كتلة القاعدة')
    else:
        if "request.resource.data.status == 'open'" not in reports_block:
            problems.append('contentReports: الإنشاء غير مقيّد بحالة open')
        if 'allow update: if isAdminWriter()' not in reports_block:
            problems.append('contentReports: الحسم غير مقيّد بالإدارة')
        if 'allow delete: if false;' not in reports_block:
            problems.append('contentReports: البلاغ قابل للحذف')
    if code.count('teacherVerified(request.auth.uid)') < 6:
        problems.append('P14: مسار قبول مدرس غير مشروط بالتوثيق')

    # 15) P16: لا طلب حجز عند مدرس غير موثّق، والمهلة/الرسائل العربية موثّقة
    bookings_block = block_starting_at(code, 'match /bookingRequests/{bookingId}')
    if not bookings_block:
        problems.append('bookingRequests: تعذّر تحديد كتلة القاعدة')
    elif 'teacherVerified(request.resource.data.teacherId)' not in bookings_block:
        problems.append('P16: طلب حجز لمدرس غير موثّق غير ممنوع')

    # 16) P16: قراءة تقويم اليوم قبل وجوده (أول حجز في اليوم)
    calendar_block = block_starting_at(code, 'match /teacherCalendar/{calendarId}')
    if not calendar_block:
        problems.append('teacherCalendar: تعذّر تحديد كتلة القاعدة')
    elif 'resource == null' not in calendar_block:
        problems.append('teacherCalendar: قراءة مستند غير موجود تُرفض (أول حجز يفشل)')

    # 17) P17: حذف الحساب الناعم — انتقالات محددة، وخروج الملف من الاكتشاف
    users_block = block_starting_at(code, 'match /users/{uid}')
    if not users_block:
        problems.append('users: تعذّر تحديد كتلة القاعدة')
    else:
        if 'validAccountStateChange()' not in users_block:
            problems.append('users: لا قاعدة انتقال لحالة الحساب (P17)')
        if "'status', 'scheduledDeletionAt'" not in users_block:
            problems.append('users: حقلا الحذف الناعم غير مذكورين في قائمة التحديث')
    for needle, message in (
        (
            "accountStatusOf(request.resource.data) == 'pending_deletion'",
            'users: لا مسار لطلب الحذف (P17)',
        ),
        (
            "accountStatusOf(request.resource.data) == 'active'",
            'users: لا مسار لاستعادة الحساب (P17)',
        ),
        (
            'request.resource.data.scheduledDeletionAt > request.time',
            'users: موعد الحذف قد يكون في الماضي (P17)',
        ),
        (
            "duration.value(8, 'd')",
            'users: سقف مهلة الحذف (8 أيام) غير مفروض',
        ),
        (
            "!('scheduledDeletionAt' in request.resource.data.keys())",
            'users: الاستعادة قد تُبقي موعد الحذف',
        ),
        (
            "resource.data.scheduledDeletionAt > request.time",
            'users: الاستعادة ممكنة بعد انتهاء المهلة',
        ),
        (
            "'accountHidden', false) == false",
            'P17: علم إخفاء الملف عند الحذف غير مفحوص',
        ),
    ):
        if needle not in code:
            problems.append(message)
    if (
        "resource.data.status == 'verified'" not in code
        or code.count("'accountHidden', false) == false") < 2
    ):
        problems.append(
            'teacherProfiles: الاكتشاف/التوثيق لا يستثني الملف المخفي بحذف الحساب'
        )
    if "'reviewedBy', 'accountHidden'" not in code:
        problems.append('teacherProfiles: accountHidden غير مسموح لصاحب الملف')

    # 18) المزاد (P30): **لا كتابة عميل** على أي مسار، والخصوصية مفروضة.
    auction_blocks = {
        'match /auctions/{auctionId}': ("allow write: if false", 'auctions'),
        'match /auctionResults/{auctionId}': ("allow write: if false", 'auctionResults'),
        'match /auctionConfig/{docId}': ("allow write: if false", 'auctionConfig'),
        'match /auctionAudit/{entryId}': ("allow write: if false", 'auctionAudit'),
        'match /auctionIdempotency/{key}': ("allow read, write: if false", 'auctionIdempotency'),
    }
    for header, (needle, label) in auction_blocks.items():
        block = match_block(code, header)
        if not block:
            problems.append(f'P30: كتلة {label} غير مقروءة')
            continue
        if needle not in block:
            problems.append(f'P30: {label} تقبل كتابة من العميل (يجب {needle})')

    auctions_block = match_block(code, 'match /auctions/{auctionId}')
    for needle, message in (
        (
            'allow read: if isAdmin()',
            'P30: مستند الدورة يُقرأ لغير الإدارة',
        ),
        (
            'match /bids/{teacherId}',
            'P30: مزايدات المدرسين غير مقيّدة بمسار المدرّس نفسه',
        ),
        (
            'match /winners/{teacherId}',
            'P30: مقاعد الفائزين غير مقيّدة بمسار الفائز نفسه',
        ),
    ):
        if auctions_block and needle not in auctions_block:
            problems.append(message)

    results_block = match_block(code, 'match /auctionResults/{auctionId}')
    if results_block and 'allow read: if signedIn()' not in results_block:
        problems.append('P30: النتائج العامة غير متاحة للمسجّلين')

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
