import 'package:equatable/equatable.dart';

/// Types of navigation nodes
enum NodeType {
  waypoint,
  department,
  entrance,
  elevator,
  stairs,
  beacon,
}

/// Represents a navigation node that can be configured dynamically.
class ConfigurableNode extends Equatable {
  final String id;
  final String name;
  final double x;
  final double y;
  final int floor;
  final NodeType type;
  final String? departmentId;
  final String? linkedBeaconId;
  final List<NodeConnection> connections;
  final bool isNavigable;
  final Map<String, dynamic> metadata;

  const ConfigurableNode({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.floor,
    this.type = NodeType.waypoint,
    this.departmentId,
    this.linkedBeaconId,
    this.connections = const [],
    this.isNavigable = true,
    this.metadata = const {},
  });

  ConfigurableNode copyWith({
    String? id,
    String? name,
    double? x,
    double? y,
    int? floor,
    NodeType? type,
    String? departmentId,
    String? linkedBeaconId,
    List<NodeConnection>? connections,
    bool? isNavigable,
    Map<String, dynamic>? metadata,
  }) {
    return ConfigurableNode(
      id: id ?? this.id,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      floor: floor ?? this.floor,
      type: type ?? this.type,
      departmentId: departmentId ?? this.departmentId,
      linkedBeaconId: linkedBeaconId ?? this.linkedBeaconId,
      connections: connections ?? this.connections,
      isNavigable: isNavigable ?? this.isNavigable,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'x': x,
      'y': y,
      'floor': floor,
      'type': type.name,
      'departmentId': departmentId,
      'linkedBeaconId': linkedBeaconId,
      'connections': connections.map((c) => c.toJson()).toList(),
      'isNavigable': isNavigable,
      'metadata': metadata,
    };
  }

  factory ConfigurableNode.fromJson(Map<String, dynamic> json) {
    return ConfigurableNode(
      id: json['id'] as String,
      name: json['name'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      floor: json['floor'] as int,
      type: NodeType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => NodeType.waypoint,
      ),
      departmentId: json['departmentId'] as String?,
      linkedBeaconId: json['linkedBeaconId'] as String?,
      connections: (json['connections'] as List<dynamic>?)
              ?.map((c) => NodeConnection.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      isNavigable: json['isNavigable'] as bool? ?? true,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  @override
  List<Object?> get props => [id, name, x, y, floor, type, departmentId, linkedBeaconId, connections, isNavigable, metadata];
}

/// Represents a connection between two nodes with optional weight.
class NodeConnection extends Equatable {
  final String targetNodeId;
  final double? weight;
  final bool isBidirectional;
  final ConnectionType type;

  const NodeConnection({
    required this.targetNodeId,
    this.weight,
    this.isBidirectional = true,
    this.type = ConnectionType.normal,
  });

  Map<String, dynamic> toJson() {
    return {
      'targetNodeId': targetNodeId,
      'weight': weight,
      'isBidirectional': isBidirectional,
      'type': type.name,
    };
  }

  factory NodeConnection.fromJson(Map<String, dynamic> json) {
    return NodeConnection(
      targetNodeId: json['targetNodeId'] as String,
      weight: (json['weight'] as num?)?.toDouble(),
      isBidirectional: json['isBidirectional'] as bool? ?? true,
      type: ConnectionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ConnectionType.normal,
      ),
    );
  }

  @override
  List<Object?> get props => [targetNodeId, weight, isBidirectional, type];
}

enum ConnectionType {
  normal,
  stairs,
  elevator,
  restricted,
}
