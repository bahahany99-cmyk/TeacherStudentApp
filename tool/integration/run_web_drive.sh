#!/usr/bin/env bash
# تشغيل اختبار التكامل الحقيقي لتنفيذ Firestore (P32 — محاولة أخيرة).
#
# **يُشغَّل داخل `firebase emulators:exec`** لأن المحاكيين يجب أن يكونا جاهزين:
#   firebase emulators:exec --only firestore,auth --project demo-darsly \
#     --config firebase.json "tool/integration/run_web_drive.sh"
#
# ما يفعله:
#   1. يشغّل chromedriver على المنفذ 4444 (يحتاجه `flutter drive` للويب).
#   2. يهيّئ البيانات + حسابات المحاكي بسكربت Node (متجاوزًا القواعد للتهيئة).
#   3. يشغّل `flutter drive -d web-server`: بناء ويب **حقيقي** يمرّ على مُسجِّل
#      إضافات Flutter، فتعمل Firebase كما في التطبيق — خلافًا لـ`flutter test
#      --platform chrome` الذي لا يسجّل الإضافات فيه.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CHROMEDRIVER_PORT=4444
WEB_PORT=7357

if ! command -v chromedriver >/dev/null 2>&1; then
  echo "::error::chromedriver غير موجود في PATH — لا يمكن تشغيل flutter drive للويب."
  exit 1
fi

echo "→ تشغيل chromedriver على المنفذ ${CHROMEDRIVER_PORT}"
chromedriver --port="${CHROMEDRIVER_PORT}" >/tmp/chromedriver.log 2>&1 &
CHROMEDRIVER_PID=$!
trap 'kill "${CHROMEDRIVER_PID}" 2>/dev/null || true' EXIT
sleep 3
if ! kill -0 "${CHROMEDRIVER_PID}" 2>/dev/null; then
  echo "::error::chromedriver لم يبدأ:"
  cat /tmp/chromedriver.log || true
  exit 1
fi

echo "→ تهيئة بيانات المحاكي وحساباته"
node tool/rules_tests/seed_integration.mjs

echo "→ flutter drive (بناء ويب حقيقي + Chrome)"
# أقل خيارات ممكنة: أي خيار غير مدعوم في إصدار Flutter الحالي يُفشل الأمر كله.
flutter drive --verbose \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/p32_firestore_repositories_test.dart \
  -d web-server \
  --web-port="${WEB_PORT}" \
  --browser-name=chrome

echo "✅ اختبار التكامل: تنفيذ Firestore الحقيقي (تصفّح/تعليم/عدّاد/علامات القراءة)."
