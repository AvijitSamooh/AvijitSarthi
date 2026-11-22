import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:avijit_sahyog/features/auth/data/auth_repository.dart';
import 'package:avijit_sahyog/features/auth/models/app_user.dart';
import 'package:avijit_sahyog/features/auth/providers/auth_providers.dart';

import 'package:avijit_sahyog/features/causes/models/cause.dart';
import 'package:avijit_sahyog/features/causes/providers/causes_providers.dart';
import 'package:avijit_sahyog/features/donations/presentation/donation_planner_page.dart';
import 'package:avijit_sahyog/l10n/app_localizations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('saves and restores a giving plan locally without starting a payment', (tester) async {
    Widget plannerApp({String? initialCauseId}) {
      return ProviderScope(
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
          home: DonationPlannerPage(initialCauseId: initialCauseId),
        ),
      );
    }

    await tester.pumpWidget(plannerApp(initialCauseId: 'jeev-daya'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('donation_plan_amount')), '5');
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('donation_plan_save')), 300);
    await tester.tap(find.byKey(const ValueKey('donation_plan_save')));
    await tester.pumpAndSettle();

    expect(find.text('Your giving plan is saved on this device.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('₹150.00'), -300);
    expect(find.text('₹150.00'), findsOneWidget);

    await tester.pumpWidget(plannerApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const ValueKey('donation_plan_active')), 300);
    expect(find.text('Plan active'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Plan created'), 300);
    expect(find.text('Plan created'), findsOneWidget);
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
