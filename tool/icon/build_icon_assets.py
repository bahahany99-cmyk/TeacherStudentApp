#!/usr/bin/env python3
"""يشتقّ طبقات أيقونة أندرويد التكيّفية من الصورة الأم (P20).

**لماذا سكربت لا ملفات سحرية؟** لأن `app_icon_foreground.png` و
`app_icon_background.png` و`app_icon_monochrome.png` مشتقّة من
`app_icon.png` بقواعد (فصل العلامة عن التدرّج، إعادة التوسيط داخل المنطقة
الآمنة، تمويه الخلفية). بدون هذا الملف يصبح كل تعديل على الصورة الأم عملية
يدوية غير قابلة للتكرار، وأول من يعيد التوليد بعد شهور سيحصل على نتيجة مختلفة.

الاستخدام (يتطلب Pillow وnumpy — بيئة تطوير فقط، لا وقت التشغيل):

    python3 tool/icon/build_icon_assets.py
    dart run flutter_launcher_icons      # بعد pub get

⚠️ الصورة الأم **يجب أن تكون 1024×1024 وبخلفية تدرّج ملوّنة**، والعلامة في
وسطها. السكربت يفصل «خلفية» عن «علامة» بقاعدة لونية (درجة لون أرجوانية/ماجنتا
بتشبّع عالٍ = خلفية)، ثم:

- `app_icon_foreground.png`: العلامة وحدها، شفافة، مكبَّرة/موسَّطة لتشغل 52.7%
  من اللوحة (كل نقاطها داخل الدائرة الآمنة 66dp في أندرويد، فلا يقطعها القناع).
- `app_icon_background.png`: التدرّج وحده، مموّه تمريرًا على نسخة مصغّرة ثم
  مكبَّرة — يمحو أثر العلامة تمامًا ويُبقي الألوان بلا كتل مرئية عند التكبير
  1.5× الذي يطبّقه أندرويد على طبقة الخلفية.
- `app_icon_monochrome.png`: ظلّية بيضاء بقناع شفاف العلامة (أيقونات أندرويد
  13+ «Themed icons»).
"""

from __future__ import annotations

import pathlib
import sys

try:
    import numpy as np
    from PIL import Image, ImageFilter
except ImportError:  # pragma: no cover - رسالة واضحة بدل أثر استيراد
    sys.exit('يتطلب Pillow وnumpy: pip install Pillow numpy')

ROOT = pathlib.Path(__file__).resolve().parents[2]
ICON_DIR = ROOT / 'assets' / 'icon'

MASTER = ICON_DIR / 'app_icon.png'
FOREGROUND = ICON_DIR / 'app_icon_foreground.png'
BACKGROUND = ICON_DIR / 'app_icon_background.png'
MONOCHROME = ICON_DIR / 'app_icon_monochrome.png'

CANVAS = 1024
# 540/1024 = 52.7%: العلامة كلها داخل **الدائرة الآمنة** في أندرويد التكيّفي.
#   طبقة الأيقونة 108dp والماسك 72dp والدائرة المضمونة 66dp ⇒ 313px من 1024.
#   على 600px كان نصف قطر أبعد بكسل 338px (خارج الضمان بقليل — تقطعه الأقنعة
#   الصغيرة)، وعلى 540px يصبح ≈304px. والغلاف لا يزال يملأ ~86% من الدائرة
#   الآمنة، أي بوزن بصري كأيقونات التطبيقات الكبيرة لا أصغر.
EMBLEM_SIZE = 540


def emblem_alpha(rgb: 'np.ndarray') -> 'np.ndarray':
    """قناع العلامة: كل ما ليس خلفية التدرّج."""
    arr = rgb.astype(np.float32) / 255.0
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    high = arr.max(axis=2)
    low = arr.min(axis=2)
    delta = high - low + 1e-6

    # درجة اللون بالدرجات
    hue = np.zeros_like(high)
    is_r, is_g, is_b = high == r, high == g, high == b
    hue[is_r] = ((g - b) / delta)[is_r] % 6
    hue[is_g] = ((b - r) / delta + 2)[is_g]
    hue[is_b] = ((r - g) / delta + 4)[is_b]
    hue *= 60.0

    saturation = np.where(high > 0, (high - low) / np.maximum(high, 1e-6), 0)

    # خلفية الهوية: بنفسجي/ماجنتا عالي التشبّع (235°..360° و0°..8°).
    background = (((hue >= 232) | (hue <= 8)) & (saturation > 0.30) & (high > 0.22))

    alpha = np.where(background, 0.0, 1.0).astype(np.float32)
    softened = Image.fromarray((alpha * 255).astype(np.uint8), 'L').filter(
        ImageFilter.GaussianBlur(1.4)
    )
    edge = np.asarray(softened).astype(np.float32) / 255.0
    # ضغط القيم نحو 0/1 مع إبقاء تدرّج رفيع على الحافة (بلا هالة أرجوانية).
    return np.clip((edge - 0.25) / 0.5, 0, 1)


def main() -> int:
    if not MASTER.exists():
        return _fail(f'الصورة الأم غير موجودة: {MASTER}')

    master = Image.open(MASTER).convert('RGB')
    if master.size != (CANVAS, CANVAS):
        return _fail(f'الصورة الأم يجب أن تكون {CANVAS}×{CANVAS}، وجدنا {master.size}')

    rgb = np.asarray(master)
    alpha = emblem_alpha(rgb)

    foreground = Image.fromarray(
        np.dstack([rgb.astype(np.float32), alpha * 255.0]).astype(np.uint8), 'RGBA'
    )
    emblem = foreground.crop(foreground.split()[3].getbbox())

    scale = EMBLEM_SIZE / max(emblem.size)
    emblem = emblem.resize(
        (max(1, round(emblem.width * scale)), max(1, round(emblem.height * scale))),
        Image.LANCZOS,
    )
    canvas = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(
        emblem, ((CANVAS - emblem.width) // 2, (CANVAS - emblem.height) // 2)
    )
    canvas.save(FOREGROUND, optimize=True)

    # الخلفية: تصغير شديد ⇒ تمويه ⇒ تكبير. يمحو العلامة ويُبقي التدرّج ناعمًا.
    background = (
        master.resize((64, 64), Image.LANCZOS)
        .filter(ImageFilter.GaussianBlur(6))
        .resize((CANVAS, CANVAS), Image.BICUBIC)
        .filter(ImageFilter.GaussianBlur(12))
    )
    background.save(BACKGROUND, optimize=True)

    mono_alpha = np.asarray(canvas.split()[3])
    monochrome = np.dstack([np.full_like(mono_alpha, 255)] * 3 + [mono_alpha])
    Image.fromarray(monochrome.astype(np.uint8), 'RGBA').save(MONOCHROME, optimize=True)

    coverage = float((alpha > 0.5).mean()) * 100
    print(f'✅ app_icon_foreground.png  (تغطية العلامة في الأم: {coverage:.1f}%)')
    print('✅ app_icon_background.png')
    print('✅ app_icon_monochrome.png')
    print('الخطوة التالية: dart run flutter_launcher_icons')
    return 0


def _fail(message: str) -> int:
    print(f'❌ {message}', file=sys.stderr)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
