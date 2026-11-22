import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:avijit_sahyog/features/auth/data/auth_repository.dart';
import 'package:avijit_sahyog/features/auth/models/app_user.dart';
import 'package:avijit_sahyog/features/auth/providers/auth_providers.dart';

import 'package:avijit_sahyog/features/causes/models/cause.dart';
import 'package:avijit_sahyog/features/causes/providers/causes_providers.dart';
import 'package:avijit_sahyog/features/donations/presentation/donation_planner_page.dart';
import 'package:avijit_sahyog/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('creates a local giving plan and shows its monthly estimate and history', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => AuthController(_GuestAuthRepository())),
          causesProvider('en').overrideWith(
            (ref) async => const [
              Cause(id: 'jeev-daya', slug: 'jeev-daya', name: 'Jeev Daya'),
              Cause(id: 'education', slug: 'education', name: 'Education'),
            ],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const DonationPlannerPage(initialCauseId: 'jeev-daya'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Plan your giving'), findsOneWidget);
    expect(find.text('Jeev Daya'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('donation_plan_amount')), '5');
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('donation_plan_save')), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('donation_plan_save')));
    await tester.pumpAndSettle();

    expect(find.text('Your giving plan is saved on this device.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Estimated monthly giving'), -300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Estimated monthly giving'), findsOneWidget);
    expect(find.text('₹150.00'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Plan created'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Plan created'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('donation_plan_active')), -300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('donation_plan_active')), findsOneWidget);
  });

  testWidgets('supports a custom interval and pauses a saved plan', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => AuthController(_GuestAuthRepository())),
          causesProvider('en').overrideWith(
            (ref) async => const [
              Cause(id: 'jeev-daya', slug: 'jeev-daya', name: 'Jeev Daya'),
            ],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const DonationPlannerPage(initialCauseId: 'jeev-daya'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('donation_plan_amount')), '10');
    await tester.tap(find.byKey(const ValueKey('donation_plan_frequency')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('donation_plan_custom_days')), '10');
    await tester.pump();
    expect(find.text('₹30.00'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('donation_plan_save')), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('donation_plan_save')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const ValueKey('donation_plan_active')), -300, scrollable: find.byType(Scrollable).first);
    final activeSwitch = find.descendant(
      of: find.byKey(const ValueKey('donation_plan_active')),
      matching: find.byType(Switch),
    );
    expect(activeSwitch, findsOneWidget);
    await tester.ensureVisible(activeSwitch);
    await tester.pumpAndSettle();
    await tester.tap(activeSwitch);
    await tester.pumpAndSettle();
    expect(find.text('Plan paused'), findsWidgets);
  });
}

class _GuestAuthRepository implements AuthRepository {
  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  Future<AppUser> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}
