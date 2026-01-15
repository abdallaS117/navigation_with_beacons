import 'package:equatable/equatable.dart';

/// Configuration for a predefined route
class RouteConfig extends Equatable {
  final String id;
  final String name;
  final String? description;
  final List<String> nodeIds;
  final bool isPreferred;
  final RouteType type;
  final Map<String, dynamic> metadata;

  const RouteConfig({
    required this.id,
    required this.name,
    this.description,
    required this.nodeIds,
    this.isPreferred = false,
    this.type = RouteType.normal,
    this.metadata = const {},
  });

  RouteConfig copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? nodeIds,
    bool? isPreferred,
    RouteType? type,
    Map<String, dynamic>? metadata,
  }) {
    return RouteConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      nodeIds: nodeIds ?? this.nodeIds,
      isPreferred: isPreferred ?? this.isPreferred,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'nodeIds': nodeIds,
      'isPreferred': isPreferred,
      'type': type.name,
      'metadata': metadata,
    };
  }

  factory RouteConfig.fromJson(Map<String, dynamic> json) {
    return RouteConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      nodeIds: (json['nodeIds'] as List<dynamic>).cast<String>(),
      isPreferred: json['isPreferred'] as bool? ?? false,
      type: RouteType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => RouteType.normal,
      ),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  @override
  List<Object?> get props => [id, name, description, nodeIds, isPreferred, type, metadata];
}

enum RouteType {
  normal,
  accessible,
  emergency,
  restricted,
}
