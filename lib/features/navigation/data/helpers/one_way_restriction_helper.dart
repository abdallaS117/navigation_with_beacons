import 'package:flutter/foundation.dart';
import '../../domain/entities/beacon_node.dart';
import '../../../configuration/domain/models/configurable_node.dart';

/// Helper class for checking one-way connection restrictions.
class OneWayRestrictionHelper {
  /// Check if the route from start to end is blocked by one-way restrictions.
  /// Returns a descriptive error message if blocked, null otherwise.
  static String? checkOneWayRestriction(
    BeaconNode start,
    BeaconNode end,
    Map<String, ConfigurableNode> configurableNodeMap,
  ) {
    debugPrint('🔍 Checking one-way restriction: ${start.name} (${start.uid}) → ${end.name} (${end.uid})');

    final startNode = configurableNodeMap[start.uid];
    final endNode = configurableNodeMap[end.uid];

    debugPrint('   Start node in config: ${startNode != null}');
    debugPrint('   End node in config: ${endNode != null}');

    if (startNode != null) {
      debugPrint('   Start node connections: ${startNode.connections.map((c) => "${c.targetNodeId} (bidir: ${c.isBidirectional})").join(", ")}');
    }
    if (endNode != null) {
      debugPrint('   End node connections: ${endNode.connections.map((c) => "${c.targetNodeId} (bidir: ${c.isBidirectional})").join(", ")}');
    }

    final canReachEndFromStart = _canReachNode(start.uid, end.uid, configurableNodeMap, <String>{});

    debugPrint('   Can reach end from start (any path): $canReachEndFromStart');

    if (!canReachEndFromStart) {
      final canReachStartFromEnd = _canReachNode(end.uid, start.uid, configurableNodeMap, <String>{});
      debugPrint('   Can reach start from end: $canReachStartFromEnd');

      if (canReachStartFromEnd) {
        debugPrint('   ❌ BLOCKED: Route exists only in reverse direction (one-way restriction)');
        return 'Cannot navigate to ${end.name} from your current location. The route is configured as one-way in the opposite direction.';
      }
    }

    debugPrint('   ✅ No one-way restriction found');
    return null;
  }

  /// Check if we can reach targetId from sourceId following connection directions.
  static bool _canReachNode(
    String sourceId,
    String targetId,
    Map<String, ConfigurableNode> configurableNodeMap,
    Set<String> visited,
  ) {
    if (sourceId == targetId) return true;
    if (visited.contains(sourceId)) return false;

    visited.add(sourceId);

    final sourceNode = configurableNodeMap[sourceId];
    if (sourceNode == null) return false;

    // Check direct outgoing connections
    for (final connection in sourceNode.connections) {
      if (_canReachNode(connection.targetNodeId, targetId, configurableNodeMap, visited)) {
        return true;
      }
    }

    // Check incoming bidirectional connections
    for (final node in configurableNodeMap.values) {
      for (final conn in node.connections) {
        if (conn.targetNodeId == sourceId && conn.isBidirectional) {
          if (_canReachNode(node.id, targetId, configurableNodeMap, visited)) {
            return true;
          }
        }
      }
    }

    return false;
  }
}
