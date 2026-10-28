#!/usr/bin/env python3
"""ينشر مقاطع الفشل من ملف سجل كـ GitHub Actions annotations.

السبب: سجلات Actions وملفاتها تُخزَّن في blob storage غير متاح من بيئة التطوير،
لكن الـ annotations تُقرأ عبر api.github.com، فتصبح النتائج قابلة للمراجعة.

ننشر **مقاطع الفشل كاملة** (من سطر العنوان حتى نهاية الأثر) لا شرائح متساوية:
الشرائح المتساوية كانت تقطع سطر «The following X was thrown» الذي يحدّد نوع
الخطأ، فيصل التشخيص بلا سببه.

الاستخدام:
    python3 tool/ci/annotate_log.py /tmp/test.txt "flutter-test"
"""

from __future__ import annotations

import pathlib
import sys

# GitHub يعرض عددًا محدودًا من الـ annotations لكل خطوة، فنبدأ بالأهم.
MAX_ANNOTATIONS = 9
LINES_PER_BLOCK = 70
MAX_CHARS = 6000

MARKERS = (
    'EXCEPTION CAUGHT',
    'Failing tests:',
    'Error:',
    'error •',
    'FAILED',
    # صيغة `node --test`: كل فشل يبدأ بـ✖، وتفاصيله في قسم «failing tests».
    '✖',
    'not ok',
    'failing tests',
    'AssertionError',
    'PERMISSION_DENIED',
    'Missing or insufficient permissions',
)

# **ترتيب الأهمية:** اختبارات القواعد السلبية تُنتج `PERMISSION_DENIED` في كل
# تشغيل ناجح، فلو أخذنا المقاطع بترتيب ظهورها لامتلأت الـannotations بالضجيج
# وضاعت أسطر الفشل الحقيقية (حدث فعلًا في P14). نقدّم مقاطع الفشل الفعلية.
HIGH_PRIORITY = (
    '✖',
    'not ok',
    'Failing tests:',
    'failing tests',
    'AssertionError',
    'EXCEPTION CAUGHT',
    'Error:',
    'error •',
    'FAILED',
)

# سطور نهاية السجل: فيها ملخّص `node --test` (`ℹ fail`) وسطر خروج الأداة.
TAIL_LINES = 40


def escape(value: str) -> str:
    return value.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')


def main() -> int:
    if len(sys.argv) < 2:
        print('الاستخدام: annotate_log.py <log-file> [title]', file=sys.stderr)
        return 2

    path = pathlib.Path(sys.argv[1])
    title = sys.argv[2] if len(sys.argv) > 2 else 'log'

    if not path.exists():
        print(f'::warning::ملف السجل غير موجود: {path}')
        return 0

    lines = path.read_text(errors='replace').splitlines()

    candidates: list[tuple[int, int, str]] = []
    used_until = -1

    for index, line in enumerate(lines):
        if index <= used_until:
            continue
        if not any(marker in line for marker in MARKERS):
            continue

        part = lines[index : index + LINES_PER_BLOCK]
        block = '\n'.join(part)[:MAX_CHARS]
        priority = 0 if any(marker in line for marker in HIGH_PRIORITY) else 1
        candidates.append((priority, index, f'[سطر {index + 1}]\n{block}'))
        used_until = index + len(part) - 1

    # الفشل الحقيقي أولًا، وداخل الفئة نفسها ترتيب ظهوره.
    candidates.sort(key=lambda item: (item[0], item[1]))
    blocks: list[str] = [item[2] for item in candidates]

    # ذيل السجل دائمًا: ملخّص الفشل الحقيقي يكون في آخر السطور، وكان يضيع
    # حين تستهلك مقاطع الضجيج الحدّ الأقصى للـannotations.
    tail = lines[-TAIL_LINES:]
    if tail:
        tail_block = '[النهاية]\n' + '\n'.join(tail)[:MAX_CHARS]
        if tail_block not in blocks:
            blocks.insert(0, tail_block)

    for number, block in enumerate(blocks[:MAX_ANNOTATIONS], start=1):
        print(f'::error title={title} ({number}/{len(blocks)})::{escape(block)}')

    if len(blocks) > MAX_ANNOTATIONS:
        print(
            f'::warning::{title}: عُرض {MAX_ANNOTATIONS} من {len(blocks)} مقطع فشل.'
        )

    return 0


if __name__ == '__main__':
    sys.exit(main())
