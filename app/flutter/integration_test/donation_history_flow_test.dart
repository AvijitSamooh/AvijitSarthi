import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:avijit_sahyog/core/network/api_client.dart';
import 'package:avijit_sahyog/features/auth/data/auth_repository.dart';
import 'package:avijit_sahyog/features/auth/models/app_user.dart';
import 'package:avijit_sahyog/features/auth/providers/auth_providers.dart';
import 'package:avijit_sahyog/features/causes/models/cause.dart';
import 'package:avijit_sahyog/features/causes/providers/causes_providers.dart';
import 'package:avijit_sahyog/features/donations/data/donation_history_repository.dart';
import 'package:avijit_sahyog/features/donations/models/donation_history.dart';
import 'package:avijit_sahyog/features/donations/presentation/donation_history_page.dart';
import 'package:avijit_sahyog/features/donations/providers/donation_history_providers.dart';
import 'package:avijit_sahyog/l10n/app_localizations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('donor can view a verified donation and create its receipt record', (tester) async {
    final donation = DonationRecord(
      id: 'donation-1',
      amount: '125.50',
      currency: 'INR',
      status: 'SUCCESS',
      createdAt: DateTime.utc(2026, 3, 4),
      updatedAt: DateTime.utc(2026, 3, 4),
      allocations: const [
        DonationAllocationRecord(causeId: 'jeev-daya', amount: '100.00'),
        DonationAllocationRecord(causeId: 'education', amount: '25.50'),
      ],
    );
    final repository = _FakeDonationHistoryRepository(donation);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => AuthController(_SignedInAuthRepository())),
        donationHistoryRepositoryProvider.overrideWithValue(repository),
        myDonationsProvider.overrideWith((ref) async => [donation]),
        myDonationProvider('donation-1').overrideWith((ref) async => donation),
        causesProvider('en').overrideWith((ref) async => const [
          Cause(id: 'jeev-daya', slug: 'jeev-daya', name: 'Jeev Daya'),
          Cause(id: 'education', slug: 'education', name: 'Education'),
        ]),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const DonationHistoryPage(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('donation_history_donation-1')));
    await tester.pumpAndSettle();
    expect(find.text('₹125.50'), findsOneWidget);
    expect(find.text('Jeev Daya'), findsOneWidget);

    await tester.tap(find.text('Create / view receipt'));
    await tester.pumpAndSettle();
    expect(find.text('AS-2026-ABCDEF1234'), findsOneWidget);
    expect(repository.issuedLanguage, 'en');
  });
}

class _SignedInAuthRepository implements AuthRepository {
  @override
  Future<AppUser?> restoreSession() async => const AppUser(
        id: 'user-1', email: 'donor@example.com', displayName: 'Donor', role: UserRole.user,
      );
  @override
  Future<AppUser> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
}

class _FakeDonationHistoryRepository extends DonationHistoryRepository {
  _FakeDonationHistoryRepository(this.donation) : super(ApiClient());

  final DonationRecord donation;
  String? issuedLanguage;

  @override
  Future<List<DonationRecord>> mine() async => [donation];
  @override
  Future<DonationRecord> findMine(String id) async => donation;
  @override
  Future<DonationReceipt> issueReceipt(String id, String languageCode) async {
    issuedLanguage = languageCode;
    return DonationReceipt(
      id: id,
      donationId: id,
      receiptNumber: 'AS-2026-ABCDEF1234',
      amount: donation.amount,
      currency: donation.currency,
      language: languageCode,
      allocations: donation.allocations,
      donationCreatedAt: donation.createdAt,
      issuedAt: DateTime.utc(2026, 3, 5),
    );
  }
}
