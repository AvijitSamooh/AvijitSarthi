class DonationAllocationRecord {
  const DonationAllocationRecord({
    required this.causeId,
    required this.amount,
    this.id,
    this.createdAt,
  });

  final String causeId;
  final String amount;
  final String? id;
  final DateTime? createdAt;

  factory DonationAllocationRecord.fromJson(Map<String, dynamic> json) {
    return DonationAllocationRecord(
      causeId: json['causeId'] as String,
      amount: json['amount'] as String,
      id: json['id'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}

class DonationRecord {
  const DonationRecord({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.allocations,
  });

  final String id;
  final String amount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DonationAllocationRecord> allocations;

  bool get isSuccessful => status.toUpperCase() == 'SUCCESS';

  factory DonationRecord.fromJson(Map<String, dynamic> json) {
    return DonationRecord(
      id: json['id'] as String,
      amount: json['amount'] as String,
      currency: json['currency'] as String? ?? 'INR',
      status: json['status'] as String? ?? 'PENDING',
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      allocations: (json['allocations'] as List<dynamic>? ?? const [])
          .map((item) => DonationAllocationRecord.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class DonationReceipt {
  const DonationReceipt({
    required this.id,
    required this.donationId,
    required this.receiptNumber,
    required this.amount,
    required this.currency,
    required this.language,
    required this.allocations,
    required this.donationCreatedAt,
    required this.issuedAt,
  });

  final String id;
  final String donationId;
  final String receiptNumber;
  final String amount;
  final String currency;
  final String language;
  final List<DonationAllocationRecord> allocations;
  final DateTime donationCreatedAt;
  final DateTime issuedAt;

  factory DonationReceipt.fromJson(Map<String, dynamic> json) {
    return DonationReceipt(
      id: json['id'] as String,
      donationId: json['donationId'] as String,
      receiptNumber: json['receiptNumber'] as String,
      amount: json['amount'] as String,
      currency: json['currency'] as String? ?? 'INR',
      language: json['language'] as String? ?? 'en',
      allocations: (json['allocations'] as List<dynamic>? ?? const [])
          .map((item) => DonationAllocationRecord.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      donationCreatedAt: DateTime.parse(json['donationCreatedAt'] as String).toLocal(),
      issuedAt: DateTime.parse(json['issuedAt'] as String).toLocal(),
    );
  }
}
