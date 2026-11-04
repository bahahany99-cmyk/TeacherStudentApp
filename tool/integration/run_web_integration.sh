#!/usr/bin/env bash
# تشغيل اختبار التكامل الحقيقي لتنفيذ Firestore (P32 — محاولة أخيرة).
#
# **يُشغَّل داخل `firebase emulators:exec`** لأن المحاكيين يجب أن يكونا جاهزين:
#   firebase emulators:exec --only firestore,auth --project demo-darsly \
#     --config firebase.json "tool/integration/run_web_integration.sh"
#
# **المسارات التي جُرّبت وأُغلقت:**
#   * `flutter test --platform chrome` ⇒ لا يُسجّل إضافات الويب، فيُعلَّق
#     `Firebase.initializeApp` (تشغيلات 41793072285 … 41800407384).
#   * `flutter test … -d chrome` ⇒ يرفضه Flutter نفسه: «Web devices are not
#     supported for integration tests yet.» (تشغيل 41831091503).
#   * `flutter drive … -d chrome` ⇒ عُلِّق حتى ألغت المهلة الوظيفة (41825828025).
#   * الباقي: `flutter drive -d web-server --browser-name=chrome` مع chromedriver
#     — الطريق الموثّق والوحيد المدعوم لاختبار التكامل على الويب.
#
# **كيف نحكم؟** لا بسطر «All tests passed» (قد يُطبع بعدد صفر اختبارات)، بل
# بتقارير كل اختبار من داخل التطبيق إلى خادم محلي (`results_server.mjs`):
#   لا `__main` ⇒ التطبيق لم يبدأ في المتصفح.
#   بلا `__registered` ⇒ بدأ وتعطّلت التهيئة/`setUpAll`.
#   أقل من 11 تقريرًا ⇒ سُجّلت ولم تُنفَّذ كلها.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CHROMEDRIVER_PORT=4444
WEB_PORT=7357
RESULTS_PORT=4445
RESULTS_FILE=/tmp/repos_results.txt
EXPECTED_TESTS=11
# مهلة قصوى: إن عُلِّق السائق نفشل برسالة مفهومة بدل أن تُلغي المهلة الوظيفة.
DRIVE_TIMEOUT=900

if ! command -v chromedriver >/dev/null 2>&1; then
  echo "::error::chromedriver غير موجود في PATH — لا يمكن تشغيل flutter drive للويب."
  exit 1
fi

echo "→ تشغيل chromedriver على المنفذ ${CHROMEDRIVER_PORT}"
chromedriver --port="${CHROMEDRIVER_PORT}" >/tmp/chromedriver.log 2>&1 &
CHROMEDRIVER_PID=$!
trap 'kill "${CHROMEDRIVER_PID}" "${RESULTS_PID:-}" 2>/dev/null || true' EXIT
sleep 3
if ! kill -0 "${CHROMEDRIVER_PID}" 2>/dev/null; then
  echo "::error::chromedriver لم يبدأ:"
  cat /tmp/chromedriver.log || true
  exit 1
fi

echo "→ تهيئة بيانات المحاكي وحساباته"
node tool/rules_tests/seed_integration.mjs

echo "→ تشغيل خادم نتائج الاختبارات على 127.0.0.1:${RESULTS_PORT}"
node tool/integration/results_server.mjs serve "${RESULTS_PORT}" "${RESULTS_FILE}" \
  >/tmp/results_server.log 2>&1 &
RESULTS_PID=$!
sleep 2
if ! kill -0 "${RESULTS_PID}" 2>/dev/null; then
  echo "::error::خادم النتائج لم يبدأ:"
  cat /tmp/results_server.log || true
  exit 1
fi

DRIVE_STATUS=0
echo "→ flutter drive -d web-server (بناء ويب حقيقي + Chrome، مهلة ${DRIVE_TIMEOUT}s)"
timeout --signal=INT "${DRIVE_TIMEOUT}" \
  flutter drive --verbose \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/p32_firestore_repositories_test.dart \
  -d web-server \
  --web-port="${WEB_PORT}" \
  --browser-name=chrome \
  || DRIVE_STATUS=$?

if [ "${DRIVE_STATUS}" -eq 124 ] || [ "${DRIVE_STATUS}" -eq 130 ]; then
  echo "::error::انتهت المهلة (${DRIVE_TIMEOUT}s) قبل إنهاء السائق — تعليق في البناء أو تشغيل الصفحة."
fi

# الفحص الحاسم: ما وصل من داخل التطبيق، لا ما طبعه السائق.
set +e
node tool/integration/results_server.mjs verify "${RESULTS_PORT}" "${RESULTS_FILE}" "${EXPECTED_TESTS}"
VERIFY_STATUS=$?
set -e

if [ "${DRIVE_STATUS}" -ne 0 ]; then
  echo "::error::flutter drive خرج بالرمز ${DRIVE_STATUS}."
  exit "${DRIVE_STATUS}"
fi
if [ "${VERIFY_STATUS}" -ne 0 ]; then
  echo "::error::الاختبارات لم تُنفَّذ كلها داخل التطبيق (انظر رسائل الفحص أعلاه)."
  exit "${VERIFY_STATUS}"
fi

echo "✅ اختبار التكامل: تنفيذ Firestore الحقيقي (تصفّح/تعليم/عدّاد/علامات القراءة)."
