import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avijit_sahyog/features/causes/models/organisation.dart';
import 'package:avijit_sahyog/features/causes/presentation/organisation_detail_page.dart';
import 'package:avijit_sahyog/features/community/models/city.dart';
import 'package:avijit_sahyog/features/community/models/city_content.dart';
import 'package:avijit_sahyog/features/community/presentation/city_discovery_page.dart';
import 'package:avijit_sahyog/features/community/presentation/city_content_detail_page.dart';
import 'package:avijit_sahyog/features/community/providers/city_providers.dart';
import 'package:avijit_sahyog/l10n/app_localizations.dart';

void expectLiveRegion(WidgetTester tester, String label) {
  final semantics = tester.ensureSemantics();
  try {
    final node = tester.getSemantics(find.bySemanticsLabel(label));
    expect(
      node.getSemanticsData().hasFlag(SemanticsFlag.isLiveRegion),
      isTrue,
      reason: '"$label" should be announced as a live region.',
    );
  } finally {
    semantics.dispose();
  }
}

void main() {
  testWidgets('announces city catalogue loading while the city list is pending', (tester) async {
    final cities = Completer<List<City>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityCatalogueProvider('en').overrideWith((ref) => cities.future),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const CityDiscoveryPage(),
        ),
      ),
    );
    await tester.pump();

    expectLiveRegion(tester, 'Loading cities.');
  });

  testWidgets('announces activity loading while the public feed is pending', (tester) async {
    final activities = Completer<List<CityContent>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityCatalogueProvider('en').overrideWith(
            (ref) async => const [City(id: 'pune', name: 'Pune')],
          ),
          cityContentProvider((kind: 'activities', cityId: null)).overrideWith(
            (ref) => activities.future,
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expectLiveRegion(tester, 'Loading activities.');
  });

  test('city discovery loading announcements are localized in all supported languages', () async {
    const expected = <String, Map<String, String>>{
      'en': {
        'cities': 'Loading cities.',
        'activities': 'Loading activities.',
        'accomplishments': 'Loading accomplishments.',
      },
      'hi': {
        'cities': 'शहरों की सूची लोड हो रही है।',
        'activities': 'गतिविधियाँ लोड हो रही हैं।',
        'accomplishments': 'उपलब्धियाँ लोड हो रही हैं।',
      },
      'mr': {
        'cities': 'शहरांची यादी लोड होत आहे.',
        'activities': 'उपक्रम लोड होत आहेत.',
        'accomplishments': 'यशोगाथा लोड होत आहेत.',
      },
      'gu': {
        'cities': 'શહેરોની યાદી લોડ થઈ રહી છે.',
        'activities': 'પ્રવૃત્તિઓ લોડ થઈ રહી છે.',
        'accomplishments': 'સિદ્ધિઓ લોડ થઈ રહી છે.',
      },
    };

    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      final values = expected[locale.languageCode]!;
      expect(l10n.communityLoadingCities, values['cities']);
      expect(l10n.communityLoadingActivities, values['activities']);
      expect(l10n.communityLoadingAccomplishments, values['accomplishments']);
    }
  });

  testWidgets('announces a city catalogue error and keeps retry available', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityCatalogueProvider('en').overrideWith((ref) async {
            throw StateError('offline');
          }),
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

    expect(find.text('Unable to load the city list.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expectLiveRegion(tester, 'Unable to load the city list.');
  });

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
    expectLiveRegion(tester, 'No published activities for this city yet.');

  });

  testWidgets('opens a public detail view and safely renders existing organisation affiliates', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityContentDetailProvider((kind: 'activities', id: 'activity-1')).overrideWith(
            (ref) async => CityContent(
              id: 'activity-1',
              cityId: 'pune',
              title: 'Seva camp',
              description: 'Community service',
              startsAt: DateTime.utc(2026, 12, 1),
              organisationIds: const ['org-1'],
            ),
          ),
          cityOrganisationsProvider('en').overrideWith(
            (ref) async => const [
              Organisation(id: 'org-1', slug: 'seva-trust', name: 'Seva Trust'),
            ],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const CityContentDetailPage(
            kind: 'activities',
            contentId: 'activity-1',
            cityName: 'Pune',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Seva camp'), findsOneWidget);
    expect(find.text('Seva Trust'), findsOneWidget);
    await tester.tap(find.text('Seva Trust'));
    await tester.pumpAndSettle();
    expect(find.byType(OrganisationDetailPage), findsOneWidget);
  });

  testWidgets('shows a safe fallback when an affiliate reference is unavailable', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityContentDetailProvider((kind: 'accomplishments', id: 'award-1')).overrideWith(
            (ref) async => CityContent(
              id: 'award-1',
              cityId: 'pune',
              title: 'Award',
              description: 'Achievement',
              achievedAt: DateTime.utc(2026, 11, 15),
              organisationIds: const ['deleted-org'],
            ),
          ),
          cityOrganisationsProvider('en').overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const CityContentDetailPage(
            kind: 'accomplishments',
            contentId: 'award-1',
            cityName: 'Pune',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('No organisation details are available for this item.'), findsOneWidget);
  });

  testWidgets('shows localized content error and retries the public feed', (tester) async {
    var shouldFail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityCatalogueProvider('en').overrideWith((ref) async => const [City(id: 'pune', name: 'Pune')]),
          cityContentProvider((kind: 'activities', cityId: null)).overrideWith((ref) async {
            if (shouldFail) throw StateError('offline');
            return [
              CityContent(
                id: 'activity-1',
                cityId: 'pune',
                title: 'Recovered activity',
                description: 'Loaded after retry',
                startsAt: DateTime.utc(2026, 12, 1),
              ),
            ];
          }),
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
    expect(find.text('Unable to load community updates.'), findsOneWidget);
    expectLiveRegion(tester, 'Unable to load community updates.');
    shouldFail = false;
    await tester.tap(find.text('Retry').first);
    await tester.pumpAndSettle();
    expect(find.text('Recovered activity'), findsOneWidget);
  });

  testWidgets('shows a retryable fallback when organisation references cannot be loaded', (tester) async {
    var shouldFail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityContentDetailProvider((kind: 'activities', id: 'activity-2')).overrideWith(
            (ref) async => CityContent(
              id: 'activity-2',
              cityId: 'pune',
              title: 'Community meal',
              description: 'Shared meal for families',
              startsAt: DateTime.utc(2026, 12, 3),
              organisationIds: const ['org-1'],
            ),
          ),
          cityOrganisationsProvider('en').overrideWith((ref) async {
            if (shouldFail) throw StateError('offline');
            return const [
              Organisation(id: 'org-1', slug: 'seva-trust', name: 'Seva Trust'),
            ];
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const CityContentDetailPage(
            kind: 'activities',
            contentId: 'activity-2',
            cityName: 'Pune',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Organisation details could not be loaded.'), findsOneWidget);
    shouldFail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Seva Trust'), findsOneWidget);
  });


}
