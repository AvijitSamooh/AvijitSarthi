class CityContent {
  const CityContent({
    required this.id,
    required this.cityId,
    required this.title,
    required this.description,
    this.startsAt,
    this.endsAt,
    this.achievedAt,
  });

  final String id;
  final String cityId;
  final String title;
  final String description;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? achievedAt;

  DateTime? get displayDate => startsAt ?? achievedAt;

  factory CityContent.fromJson(Map<String, dynamic> json) => CityContent(
        id: json['id'] as String,
        cityId: json['cityId'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        startsAt: _parseDate(json['startsAt']),
        endsAt: _parseDate(json['endsAt']),
        achievedAt: _parseDate(json['achievedAt']),
      );

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
