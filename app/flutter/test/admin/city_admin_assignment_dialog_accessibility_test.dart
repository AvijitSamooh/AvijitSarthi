import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avijit_sahyog/features/admin/presentation/city_admin_assignment_dialog.dart';
import 'package:avijit_sahyog/features/community/models/city.dart';
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

Widget _dialogLauncher() => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => const CityAdminAssignmentDialog(
                  userLabel: 'Nikita Manoriya',
                ),
              );
            },
            child: const Text('Open city assignment'),
          ),
        ),
      ),
    );

Widget _dialogApp() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: _dialogLauncher(),
    );

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open city assignment'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('announces city catalogue loading for Super Admin assignment', (tester) async {
    final cities = Completer<List<City>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityCatalogueProvider('en').overrideWith((ref) => cities.future),
        ],
        child: _dialogApp(),
      ),
    );
    await _openDialog(tester);
    await tester.pump();

    expectLiveRegion(tester, 'Loading cities for assignment.');
  });

  testWidgets('announces assignment catalogue errors and retry recovers', (tester) async {
    var shouldFail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityCatalogueProvider('en').overrideWith((ref) async {
            if (shouldFail) throw StateError('offline');
            return const [City(id: 'pune', name: 'Pune')];
          }),
        ],
        child: _dialogApp(),
      ),
    );
    await _openDialog(tester);
    await tester.pumpAndSettle();

    expect(find.text('Unable to load cities for assignment.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expectLiveRegion(tester, 'Unable to load cities for assignment.');

    shouldFail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Pune'), findsOneWidget);
  });

  testWidgets('announces when no cities are available for assignment', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityCatalogueProvider('en').overrideWith((ref) async => const <City>[]),
        ],
        child: _dialogApp(),
      ),
    );
    await _openDialog(tester);
    await tester.pumpAndSettle();

    expect(find.text('No cities are available for assignment.'), findsOneWidget);
    expectLiveRegion(tester, 'No cities are available for assignment.');
  });

  testWidgets('city choices expose their checked state to assistive technology', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityCatalogueProvider('en').overrideWith(
            (ref) async => const [City(id: 'pune', name: 'Pune')],
          ),
        ],
        child: _dialogApp(),
      ),
    );
    await _openDialog(tester);
    await tester.pumpAndSettle();

    final semantics = tester.ensureSemantics();
    try {
      var city = tester.getSemantics(find.bySemanticsLabel('Pune'));
      expect(city.getSemanticsData().hasFlag(SemanticsFlag.hasCheckedState), isTrue);
      expect(city.getSemanticsData().hasFlag(SemanticsFlag.isChecked), isFalse);

      await tester.tap(find.byKey(const ValueKey('city_assignment_pune')));
      await tester.pump();

      city = tester.getSemantics(find.bySemanticsLabel('Pune'));
      expect(city.getSemanticsData().hasFlag(SemanticsFlag.isChecked), isTrue);
    } finally {
      semantics.dispose();
    }
  });

  test('city assignment async-state messages are localized in all supported languages', () async {
    const expected = <String, Map<String, String>>{
      'en': {
        'loading': 'Loading cities for assignment.',
        'error': 'Unable to load cities for assignment.',
        'empty': 'No cities are available for assignment.',
      },
      'hi': {
        'loading': 'असाइनमेंट के लिए शहर लोड हो रहे हैं।',
        'error': 'असाइनमेंट के लिए शहर लोड नहीं हो सके।',
        'empty': 'असाइनमेंट के लिए कोई शहर उपलब्ध नहीं है।',
      },
      'mr': {
        'loading': 'नेमणुकीसाठी शहरे लोड होत आहेत.',
        'error': 'नेमणुकीसाठी शहरे लोड करता आली नाहीत.',
        'empty': 'नेमणुकीसाठी कोणतेही शहर उपलब्ध नाही.',
      },
      'gu': {
        'loading': 'ફાળવણી માટે શહેરો લોડ થઈ રહ્યા છે.',
        'error': 'ફાળવણી માટે શહેરો લોડ થઈ શક્યા નથી.',
        'empty': 'ફાળવણી માટે કોઈ શહેર ઉપલબ્ધ નથી.',
      },
    };

    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      final values = expected[locale.languageCode]!;
      expect(l10n.adminCityAssignmentLoadingCities, values['loading']);
      expect(l10n.adminCityAssignmentLoadError, values['error']);
      expect(l10n.adminCityAssignmentNoCities, values['empty']);
    }
  });

  testWidgets('keeps city assignment usable on a compact screen at 200% text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityCatalogueProvider('en').overrideWith(
            (ref) async => const [City(id: 'pune', name: 'Pune')],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: _dialogLauncher(),
        ),
      ),
    );
    await _openDialog(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Pune'), findsOneWidget);
    final saveAction = find.text('Save assignments');
    expect(saveAction, findsOneWidget);
    expect(
      tester.getRect(saveAction).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
      reason: 'The save action should remain inside the compact viewport.',
    );
  });

}
