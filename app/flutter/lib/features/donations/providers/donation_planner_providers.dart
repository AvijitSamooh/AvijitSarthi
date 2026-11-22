import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/donation_planner_repository.dart';

final donationPlannerRepositoryProvider = Provider<DonationPlannerRepository>(
  (ref) => SharedPreferencesDonationPlannerRepository(),
);
