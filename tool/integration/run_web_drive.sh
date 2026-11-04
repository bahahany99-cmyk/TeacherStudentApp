#!/usr/bin/env bash
# تشغيل اختبار التكامل الحقيقي لتنفيذ Firestore (P32 — محاولة أخيرة).
#
# **يُشغَّل داخل `firebase emulators:exec`** لأن المحاكيين يجب أن يكونا جاهزين:
#   firebase emulators:exec --only firestore,auth --project demo-darsly \
#     --config firebase.json "tool/integration/run_web_drive.sh"
#
# ما يفعله:
#   1. يهيّئ البيانات + حسابات المحاكي بسكربت Node (متجاوزًا القواعد للتهيئة).
#   2. يشغّل خادم نتائج محليًا (4445): كل اختبار يُرسل نتيجته من **داخل التطبيق**
#      (`results_server.mjs` + `integration_test/result_reporter_web.dart`)، لأن
#      `flutter drive` على الويب قد يطبع «All tests passed.» بعدد صفر اختبارات
#      (flutter#94434، #150358، #151480).
#   3. يشغّل `flutter drive -d chrome`: بناء ويب **حقيقي** يمرّ على مُسجِّل
#      إضافات Flutter، فتعمل Firebase كما في التطبيق — خلافًا لـ`flutter test
#      --platform chrome` الذي لا يسجّل الإضافات فيه.
#      **تغيير مقصود:** كان التشغيل السابق `-d web-server --browser-name=chrome`
#      مع chromedriver منفصل، وخرج بـ«All tests passed» بلا تنفيذ أي اختبار.
#      الصيغة الموثّقة لاختبار التكامل على الويب هي `-d chrome` (Flutter يطلق
#      المتصفح ويتصل به بنفسه، بلا chromedriver ولا وسيط).
#   4. يفحص النتائج المُستلمة ويحكم: لم يبدأ التطبيق؟ لم تُسجَّل الاختبارات؟
#      نُفِّذت كلها؟ — هذا هو دليل التنفيذ الفعلي، لا سطر «All tests passed».
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

RESULTS_PORT=4445
RESULTS_FILE=/tmp/repos_results.txt
EXPECTED_TESTS=11

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

DRIVE_STATUS=0
echo "→ flutter drive -d chrome (بناء ويب حقيقي + Chrome)"
# أقل خيارات ممكنة: أي خيار غير مدعوم في إصدار Flutter الحالي يُفشل الأمر كله.
flutter drive --verbose \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/p32_firestore_repositories_test.dart \
  -d chrome \
  || DRIVE_STATUS=$?

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
