#!/usr/bin/env python3
"""فحص بنيوي سريع لملفات Dart (بديل جزئي لا يعوّض `dart analyze`).

يتحقق من:
- توازن الأقواس `{}` `()` `[]` بعد إزالة التعليقات والنصوص.
- وجود كل ملفات الاستيراد (package:teacher_student_app/… والمسارات النسبية).
- عدم وجود واجهات LTR مثبتة (EdgeInsets.only(left/right)، Positioned(left/right)،
  TextAlign.left/right) خارج الأماكن المسموح بها — مشروعنا RTL بالكامل.

يُستخدم في بيئة التطوير المحلية، والتحقق الحقيقي هو `dart analyze` في CI.
"""

from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PKG = 'teacher_student_app'

LTR_PATTERNS = (
    r'EdgeInsets\.only\(\s*(left|right)\s*:',
    r'EdgeInsets\.fromLTRB\(',
    r'Positioned\(\s*(left|right)\s*:',
    r'TextAlign\.(left|right)\b',
    r'Alignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)',
    r'BorderRadius\.only\(\s*top(Left|Right)',
)

# ملفات مسموح لها (لا يوجد حاليًا) — تُضاف بمبرر.
LTR_ALLOWED: set[str] = set()


def strip_code(src: str) -> str:
    out: list[str] = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            while i < n and src[i] != '\n':
                i += 1
            continue
        if c == '/' and i + 1 < n and src[i + 1] == '*':
            i += 2
            while i + 1 < n and not (src[i] == '*' and src[i + 1] == '/'):
                i += 1
            i += 2
            continue
        if c in "'\"":
            q = c
            triple = src[i:i + 3] == q * 3
            if triple:
                i += 3
                while i < n and src[i:i + 3] != q * 3:
                    i += 1
                i += 3
            else:
                i += 1
                while i < n:
                    if src[i] == '\\':
                        i += 2
                        continue
                    if src[i] == q:
                        i += 1
                        break
                    if src[i] == '\n':
                        break
                    i += 1
            out.append('""')
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def main() -> int:
    problems: list[str] = []
    files: list[str] = []

    for dirpath, dirnames, names in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in {'.git', 'build', '.dart_tool'}]
        for name in names:
            if name.endswith('.dart'):
                files.append(os.path.join(dirpath, name))

    for path in sorted(files):
        rel = os.path.relpath(path, ROOT)
        src = open(path, encoding='utf-8').read()
        code = strip_code(src)

        for open_c, close_c in (('{', '}'), ('(', ')'), ('[', ']')):
            if code.count(open_c) != code.count(close_c):
                problems.append(f'{rel}: أقواس غير متوازنة {open_c}{close_c}')

        for match in re.finditer(r"import\s+'([^']+)'", src):
            uri = match.group(1)
            if uri.startswith(f'package:{PKG}/'):
                target = os.path.join(ROOT, 'lib', uri[len(f'package:{PKG}/'):])
                if not os.path.exists(target):
                    problems.append(f'{rel}: استيراد غير موجود -> {uri}')
            elif uri.startswith(('package:', 'dart:')):
                continue
            else:
                target = os.path.normpath(os.path.join(os.path.dirname(path), uri))
                if not os.path.exists(target):
                    problems.append(f'{rel}: استيراد نسبي غير موجود -> {uri}')

        if rel not in LTR_ALLOWED and '/features/' in f'/{rel}' or rel.startswith('lib/core'):
            for pattern in LTR_PATTERNS:
                for hit in re.finditer(pattern, code):
                    line = code[: hit.start()].count('\n') + 1
                    problems.append(
                        f'{rel}:{line}: اتجاه LTR مثبّت ({hit.group(0).strip()}) '
                        '— استخدم البديل الاتجاهي (Directional/start/end)'
                    )

    print(f'ملفات Dart: {len(files)}')
    if problems:
        print(f'مشاكل: {len(problems)}')
        for problem in problems:
            print(' -', problem)
        return 1

    print('OK: الأقواس متوازنة، الاستيرادات موجودة، ولا اتجاه LTR مثبّت.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
