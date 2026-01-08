import 'dart:math';
import 'package:collection/collection.dart';
import '../../domain/entities/beacon_node.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/floor_map.dart';
import '../../domain/entities/navigation_route.dart';
import '../../domain/repositories/navigation_repository.dart';
import '../datasources/hybrid_beacon_datasource.dart';
import '../datasources/map_datasource.dart';

class NavigationRepositoryImpl implements NavigationRepository {
  final MapDataSource mapDataSource;
  final BeaconDataSource beaconDataSource;

  NavigationRepositoryImpl({
    required this.mapDataSource,
    required this.beaconDataSource,
  });

  @override
  Future<NavigationRoute> calculateRoute(BeaconNode start, BeaconNode end) async {
    final allBeacons = beaconDataSource.getAllBeacons();
    final path = _dijkstra(start, end, allBeacons);
    
    if (path.isEmpty) {
      return const NavigationRoute(
        nodes: [],
        totalDistance: 0,
        estimatedTimeSeconds: 0,
        instructions: ['No route found'],
      );
    }

    final distance = _calculateTotalDistance(path);
    final timeSeconds = (distance / 50 * 60).round(); // Assuming 50 units per minute walking speed
    final instructions = _generateInstructions(path);

    return NavigationRoute(
      nodes: path,
      totalDistance: distance,
      estimatedTimeSeconds: timeSeconds,
      instructions: instructions,
    );
  }

  List<BeaconNode> _dijkstra(BeaconNode start, BeaconNode end, List<BeaconNode> allBeacons) {
    final Map<String, double> distances = {};
    final Map<String, String?> previous = {};
    final Set<String> visited = {};
    final PriorityQueue<_NodeDistance> queue = PriorityQueue((a, b) => a.distance.compareTo(b.distance));

    // Initialize distances
    for (final beacon in allBeacons) {
      distances[beacon.uid] = double.infinity;
      previous[beacon.uid] = null;
    }
    distances[start.uid] = 0;
    queue.add(_NodeDistance(start.uid, 0));

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      
      if (visited.contains(current.uid)) continue;
      visited.add(current.uid);

      if (current.uid == end.uid) break;

      final currentNode = allBeacons.firstWhereOrNull((b) => b.uid == current.uid);
      if (currentNode == null) continue;

      for (final neighborUid in currentNode.connectedNodes) {
        if (visited.contains(neighborUid)) continue;

        final neighbor = allBeacons.firstWhereOrNull((b) => b.uid == neighborUid);
        if (neighbor == null) continue;

        final distance = _calculateDistance(currentNode, neighbor);
        final newDist = distances[current.uid]! + distance;

        if (newDist < distances[neighborUid]!) {
          distances[neighborUid] = newDist;
          previous[neighborUid] = current.uid;
          queue.add(_NodeDistance(neighborUid, newDist));
        }
      }
    }

    // Reconstruct path
    final List<BeaconNode> path = [];
    String? currentUid = end.uid;

    while (currentUid != null) {
      final node = allBeacons.firstWhereOrNull((b) => b.uid == currentUid);
      if (node != null) {
        path.insert(0, node);
      }
      currentUid = previous[currentUid];
    }

    // Check if valid path (starts with start node)
    if (path.isEmpty || path.first.uid != start.uid) {
      return [];
    }

    return path;
  }

  double _calculateDistance(BeaconNode a, BeaconNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    double distance = sqrt(dx * dx + dy * dy);
    
    // Add penalty for floor changes
    if (a.floor != b.floor) {
      distance += 100 * (a.floor - b.floor).abs();
    }
    
    return distance;
  }

  double _calculateTotalDistance(List<BeaconNode> path) {
    double total = 0;
    for (int i = 0; i < path.length - 1; i++) {
      total += _calculateDistance(path[i], path[i + 1]);
    }
    return total;
  }

  List<String> _generateInstructions(List<BeaconNode> path) {
    final List<String> instructions = [];
    
    if (path.isEmpty) return instructions;

    instructions.add('Start at ${path.first.name}');

    for (int i = 1; i < path.length; i++) {
      final current = path[i];
      final prev = path[i - 1];

      if (current.floor != prev.floor) {
        if (current.departmentId == 'elevator') {
          instructions.add('Take elevator to Floor ${current.floor}');
        } else if (current.departmentId == 'stairs') {
          instructions.add('Take stairs to Floor ${current.floor}');
        } else {
          instructions.add('Go to Floor ${current.floor}');
        }
      } else {
        final direction = _getDirection(prev, current);
        instructions.add('$direction to ${current.name}');
      }
    }

    instructions.add('You have arrived at ${path.last.name}');
    return instructions;
  }

  String _getDirection(BeaconNode from, BeaconNode to) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;

    if (dx.abs() > dy.abs()) {
      return dx > 0 ? 'Go right' : 'Go left';
    } else {
      return dy > 0 ? 'Go down' : 'Go up';
    }
  }

  @override
  Future<FloorMap> getFloorMap(int floor) async {
    return mapDataSource.getFloorMap(floor);
  }

  @override
  Future<List<FloorMap>> getAllFloorMaps() async {
    return mapDataSource.getAllFloorMaps();
  }

  @override
  Future<List<Department>> getAllDepartments() async {
    return mapDataSource.getAllDepartments();
  }

  @override
  Future<Department?> getDepartmentById(String id) async {
    return mapDataSource.getDepartmentById(id);
  }

  @override
  Future<BeaconNode?> getBeaconForDepartment(String departmentId) async {
    final beacons = beaconDataSource.getAllBeacons();
    return beacons.firstWhereOrNull((b) => b.departmentId == departmentId);
  }
}

class _NodeDistance {
  final String uid;
  final double distance;

  _NodeDistance(this.uid, this.distance);
}
