import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/beacon_node.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/floor_map.dart';
import '../../domain/entities/navigation_route.dart';
import '../../domain/repositories/navigation_repository.dart';
import '../../../configuration/data/repositories/configuration_repository.dart';
import '../../../configuration/domain/models/configurable_node.dart';
import '../datasources/hybrid_beacon_datasource.dart';
import '../datasources/map_datasource.dart';

class NavigationRepositoryImpl implements NavigationRepository {
  final MapDataSource mapDataSource;
  final BeaconDataSource beaconDataSource;
  final ConfigurationRepository configurationRepository;

  NavigationRepositoryImpl({
    required this.mapDataSource,
    required this.beaconDataSource,
    required this.configurationRepository,
  });

  @override
  Future<NavigationRoute> calculateRoute(BeaconNode start, BeaconNode end) async {
    // Load configuration for nodes and pre-configured routes
    final config = await configurationRepository.getConfiguration();
    
    // Build a map of node IDs to BeaconNodes for quick lookup
    final nodeMap = <String, BeaconNode>{};
    final configurableNodeMap = <String, ConfigurableNode>{};
    for (final node in config.nodes) {
      configurableNodeMap[node.id] = node;
      nodeMap[node.id] = BeaconNode(
        uid: node.id,
        name: node.name,
        x: node.x,
        y: node.y,
        floor: node.floor,
        departmentId: node.type.name,
        connectedNodes: node.connections.map((c) => c.targetNodeId).toList(),
      );
    }
    
    debugPrint('🗺️ Route calculation: ${start.name} (${start.uid}) → ${end.name} (${end.uid})');
    debugPrint('🔢 Total configured nodes: ${nodeMap.length}');
    debugPrint('📋 Pre-configured routes: ${config.routes.length}');
    debugPrint('🔑 Available node IDs: ${nodeMap.keys.toList()}');
    debugPrint('🏢 Start floor: ${start.floor}, End floor: ${end.floor}');
    
    // Log all routes and their node IDs for debugging
    for (final route in config.routes) {
      debugPrint('📍 Route "${route.name}": ${route.nodeIds}');
      // Also show node names for this route
      final nodeNames = route.nodeIds.map((id) => nodeMap[id]?.name ?? 'UNKNOWN($id)').toList();
      debugPrint('   Node names: $nodeNames');
    }
    
    // Ensure start and end nodes are in the nodeMap
    if (!nodeMap.containsKey(start.uid)) {
      nodeMap[start.uid] = start;
      debugPrint('📌 Added start node to nodeMap: ${start.uid}');
    }
    if (!nodeMap.containsKey(end.uid)) {
      nodeMap[end.uid] = end;
      debugPrint('📌 Added end node to nodeMap: ${end.uid}');
    }
    
    // ============================================
    // FIRST: Try to find a pre-configured route (works for both same-floor and multi-floor)
    // ============================================
    
    // Check 1: Find a route that contains both start and end nodes
    for (final route in config.routes) {
      final nodeIds = route.nodeIds;
      final startIndex = nodeIds.indexOf(start.uid);
      final endIndex = nodeIds.indexOf(end.uid);
      
      debugPrint('🔍 Checking route "${route.name}" for both nodes: start="${start.uid}", end="${end.uid}"');
      debugPrint('   Route nodeIds: $nodeIds');
      debugPrint('   Start index: $startIndex, End index: $endIndex');
      
      if (startIndex != -1 && endIndex != -1) {
        // Both nodes are in this route - extract the path between them
        // IMPORTANT: Only use forward direction (startIndex < endIndex)
        // Reverse direction requires checking if all connections are bidirectional
        List<String> pathNodeIds;
        bool isValidPath = true;
        
        if (startIndex < endIndex) {
          // Forward direction - always valid for routes
          pathNodeIds = nodeIds.sublist(startIndex, endIndex + 1);
        } else {
          // Reverse direction - need to check if all connections allow reverse traversal
          pathNodeIds = nodeIds.sublist(endIndex, startIndex + 1).reversed.toList();
          
          // Validate that we can traverse in reverse (all connections must be bidirectional)
          for (int i = 0; i < pathNodeIds.length - 1; i++) {
            final fromId = pathNodeIds[i];
            final toId = pathNodeIds[i + 1];
            final fromNode = configurableNodeMap[fromId];
            
            // Check if there's a valid connection from fromId to toId
            final hasDirectConnection = fromNode?.connections.any((c) => c.targetNodeId == toId) ?? false;
            final hasIncomingBidirectional = configurableNodeMap[toId]?.connections
                .any((c) => c.targetNodeId == fromId && c.isBidirectional) ?? false;
            
            if (!hasDirectConnection && !hasIncomingBidirectional) {
              debugPrint('   ❌ Cannot traverse reverse: $fromId → $toId (one-way in opposite direction)');
              isValidPath = false;
              break;
            }
          }
        }
        
        if (!isValidPath) {
          debugPrint('   ⚠️ Route "${route.name}" cannot be used in reverse direction');
          continue; // Try next route
        }
        
        final path = pathNodeIds
            .map((id) => nodeMap[id])
            .where((node) => node != null)
            .cast<BeaconNode>()
            .toList();
        
        if (path.length == pathNodeIds.length) {
          debugPrint('✅ Using pre-configured route "${route.name}": ${path.map((n) => "${n.name}(F${n.floor})").join(' → ')}');
          
          final distance = _calculateTotalDistance(path);
          final timeSeconds = (distance / 50 * 60).round();
          final instructions = _generateInstructions(path);
          
          return NavigationRoute(
            nodes: path,
            totalDistance: distance,
            estimatedTimeSeconds: timeSeconds,
            instructions: instructions,
          );
        }
      }
    }
    
    // Check 2: Find a route where destination is the LAST node
    for (final route in config.routes) {
      final nodeIds = route.nodeIds;
      if (nodeIds.isNotEmpty && nodeIds.last == end.uid) {
        final path = nodeIds
            .map((id) => nodeMap[id])
            .where((node) => node != null)
            .cast<BeaconNode>()
            .toList();
        
        if (path.isNotEmpty) {
          debugPrint('✅ Using full route "${route.name}" to destination: ${path.map((n) => "${n.name}(F${n.floor})").join(' → ')}');
          
          final distance = _calculateTotalDistance(path);
          final timeSeconds = (distance / 50 * 60).round();
          final instructions = _generateInstructions(path);
          
          return NavigationRoute(
            nodes: path,
            totalDistance: distance,
            estimatedTimeSeconds: timeSeconds,
            instructions: instructions,
          );
        }
      }
    }
    
    // Check 3: Find any route containing the destination
    for (final route in config.routes) {
      final nodeIds = route.nodeIds;
      final endIndex = nodeIds.indexOf(end.uid);
      
      if (endIndex != -1 && nodeIds.isNotEmpty) {
        final pathNodeIds = nodeIds.sublist(0, endIndex + 1);
        final path = pathNodeIds
            .map((id) => nodeMap[id])
            .where((node) => node != null)
            .cast<BeaconNode>()
            .toList();
        
        if (path.isNotEmpty) {
          debugPrint('✅ Using route "${route.name}" (partial): ${path.map((n) => "${n.name}(F${n.floor})").join(' → ')}');
          
          final distance = _calculateTotalDistance(path);
          final timeSeconds = (distance / 50 * 60).round();
          final instructions = _generateInstructions(path);
          
          return NavigationRoute(
            nodes: path,
            totalDistance: distance,
            estimatedTimeSeconds: timeSeconds,
            instructions: instructions,
          );
        }
      }
    }
    
    debugPrint('⚠️ No pre-configured route found, trying dynamic pathfinding...');
    
    // ============================================
    // SECOND: Dynamic pathfinding (if no pre-configured route)
    // ============================================
    
    // Check if navigation requires floor change
    final requiresFloorChange = start.floor != end.floor;
    
    if (requiresFloorChange) {
      debugPrint('🔄 Multi-floor navigation required: Floor ${start.floor} → Floor ${end.floor}');
      
      // Find all stair/elevator transition points
      final transitionPoints = _findFloorTransitionPoints(config.nodes, start.floor, end.floor);
      
      if (transitionPoints.isEmpty) {
        debugPrint('❌ No stair or elevator points found to connect Floor ${start.floor} to Floor ${end.floor}');
        return const NavigationRoute(
          nodes: [],
          totalDistance: 0,
          estimatedTimeSeconds: 0,
          instructions: ['No route found - no stairs or elevator connecting these floors'],
        );
      }
      
      debugPrint('🚶 Found ${transitionPoints.length} transition point(s): ${transitionPoints.map((t) => '${t['startNode']!.name} (Floor ${t['startNode']!.floor})').join(', ')}');
      
      // Ensure transition nodes are in nodeMap
      for (final transition in transitionPoints) {
        final startTrans = transition['startNode']!;
        final endTrans = transition['endNode']!;
        if (!nodeMap.containsKey(startTrans.uid)) {
          nodeMap[startTrans.uid] = startTrans;
        }
        if (!nodeMap.containsKey(endTrans.uid)) {
          nodeMap[endTrans.uid] = endTrans;
        }
      }
      
      // Calculate route through each transition point and find the shortest
      NavigationRoute? bestRoute;
      double bestDistance = double.infinity;
      
      final allNodes = nodeMap.values.toList();
      
      for (final transition in transitionPoints) {
        final startTransition = transition['startNode']!;
        final endTransition = transition['endNode']!;
        
        debugPrint('🔍 Trying transition through: ${startTransition.name} (F${startTransition.floor}) → ${endTransition.name} (F${endTransition.floor})');
        
        // Calculate path: start → transition point (start floor)
        // Use proximity-based pathfinding for same-floor navigation
        final pathToTransition = _findPathOnFloor(start, startTransition, allNodes, configurableNodeMap);
        
        if (pathToTransition.isEmpty) {
          debugPrint('   ❌ No path from start to transition point on floor ${start.floor}');
          continue;
        }
        
        debugPrint('   ✓ Path to transition: ${pathToTransition.map((n) => n.name).join(' → ')}');
        
        // Calculate path: transition point (end floor) → end
        final pathFromTransition = _findPathOnFloor(endTransition, end, allNodes, configurableNodeMap);
        
        if (pathFromTransition.isEmpty) {
          debugPrint('   ❌ No path from transition point to destination on floor ${end.floor}');
          continue;
        }
        
        debugPrint('   ✓ Path from transition: ${pathFromTransition.map((n) => n.name).join(' → ')}');
        
        // Combine paths: path to stair + stair transition + path from stair
        final combinedPath = [
          ...pathToTransition,
          if (pathFromTransition.isNotEmpty && pathFromTransition.first.uid != pathToTransition.last.uid)
            ...pathFromTransition
          else
            ...pathFromTransition.skip(1)
        ];
        
        final totalDistance = _calculateTotalDistance(combinedPath);
        
        debugPrint('   ✓ Combined path found with distance: $totalDistance');
        
        if (totalDistance < bestDistance) {
          bestDistance = totalDistance;
          final timeSeconds = (totalDistance / 50 * 60).round();
          final instructions = _generateInstructions(combinedPath);
          bestRoute = NavigationRoute(
            nodes: combinedPath,
            totalDistance: totalDistance,
            estimatedTimeSeconds: timeSeconds,
            instructions: instructions,
          );
        }
      }
      
      if (bestRoute != null) {
        debugPrint('✅ Multi-floor route found: ${bestRoute.nodes.map((n) => '${n.name}(F${n.floor})').join(' → ')}');
        return bestRoute;
      }
      
      debugPrint('❌ No valid multi-floor route found');
      return const NavigationRoute(
        nodes: [],
        totalDistance: 0,
        estimatedTimeSeconds: 0,
        instructions: ['No route allowed for this destination. Cannot reach through available stairs/elevators.'],
      );
    }
    
    // SAME FLOOR NAVIGATION - Use Dijkstra algorithm
    debugPrint('⚠️ Same floor navigation, using Dijkstra algorithm');
    
    // Find the actual start and end nodes in the configuration
    // The start/end BeaconNodes might have UIDs that don't match configurableNodeMap keys
    BeaconNode actualStart = start;
    BeaconNode actualEnd = end;
    
    // Try to find matching nodes by position or name if UID doesn't match
    if (!configurableNodeMap.containsKey(start.uid)) {
      debugPrint('⚠️ Start node ${start.uid} not in configurableNodeMap, searching by name/position...');
      for (final entry in configurableNodeMap.entries) {
        if (entry.value.name == start.name || 
            (entry.value.x == start.x && entry.value.y == start.y && entry.value.floor == start.floor)) {
          actualStart = nodeMap[entry.key] ?? start;
          debugPrint('   Found matching start node: ${entry.key}');
          break;
        }
      }
    }
    
    if (!configurableNodeMap.containsKey(end.uid)) {
      debugPrint('⚠️ End node ${end.uid} not in configurableNodeMap, searching by name/position...');
      for (final entry in configurableNodeMap.entries) {
        if (entry.value.name == end.name || 
            (entry.value.x == end.x && entry.value.y == end.y && entry.value.floor == end.floor)) {
          actualEnd = nodeMap[entry.key] ?? end;
          debugPrint('   Found matching end node: ${entry.key}');
          break;
        }
      }
    }
    
    // FIRST: Check if this is a direct one-way restriction BEFORE running Dijkstra
    // This catches cases where the user is trying to go against a one-way connection
    final oneWayBlockReason = _checkOneWayRestriction(actualStart, actualEnd, configurableNodeMap);
    if (oneWayBlockReason != null) {
      debugPrint('🚫 One-way restriction detected BEFORE pathfinding: $oneWayBlockReason');
      return NavigationRoute(
        nodes: const [],
        totalDistance: 0,
        estimatedTimeSeconds: 0,
        instructions: [oneWayBlockReason],
      );
    }
    
    // Use Dijkstra algorithm with node connections
    final allBeacons = nodeMap.values.toList();
    final path = _dijkstraWithConfig(actualStart, actualEnd, allBeacons, configurableNodeMap);
    
    if (path.isEmpty) {
      debugPrint('❌ No route found from ${actualStart.name} to ${actualEnd.name}');
      
      return const NavigationRoute(
        nodes: [],
        totalDistance: 0,
        estimatedTimeSeconds: 0,
        instructions: ['No route allowed for this destination. Please configure a route first.'],
      );
    }
    
    debugPrint('✅ Dijkstra route found: ${path.map((n) => n.name).join(' → ')}');

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

  /// Find floor transition points (stairs/elevators) that connect two floors.
  /// Returns a list of maps containing paired nodes on each floor.
  List<Map<String, BeaconNode>> _findFloorTransitionPoints(
    List<ConfigurableNode> nodes,
    int fromFloor,
    int toFloor,
  ) {
    final transitionPoints = <Map<String, BeaconNode>>[];
    
    // Find all stair and elevator nodes by type OR by name
    final stairAndElevatorNodes = nodes.where((node) {
      // Check by NodeType
      if (node.type == NodeType.stairs || node.type == NodeType.elevator) {
        return true;
      }
      // Also check by name (case-insensitive) for flexibility
      final nameLower = node.name.toLowerCase();
      return nameLower.contains('stair') || 
             nameLower.contains('elevator') || 
             nameLower.contains('lift') ||
             nameLower.contains('escalator');
    }).toList();
    
    debugPrint('🔍 Searching for transition points among ${stairAndElevatorNodes.length} stair/elevator nodes');
    debugPrint('   All nodes on fromFloor ($fromFloor): ${nodes.where((n) => n.floor == fromFloor).map((n) => "${n.name}(${n.type.name})").join(", ")}');
    debugPrint('   All nodes on toFloor ($toFloor): ${nodes.where((n) => n.floor == toFloor).map((n) => "${n.name}(${n.type.name})").join(", ")}');
    
    // Group transition nodes by their base name (e.g., "Main Stairs" on different floors)
    final groupedByName = <String, List<ConfigurableNode>>{};
    for (final node in stairAndElevatorNodes) {
      // Extract base name (remove floor indicators if any)
      final baseName = _extractBaseName(node.name);
      groupedByName.putIfAbsent(baseName, () => []).add(node);
    }
    
    // For each group, find nodes that can connect fromFloor and toFloor
    for (final entry in groupedByName.entries) {
      final group = entry.value;
      
      // Find node on fromFloor
      final startFloorNode = group.firstWhereOrNull((n) => n.floor == fromFloor);
      // Find node on toFloor
      final endFloorNode = group.firstWhereOrNull((n) => n.floor == toFloor);
      
      if (startFloorNode != null && endFloorNode != null) {
        transitionPoints.add({
          'startNode': BeaconNode(
            uid: startFloorNode.id,
            name: startFloorNode.name,
            x: startFloorNode.x,
            y: startFloorNode.y,
            floor: startFloorNode.floor,
            departmentId: startFloorNode.type.name,
            connectedNodes: startFloorNode.connections.map((c) => c.targetNodeId).toList(),
          ),
          'endNode': BeaconNode(
            uid: endFloorNode.id,
            name: endFloorNode.name,
            x: endFloorNode.x,
            y: endFloorNode.y,
            floor: endFloorNode.floor,
            departmentId: endFloorNode.type.name,
            connectedNodes: endFloorNode.connections.map((c) => c.targetNodeId).toList(),
          ),
        });
        debugPrint('   Found transition pair: ${startFloorNode.name} (F${startFloorNode.floor}) ↔ ${endFloorNode.name} (F${endFloorNode.floor})');
      }
    }
    
    // Also check for direct connections between floors via connections
    for (final node in stairAndElevatorNodes) {
      if (node.floor == fromFloor) {
        for (final connection in node.connections) {
          if (connection.type == ConnectionType.stairs || connection.type == ConnectionType.elevator) {
            final targetNode = nodes.firstWhereOrNull((n) => n.id == connection.targetNodeId);
            if (targetNode != null && targetNode.floor == toFloor) {
              // Check if we already have this pair
              final alreadyExists = transitionPoints.any((t) =>
                t['startNode']!.uid == node.id && t['endNode']!.uid == targetNode.id);
              
              if (!alreadyExists) {
                transitionPoints.add({
                  'startNode': BeaconNode(
                    uid: node.id,
                    name: node.name,
                    x: node.x,
                    y: node.y,
                    floor: node.floor,
                    departmentId: node.type.name,
                    connectedNodes: node.connections.map((c) => c.targetNodeId).toList(),
                  ),
                  'endNode': BeaconNode(
                    uid: targetNode.id,
                    name: targetNode.name,
                    x: targetNode.x,
                    y: targetNode.y,
                    floor: targetNode.floor,
                    departmentId: targetNode.type.name,
                    connectedNodes: targetNode.connections.map((c) => c.targetNodeId).toList(),
                  ),
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

  /// Extract base name from a node name (removes floor indicators)
  String _extractBaseName(String name) {
    // Remove common floor indicators like "Floor 1", "F1", "(1)", etc.
    return name
        .replaceAll(RegExp(r'\s*[Ff]loor\s*\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[Ff]\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(\d+\)'), '')
        .replaceAll(RegExp(r'\s*-\s*\d+$'), '')
        .trim();
  }

  /// Enhanced Dijkstra that uses ConfigurableNode connections
  List<BeaconNode> _dijkstraWithConfig(
    BeaconNode start,
    BeaconNode end,
    List<BeaconNode> allBeacons,
    Map<String, ConfigurableNode> configurableNodeMap,
  ) {
    // Debug: Log all connections in the configuration
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

      // Get connections from configurable node for more detailed routing
      final configurableNode = configurableNodeMap[current.uid];
      debugPrint('🔍 Processing node: ${configurableNode?.name ?? current.uid}');
      
      // Build list of valid neighbors we can traverse TO from current node
      final validNeighborIds = <String>{};
      
      // 1. Direct outgoing connections from this node (we can always follow our own outgoing connections)
      final directConnections = configurableNode?.connections ?? [];
      for (final conn in directConnections) {
        validNeighborIds.add(conn.targetNodeId);
        debugPrint('   → Direct outgoing: ${current.uid} → ${conn.targetNodeId} (bidirectional: ${conn.isBidirectional})');
      }
      
      // 2. Incoming bidirectional connections from other nodes
      // If another node has a BIDIRECTIONAL connection pointing to us, we can traverse back to them
      for (final otherNode in configurableNodeMap.values) {
        if (otherNode.id == current.uid) continue;
        for (final conn in otherNode.connections) {
          if (conn.targetNodeId == current.uid && conn.isBidirectional) {
            validNeighborIds.add(otherNode.id);
            debugPrint('   ← Incoming bidirectional: ${otherNode.id} ↔ ${current.uid}');
          }
        }
      }

      for (final neighborUid in validNeighborIds) {
        if (visited.contains(neighborUid)) continue;

        final neighbor = allBeacons.firstWhereOrNull((b) => b.uid == neighborUid);
        if (neighbor == null) continue;

        // Check if this is a valid same-floor or allowed floor-transition connection
        if (currentNode.floor != neighbor.floor) {
          // Only allow floor transitions through stairs/elevator connections
          final connection = configurableNode?.connections.firstWhereOrNull((c) => c.targetNodeId == neighborUid);
          final isValidTransition = connection?.type == ConnectionType.stairs || 
                                    connection?.type == ConnectionType.elevator ||
                                    currentNode.departmentId == 'stairs' ||
                                    currentNode.departmentId == 'elevator';
          if (!isValidTransition) continue;
        }

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

  /// Find path between two nodes on the same floor.
  /// Uses Dijkstra if connections exist, otherwise falls back to proximity-based routing.
  List<BeaconNode> _findPathOnFloor(
    BeaconNode start,
    BeaconNode end,
    List<BeaconNode> allNodes,
    Map<String, ConfigurableNode> configurableNodeMap,
  ) {
    // If start and end are the same, return just that node
    if (start.uid == end.uid) {
      return [start];
    }

    // Filter nodes to only those on the relevant floors (start or end floor)
    final relevantFloors = {start.floor, end.floor};
    final floorNodes = allNodes.where((n) => relevantFloors.contains(n.floor)).toList();
    
    // Ensure start and end are in the list
    if (!floorNodes.any((n) => n.uid == start.uid)) {
      floorNodes.add(start);
    }
    if (!floorNodes.any((n) => n.uid == end.uid)) {
      floorNodes.add(end);
    }

    // First try Dijkstra with existing connections
    final dijkstraPath = _dijkstraWithConfig(start, end, floorNodes, configurableNodeMap);
    if (dijkstraPath.isNotEmpty) {
      return dijkstraPath;
    }

    debugPrint('   ⚠️ Dijkstra failed, trying proximity-based routing');

    // Fallback: proximity-based pathfinding for nodes without explicit connections
    // This creates implicit connections based on distance for same-floor nodes
    return _proximityBasedPath(start, end, floorNodes);
  }

  /// Find path using proximity-based connections (for nodes without explicit connections)
  List<BeaconNode> _proximityBasedPath(
    BeaconNode start,
    BeaconNode end,
    List<BeaconNode> floorNodes,
  ) {
    // Only consider nodes on the same floor as start or end
    final sameFloorNodes = floorNodes.where((n) => n.floor == start.floor || n.floor == end.floor).toList();
    
    // If same floor, find path using proximity
    if (start.floor == end.floor) {
      final startFloorNodes = sameFloorNodes.where((n) => n.floor == start.floor).toList();
      return _dijkstraProximity(start, end, startFloorNodes);
    }
    
    // Different floors - this shouldn't happen in _findPathOnFloor, but handle it
    // by returning direct path if nodes are transition points
    if (start.departmentId == 'stairs' || start.departmentId == 'elevator' ||
        end.departmentId == 'stairs' || end.departmentId == 'elevator') {
      return [start, end];
    }
    
    return [];
  }

  /// Dijkstra using proximity-based implicit connections (all nodes on same floor connect)
  List<BeaconNode> _dijkstraProximity(
    BeaconNode start,
    BeaconNode end,
    List<BeaconNode> floorNodes,
  ) {
    if (floorNodes.isEmpty) return [];
    
    // Ensure start and end are in the list
    if (!floorNodes.any((n) => n.uid == start.uid)) {
      floorNodes = [...floorNodes, start];
    }
    if (!floorNodes.any((n) => n.uid == end.uid)) {
      floorNodes = [...floorNodes, end];
    }

    final Map<String, double> distances = {};
    final Map<String, String?> previous = {};
    final Set<String> visited = {};
    final PriorityQueue<_NodeDistance> queue = PriorityQueue((a, b) => a.distance.compareTo(b.distance));

    // Initialize
    for (final node in floorNodes) {
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

      final currentNode = floorNodes.firstWhereOrNull((n) => n.uid == current.uid);
      if (currentNode == null) continue;

      // Connect to ALL other nodes on the same floor (proximity-based)
      for (final neighbor in floorNodes) {
        if (visited.contains(neighbor.uid)) continue;
        if (neighbor.floor != currentNode.floor) continue;

        final distance = _calculateDistance(currentNode, neighbor);
        final newDist = distances[current.uid]! + distance;

        if (newDist < (distances[neighbor.uid] ?? double.infinity)) {
          distances[neighbor.uid] = newDist;
          previous[neighbor.uid] = current.uid;
          queue.add(_NodeDistance(neighbor.uid, newDist));
        }
      }
    }

    // Reconstruct path
    final List<BeaconNode> path = [];
    String? currentUid = end.uid;

    while (currentUid != null) {
      final node = floorNodes.firstWhereOrNull((n) => n.uid == currentUid);
      if (node != null) {
        path.insert(0, node);
      }
      currentUid = previous[currentUid];
    }

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
    try {
      // Load departments from configured nodes
      final config = await configurationRepository.getConfiguration();
      final departmentNodes = config.nodes.where((node) => node.type == NodeType.department).toList();
      
      // Convert department nodes to Department entities
      return departmentNodes.map((node) {
        return Department(
          id: node.id,
          name: node.name,
          floor: node.floor,
          color: Colors.blue, // Default color for configured departments
          bounds: Rect.fromCenter(
            center: Offset(node.x, node.y),
            width: 80,
            height: 80,
          ),
          description: node.metadata['description'] as String?,
          icon: Icons.business,
        );
      }).toList();
    } catch (e) {
      // Fallback to hardcoded departments if configuration fails
      return mapDataSource.getAllDepartments();
    }
  }

  @override
  Future<Department?> getDepartmentById(String id) async {
    try {
      final config = await configurationRepository.getConfiguration();
      final node = config.nodes.firstWhereOrNull((n) => n.id == id && n.type == NodeType.department);
      
      if (node != null) {
        return Department(
          id: node.id,
          name: node.name,
          floor: node.floor,
          color: Colors.blue,
          bounds: Rect.fromCenter(
            center: Offset(node.x, node.y),
            width: 80,
            height: 80,
          ),
          description: node.metadata['description'] as String?,
          icon: Icons.business,
        );
      }
      return null;
    } catch (e) {
      return mapDataSource.getDepartmentById(id);
    }
  }

  @override
  Future<BeaconNode?> getBeaconForDepartment(String departmentId) async {
    try {
      // Load configuration to find the department node
      final config = await configurationRepository.getConfiguration();
      
      // Find the department node by ID
      final departmentNode = config.nodes.firstWhereOrNull(
        (node) => node.id == departmentId && node.type == NodeType.department,
      );
      
      if (departmentNode != null) {
        // Return the department node as a BeaconNode (it's the destination)
        return BeaconNode(
          uid: departmentNode.id,
          name: departmentNode.name,
          x: departmentNode.x,
          y: departmentNode.y,
          floor: departmentNode.floor,
          departmentId: departmentNode.id,
          connectedNodes: departmentNode.connections.map((c) => c.targetNodeId).toList(),
        );
      }
      
      // Fallback: try to find any beacon with matching departmentId
      final beacons = beaconDataSource.getAllBeacons();
      return beacons.firstWhereOrNull((b) => b.departmentId == departmentId);
    } catch (e) {
      // Fallback to beacon lookup
      final beacons = beaconDataSource.getAllBeacons();
      return beacons.firstWhereOrNull((b) => b.departmentId == departmentId);
    }
  }
}

class _NodeDistance {
  final String uid;
  final double distance;

  _NodeDistance(this.uid, this.distance);
}

extension _OneWayRestrictionCheck on NavigationRepositoryImpl {
  /// Check if the route from start to end is blocked by one-way restrictions.
  /// Returns a descriptive error message if blocked, null otherwise.
  String? _checkOneWayRestriction(
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
    
    // Check if there's a direct one-way connection from end to start (reverse direction)
    if (endNode != null) {
      for (final connection in endNode.connections) {
        if (connection.targetNodeId == start.uid && !connection.isBidirectional) {
          // There's a one-way connection from end → start, but user wants start → end
          debugPrint('   ❌ BLOCKED: Direct one-way from end to start');
          return 'Cannot navigate this direction. This is a one-way route from ${end.name} to ${start.name}.';
        }
      }
    }
    
    // Check if start has no outgoing connections to end, but end has to start
    if (startNode != null && endNode != null) {
      final startHasConnectionToEnd = startNode.connections.any((c) => c.targetNodeId == end.uid);
      final endHasConnectionToStart = endNode.connections.any((c) => c.targetNodeId == start.uid);
      
      debugPrint('   Start has connection to end: $startHasConnectionToEnd');
      debugPrint('   End has connection to start: $endHasConnectionToStart');
      
      if (!startHasConnectionToEnd && endHasConnectionToStart) {
        final connection = endNode.connections.firstWhere((c) => c.targetNodeId == start.uid);
        if (!connection.isBidirectional) {
          debugPrint('   ❌ BLOCKED: One-way only from end to start');
          return 'This route is one-way only. You can only travel from ${end.name} to ${start.name}, not the reverse.';
        }
      }
    }
    
    // Check for indirect one-way blocking (path exists in reverse but not forward)
    // by checking if we can reach start from end but not end from start
    final canReachStartFromEnd = _canReachNode(end.uid, start.uid, configurableNodeMap, <String>{});
    final canReachEndFromStart = _canReachNode(start.uid, end.uid, configurableNodeMap, <String>{});
    
    debugPrint('   Can reach start from end: $canReachStartFromEnd');
    debugPrint('   Can reach end from start: $canReachEndFromStart');
    
    if (canReachStartFromEnd && !canReachEndFromStart) {
      debugPrint('   ❌ BLOCKED: Indirect one-way restriction');
      return 'Cannot navigate to ${end.name} from your current location. The route is configured as one-way in the opposite direction.';
    }
    
    debugPrint('   ✅ No one-way restriction found');
    return null;
  }
  
  /// Check if we can reach targetId from sourceId following connection directions
  bool _canReachNode(
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
    
    // Check incoming bidirectional connections (can traverse back)
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
