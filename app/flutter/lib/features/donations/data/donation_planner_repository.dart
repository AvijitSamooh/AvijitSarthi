import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/donation_plan.dart';

abstract class DonationPlannerRepository {
  Future<DonationPlannerState> load();

  Future<DonationPlannerState> savePlan({
    required int amountPaise,
    required DonationPlanFrequency frequency,
    required int customIntervalDays,
    required List<DonationPlanAllocation> allocations,
  });

  Future<DonationPlannerState> setActive(bool isActive);
}

class SharedPreferencesDonationPlannerRepository implements DonationPlannerRepository {
  static const storageKey = 'avijit_sarthi.donation_planner.v1';
  static const historyLimit = 20;

  @override
  Future<DonationPlannerState> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return const DonationPlannerState();
    try {
      return DonationPlannerState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      throw StateError('Saved giving plan data is invalid.');
    } on TypeError {
      throw StateError('Saved giving plan data is invalid.');
    }
  }

  @override
  Future<DonationPlannerState> savePlan({
    required int amountPaise,
    required DonationPlanFrequency frequency,
    required int customIntervalDays,
    required List<DonationPlanAllocation> allocations,
  }) async {
    _validate(amountPaise, frequency, customIntervalDays, allocations);
    final current = await load();
    final now = DateTime.now().toUtc();
    final plan = DonationPlan(
      amountPaise: amountPaise,
      frequency: frequency,
      customIntervalDays: customIntervalDays,
      allocations: List.unmodifiable(allocations),
      isActive: current.plan?.isActive ?? true,
      createdAt: current.plan?.createdAt ?? now,
      updatedAt: now,
    );
    final history = [
      DonationPlanHistoryEntry(
        action: current.plan == null ? 'created' : 'updated',
        amountPaise: plan.amountPaise,
        frequency: plan.frequency,
        isActive: plan.isActive,
        changedAt: now,
      ),
      ...current.history,
    ].take(historyLimit).toList(growable: false);
    final next = DonationPlannerState(plan: plan, history: history);
    await _persist(next);
    return next;
  }

  @override
  Future<DonationPlannerState> setActive(bool isActive) async {
    final current = await load();
    final existing = current.plan;
    if (existing == null) throw StateError('Create a giving plan before changing its status.');
    if (existing.isActive == isActive) return current;

    final now = DateTime.now().toUtc();
    final plan = existing.copyWith(isActive: isActive, updatedAt: now);
    final history = [
      DonationPlanHistoryEntry(
        action: isActive ? 'activated' : 'paused',
        amountPaise: plan.amountPaise,
        frequency: plan.frequency,
        isActive: isActive,
        changedAt: now,
      ),
      ...current.history,
    ].take(historyLimit).toList(growable: false);
    final next = DonationPlannerState(plan: plan, history: history);
    await _persist(next);
    return next;
  }

  Future<void> _persist(DonationPlannerState state) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(storageKey, jsonEncode(state.toJson()));
    if (!saved) throw StateError('Giving plan could not be saved on this device.');
  }

  void _validate(
    int amountPaise,
    DonationPlanFrequency frequency,
    int customIntervalDays,
    List<DonationPlanAllocation> allocations,
  ) {
    if (amountPaise <= 0) throw ArgumentError.value(amountPaise, 'amountPaise');
    if (frequency == DonationPlanFrequency.custom &&
        (customIntervalDays < 1 || customIntervalDays > 365)) {
      throw ArgumentError.value(customIntervalDays, 'customIntervalDays');
    }
    if (allocations.isEmpty ||
        allocations.any((item) => item.causeId.trim().isEmpty || item.percentage <= 0 || item.percentage > 100) ||
        allocations.fold<int>(0, (sum, item) => sum + item.percentage) != 100 ||
        allocations.map((item) => item.causeId).toSet().length != allocations.length) {
      throw ArgumentError.value(allocations, 'allocations', 'Cause allocations must be unique and total 100%.');
    }
  }
}
