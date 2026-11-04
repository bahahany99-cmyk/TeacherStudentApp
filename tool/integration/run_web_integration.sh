#!/usr/bin/env bash
# تشغيل اختبار التكامل الحقيقي لتنفيذ Firestore (P32 — محاولة أخيرة).
#
# **يُشغَّل داخل `firebase emulators:exec`** لأن المحاكيين يجب أن يكونا جاهزين:
#   firebase emulators:exec --only firestore,auth --project demo-darsly \
#     --config firebase.json "tool/integration/run_web_integration.sh"
#
# ما يفعله:
#   1. يهيّئ البيانات + حسابات المحاكي بسكربت Node (متجاوزًا القواعد للتهيئة).
#   2. يشغّل خادم نتائج محليًا (4445): كل اختبار يُرسل نتيجته من **داخل التطبيق**
#      (`results_server.mjs` + `integration_test/result_reporter_web.dart`)، لأن
#      `flutter drive` على الويب قد يطبع «All tests passed.» بعدد صفر اختبارات
#      (flutter#94434، #150358، #151480).
#   3. يشغّل `flutter test integration_test/... -d chrome`:
#      * ليس `--platform chrome` (جُرّب وفشل: لا يُسجّل إضافات الويب، فيُعلَّق
#        `Firebase.initializeApp` — التشغيلات 41793072285 … 41800407384).
#      * وليس `flutter drive` (جُرّب بصيغتين: `-d web-server` + chromedriver
#        انتهى بـ«All tests passed» بلا أي اختبار، و`-d chrome` عُلِّق 35 دقيقة
#        حتى ألغت المهلة الوظيفة — التشغيل 41825828025).
#      الصيغة `flutter test … -d chrome` تبني **تطبيق الويب الحقيقي** (فيمرّ على
#      مُسجِّل إضافات Flutter) وتشغّله في Chrome بلا chromedriver ولا سائق منفصل.
#   4. يفحص النتائج المُستلمة ويحكم: لم يبدأ التطبيق؟ لم تُسجَّل الاختبارات؟
#      نُفِّذت كلها؟ — هذا هو دليل التنفيذ الفعلي، لا سطر «All tests passed».
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

RESULTS_PORT=4445
RESULTS_FILE=/tmp/repos_results.txt
EXPECTED_TESTS=11
# مهلة قصوى للاختبار نفسه: إن عُلِّق، نفشل بسبب مفهوم بدل أن تُلغي المهلة
# الوظيفة كلها بلا تشخيص (كما حدث في التشغيل 41825828025).
TEST_TIMEOUT=900

# Flutter يحتاج مسار Chrome؛ عدّاءات GitHub تضعه في PATH عادةً.
if [ -z "${CHROME_EXECUTABLE:-}" ]; then
  for candidate in google-chrome google-chrome-stable chromium chromium-browser; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      export CHROME_EXECUTABLE="$(command -v "${candidate}")"
      break
    fi
  done
fi
echo "→ Chrome: ${CHROME_EXECUTABLE:-غير موجود}"
if [ -z "${CHROME_EXECUTABLE:-}" ]; then
  echo "::error::لا متصفح Chrome — لا يمكن تشغيل اختبار الويب."
  exit 1
fi

echo "→ تهيئة بيانات المحاكي وحساباته"
node tool/rules_tests/seed_integration.mjs

echo "→ تشغيل خادم نتائج الاختبارات على 127.0.0.1:${RESULTS_PORT}"
node tool/integration/results_server.mjs serve "${RESULTS_PORT}" "${RESULTS_FILE}" \
  >/tmp/results_server.log 2>&1 &
RESULTS_PID=$!
trap 'kill "${RESULTS_PID}" 2>/dev/null || true' EXIT
sleep 2
if ! kill -0 "${RESULTS_PID}" 2>/dev/null; then
  echo "::error::خادم النتائج لم يبدأ:"
  cat /tmp/results_server.log || true
  exit 1
fi

TEST_STATUS=0
echo "→ flutter test -d chrome (بناء ويب حقيقي + Chrome، مهلة ${TEST_TIMEOUT}s)"
timeout --signal=INT "${TEST_TIMEOUT}" \
  flutter test integration_test/p32_firestore_repositories_test.dart \
  -d chrome \
  --reporter expanded \
  || TEST_STATUS=$?

if [ "${TEST_STATUS}" -eq 124 ] || [ "${TEST_STATUS}" -eq 130 ]; then
  echo "::error::انتهت المهلة (${TEST_TIMEOUT}s) قبل إنهاء الاختبار — تعليق في بناء الويب أو تشغيله."
fi

# الفحص الحاسم: ما وصل من داخل التطبيق، لا ما طبعه المشغّل.
set +e
node tool/integration/results_server.mjs verify "${RESULTS_PORT}" "${RESULTS_FILE}" "${EXPECTED_TESTS}"
VERIFY_STATUS=$?
set -e

if [ "${TEST_STATUS}" -ne 0 ]; then
  echo "::error::flutter test خرج بالرمز ${TEST_STATUS}."
  exit "${TEST_STATUS}"
fi
if [ "${VERIFY_STATUS}" -ne 0 ]; then
  echo "::error::الاختبارات لم تُنفَّذ كلها داخل التطبيق (انظر رسائل الفحص أعلاه)."
  exit "${VERIFY_STATUS}"
fi

echo "✅ اختبار التكامل: تنفيذ Firestore الحقيقي (تصفّح/تعليم/عدّاد/علامات القراءة)."
