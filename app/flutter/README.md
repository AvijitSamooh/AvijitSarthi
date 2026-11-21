# Avijit Sahyog Flutter App

Flutter client for the Avijit Sahyog donation platform.

## Current features

- Multilingual application shell
- Home experience with Maharaj Ji hero image
- Cause discovery
- Cause-centric donation entry flow
- Affiliated organisation transparency
- Impact Explorer with beneficiary cards
- Beneficiary impact story detail
- Search and sorting for beneficiary discovery
- Backend-driven API configuration using `API_BASE_URL`
- Firebase Authentication with Google Sign-In and backend identity resolution

## Run locally

```bash
flutter pub get
flutter gen-l10n
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

## Test and quality

```bash
flutter analyze
flutter test
flutter test integration_test
flutter test --coverage
```

UI tests should cover primary journeys plus important loading, empty and error states.

- Dynamically managed organisation logos and beneficiary profile/gallery images delivered from the public API

## Firebase authentication

Firebase must be configured before running the authentication flow:

1. Register the target Android/Web applications in the Firebase project.
2. Run `flutterfire configure` from `app/flutter`.
3. Enable the Google provider in Firebase Authentication.
4. Configure the backend with Firebase Admin credentials so `/auth/me` can verify ID tokens.

The Flutter app initializes Firebase at startup, restores an existing Firebase session, exchanges the Firebase ID token with the backend through `GET /auth/me`, and uses the resolved backend role to unlock protected admin operations.

## Android emulator E2E

The dedicated **Android Emulator E2E - Avijit Sarthi** workflow builds and installs a debug APK on an Android emulator, launches the installed application, and runs the Flutter integration test against the real application startup path.

Run it manually from GitHub Actions with **workflow_dispatch**, or let it run for pull requests targeting `master`, pushes to `master`, and the nightly schedule.

The workflow uses:

- A debug-only `E2E_TEST_MODE=true` define. Release builds cannot activate this mode.
- Isolated Firebase Auth and Firestore emulators with a disposable project identity and ephemeral Admin SDK key.
- A locally built NestJS API connected only to the Firestore emulator.
- Deterministic published Pune/Mumbai Activities and Accomplishments plus a draft Activity. The seed script refuses to run unless the local Firestore emulator and the Avijit E2E project ID are selected.
- A real Android guest-discovery journey that loads content through the API, verifies drafts are hidden, filters by city, and switches between Activities and Accomplishments.
- The Android emulator host bridge to reach the local API; cleartext HTTP is enabled only in the debug manifest.
- Disabled Firebase Analytics collection and suppressed client-health telemetry in E2E mode.
- No production API, Firestore, customer records, sign-in account, donation, payment or real payment rail writes.
- Uploaded emulator screenshots, logcat, Firebase emulator/API logs and integration-test output for triage.

The Android suite includes the installed-app startup smoke test, UI-level city/admin flows, and a real guest read journey against isolated Firestore-backed API fixtures. The cross-repository issue also covers JCP and FnOPlayer; this workflow validates only Avijit Sarthi and does not claim those other repositories are covered.

## UX and integration coverage

Detailed application journeys are covered by the unit/widget suites. The `integration_test/` suite exercises the Android runtime and native plugin boundary.

See ../../docs/user-experience.md and ../../docs/test-and-ux-matrix.md for journey specifications and traceability.
