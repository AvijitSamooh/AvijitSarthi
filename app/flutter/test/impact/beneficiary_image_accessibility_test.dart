import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avijit_sahyog/core/navigation/app_shell_scope.dart';
import 'package:avijit_sahyog/features/impact/models/beneficiary.dart';
import 'package:avijit_sahyog/features/impact/presentation/beneficiary_detail_page.dart';
import 'package:avijit_sahyog/features/impact/presentation/impact_page.dart';
import 'package:avijit_sahyog/l10n/app_localizations.dart';

void main() {
  testWidgets('announces a beneficiary placeholder as a named image', (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: beneficiaryImage(
            null,
            height: 120,
            borderRadius: BorderRadius.zero,
            semanticLabel: 'Photo of Alice',
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Photo of Alice'), findsOneWidget);
  });

  testWidgets('labels the beneficiary profile and story gallery images', (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    const beneficiary = Beneficiary(
      id: 'beneficiary-1',
      name: 'Alice',
      cause: 'Education',
      supportedYear: 2026,
      contributionAmount: 0,
      gallery: ['https://images.example.com/story-1.webp'],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: AppShellScope(
          onLocaleChanged: (_) {},
          navigation: AppNavigationController(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: BeneficiaryDetailPage(beneficiary: beneficiary),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Photo of Alice'), findsOneWidget);
    expect(find.bySemanticsLabel("Photo 1 in Alice's story"), findsOneWidget);
  });
}
