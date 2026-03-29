import 'package:flutter/foundation.dart';
import '../../domain/entities/beacon_node.dart';
import '../../../configuration/domain/models/configurable_node.dart';

/// Helper class for validating one-way connection restrictions.
/// 
/// One-way connections allow travel in only one direction. This helper
/// checks if a route is blocked by such restrictions and provides
/// user-friendly error messages.
/// 
/// ## How It Works
/// 
/// 1. Attempts to find ANY path from start to end following connection rules
/// 2. If no path exists, checks if a path exists in REVERSE direction
/// 3. If reverse path exists, the route is blocked by one-way restriction
/// 
/// ## Example
/// 
/// ```dart
/// final error = OneWayRestrictionHelper.checkOneWayRestriction(
///   startNode, endNode, configurableNodeMap,
/// );
/// if (error != null) {
///   showDialog(message: error); // "Route is one-way in opposite direction"
/// }
/// ```
class OneWayRestrictionHelper {
  /// Checks if navigation from [start] to [end] is blocked by one-way restrictions.
  /// 
  /// Returns:
  /// - `null` if navigation is allowed
  /// - Error message string if blocked by one-way restriction
  /// 
  /// The error message is user-friendly and can be displayed directly.
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

  /// Recursively checks if [targetId] is reachable from [sourceId].
  /// 
  /// Follows connection direction rules:
  /// - Direct outgoing connections are always traversable
  /// - Incoming connections are only traversable if bidirectional
  /// 
  /// Uses [visited] set to prevent infinite loops in cyclic graphs.
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

    // Check direct outgoing connections (skip blocked)
    for (final connection in sourceNode.connections) {
      if (connection.type == ConnectionType.blocked) continue;
      if (_canReachNode(connection.targetNodeId, targetId, configurableNodeMap, visited)) {
        return true;
      }
    }

    // Check incoming bidirectional connections (skip blocked)
    for (final node in configurableNodeMap.values) {
      for (final conn in node.connections) {
        if (conn.type == ConnectionType.blocked) continue;
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
