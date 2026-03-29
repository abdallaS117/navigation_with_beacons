import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/beacon_node.dart';
import '../../../configuration/domain/models/configurable_node.dart';

/// Helper class for pathfinding algorithms used in indoor navigation.
/// 
/// Provides static methods for:
/// - Dijkstra's algorithm with connection direction support
/// - Proximity-based fallback routing
/// - Distance calculations
/// 
/// ## One-Way Connection Handling
/// 
/// The pathfinding respects connection directions:
/// - **Direct outgoing**: Connections defined FROM a node are always traversable
/// - **Incoming bidirectional**: Connections TO a node are only traversable if marked bidirectional
/// 
/// Example:
/// ```
/// Node A ──────► Node B (one-way)
/// 
/// From A: Can reach B (direct outgoing)
/// From B: Cannot reach A (incoming is NOT bidirectional)
/// ```
class PathfindingHelper {
  /// Finds the shortest path using Dijkstra's algorithm.
  /// 
  /// Respects connection directions defined in [ConfigurableNode.connections].
  /// Returns empty list if no valid path exists.
  /// 
  /// Parameters:
  /// - [start]: Starting node
  /// - [end]: Destination node
  /// - [allBeacons]: All available nodes for routing
  /// - [configurableNodeMap]: Map of node IDs to their configurations
  static List<BeaconNode> dijkstraWithConfig(
    BeaconNode start,
    BeaconNode end,
    List<BeaconNode> allBeacons,
    Map<String, ConfigurableNode> configurableNodeMap,
  ) {
    _logConnectionMap(configurableNodeMap);

    // Build a map for quick beacon lookup
    final beaconMap = <String, BeaconNode>{};
    for (final beacon in allBeacons) {
      beaconMap[beacon.uid] = beacon;
    }

    final Map<String, double> distances = {};
    final Map<String, String?> previous = {};
    final Set<String> visited = {};
    final PriorityQueue<_NodeDistance> queue = PriorityQueue((a, b) => a.distance.compareTo(b.distance));

    // Initialize all distances to infinity
    for (final beacon in allBeacons) {
      distances[beacon.uid] = double.infinity;
      previous[beacon.uid] = null;
    }
    distances[start.uid] = 0;
    queue.add(_NodeDistance(start.uid, 0));

    debugPrint('🚀 Starting Dijkstra from ${start.name} (${start.uid}) to ${end.name} (${end.uid})');

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();

      // Skip if already visited (we may have added duplicates with better distances)
      if (visited.contains(current.uid)) continue;
      visited.add(current.uid);

      debugPrint('📍 Visiting: ${beaconMap[current.uid]?.name ?? current.uid}, distance: ${current.distance}');

      // Early termination if we reached the destination
      if (current.uid == end.uid) {
        debugPrint('🎯 Reached destination!');
        break;
      }

      final currentNode = beaconMap[current.uid];
      if (currentNode == null) continue;

      final configurableNode = configurableNodeMap[current.uid];

      // Get all valid neighbors (respecting connection directions)
      final validNeighborIds = _getValidNeighbors(current.uid, configurableNodeMap);
      debugPrint('   Valid neighbors: $validNeighborIds');

      for (final neighborUid in validNeighborIds) {
        if (visited.contains(neighborUid)) continue;

        final neighbor = beaconMap[neighborUid];
        if (neighbor == null) continue;

        // Check floor transition validity
        if (currentNode.floor != neighbor.floor) {
          final connection = configurableNode?.connections.firstWhereOrNull((c) => c.targetNodeId == neighborUid);
          final isValidTransition = connection?.type == ConnectionType.stairs ||
              connection?.type == ConnectionType.elevator ||
              currentNode.departmentId == 'stairs' ||
              currentNode.departmentId == 'elevator';
          if (!isValidTransition) continue;
        }

        // Calculate distance using Euclidean distance
        final distance = calculateDistance(currentNode, neighbor);
        final newDist = distances[current.uid]! + distance;

        debugPrint('   Checking neighbor: ${neighbor.name} (${neighborUid}), edge distance: $distance, total: $newDist, current best: ${distances[neighborUid]}');

        // Relaxation step: update if we found a shorter path
        if (newDist < distances[neighborUid]!) {
          distances[neighborUid] = newDist;
          previous[neighborUid] = current.uid;
          queue.add(_NodeDistance(neighborUid, newDist));
          debugPrint('   ✅ Updated distance to ${neighbor.name}: $newDist');
        }
      }
    }

    final path = _reconstructPath(end.uid, start.uid, previous, allBeacons);
    debugPrint('📊 Final path: ${path.map((n) => n.name).join(' → ')}');
    debugPrint('📊 Final distances: ${path.map((n) => distances[n.uid]).join(' → ')}');
    
    return path;
  }

  /// Gets valid neighbors for a node considering connection directions.
  /// 
  /// A neighbor is valid if:
  /// 1. There's a direct outgoing connection from current node, OR
  /// 2. There's an incoming connection that is bidirectional
  /// 
  /// This ensures one-way connections are respected during pathfinding.
  static Set<String> _getValidNeighbors(
    String currentUid,
    Map<String, ConfigurableNode> configurableNodeMap,
  ) {
    final validNeighborIds = <String>{};
    final configurableNode = configurableNodeMap[currentUid];

    // Direct outgoing connections (skip blocked connections)
    final directConnections = configurableNode?.connections ?? [];
    for (final conn in directConnections) {
      if (conn.type == ConnectionType.blocked) {
        debugPrint('   ✖ Blocked connection: $currentUid → ${conn.targetNodeId}');
        continue;
      }
      validNeighborIds.add(conn.targetNodeId);
      debugPrint('   → Direct outgoing: $currentUid → ${conn.targetNodeId} (bidirectional: ${conn.isBidirectional})');
    }

    // Incoming bidirectional connections (skip blocked connections)
    for (final otherNode in configurableNodeMap.values) {
      if (otherNode.id == currentUid) continue;
      for (final conn in otherNode.connections) {
        if (conn.type == ConnectionType.blocked) continue;
        if (conn.targetNodeId == currentUid && conn.isBidirectional) {
          validNeighborIds.add(otherNode.id);
          debugPrint('   ← Incoming bidirectional: ${otherNode.id} ↔ $currentUid');
        }
      }
    }

    return validNeighborIds;
  }

  /// Reconstructs the path from Dijkstra's previous-node map.
  /// 
  /// Walks backwards from end to start using the previous map,
  /// then reverses to get the correct order.
  static List<BeaconNode> _reconstructPath(
    String endUid,
    String startUid,
    Map<String, String?> previous,
    List<BeaconNode> allBeacons,
  ) {
    final List<BeaconNode> path = [];
    String? currentUid = endUid;

    while (currentUid != null) {
      final node = allBeacons.firstWhereOrNull((b) => b.uid == currentUid);
      if (node != null) {
        path.insert(0, node);
      }
      currentUid = previous[currentUid];
    }

    if (path.isEmpty || path.first.uid != startUid) {
      return [];
    }

    return path;
  }

  /// Find path between two nodes on the same floor.
  static List<BeaconNode> findPathOnFloor(
    BeaconNode start,
    BeaconNode end,
    List<BeaconNode> allNodes,
    Map<String, ConfigurableNode> configurableNodeMap,
  ) {
    if (start.uid == end.uid) {
      return [start];
    }

    final relevantFloors = {start.floor, end.floor};
    final floorNodes = allNodes.where((n) => relevantFloors.contains(n.floor)).toList();

    if (!floorNodes.any((n) => n.uid == start.uid)) {
      floorNodes.add(start);
    }
    if (!floorNodes.any((n) => n.uid == end.uid)) {
      floorNodes.add(end);
    }

    final dijkstraPath = dijkstraWithConfig(start, end, floorNodes, configurableNodeMap);
    if (dijkstraPath.isNotEmpty) {
      return dijkstraPath;
    }

    // Do NOT fall back to proximity-based routing as it ignores one-way restrictions
    // If Dijkstra fails, it means there's no valid path considering connection directions
    debugPrint('   ❌ No valid path found (one-way restrictions may apply)');
    return [];
  }

  /// Find path using proximity-based connections.
  static List<BeaconNode> proximityBasedPath(
    BeaconNode start,
    BeaconNode end,
    List<BeaconNode> floorNodes,
  ) {
    final sameFloorNodes = floorNodes.where((n) => n.floor == start.floor || n.floor == end.floor).toList();

    if (start.floor == end.floor) {
      final startFloorNodes = sameFloorNodes.where((n) => n.floor == start.floor).toList();
      return dijkstraProximity(start, end, startFloorNodes);
    }

    if (start.departmentId == 'stairs' || start.departmentId == 'elevator' ||
        end.departmentId == 'stairs' || end.departmentId == 'elevator') {
      return [start, end];
    }

    return [];
  }

  /// Dijkstra using proximity-based implicit connections.
  static List<BeaconNode> dijkstraProximity(
    BeaconNode start,
    BeaconNode end,
    List<BeaconNode> floorNodes,
  ) {
    if (floorNodes.isEmpty) return [];

    var nodes = List<BeaconNode>.from(floorNodes);
    if (!nodes.any((n) => n.uid == start.uid)) {
      nodes.add(start);
    }
    if (!nodes.any((n) => n.uid == end.uid)) {
      nodes.add(end);
    }

    final Map<String, double> distances = {};
    final Map<String, String?> previous = {};
    final Set<String> visited = {};
    final PriorityQueue<_NodeDistance> queue = PriorityQueue((a, b) => a.distance.compareTo(b.distance));

    for (final node in nodes) {
      distances[node.uid] = double.infinity;
      previous[node.uid] = null;
    }
    distances[start.uid] = 0;
    queue.add(_NodeDistance(start.uid, 0));

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();

      if (visited.contains(current.uid)) continue;
      visited.add(current.uid);

      if (current.uid == end.uid) break;

      final currentNode = nodes.firstWhereOrNull((n) => n.uid == current.uid);
      if (currentNode == null) continue;

      for (final neighbor in nodes) {
        if (visited.contains(neighbor.uid)) continue;
        if (neighbor.floor != currentNode.floor) continue;

        final distance = calculateDistance(currentNode, neighbor);
        final newDist = distances[current.uid]! + distance;

        if (newDist < (distances[neighbor.uid] ?? double.infinity)) {
          distances[neighbor.uid] = newDist;
          previous[neighbor.uid] = current.uid;
          queue.add(_NodeDistance(neighbor.uid, newDist));
        }
      }
    }

    return _reconstructPath(end.uid, start.uid, previous, nodes);
  }

  /// Calculate distance between two beacon nodes.
  static double calculateDistance(BeaconNode a, BeaconNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    double distance = sqrt(dx * dx + dy * dy);

    if (a.floor != b.floor) {
      distance += 100 * (a.floor - b.floor).abs();
    }

    return distance;
  }

  /// Calculate total distance of a path.
  static double calculateTotalDistance(List<BeaconNode> path) {
    double total = 0;
    for (int i = 0; i < path.length - 1; i++) {
      total += calculateDistance(path[i], path[i + 1]);
    }
    return total;
  }

  /// Log connection map for debugging.
  static void _logConnectionMap(Map<String, ConfigurableNode> configurableNodeMap) {
    debugPrint('🔗 === CONNECTION MAP ===');
    for (final node in configurableNodeMap.values) {
      if (node.connections.isNotEmpty) {
        for (final conn in node.connections) {
          final direction = conn.isBidirectional ? '↔' : '→';
          debugPrint('   ${node.name} (${node.id}) $direction ${conn.targetNodeId} [${conn.type.name}]');
        }
      }
    }
    debugPrint('🔗 === END CONNECTION MAP ===');
  }
}

/// Helper class for priority queue in Dijkstra algorithm.
class _NodeDistance {
  final String uid;
  final double distance;

  _NodeDistance(this.uid, this.distance);
}
