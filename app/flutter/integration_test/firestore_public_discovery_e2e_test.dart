import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:avijit_sahyog/features/community/presentation/city_discovery_page.dart';
import 'package:avijit_sahyog/l10n/app_localizations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'guest discovers published Activities and Accomplishments from Firestore through the API',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const CityDiscoveryPage(),
          ),
        ),
      );

      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
      );

      // These records are seeded into the local Firestore emulator. The app
      // reaches them through the real NestJS public API without signing in.
      expect(find.text('E2E Pune published activity'), findsOneWidget);
      expect(find.text('E2E Mumbai published activity'), findsOneWidget);

      // The API must not expose a draft through its guest/public endpoint.
      expect(find.text('E2E Pune draft activity'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('city_filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pune').last);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
      );

      expect(find.text('E2E Pune published activity'), findsOneWidget);
      expect(find.text('E2E Mumbai published activity'), findsNothing);

      await tester.tap(find.byType(Tab).at(1));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
      );

      expect(find.text('E2E Pune published accomplishment'), findsOneWidget);
      expect(find.text('E2E Mumbai published accomplishment'), findsNothing);
    },
    skip: !Platform.isAndroid,
  );
}
