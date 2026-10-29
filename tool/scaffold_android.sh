#!/usr/bin/env bash
#
# توليد مجلد منصة Android بشكل حتمي (deterministic).
#
# السبب: المشروع بُني في بيئة لا تحتوي Flutter SDK، فلم يكن ممكنًا تنفيذ
# `flutter create` وقت الإنشاء. هذا السكربت يولّد المجلد على أي جهاز/CI فيه
# Flutter، بنفس الناتج في كل مرة.
#
# الاستخدام:
#   bash tool/scaffold_android.sh          # يولّد android/ إن لم يكن موجودًا
#   bash tool/scaffold_android.sh --force  # يعيد التوليد من جديد
#
# ملاحظات:
# - لا يلمس lib/ ولا test/ ولا pubspec.yaml إطلاقًا (التوليد في مجلد مؤقت).
# - يستخدم --project-name app --org com.darsly لإنتاج applicationId = com.darsly.app
#   (القرار المعتمد G1 — راجع docs/ARCHITECTURE_DECISIONS.md → A-21).
# - يضبط اسم التطبيق الظاهر على الاسم المؤقت (قابل للتغيير عند اعتماد الهوية).

set -euo pipefail

ORG="com.darsly"
PROJECT_NAME="app"
EXPECTED_APP_ID="${ORG}.${PROJECT_NAME}"
# الاسم الظاهر المؤقت — يُحدَّث في P1/P17 عند اعتماد الهوية (G3).
TEMP_APP_LABEL="درسلي"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
  FORCE=1
fi

if [[ -d "android" && $FORCE -eq 0 ]]; then
  echo "android/ موجود بالفعل — لا شيء لتوليده (استخدم --force لإعادة التوليد)."
  exit 0
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "خطأ: flutter غير متاح في PATH. هذا السكربت يحتاج Flutter SDK." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "→ توليد مشروع هيكلي في مجلد مؤقت…"
flutter create \
  --platforms=android \
  --org "$ORG" \
  --project-name "$PROJECT_NAME" \
  --description "scaffold only" \
  "$TMP_DIR/scaffold" >/dev/null

if [[ -d "android" && $FORCE -eq 1 ]]; then
  echo "→ حذف android/ القديم (--force)…"
  rm -rf "android"
fi

echo "→ نسخ مجلد المنصة فقط…"
cp -r "$TMP_DIR/scaffold/android" ./android

# ضبط اسم التطبيق الظاهر (مؤقت).
MANIFEST="android/app/src/main/AndroidManifest.xml"
if [[ -f "$MANIFEST" ]]; then
  python3 - "$MANIFEST" "$TEMP_APP_LABEL" <<'PY'
import re
import sys

path, label = sys.argv[1], sys.argv[2]
src = open(path, encoding='utf-8').read()
new = re.sub(r'android:label="[^"]*"', f'android:label="{label}"', src, count=1)
if new == src and 'android:label' not in src:
    new = src.replace('<application', f'<application\n        android:label="{label}"', 1)
open(path, 'w', encoding='utf-8').write(new)
PY
fi

# ---------------------------------------------------------------------------
# إذن الإنترنت في البيان الرئيسي (P18) — عطل حقيقي اكتُشف على جهاز فعلي.
#
# قالب Flutter يضع <uses-permission android:name="android.permission.INTERNET"/>
# في src/debug/AndroidManifest.xml و src/profile/AndroidManifest.xml **فقط**.
# النتيجة: نسخة release (وهي ما نوزّعه) تخرج بلا إذن إنترنت، فيفشل كل طلب شبكي
# بـ network-request-failed، ويظهر للمستخدم «لا يوجد اتصال بالإنترنت» رغم أن
# الشبكة تعمل — وهذا ما حدث بالضبط عند اختيار حساب Google ثم استدعاء Firebase.
#
# نضيفه هنا فيبقى ثابتًا في كل بناء، مع ACCESS_NETWORK_STATE لتشخيص حالة الشبكة.
# ---------------------------------------------------------------------------
if [[ -f "$MANIFEST" ]]; then
  python3 - "$MANIFEST" <<'PERMISSIONS'
import sys

path = sys.argv[1]
src = open(path, encoding='utf-8').read()

needed = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
]

added = []
for permission in needed:
    if permission in src:
        continue
    if '<application' in src:
        # نحافظ على المسافة البادئة لسطر <application> نفسه.
        index = src.index('<application')
        line_start = src.rfind('\n', 0, index) + 1
        indent = src[line_start:index]
        entry = f'{indent}<uses-permission android:name="{permission}"/>\n'
        src = src[:line_start] + entry + src[line_start:]
    else:
        # بلا <application>: نُدرج قبل إغلاق <manifest>
        entry = f'    <uses-permission android:name="{permission}"/>\n'
        src = src.replace('</manifest>', entry + '</manifest>', 1)
    added.append(permission)

if added:
    open(path, 'w', encoding='utf-8').write(src)
    print('✓ أُضيف إلى البيان الرئيسي: ' + '، '.join(added))
else:
    print('✓ أذونات الشبكة موجودة مسبقًا في البيان الرئيسي')
PERMISSIONS

  # تحقق صريح: بلا INTERNET يفشل كل شيء شبكي في release.
  if grep -q 'android.permission.INTERNET' "$MANIFEST"; then
    echo "✓ إذن INTERNET مثبّت في البيان الرئيسي (لا debug فقط)"
  else
    echo "خطأ: إذن INTERNET غير موجود في $MANIFEST" >&2
    exit 1
  fi
fi

# رفع أدنى إصدار أندرويد إلى 23.
# السبب: firebase_auth / cloud_firestore (P4) يتطلبان minSdk 23 على الأقل؛
# القيمة الافتراضية في Flutter قد تكون 21 فتظهر أخطاء بناء متأخرة.
GRADLE_SDK_FILE="android/app/build.gradle.kts"
[[ -f "$GRADLE_SDK_FILE" ]] || GRADLE_SDK_FILE="android/app/build.gradle"
python3 - "$GRADLE_SDK_FILE" <<'MINSDK'
import re
import sys

path = sys.argv[1]
src = open(path, encoding='utf-8').read()
new, count = re.subn(
    r'minSdk\s*=?\s*(?:flutter\.)?minSdkVersion',
    'minSdk = 23',
    src,
    count=1,
)
if count == 0:
    sys.exit('خطأ: لم أجد minSdk في ملف Gradle')
open(path, 'w', encoding='utf-8').write(new)
print('✓ minSdk = 23 (متطلب Firebase Auth / Firestore)')
MINSDK

# تحقق من أن applicationId هو المعتمد.
GRADLE_FILE="android/app/build.gradle.kts"
[[ -f "$GRADLE_FILE" ]] || GRADLE_FILE="android/app/build.gradle"
if grep -q "applicationId = \"$EXPECTED_APP_ID\"\|applicationId \"$EXPECTED_APP_ID\"" "$GRADLE_FILE"; then
  echo "✓ applicationId = $EXPECTED_APP_ID"
else
  echo "خطأ: applicationId المتوقع ($EXPECTED_APP_ID) غير موجود في $GRADLE_FILE" >&2
  grep -n "applicationId" "$GRADLE_FILE" || true
  exit 1
fi

# ---------------------------------------------------------------------------
# Edge-to-Edge: transparent system bars (v3, 2026-10-27).
# The black band at the top of the screen came from the platform painting the
# status bar with the default dark colour behind our light UI. Overriding the
# theme removes it even before the Dart-side SystemChrome call runs (i.e. also
# on the launch screen and in the Recent Apps preview).
# ---------------------------------------------------------------------------
for STYLES_FILE in \
  android/app/src/main/res/values/styles.xml \
  android/app/src/main/res/values-night/styles.xml; do
[[ -f "$STYLES_FILE" ]] || continue
python3 - "$STYLES_FILE" <<'STYLES_PATCH'
import re
import sys

path = sys.argv[1]
src = open(path, encoding='utf-8').read()

items = [
    '<item name="android:statusBarColor">@android:color/transparent</item>',
    '<item name="android:navigationBarColor">@android:color/transparent</item>',
    '<item name="android:windowDrawsSystemBarBackgrounds">true</item>',
    '<item name="android:windowLightStatusBar">true</item>',
    '<item name="android:windowLightNavigationBar">true</item>',
    '<item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>',
]

inserted = []


def patch_style(match):
    block = match.group(0)
    missing = [item for item in items if item not in block]
    if not missing:
        return block
    indent = '        '
    body = '\n'.join(indent + item for item in missing)
    inserted.extend(missing)
    return block.replace('</style>', body + '\n    </style>', 1)


src = re.sub(r'<style\b.*?</style>', patch_style, src, flags=re.S)
open(path, 'w', encoding='utf-8').write(src)
print('%s: %d item(s) added' % (path, len(inserted)))
STYLES_PATCH
done

echo "✓ تم توليد android/ — الاسم الظاهر: $TEMP_APP_LABEL (مؤقت)"
echo "  ملاحظة: android/local.properties يُنشأ تلقائيًا وقت البناء وهو مستثنى من Git."
