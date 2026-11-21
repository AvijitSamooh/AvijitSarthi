#!/usr/bin/env bash
set -euo pipefail
cd app/flutter
mkdir -p artifacts
adb wait-for-device

system_services_ready=false
ready_streak=0
for attempt in $(seq 1 45); do
  if timeout 5s adb shell cmd package list packages >/dev/null 2>&1 \
    && timeout 5s adb shell cmd activity get-config >/dev/null 2>&1; then
    ready_streak=$((ready_streak + 1))
    if [ "$ready_streak" -ge 3 ]; then
      system_services_ready=true
      break
    fi
  else
    ready_streak=0
  fi
  sleep 2
done
if [ "$system_services_ready" != true ]; then
  adb logcat -d > artifacts/logcat-preflight.txt || true
  echo "::error::Android emulator booted but Package Manager and Activity Manager did not become responsive."
  exit 1
fi

echo eyJlbXVsYXRvcnMiOnsiYXV0aCI6eyJwb3J0Ijo5MDk5fSwidWkiOnsiZW5hYmxlZCI6ZmFsc2V9fX0= | base64 -d > /tmp/firebase-e2e.json
npx --yes firebase-tools@14 emulators:start --only auth --project avijitsahyog-firebase --config /tmp/firebase-e2e.json > artifacts/firebase-auth-emulator.log 2>&1 &
firebase_pid=$!
cleanup() {
  adb logcat -d > artifacts/logcat.txt || true
  adb exec-out screencap -p > artifacts/final-screen.png || true
  kill "$firebase_pid" 2>/dev/null || true
}
trap cleanup EXIT

firebase_ready=false
for attempt in $(seq 1 60); do
  if curl --silent --output /dev/null http://127.0.0.1:9099/; then
    firebase_ready=true
    break
  fi
  if ! kill -0 "$firebase_pid" 2>/dev/null; then
    cat artifacts/firebase-auth-emulator.log
    exit 1
  fi
  sleep 2
done
if [ "$firebase_ready" != true ]; then
  cat artifacts/firebase-auth-emulator.log
  echo "::error::Firebase Auth Emulator did not become ready."
  exit 1
fi

adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell monkey -p com.avijitsamooh.avijitsahyog 1
sleep 8
adb exec-out screencap -p > artifacts/installed-app-launch.png
flutter test integration_test -d emulator-5554 --reporter expanded \
  --dart-define=E2E_TEST_MODE=true \
  --dart-define=API_BASE_URL=http://10.0.2.2:9 2>&1 | tee artifacts/integration-test.log
