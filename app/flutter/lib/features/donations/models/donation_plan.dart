enum DonationPlanFrequency { daily, weekly, monthly, custom }

class DonationPlanAllocation {
  const DonationPlanAllocation({required this.causeId, required this.percentage});

  final String causeId;
  final int percentage;

  Map<String, dynamic> toJson() => {
        'causeId': causeId,
        'percentage': percentage,
      };

  factory DonationPlanAllocation.fromJson(Map<String, dynamic> json) {
    return DonationPlanAllocation(
      causeId: json['causeId'] as String,
      percentage: (json['percentage'] as num).toInt(),
    );
  }
}

class DonationPlan {
  const DonationPlan({
    required this.amountPaise,
    required this.frequency,
    required this.customIntervalDays,
    required this.allocations,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int amountPaise;
  final DonationPlanFrequency frequency;
  final int customIntervalDays;
  final List<DonationPlanAllocation> allocations;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get monthlyEstimatePaise => estimateMonthlyPaise(
        amountPaise: amountPaise,
        frequency: frequency,
        customIntervalDays: customIntervalDays,
      );

  static int estimateMonthlyPaise({
    required int amountPaise,
    required DonationPlanFrequency frequency,
    required int customIntervalDays,
  }) {
    final intervalDays = switch (frequency) {
      DonationPlanFrequency.daily => 1,
      DonationPlanFrequency.weekly => 7,
      DonationPlanFrequency.monthly => 30,
      DonationPlanFrequency.custom => customIntervalDays,
    };
    if (intervalDays <= 0) return 0;
    return (amountPaise * 30 + intervalDays ~/ 2) ~/ intervalDays;
  }

  DonationPlan copyWith({
    int? amountPaise,
    DonationPlanFrequency? frequency,
    int? customIntervalDays,
    List<DonationPlanAllocation>? allocations,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DonationPlan(
      amountPaise: amountPaise ?? this.amountPaise,
      frequency: frequency ?? this.frequency,
      customIntervalDays: customIntervalDays ?? this.customIntervalDays,
      allocations: allocations ?? this.allocations,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'amountPaise': amountPaise,
        'frequency': frequency.name,
        'customIntervalDays': customIntervalDays,
        'allocations': allocations.map((item) => item.toJson()).toList(),
        'isActive': isActive,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory DonationPlan.fromJson(Map<String, dynamic> json) {
    final frequencyName = json['frequency'] as String? ?? 'daily';
    final frequency = DonationPlanFrequency.values.firstWhere(
      (value) => value.name == frequencyName,
      orElse: () => DonationPlanFrequency.daily,
    );
    return DonationPlan(
      amountPaise: (json['amountPaise'] as num).toInt(),
      frequency: frequency,
      customIntervalDays: (json['customIntervalDays'] as num?)?.toInt() ?? 1,
      allocations: (json['allocations'] as List<dynamic>? ?? [])
          .map((item) => DonationPlanAllocation.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }
}

class DonationPlanHistoryEntry {
  const DonationPlanHistoryEntry({
    required this.action,
    required this.amountPaise,
    required this.frequency,
    required this.isActive,
    required this.changedAt,
  });

  final String action;
  final int amountPaise;
  final DonationPlanFrequency frequency;
  final bool isActive;
  final DateTime changedAt;

  Map<String, dynamic> toJson() => {
        'action': action,
        'amountPaise': amountPaise,
        'frequency': frequency.name,
        'isActive': isActive,
        'changedAt': changedAt.toUtc().toIso8601String(),
      };

  factory DonationPlanHistoryEntry.fromJson(Map<String, dynamic> json) {
    final frequencyName = json['frequency'] as String? ?? 'daily';
    return DonationPlanHistoryEntry(
      action: json['action'] as String? ?? 'updated',
      amountPaise: (json['amountPaise'] as num).toInt(),
      frequency: DonationPlanFrequency.values.firstWhere(
        (value) => value.name == frequencyName,
        orElse: () => DonationPlanFrequency.daily,
      ),
      isActive: json['isActive'] as bool? ?? true,
      changedAt: DateTime.parse(json['changedAt'] as String).toUtc(),
    );
  }
}

class DonationPlannerState {
  const DonationPlannerState({
    this.plan,
    this.history = const [],
  });

  final DonationPlan? plan;
  final List<DonationPlanHistoryEntry> history;

  Map<String, dynamic> toJson() => {
        'plan': plan?.toJson(),
        'history': history.map((entry) => entry.toJson()).toList(),
      };

  factory DonationPlannerState.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['plan'];
    return DonationPlannerState(
      plan: rawPlan is Map<String, dynamic> ? DonationPlan.fromJson(rawPlan) : null,
      history: (json['history'] as List<dynamic>? ?? [])
          .map((item) => DonationPlanHistoryEntry.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

int? parseRupeesToPaise(String value) {
  final normalized = value.trim().replaceAll(',', '');
  if (!RegExp(r'^[0-9]+(?:[.][0-9]{1,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final whole = int.tryParse(parts.first);
  if (whole == null) return null;
  final fraction = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  final paise = whole * 100 + int.parse(fraction);
  return paise > 0 ? paise : null;
}

String formatRupees(int paise) {
  final whole = paise ~/ 100;
  final fraction = (paise % 100).toString().padLeft(2, '0');
  return '₹$whole.$fraction';
}
