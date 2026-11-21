import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:avijit_sahyog/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real app starts and renders the home experience',
    (tester) async {
      // Keep this smoke test independent of the locale selected by earlier
      // integration tests or the hosted emulator's system language.
      SharedPreferences.setMockInitialValues({'selected_locale': 'en'});

      // Exercise the same startup path as the installed Android application.
      // E2E_TEST_MODE disables production analytics/health telemetry and
      // routes Auth to the Firebase Auth Emulator.
      await app.main();
      // The splash screen and home shell can keep frame callbacks active.
      // Advance the splash timer explicitly instead of waiting for global
      // pumpAndSettle, which can stall on app-owned animations.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Avijit Sarthi'), findsWidgets);
      expect(find.text('Our Purpose'), findsOneWidget);
      expect(find.text('Education'), findsOneWidget);
      expect(find.text('Cooperation'), findsOneWidget);
      expect(find.text('Recognition'), findsOneWidget);
    },
    skip: !Platform.isAndroid,
  );
}
