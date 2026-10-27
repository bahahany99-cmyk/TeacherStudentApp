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

echo "✓ تم توليد android/ — الاسم الظاهر: $TEMP_APP_LABEL (مؤقت)"
echo "  ملاحظة: android/local.properties يُنشأ تلقائيًا وقت البناء وهو مستثنى من Git."
