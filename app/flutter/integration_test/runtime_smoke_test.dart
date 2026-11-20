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
      SharedPreferences.setMockInitialValues({});

      // Exercise the same startup path as the installed Android application.
      // E2E_TEST_MODE disables production analytics/health telemetry and
      // routes Auth to the Firebase Auth Emulator.
      await app.main();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );

      expect(find.text('Avijit Sarthi'), findsWidgets);
      expect(find.text('Our Purpose'), findsOneWidget);
      expect(find.text('Education'), findsOneWidget);
      expect(find.text('Cooperation'), findsOneWidget);
      expect(find.text('Recognition'), findsOneWidget);
    },
    skip: !Platform.isAndroid,
  );
}
