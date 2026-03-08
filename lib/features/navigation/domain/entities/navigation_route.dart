import 'package:equatable/equatable.dart';
import 'beacon_node.dart';

class NavigationRoute extends Equatable {
  final List<BeaconNode> nodes;
  final double totalDistance;
  final int estimatedTimeSeconds;
  final List<String> instructions;

  const NavigationRoute({
    required this.nodes,
    required this.totalDistance,
    required this.estimatedTimeSeconds,
    this.instructions = const [],
  });

  bool get isEmpty => nodes.isEmpty;
  bool get isNotEmpty => nodes.isNotEmpty;
  
  BeaconNode? get startNode => nodes.isNotEmpty ? nodes.first : null;
  BeaconNode? get endNode => nodes.isNotEmpty ? nodes.last : null;

  int get nodeCount => nodes.length;

  List<int> get floorsInRoute {
    final floors = nodes.map((n) => n.floor).toSet().toList();
    floors.sort();
    return floors;
  }

  bool requiresFloorChange() {
    if (nodes.length < 2) return false;
    final firstFloor = nodes.first.floor;
    return nodes.any((node) => node.floor != firstFloor);
  }

  @override
  List<Object?> get props => [nodes, totalDistance, estimatedTimeSeconds, instructions];
}
