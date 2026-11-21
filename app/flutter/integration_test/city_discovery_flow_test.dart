import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:avijit_sahyog/features/community/models/city.dart';
import 'package:avijit_sahyog/features/community/models/city_content.dart';
import 'package:avijit_sahyog/features/community/presentation/city_discovery_page.dart';
import 'package:avijit_sahyog/features/community/providers/city_providers.dart';
import 'package:avijit_sahyog/l10n/app_localizations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('public discovery flow filters city activities and switches to accomplishments', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityCatalogueProvider('en').overrideWith(
            (ref) async => const [City(id: 'pune', name: 'Pune')],
          ),
          cityContentProvider((kind: 'activities', cityId: null)).overrideWith(
            (ref) async => [
              CityContent(
                id: 'all-activity',
                cityId: 'pune',
                title: 'All-city activity',
                description: 'Visible before a city is selected.',
                startsAt: DateTime.utc(2026, 12, 1),
              ),
            ],
          ),
          cityContentProvider((kind: 'activities', cityId: 'pune')).overrideWith(
            (ref) async => [
              CityContent(
                id: 'pune-activity',
                cityId: 'pune',
                title: 'Pune community activity',
                description: 'Filtered by canonical city ID.',
                startsAt: DateTime.utc(2026, 12, 2),
              ),
            ],
          ),
          cityContentProvider((kind: 'accomplishments', cityId: 'pune')).overrideWith(
            (ref) async => [
              CityContent(
                id: 'pune-accomplishment',
                cityId: 'pune',
                title: 'Pune community accomplishment',
                description: 'A published achievement.',
                achievedAt: DateTime.utc(2026, 11, 15),
              ),
            ],
          ),
          cityContentProvider((kind: 'accomplishments', cityId: null)).overrideWith(
            (ref) async => const [],
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
    expect(find.text('All-city activity'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('city_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pune').last);
    await tester.pumpAndSettle();
    expect(find.text('Pune community activity'), findsOneWidget);

    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Pune community accomplishment'), findsOneWidget);
  });
}
