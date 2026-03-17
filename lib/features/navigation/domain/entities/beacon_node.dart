import 'package:equatable/equatable.dart';

/// Represents a navigation node or beacon position in the indoor map.
/// 
/// A [BeaconNode] is the runtime representation of a navigation point,
/// used for:
/// - User positioning (when detected by BLE beacon)
/// - Route calculation (as waypoints in the navigation graph)
/// - Destination markers (departments users can navigate to)
/// 
/// This is the domain entity used throughout the navigation feature,
/// converted from [ConfigurableNode] in the configuration layer.
/// 
/// Example:
/// ```dart
/// final node = BeaconNode(
///   uid: 'beacon_reception',
///   name: 'Reception',
///   x: 200,
///   y: 300,
///   floor: 1,
///   departmentId: 'reception',
/// );
/// ```
class BeaconNode extends Equatable {
  /// Unique identifier (matches beacon UID or node ID)
  final String uid;
  
  /// Human-readable display name
  final String name;
  
  /// X coordinate position on the map (in pixels)
  final double x;
  
  /// Y coordinate position on the map (in pixels)
  final double y;
  
  /// Floor number where this node is located (1-indexed)
  final int floor;
  
  /// Optional department ID if this is a destination
  final String? departmentId;
  
  /// Whether this node can be used in navigation routes
  final bool isNavigable;
  
  /// List of connected node UIDs (for legacy compatibility)
  final List<String> connectedNodes;

  const BeaconNode({
    required this.uid,
    required this.name,
    required this.x,
    required this.y,
    required this.floor,
    this.departmentId,
    this.isNavigable = true,
    this.connectedNodes = const [],
  });

  BeaconNode copyWith({
    String? uid,
    String? name,
    double? x,
    double? y,
    int? floor,
    String? departmentId,
    bool? isNavigable,
    List<String>? connectedNodes,
  }) {
    return BeaconNode(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      floor: floor ?? this.floor,
      departmentId: departmentId ?? this.departmentId,
      isNavigable: isNavigable ?? this.isNavigable,
      connectedNodes: connectedNodes ?? this.connectedNodes,
    );
  }

  @override
  List<Object?> get props => [uid, name, x, y, floor, departmentId, isNavigable, connectedNodes];
}
