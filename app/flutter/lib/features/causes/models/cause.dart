import 'organisation.dart';

class Cause {
  const Cause({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.displayOrder = 0,
    this.parentId,
    this.hasChildren = false,
    this.children = const [],
    this.organisations = const [],
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final int displayOrder;
  final String? parentId;
  final bool hasChildren;
  final List<Cause> children;
  final List<Organisation> organisations;

  bool get isParent => hasChildren || children.isNotEmpty;
  bool get isLeaf => !isParent;

  Iterable<Cause> get leafCauses sync* {
    if (!isParent) {
      yield this;
      return;
    }
    for (final child in children) {
      yield* child.leafCauses;
    }
  }

  factory Cause.fromJson(Map<String, dynamic> json) {
    final children = (json['children'] as List<dynamic>? ?? [])
        .map((item) => Cause.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    return Cause(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      parentId: json['parentId'] as String?,
      hasChildren: json['hasChildren'] as bool? ?? children.isNotEmpty,
      children: children,
      organisations: (json['organisations'] as List<dynamic>? ?? [])
          .map((item) => Organisation.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
