#!/usr/bin/env python3
"""ينشر محتوى ملف سجل كـ GitHub Actions annotations.

السبب: سجلات Actions تُخزَّن في blob storage غير متاح من بيئة التطوير، لكن
الـ annotations تُقرأ عبر api.github.com، فتصبح النتائج قابلة للمراجعة.

الاستخدام:
    python3 tool/ci/annotate_log.py /tmp/test.txt "flutter-test"
"""

from __future__ import annotations

import pathlib
import sys

MAX_ANNOTATIONS = 10
LINES_PER_ANNOTATION = 40


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
    limit = LINES_PER_ANNOTATION * MAX_ANNOTATIONS

    for start in range(0, min(len(lines), limit), LINES_PER_ANNOTATION):
        part = lines[start : start + LINES_PER_ANNOTATION]
        message = escape('\n'.join(part))
        print(f'::error title={title} (سطور {start + 1}-{start + len(part)})::{message}')

    if len(lines) > limit:
        print(f'::warning::{title}: تم قصّ السجل ({len(lines)} سطرًا).')

    return 0


if __name__ == '__main__':
    sys.exit(main())
