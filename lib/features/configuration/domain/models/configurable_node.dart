import 'package:equatable/equatable.dart';

/// Types of navigation nodes in the indoor navigation system.
/// 
/// Each type determines the node's behavior and visual representation:
/// - [waypoint]: Generic navigation point (corridor intersection, corner)
/// - [department]: Destination point (e.g., Reception, Lab, Pharmacy)
/// - [entrance]: Building entrance point
/// - [elevator]: Elevator for floor transitions
/// - [stairs]: Staircase for floor transitions
/// - [beacon]: Node with associated BLE beacon
enum NodeType {
  /// Generic navigation waypoint (corridor intersection, corner, etc.)
  waypoint,
  
  /// Destination department (e.g., Reception, Lab, Pharmacy)
  department,
  
  /// Building entrance point
  entrance,
  
  /// Elevator connection point for floor transitions
  elevator,
  
  /// Staircase connection point for floor transitions
  stairs,
  
  /// Node with an associated BLE beacon for positioning
  beacon,
}

/// Represents a navigation node that can be configured dynamically.
/// 
/// A [ConfigurableNode] is a point on the indoor map that can be:
/// - A waypoint for navigation routing
/// - A destination (department) that users can navigate to
/// - A floor transition point (stairs/elevator)
/// - Linked to a physical BLE beacon for positioning
/// 
/// Nodes are connected via [NodeConnection] objects which define
/// the navigation graph used for pathfinding.
/// 
/// Example:
/// ```dart
/// final node = ConfigurableNode(
///   id: 'node_reception',
///   name: 'Reception',
///   x: 200,
///   y: 300,
///   floor: 1,
///   type: NodeType.department,
///   connections: [
///     NodeConnection(targetNodeId: 'node_corridor'),
///   ],
/// );
/// ```
class ConfigurableNode extends Equatable {
  /// Unique identifier for this node (used in connections and routing)
  final String id;
  
  /// Human-readable display name
  final String name;
  
  /// X coordinate position on the map (in pixels)
  final double x;
  
  /// Y coordinate position on the map (in pixels)
  final double y;
  
  /// Floor number where this node is located (1-indexed)
  final int floor;
  
  /// Type of node (waypoint, department, stairs, etc.)
  final NodeType type;
  
  /// Optional department ID if this is a destination node
  final String? departmentId;
  
  /// Optional linked beacon ID for positioning
  final String? linkedBeaconId;
  
  /// List of outgoing connections to other nodes
  final List<NodeConnection> connections;
  
  /// Whether this node can be used in navigation routes
  final bool isNavigable;
  
  /// Additional metadata for custom extensions
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

/// Represents a directed connection between two navigation nodes.
/// 
/// A [NodeConnection] defines a path from one node to another with:
/// - Direction: Can be one-way or bidirectional
/// - Type: Access restrictions (normal, emergency, staff-only)
/// - Weight: Optional distance override for routing
/// 
/// ## One-Way vs Bidirectional
/// 
/// - **Bidirectional** (`isBidirectional: true`): Users can travel in both directions
/// - **One-Way** (`isBidirectional: false`): Users can only travel FROM the source node
///   TO the target node, not in reverse
/// 
/// Example:
/// ```dart
/// // Bidirectional connection (default)
/// final conn1 = NodeConnection(
///   targetNodeId: 'node_corridor',
///   isBidirectional: true,
/// );
/// 
/// // One-way connection (e.g., exit-only door)
/// final conn2 = NodeConnection(
///   targetNodeId: 'node_exit',
///   isBidirectional: false,
///   type: ConnectionType.emergency,
/// );
/// ```
class NodeConnection extends Equatable {
  /// ID of the target node this connection leads to
  final String targetNodeId;
  
  /// Optional weight/distance override (uses Euclidean distance if null)
  final double? weight;
  
  /// Whether travel is allowed in both directions.
  /// If false, travel is only allowed FROM source TO target.
  final bool isBidirectional;
  
  /// Type of connection determining access restrictions
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

/// Types of connections between nodes with different access restrictions.
/// 
/// Connection types determine who can use a particular path:
/// - [normal]: Standard corridor, anyone can use
/// - [emergency]: Emergency routes only (fire exits)
/// - [staff]: Staff-only access (restricted areas)
/// - [stairs]: Staircase connection (floor transition)
/// - [elevator]: Elevator connection (floor transition)
/// - [blocked]: Blocked route - no passage allowed (displayed in red)
enum ConnectionType {
  /// Standard corridor - accessible to everyone
  normal,
  
  /// Emergency route only (e.g., fire exit)
  emergency,
  
  /// Staff-only access (restricted area)
  staff,
  
  /// Staircase connection for floor transitions
  stairs,
  
  /// Elevator connection for floor transitions
  elevator,
  
  /// Blocked route - no passage allowed (prevents pathfinding)
  blocked,
}
