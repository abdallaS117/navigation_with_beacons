import 'package:equatable/equatable.dart';
import 'configurable_beacon.dart';
import 'configurable_node.dart';
import 'map_layout_config.dart';
import 'route_config.dart';

/// Complete navigation configuration that combines all config elements.
/// This is the root model for saving/loading complete configurations.
class NavigationConfig extends Equatable {
  final String id;
  final String name;
  final DateTime lastModified;
  final MapLayoutConfig mapConfig;
  final List<ConfigurableBeacon> beacons;
  final List<ConfigurableNode> nodes;
  final List<RouteConfig> routes;
  final Map<String, dynamic> metadata;

  NavigationConfig({
    required this.id,
    required this.name,
    DateTime? lastModified,
    required this.mapConfig,
    this.beacons = const [],
    this.nodes = const [],
    this.routes = const [],
    this.metadata = const {},
  }) : lastModified = lastModified ?? DateTime.now();

  NavigationConfig copyWith({
    String? id,
    String? name,
    DateTime? lastModified,
    MapLayoutConfig? mapConfig,
    List<ConfigurableBeacon>? beacons,
    List<ConfigurableNode>? nodes,
    List<RouteConfig>? routes,
    Map<String, dynamic>? metadata,
  }) {
    return NavigationConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      lastModified: lastModified ?? DateTime.now(),
      mapConfig: mapConfig ?? this.mapConfig,
      beacons: beacons ?? this.beacons,
      nodes: nodes ?? this.nodes,
      routes: routes ?? this.routes,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lastModified': lastModified.toIso8601String(),
      'mapConfig': mapConfig.toJson(),
      'beacons': beacons.map((b) => b.toJson()).toList(),
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'routes': routes.map((r) => r.toJson()).toList(),
      'metadata': metadata,
    };
  }

  factory NavigationConfig.fromJson(Map<String, dynamic> json) {
    return NavigationConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      lastModified: DateTime.parse(json['lastModified'] as String),
      mapConfig: MapLayoutConfig.fromJson(json['mapConfig'] as Map<String, dynamic>),
      beacons: (json['beacons'] as List<dynamic>?)
              ?.map((b) => ConfigurableBeacon.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      nodes: (json['nodes'] as List<dynamic>?)
              ?.map((n) => ConfigurableNode.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
      routes: (json['routes'] as List<dynamic>?)
              ?.map((r) => RouteConfig.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Creates an empty default configuration
  factory NavigationConfig.empty() {
    return NavigationConfig(
      id: 'default',
      name: 'Default Configuration',
      mapConfig: const MapLayoutConfig(
        id: 'default_map',
        name: 'Hospital Layout',
        width: 800,
        height: 600,
      ),
    );
  }

  @override
  List<Object?> get props => [id, name, lastModified, mapConfig, beacons, nodes, routes, metadata];
}
