import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../causes/providers/causes_providers.dart';
import '../data/donation_history_repository.dart';
import '../models/donation_history.dart';

final donationHistoryRepositoryProvider = Provider<DonationHistoryRepository>(
  (ref) => DonationHistoryRepository(ref.watch(apiClientProvider)),
);

final myDonationsProvider = FutureProvider.autoDispose<List<DonationRecord>>(
  (ref) => ref.watch(donationHistoryRepositoryProvider).mine(),
);

final myDonationProvider = FutureProvider.autoDispose.family<DonationRecord, String>(
  (ref, id) => ref.watch(donationHistoryRepositoryProvider).findMine(id),
);
