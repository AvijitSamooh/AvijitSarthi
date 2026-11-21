class City {
  const City({required this.id, required this.name});

  final String id;
  final String name;

  factory City.fromJson(Map<String, dynamic> json) => City(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}
