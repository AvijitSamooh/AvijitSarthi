import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avijit_sahyog/features/community/models/city.dart';
import 'package:avijit_sahyog/features/community/models/city_content.dart';
import 'package:avijit_sahyog/features/community/presentation/city_discovery_page.dart';
import 'package:avijit_sahyog/features/community/providers/city_providers.dart';
import 'package:avijit_sahyog/l10n/app_localizations.dart';

void main() {
  testWidgets('discovers published activities and accomplishments with localized city names', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityCatalogueProvider('en').overrideWith(
            (ref) async => const [City(id: 'pune', name: 'Pune')],
          ),
          cityContentProvider((kind: 'activities', cityId: null)).overrideWith(
            (ref) async => [
              CityContent(
                id: 'activity-1',
                cityId: 'pune',
                title: 'Community health camp',
                description: 'A local service initiative.',
                startsAt: DateTime.utc(2026, 12, 1),
              ),
            ],
          ),
          cityContentProvider((kind: 'accomplishments', cityId: null)).overrideWith(
            (ref) async => [
              CityContent(
                id: 'award-1',
                cityId: 'pune',
                title: 'Scholarship achievement',
                description: 'Students completed the programme.',
                achievedAt: DateTime.utc(2026, 11, 15),
              ),
            ],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const CityDiscoveryPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Community health camp'), findsOneWidget);
    expect(find.text('Pune'), findsOneWidget);
    expect(find.text('Accomplishments'), findsOneWidget);

    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Scholarship achievement'), findsOneWidget);
    expect(find.text('Students completed the programme.'), findsOneWidget);
  });

  testWidgets('shows an empty state when a city has no published activities', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityCatalogueProvider('en').overrideWith(
            (ref) async => const [City(id: 'mumbai', name: 'Mumbai')],
          ),
          cityContentProvider((kind: 'activities', cityId: null)).overrideWith((ref) async => const []),
          cityContentProvider((kind: 'accomplishments', cityId: null)).overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const CityDiscoveryPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('No published activities for this city yet.'), findsOneWidget);
  });
}
