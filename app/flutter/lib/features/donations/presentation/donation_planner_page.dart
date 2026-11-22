import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_settings_menu.dart';
import '../../causes/models/cause.dart';
import '../../causes/providers/causes_providers.dart';
import '../models/donation_plan.dart';
import '../providers/donation_planner_providers.dart';

class DonationPlannerPage extends ConsumerStatefulWidget {
  const DonationPlannerPage({super.key, this.initialCauseId});

  final String? initialCauseId;

  @override
  ConsumerState<DonationPlannerPage> createState() => _DonationPlannerPageState();
}

class _DonationPlannerPageState extends ConsumerState<DonationPlannerPage> {
  final _amountController = TextEditingController();
  final _customDaysController = TextEditingController(text: '7');
  final Set<String> _selectedCauseIds = {};
  final Map<String, int> _allocationPercentages = {};
  final Map<String, TextEditingController> _percentageControllers = {};

  DonationPlannerState _savedState = const DonationPlannerState();
  DonationPlanFrequency _frequency = DonationPlanFrequency.daily;
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCauseId != null && widget.initialCauseId!.trim().isNotEmpty) {
      _selectedCauseIds.add(widget.initialCauseId!);
      _allocationPercentages[widget.initialCauseId!] = 100;
    }
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _customDaysController.dispose();
    for (final controller in _percentageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final loaded = await ref.read(donationPlannerRepositoryProvider).load();
      if (!mounted) return;
      _restorePlan(loaded.plan);
      setState(() {
        _savedState = loaded;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _restorePlan(DonationPlan? plan) {
    if (plan == null) return;
    _amountController.text = (plan.amountPaise / 100).toStringAsFixed(2);
    _frequency = plan.frequency;
    _customDaysController.text = plan.customIntervalDays.toString();
    _selectedCauseIds
      ..clear()
      ..addAll(plan.allocations.map((item) => item.causeId));
    _allocationPercentages
      ..clear()
      ..addEntries(plan.allocations.map((item) => MapEntry(item.causeId, item.percentage)));
    for (final controller in _percentageControllers.values) {
      controller.dispose();
    }
    _percentageControllers.clear();
  }

  int get _allocationTotal => _selectedCauseIds.fold(
        0,
        (total, id) => total + (_allocationPercentages[id] ?? 0),
      );

  int? get _amountPaise => parseRupeesToPaise(_amountController.text);

  int? get _customIntervalDays => int.tryParse(_customDaysController.text.trim());

  int? get _monthlyEstimatePaise {
    final amount = _amountPaise;
    if (amount == null) return null;
    final interval = _customIntervalDays ?? 0;
    if (_frequency == DonationPlanFrequency.custom && (interval < 1 || interval > 365)) {
      return null;
    }
    return DonationPlan.estimateMonthlyPaise(
      amountPaise: amount,
      frequency: _frequency,
      customIntervalDays: interval,
    );
  }

  bool get _canSave =>
      !_saving &&
      !_loading &&
      !_loadFailed &&
      (_amountPaise ?? 0) > 0 &&
      _selectedCauseIds.isNotEmpty &&
      _allocationTotal == 100 &&
      (_frequency != DonationPlanFrequency.custom ||
          ((_customIntervalDays ?? 0) >= 1 && (_customIntervalDays ?? 0) <= 365));

  void _toggleCause(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedCauseIds.add(id);
      } else {
        _selectedCauseIds.remove(id);
        _allocationPercentages.remove(id);
        _percentageControllers.remove(id)?.dispose();
      }
      _applyEqualDistribution();
    });
  }

  void _applyEqualDistribution() {
    if (_selectedCauseIds.isEmpty) return;
    final ids = _selectedCauseIds.toList(growable: false);
    final base = 100 ~/ ids.length;
    var remainder = 100 % ids.length;
    for (final id in ids) {
      _allocationPercentages[id] = base + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
    }
    for (final id in ids) {
      final controller = _percentageControllers[id];
      final value = _allocationPercentages[id].toString();
      if (controller != null && controller.text != value) controller.text = value;
    }
  }

  TextEditingController _percentageController(String id) {
    return _percentageControllers.putIfAbsent(
      id,
      () => TextEditingController(text: (_allocationPercentages[id] ?? 0).toString()),
    );
  }

  void _setPercentage(String id, String value) {
    setState(() => _allocationPercentages[id] = (int.tryParse(value) ?? 0).clamp(0, 100));
  }

  String _frequencyLabel(AppLocalizations l10n, DonationPlanFrequency value) {
    return switch (value) {
      DonationPlanFrequency.daily => l10n.donationPlannerDaily,
      DonationPlanFrequency.weekly => l10n.donationPlannerWeekly,
      DonationPlanFrequency.monthly => l10n.donationPlannerMonthly,
      DonationPlanFrequency.custom => l10n.donationPlannerCustom,
    };
  }

  String _historyLabel(AppLocalizations l10n, String action) {
    return switch (action) {
      'created' => l10n.donationPlannerPlanCreated,
      'activated' => l10n.donationPlannerPlanActivated,
      'paused' => l10n.donationPlannerPlanPausedEvent,
      _ => l10n.donationPlannerPlanUpdated,
    };
  }

  Future<void> _savePlan() async {
    final amount = _amountPaise;
    final interval = _customIntervalDays ?? 0;
    if (amount == null || amount <= 0 || _selectedCauseIds.isEmpty || _allocationTotal != 100) return;
    if (_frequency == DonationPlanFrequency.custom && (interval < 1 || interval > 365)) return;

    setState(() => _saving = true);
    try {
      final allocations = _selectedCauseIds
          .map((id) => DonationPlanAllocation(
                causeId: id,
                percentage: _allocationPercentages[id] ?? 0,
              ))
          .toList(growable: false);
      final saved = await ref.read(donationPlannerRepositoryProvider).savePlan(
            amountPaise: amount,
            frequency: _frequency,
            customIntervalDays: interval,
            allocations: allocations,
          );
      if (!mounted) return;
      setState(() {
        _savedState = saved;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.donationPlannerSaved)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.donationPlannerSaveError)),
      );
    }
  }

  Future<void> _setPlanActive(bool value) async {
    try {
      final updated = await ref.read(donationPlannerRepositoryProvider).setActive(value);
      if (!mounted) return;
      setState(() => _savedState = updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.donationPlannerSaveError)),
      );
    }
  }

  String? _validationMessage(AppLocalizations l10n) {
    if ((_amountPaise ?? 0) <= 0) return l10n.donationPlannerValidationAmount;
    if (_frequency == DonationPlanFrequency.custom &&
        ((_customIntervalDays ?? 0) < 1 || (_customIntervalDays ?? 0) > 365)) {
      return l10n.donationPlannerValidationFrequency;
    }
    if (_selectedCauseIds.isEmpty || _allocationTotal != 100) {
      return l10n.donationPlannerValidationAllocation;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final causesAsync = ref.watch(causesProvider(languageCode));
    final plan = _savedState.plan;
    final monthlyEstimate = _monthlyEstimatePaise;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.donationPlannerTitle),
        actions: const [AppSettingsMenu()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.donationPlannerLoadError, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: Text(l10n.donationPlannerRetry)),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    Text(l10n.donationPlannerSubtitle, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 20),
                    TextField(
                      key: const ValueKey('donation_plan_amount'),
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l10n.donationPlannerAmount,
                        prefixText: '₹ ',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DonationPlanFrequency>(
                      key: const ValueKey('donation_plan_frequency'),
                      value: _frequency,
                      decoration: InputDecoration(
                        labelText: l10n.donationPlannerFrequency,
                        border: const OutlineInputBorder(),
                      ),
                      items: DonationPlanFrequency.values
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(_frequencyLabel(l10n, value)),
                              ))
                          .toList(growable: false),
                      onChanged: (value) => setState(() => _frequency = value ?? _frequency),
                    ),
                    if (_frequency == DonationPlanFrequency.custom) ...[
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('donation_plan_custom_days'),
                        controller: _customDaysController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: l10n.donationPlannerEveryDays,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (monthlyEstimate != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.calendar_month_rounded),
                          title: Text(l10n.donationPlannerMonthlyEstimate),
                          subtitle: Text(formatRupees(monthlyEstimate)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(l10n.shareAcrossCauses, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(l10n.selectCauses, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    causesAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (_, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.causesLoadError),
                          TextButton(
                            onPressed: () => ref.invalidate(causesProvider(languageCode)),
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                      data: (causes) => _buildCauseChoices(causes, l10n),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${l10n.totalAllocation}: $_allocationTotal%',
                      key: const ValueKey('donation_plan_allocation_total'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _allocationTotal == 100 ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                    if (_validationMessage(l10n) case final message?) ...[
                      const SizedBox(height: 8),
                      Text(message, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                    ],
                    const SizedBox(height: 16),
                    if (plan != null)
                      Card(
                        child: SwitchListTile(
                          key: const ValueKey('donation_plan_active'),
                          value: plan.isActive,
                          title: Text(plan.isActive ? l10n.donationPlannerPlanActive : l10n.donationPlannerPlanPaused),
                          subtitle: Text(plan.isActive ? l10n.donationPlannerPause : l10n.donationPlannerActivate),
                          onChanged: _setPlanActive,
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey('donation_plan_save'),
                      onPressed: _canSave ? _savePlan : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(l10n.donationPlannerSave),
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.donationPlannerLocalOnly, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    Text(l10n.donationPlannerHistory, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (_savedState.history.isEmpty)
                      Text(l10n.donationPlannerHistoryEmpty, style: theme.textTheme.bodyMedium)
                    else
                      ..._savedState.history.map((entry) {
                        final date = DateFormat.yMMMd(languageCode).add_jm().format(entry.changedAt.toLocal());
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history_rounded),
                          title: Text(_historyLabel(l10n, entry.action)),
                          subtitle: Text('${formatRupees(entry.amountPaise)} · ${_frequencyLabel(l10n, entry.frequency)} · $date'),
                        );
                      }),
                  ],
                ),
    );
  }

  Widget _buildCauseChoices(List<Cause> causes, AppLocalizations l10n) {
    final selectableCauses = causes.expand((cause) => cause.leafCauses).toList(growable: false);
    if (selectableCauses.isEmpty) return Text(l10n.noCauses);
    return Column(
      children: selectableCauses.map((cause) {
        final selected = _selectedCauseIds.contains(cause.id);
        return Card(
          child: Column(
            children: [
              CheckboxListTile(
                key: ValueKey('donation_plan_cause_${cause.id}'),
                value: selected,
                title: Text(cause.name),
                onChanged: (value) => _toggleCause(cause.id, value ?? false),
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.allocationPercentage)),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          key: ValueKey('donation_plan_percentage_${cause.id}'),
                          controller: _percentageController(cause.id),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (value) => _setPercentage(cause.id, value),
                          decoration: const InputDecoration(suffixText: '%'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}
