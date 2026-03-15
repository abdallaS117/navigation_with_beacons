import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/beacon_node.dart';
import '../../../configuration/domain/models/configurable_node.dart';

/// Helper class for floor transition logic in multi-floor navigation.
class FloorTransitionHelper {
  /// Find floor transition points (stairs/elevators) that connect two floors.
  static List<Map<String, BeaconNode>> findFloorTransitionPoints(
    List<ConfigurableNode> nodes,
    int fromFloor,
    int toFloor,
  ) {
    final transitionPoints = <Map<String, BeaconNode>>[];

    final stairAndElevatorNodes = nodes.where((node) {
      if (node.type == NodeType.stairs || node.type == NodeType.elevator) {
        return true;
      }
      final nameLower = node.name.toLowerCase();
      return nameLower.contains('stair') ||
          nameLower.contains('elevator') ||
          nameLower.contains('lift') ||
          nameLower.contains('escalator');
    }).toList();

    debugPrint('🔍 Searching for transition points among ${stairAndElevatorNodes.length} stair/elevator nodes');
    debugPrint('   All nodes on fromFloor ($fromFloor): ${nodes.where((n) => n.floor == fromFloor).map((n) => "${n.name}(${n.type.name})").join(", ")}');
    debugPrint('   All nodes on toFloor ($toFloor): ${nodes.where((n) => n.floor == toFloor).map((n) => "${n.name}(${n.type.name})").join(", ")}');

    // Group transition nodes by their base name
    final groupedByName = <String, List<ConfigurableNode>>{};
    for (final node in stairAndElevatorNodes) {
      final baseName = _extractBaseName(node.name);
      groupedByName.putIfAbsent(baseName, () => []).add(node);
    }

    // Find nodes that can connect fromFloor and toFloor
    for (final entry in groupedByName.entries) {
      final group = entry.value;

      final startFloorNode = group.firstWhereOrNull((n) => n.floor == fromFloor);
      final endFloorNode = group.firstWhereOrNull((n) => n.floor == toFloor);

      if (startFloorNode != null && endFloorNode != null) {
        transitionPoints.add({
          'startNode': _nodeToBeaconNode(startFloorNode),
          'endNode': _nodeToBeaconNode(endFloorNode),
        });
        debugPrint('   Found transition pair: ${startFloorNode.name} (F${startFloorNode.floor}) ↔ ${endFloorNode.name} (F${endFloorNode.floor})');
      }
    }

    // Check for direct connections between floors
    for (final node in stairAndElevatorNodes) {
      if (node.floor == fromFloor) {
        for (final connection in node.connections) {
          if (connection.type == ConnectionType.stairs || connection.type == ConnectionType.elevator) {
            final targetNode = nodes.firstWhereOrNull((n) => n.id == connection.targetNodeId);
            if (targetNode != null && targetNode.floor == toFloor) {
              final alreadyExists = transitionPoints.any((t) =>
                  t['startNode']!.uid == node.id && t['endNode']!.uid == targetNode.id);

              if (!alreadyExists) {
                transitionPoints.add({
                  'startNode': _nodeToBeaconNode(node),
                  'endNode': _nodeToBeaconNode(targetNode),
                });
                debugPrint('   Found connected transition: ${node.name} (F${node.floor}) → ${targetNode.name} (F${targetNode.floor})');
              }
            }
          }
        }
      }
    }

    return transitionPoints;
  }

  /// Extract base name from a node name (removes floor indicators).
  static String _extractBaseName(String name) {
    return name
        .replaceAll(RegExp(r'\s*[Ff]loor\s*\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[Ff]\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(\d+\)'), '')
        .replaceAll(RegExp(r'\s*-\s*\d+$'), '')
        .trim();
  }

  /// Convert ConfigurableNode to BeaconNode.
  static BeaconNode _nodeToBeaconNode(ConfigurableNode node) {
    return BeaconNode(
      uid: node.id,
      name: node.name,
      x: node.x,
      y: node.y,
      floor: node.floor,
      departmentId: node.type.name,
      connectedNodes: node.connections.map((c) => c.targetNodeId).toList(),
    );
  }
}
