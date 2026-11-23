#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${GITHUB_WORKSPACE:-$(git rev-parse --show-toplevel)}"
cd "$REPO_ROOT/app/flutter"
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

cat > /tmp/firebase-e2e.json <<'JSON'
{
  "emulators": {
    "auth": { "host": "127.0.0.1", "port": 9099 },
    "firestore": { "host": "127.0.0.1", "port": 8080 },
    "ui": { "enabled": false }
  }
}
JSON

firebase_pid=""
backend_pid=""
cleanup() {
  adb logcat -d > artifacts/logcat.txt || true
  adb exec-out screencap -p > artifacts/final-screen.png || true
  if [ -n "$backend_pid" ]; then kill "$backend_pid" 2>/dev/null || true; fi
  if [ -n "$firebase_pid" ]; then kill "$firebase_pid" 2>/dev/null || true; fi
}
trap cleanup EXIT

export FIREBASE_PROJECT_ID="avijitsahyog-firebase"
export FIREBASE_CLIENT_EMAIL="e2e-admin@avijitsahyog-firebase.iam.gserviceaccount.com"
openssl genrsa -out /tmp/avijit-e2e-firebase-private-key.pem 2048 >/dev/null 2>&1
export FIREBASE_PRIVATE_KEY="$(cat /tmp/avijit-e2e-firebase-private-key.pem)"
export FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
export FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
export PORT="3000"
export NODE_ENV="test"

npx --yes firebase-tools@14 emulators:start \
  --only auth,firestore \
  --project "$FIREBASE_PROJECT_ID" \
  --config /tmp/firebase-e2e.json \
  > artifacts/firebase-emulators.log 2>&1 &
firebase_pid=$!

emulators_ready=false
for attempt in $(seq 1 120); do
  auth_ready=false
  firestore_ready=false
  if timeout 1s bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/9099' 2>/dev/null; then auth_ready=true; fi
  if timeout 1s bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/8080' 2>/dev/null; then firestore_ready=true; fi
  if [ "$auth_ready" = true ] && [ "$firestore_ready" = true ]; then
    emulators_ready=true
    break
  fi
  if ! kill -0 "$firebase_pid" 2>/dev/null; then
    cat artifacts/firebase-emulators.log
    exit 1
  fi
  sleep 2
done
if [ "$emulators_ready" != true ]; then
  cat artifacts/firebase-emulators.log
  echo "::error::Firebase Auth and Firestore emulators did not become ready."
  exit 1
fi

(
  cd "$REPO_ROOT/backend/nestjs"
  node test/seed-android-e2e-firestore.cjs
  exec node dist/main.js
) > artifacts/backend.log 2>&1 &
backend_pid=$!

backend_ready=false
for attempt in $(seq 1 60); do
  if curl --silent --fail http://127.0.0.1:3000/health/ready >/dev/null; then
    backend_ready=true
    break
  fi
  if ! kill -0 "$backend_pid" 2>/dev/null; then
    cat artifacts/backend.log
    exit 1
  fi
  sleep 2
done
if [ "$backend_ready" != true ]; then
  cat artifacts/backend.log
  echo "::error::NestJS E2E API did not become ready against the Firestore emulator."
  exit 1
fi

curl --silent --show-error --fail http://127.0.0.1:3000/activities > artifacts/public-activities.json
grep -Fq "E2E Pune published activity" artifacts/public-activities.json
grep -Fq "E2E Mumbai published activity" artifacts/public-activities.json
if grep -Fq "E2E Pune draft activity" artifacts/public-activities.json; then
  echo "::error::The public Activities API exposed a draft Firestore record."
  exit 1
fi
curl --silent --show-error --fail http://127.0.0.1:3000/accomplishments > artifacts/public-accomplishments.json
grep -Fq "E2E Pune published accomplishment" artifacts/public-accomplishments.json

adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell monkey -p com.avijitsamooh.avijitsahyog 1
sleep 8
adb exec-out screencap -p > artifacts/installed-app-launch.png
# The integration_test harness can use a different debug signature from the standalone smoke-test APK.
# Remove the smoke-test install before the harness installs its own APK to avoid an incompatible in-place update.
adb uninstall com.avijitsamooh.avijitsahyog

flutter test integration_test -d emulator-5554 --reporter expanded \
  --dart-define=E2E_TEST_MODE=true \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000 2>&1 | tee artifacts/integration-test.log
