import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:avijit_sahyog/features/donations/data/donation_planner_repository.dart';
import 'package:avijit_sahyog/features/donations/models/donation_plan.dart';

void main() {
  late SharedPreferencesDonationPlannerRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = SharedPreferencesDonationPlannerRepository();
  });

  test('persists a plan, updates it, and records status history', () async {
    final created = await repository.savePlan(
      amountPaise: 500,
      frequency: DonationPlanFrequency.daily,
      customIntervalDays: 1,
      allocations: const [
        DonationPlanAllocation(causeId: 'jeev-daya', percentage: 100),
      ],
    );

    expect(created.plan?.monthlyEstimatePaise, 15000);
    expect(created.history.single.action, 'created');

    final updated = await repository.savePlan(
      amountPaise: 1000,
      frequency: DonationPlanFrequency.weekly,
      customIntervalDays: 7,
      allocations: const [
        DonationPlanAllocation(causeId: 'jeev-daya', percentage: 70),
        DonationPlanAllocation(causeId: 'education', percentage: 30),
      ],
    );
    expect(updated.history.map((entry) => entry.action), ['updated', 'created']);

    final paused = await repository.setActive(false);
    expect(paused.plan?.isActive, isFalse);
    expect(paused.history.first.action, 'paused');

    final reloaded = await repository.load();
    expect(reloaded.plan?.amountPaise, 1000);
    expect(reloaded.plan?.allocations.map((item) => item.percentage), [70, 30]);
    expect(reloaded.plan?.isActive, isFalse);
    expect(reloaded.history.length, 3);
  });

  test('calculates monthly estimates for each frequency using integer paise', () {
    expect(
      DonationPlan.estimateMonthlyPaise(
        amountPaise: 500,
        frequency: DonationPlanFrequency.daily,
        customIntervalDays: 1,
      ),
      15000,
    );
    expect(
      DonationPlan.estimateMonthlyPaise(
        amountPaise: 700,
        frequency: DonationPlanFrequency.weekly,
        customIntervalDays: 7,
      ),
      3000,
    );
    expect(
      DonationPlan.estimateMonthlyPaise(
        amountPaise: 2500,
        frequency: DonationPlanFrequency.monthly,
        customIntervalDays: 30,
      ),
      2500,
    );
    expect(
      DonationPlan.estimateMonthlyPaise(
        amountPaise: 1000,
        frequency: DonationPlanFrequency.custom,
        customIntervalDays: 10,
      ),
      3000,
    );
  });

  test('rejects invalid amount, custom interval, duplicate causes and non-100 allocations', () async {
    Future<void> save({
      int amount = 100,
      int days = 7,
      List<DonationPlanAllocation> allocations = const [
        DonationPlanAllocation(causeId: 'cause-1', percentage: 100),
      ],
      DonationPlanFrequency frequency = DonationPlanFrequency.daily,
    }) async {
      await repository.savePlan(
        amountPaise: amount,
        frequency: frequency,
        customIntervalDays: days,
        allocations: allocations,
      );
    }

    await expect(save(amount: 0), throwsArgumentError);
    await expect(save(frequency: DonationPlanFrequency.custom, days: 0), throwsArgumentError);
    await expect(
      save(allocations: const [
        DonationPlanAllocation(causeId: 'cause-1', percentage: 60),
        DonationPlanAllocation(causeId: 'cause-1', percentage: 40),
      ]),
      throwsArgumentError,
    );
    await expect(
      save(allocations: const [
        DonationPlanAllocation(causeId: 'cause-1', percentage: 90),
        DonationPlanAllocation(causeId: 'cause-2', percentage: 10),
      ]),
      returnsNormally,
    );
    await expect(
      save(allocations: const [
        DonationPlanAllocation(causeId: 'cause-1', percentage: 0),
        DonationPlanAllocation(causeId: 'cause-2', percentage: 100),
      ]),
      throwsArgumentError,
    );
  });

  test('parses decimal rupee amounts without floating-point rounding', () {
    expect(parseRupeesToPaise('5'), 500);
    expect(parseRupeesToPaise('12.5'), 1250);
    expect(parseRupeesToPaise('1,234.56'), 123456);
    expect(parseRupeesToPaise('0'), isNull);
    expect(parseRupeesToPaise('10.999'), isNull);
    expect(parseRupeesToPaise('-5'), isNull);
  });
}
