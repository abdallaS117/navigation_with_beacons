import 'package:equatable/equatable.dart';
import 'beacon_node.dart';

/// Represents a calculated navigation route between two points.
/// 
/// A [NavigationRoute] contains:
/// - An ordered list of [BeaconNode]s forming the path
/// - Total distance and estimated travel time
/// - Turn-by-turn navigation instructions
/// 
/// Routes are calculated by [NavigationRepositoryImpl] using Dijkstra's
/// algorithm, respecting connection directions and access restrictions.
/// 
/// ## Empty Routes
/// 
/// An empty route (`isEmpty == true`) indicates navigation is not possible.
/// Check `instructions` for the reason (e.g., "One-way restriction").
/// 
/// Example:
/// ```dart
/// final route = await navigationRepository.calculateRoute(start, end);
/// if (route.isEmpty) {
///   print('Cannot navigate: ${route.instructions.first}');
/// } else {
///   print('Route: ${route.nodes.map((n) => n.name).join(' → ')}');
/// }
/// ```
class NavigationRoute extends Equatable {
  /// Ordered list of nodes forming the navigation path
  final List<BeaconNode> nodes;
  
  /// Total distance of the route (in pixels)
  final double totalDistance;
  
  /// Estimated travel time in seconds
  final int estimatedTimeSeconds;
  
  /// Turn-by-turn navigation instructions
  final List<String> instructions;

  const NavigationRoute({
    required this.nodes,
    required this.totalDistance,
    required this.estimatedTimeSeconds,
    this.instructions = const [],
  });

  /// Whether this route has no nodes (navigation not possible)
  bool get isEmpty => nodes.isEmpty;
  
  /// Whether this route has nodes (navigation is possible)
  bool get isNotEmpty => nodes.isNotEmpty;
  
  /// First node in the route (starting point)
  BeaconNode? get startNode => nodes.isNotEmpty ? nodes.first : null;
  
  /// Last node in the route (destination)
  BeaconNode? get endNode => nodes.isNotEmpty ? nodes.last : null;

  /// Number of nodes in the route
  int get nodeCount => nodes.length;

  /// List of unique floor numbers in this route (sorted)
  List<int> get floorsInRoute {
    final floors = nodes.map((n) => n.floor).toSet().toList();
    floors.sort();
    return floors;
  }

  /// Whether this route spans multiple floors
  bool requiresFloorChange() {
    if (nodes.length < 2) return false;
    final firstFloor = nodes.first.floor;
    return nodes.any((node) => node.floor != firstFloor);
  }

  @override
  List<Object?> get props => [nodes, totalDistance, estimatedTimeSeconds, instructions];
}
