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
import '../helpers/pathfinding_helper.dart';
import '../helpers/floor_transition_helper.dart';
import '../helpers/instruction_generator.dart';
import '../helpers/one_way_restriction_helper.dart';

/// Implementation of NavigationRepository with route calculation capabilities.
/// 
/// Refactored to use helper classes:
/// - [PathfindingHelper] for Dijkstra and proximity-based pathfinding
/// - [FloorTransitionHelper] for multi-floor navigation
/// - [InstructionGenerator] for navigation instructions
/// - [OneWayRestrictionHelper] for one-way connection validation
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
    final config = await configurationRepository.getConfiguration();

    // Build node maps for quick lookup
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

    _logRouteCalculationStart(start, end, nodeMap, config);

    // Ensure start and end nodes are in the nodeMap
    if (!nodeMap.containsKey(start.uid)) {
      nodeMap[start.uid] = start;
      debugPrint('📌 Added start node to nodeMap: ${start.uid}');
    }
    if (!nodeMap.containsKey(end.uid)) {
      nodeMap[end.uid] = end;
      debugPrint('📌 Added end node to nodeMap: ${end.uid}');
    }

    // Calculate routes using both methods and choose the shortest
    final requiresFloorChange = start.floor != end.floor;

    // Get Dijkstra's shortest path first
    NavigationRoute? dijkstraRoute;
    if (requiresFloorChange) {
      dijkstraRoute = await _calculateMultiFloorRoute(start, end, config, nodeMap, configurableNodeMap);
    } else {
      dijkstraRoute = _calculateSameFloorRoute(start, end, nodeMap, configurableNodeMap);
    }

    // Get pre-configured route if available
    final preConfiguredRoute = _tryPreConfiguredRoutes(start, end, config, nodeMap, configurableNodeMap);

    // Choose the shorter route
    if (preConfiguredRoute != null && dijkstraRoute.nodes.isNotEmpty) {
      debugPrint('📏 Comparing routes:');
      debugPrint('   Pre-configured: ${preConfiguredRoute.totalDistance} (${preConfiguredRoute.nodes.length} nodes)');
      debugPrint('   Dijkstra: ${dijkstraRoute.totalDistance} (${dijkstraRoute.nodes.length} nodes)');
      
      if (preConfiguredRoute.totalDistance <= dijkstraRoute.totalDistance) {
        debugPrint('✅ Using pre-configured route (shorter or equal)');
        return preConfiguredRoute;
      } else {
        debugPrint('✅ Using Dijkstra route (shorter)');
        return dijkstraRoute;
      }
    } else if (preConfiguredRoute != null) {
      debugPrint('✅ Using pre-configured route (no Dijkstra path found)');
      return preConfiguredRoute;
    } else if (dijkstraRoute.nodes.isNotEmpty) {
      debugPrint('✅ Using Dijkstra route (no pre-configured route found)');
      return dijkstraRoute;
    }

    return const NavigationRoute(
      nodes: [],
      totalDistance: 0,
      estimatedTimeSeconds: 0,
      instructions: ['No route found.'],
    );
  }

  /// Try to find a pre-configured route containing both start and end nodes.
  NavigationRoute? _tryPreConfiguredRoutes(
    BeaconNode start,
    BeaconNode end,
    dynamic config,
    Map<String, BeaconNode> nodeMap,
    Map<String, ConfigurableNode> configurableNodeMap,
  ) {
    // Check 1: Find a route that contains both start and end nodes
    for (final route in config.routes) {
      final nodeIds = route.nodeIds as List<String>;
      final startIndex = nodeIds.indexOf(start.uid);
      final endIndex = nodeIds.indexOf(end.uid);

      debugPrint('🔍 Checking route "${route.name}" for both nodes');

      if (startIndex != -1 && endIndex != -1) {
        List<String> pathNodeIds;
        bool isValidPath = true;

        if (startIndex < endIndex) {
          pathNodeIds = nodeIds.sublist(startIndex, endIndex + 1);
          
          // Validate forward traversal for blocked connections
          if (!_validatePathConnections(pathNodeIds, configurableNodeMap)) {
            debugPrint('   ❌ Path blocked: forward traversal');
            isValidPath = false;
          }
        } else {
          pathNodeIds = nodeIds.sublist(endIndex, startIndex + 1).reversed.toList();

          // Validate reverse traversal (includes blocked check)
          if (!_validatePathConnections(pathNodeIds, configurableNodeMap)) {
            debugPrint('   ❌ Cannot traverse reverse: path blocked');
            isValidPath = false;
          }
        }

        if (!isValidPath) continue;

        final path = _buildPathFromNodeIds(pathNodeIds, nodeMap);
        if (path.length == pathNodeIds.length) {
          debugPrint('✅ Using pre-configured route "${route.name}"');
          return _buildNavigationRoute(path);
        }
      }
    }

    // Check 2: Find a route where destination is the LAST node
    for (final route in config.routes) {
      final nodeIds = route.nodeIds as List<String>;
      if (nodeIds.isNotEmpty && nodeIds.last == end.uid) {
        // Find start position in this route
        final startIndex = nodeIds.indexOf(start.uid);
        if (startIndex == -1) continue; // Start not in this route
        
        final pathNodeIds = nodeIds.sublist(startIndex);
        
        // Validate one-way restrictions for this path
        if (!_validatePathConnections(pathNodeIds, configurableNodeMap)) {
          debugPrint('   ❌ Route "${route.name}" blocked by one-way restriction');
          continue;
        }
        
        final path = _buildPathFromNodeIds(pathNodeIds, nodeMap);
        if (path.isNotEmpty) {
          debugPrint('✅ Using full route "${route.name}" to destination');
          return _buildNavigationRoute(path);
        }
      }
    }

    // Check 3: Find any route containing the destination
    for (final route in config.routes) {
      final nodeIds = route.nodeIds as List<String>;
      final startIndex = nodeIds.indexOf(start.uid);
      final endIndex = nodeIds.indexOf(end.uid);

      if (startIndex != -1 && endIndex != -1 && startIndex < endIndex) {
        final pathNodeIds = nodeIds.sublist(startIndex, endIndex + 1);
        
        // Validate one-way restrictions for this path
        if (!_validatePathConnections(pathNodeIds, configurableNodeMap)) {
          debugPrint('   ❌ Route "${route.name}" blocked by one-way restriction');
          continue;
        }
        
        final path = _buildPathFromNodeIds(pathNodeIds, nodeMap);
        if (path.isNotEmpty) {
          debugPrint('✅ Using route "${route.name}" (partial)');
          return _buildNavigationRoute(path);
        }
      }
    }

    return null;
  }

  /// Calculate route for multi-floor navigation.
  Future<NavigationRoute> _calculateMultiFloorRoute(
    BeaconNode start,
    BeaconNode end,
    dynamic config,
    Map<String, BeaconNode> nodeMap,
    Map<String, ConfigurableNode> configurableNodeMap,
  ) async {
    debugPrint('🔄 Multi-floor navigation required: Floor ${start.floor} → Floor ${end.floor}');

    final transitionPoints = FloorTransitionHelper.findFloorTransitionPoints(
      config.nodes,
      start.floor,
      end.floor,
    );

    if (transitionPoints.isEmpty) {
      debugPrint('❌ No stair or elevator points found');
      return const NavigationRoute(
        nodes: [],
        totalDistance: 0,
        estimatedTimeSeconds: 0,
        instructions: ['No route found - no stairs or elevator connecting these floors'],
      );
    }

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

    // Find the best route through transition points
    NavigationRoute? bestRoute;
    double bestDistance = double.infinity;
    final allNodes = nodeMap.values.toList();

    for (final transition in transitionPoints) {
      final startTransition = transition['startNode']!;
      final endTransition = transition['endNode']!;

      debugPrint('🔍 Trying transition through: ${startTransition.name}');

      final pathToTransition = PathfindingHelper.findPathOnFloor(
        start, startTransition, allNodes, configurableNodeMap,
      );

      if (pathToTransition.isEmpty) {
        debugPrint('   ❌ No path from start to transition point');
        continue;
      }

      final pathFromTransition = PathfindingHelper.findPathOnFloor(
        endTransition, end, allNodes, configurableNodeMap,
      );

      if (pathFromTransition.isEmpty) {
        debugPrint('   ❌ No path from transition point to destination');
        continue;
      }

      final combinedPath = [
        ...pathToTransition,
        if (pathFromTransition.isNotEmpty && pathFromTransition.first.uid != pathToTransition.last.uid)
          ...pathFromTransition
        else
          ...pathFromTransition.skip(1)
      ];

      final totalDistance = PathfindingHelper.calculateTotalDistance(combinedPath);

      if (totalDistance < bestDistance) {
        bestDistance = totalDistance;
        bestRoute = _buildNavigationRoute(combinedPath);
      }
    }

    if (bestRoute != null) {
      debugPrint('✅ Multi-floor route found');
      return bestRoute;
    }

    return const NavigationRoute(
      nodes: [],
      totalDistance: 0,
      estimatedTimeSeconds: 0,
      instructions: ['No route allowed for this destination.'],
    );
  }

  /// Calculate route for same-floor navigation.
  NavigationRoute _calculateSameFloorRoute(
    BeaconNode start,
    BeaconNode end,
    Map<String, BeaconNode> nodeMap,
    Map<String, ConfigurableNode> configurableNodeMap,
  ) {
    debugPrint('⚠️ Same floor navigation, using Dijkstra algorithm');

    // Find actual start and end nodes
    BeaconNode actualStart = _findMatchingNode(start, nodeMap, configurableNodeMap);
    BeaconNode actualEnd = _findMatchingNode(end, nodeMap, configurableNodeMap);

    // Check one-way restriction
    final oneWayBlockReason = OneWayRestrictionHelper.checkOneWayRestriction(
      actualStart, actualEnd, configurableNodeMap,
    );
    if (oneWayBlockReason != null) {
      debugPrint('🚫 One-way restriction detected: $oneWayBlockReason');
      return NavigationRoute(
        nodes: const [],
        totalDistance: 0,
        estimatedTimeSeconds: 0,
        instructions: [oneWayBlockReason],
      );
    }

    // Use Dijkstra algorithm
    final allBeacons = nodeMap.values.toList();
    final path = PathfindingHelper.dijkstraWithConfig(
      actualStart, actualEnd, allBeacons, configurableNodeMap,
    );

    if (path.isEmpty) {
      debugPrint('❌ No route found');
      return const NavigationRoute(
        nodes: [],
        totalDistance: 0,
        estimatedTimeSeconds: 0,
        instructions: ['No route allowed for this destination.'],
      );
    }

    debugPrint('✅ Dijkstra route found: ${path.map((n) => n.name).join(' → ')}');
    return _buildNavigationRoute(path);
  }

  /// Find matching node by UID, name, or position.
  BeaconNode _findMatchingNode(
    BeaconNode node,
    Map<String, BeaconNode> nodeMap,
    Map<String, ConfigurableNode> configurableNodeMap,
  ) {
    if (configurableNodeMap.containsKey(node.uid)) {
      return nodeMap[node.uid] ?? node;
    }

    debugPrint('⚠️ Node ${node.uid} not in configurableNodeMap, searching...');
    for (final entry in configurableNodeMap.entries) {
      if (entry.value.name == node.name ||
          (entry.value.x == node.x && entry.value.y == node.y && entry.value.floor == node.floor)) {
        debugPrint('   Found matching node: ${entry.key}');
        return nodeMap[entry.key] ?? node;
      }
    }
    return node;
  }

  /// Validate that all connections in the path are traversable (respecting one-way and blocked restrictions).
  bool _validatePathConnections(
    List<String> pathNodeIds,
    Map<String, ConfigurableNode> configurableNodeMap,
  ) {
    for (int i = 0; i < pathNodeIds.length - 1; i++) {
      final fromId = pathNodeIds[i];
      final toId = pathNodeIds[i + 1];
      final fromNode = configurableNodeMap[fromId];

      // Check if there's a direct outgoing connection (not blocked)
      final directConnection = fromNode?.connections.firstWhere(
        (c) => c.targetNodeId == toId,
        orElse: () => const NodeConnection(targetNodeId: ''),
      );
      final hasDirectConnection = directConnection?.targetNodeId == toId && 
          directConnection?.type != ConnectionType.blocked;
      
      // Check if there's an incoming bidirectional connection from the target (not blocked)
      final incomingConnection = configurableNodeMap[toId]?.connections.firstWhere(
        (c) => c.targetNodeId == fromId && c.isBidirectional,
        orElse: () => const NodeConnection(targetNodeId: ''),
      );
      final hasIncomingBidirectional = incomingConnection?.targetNodeId == fromId && 
          incomingConnection?.type != ConnectionType.blocked;

      if (!hasDirectConnection && !hasIncomingBidirectional) {
        debugPrint('   ❌ Connection blocked or one-way: $fromId → $toId');
        return false;
      }
    }
    return true;
  }

  /// Build path from node IDs.
  List<BeaconNode> _buildPathFromNodeIds(List<String> nodeIds, Map<String, BeaconNode> nodeMap) {
    return nodeIds
        .map((id) => nodeMap[id])
        .where((node) => node != null)
        .cast<BeaconNode>()
        .toList();
  }

  /// Build NavigationRoute from path.
  NavigationRoute _buildNavigationRoute(List<BeaconNode> path) {
    final distance = PathfindingHelper.calculateTotalDistance(path);
    final timeSeconds = (distance / 50 * 60).round();
    final instructions = InstructionGenerator.generateInstructions(path);

    return NavigationRoute(
      nodes: path,
      totalDistance: distance,
      estimatedTimeSeconds: timeSeconds,
      instructions: instructions,
    );
  }

  /// Log route calculation start for debugging.
  void _logRouteCalculationStart(
    BeaconNode start,
    BeaconNode end,
    Map<String, BeaconNode> nodeMap,
    dynamic config,
  ) {
    debugPrint('🗺️ Route calculation: ${start.name} (${start.uid}) → ${end.name} (${end.uid})');
    debugPrint('🔢 Total configured nodes: ${nodeMap.length}');
    debugPrint('📋 Pre-configured routes: ${config.routes.length}');
    debugPrint('🏢 Start floor: ${start.floor}, End floor: ${end.floor}');

    for (final route in config.routes) {
      debugPrint('📍 Route "${route.name}": ${route.nodeIds}');
      final nodeNames = (route.nodeIds as List<String>).map((id) => nodeMap[id]?.name ?? 'UNKNOWN($id)').toList();
      debugPrint('   Node names: $nodeNames');
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
      final config = await configurationRepository.getConfiguration();
      final departmentNodes = config.nodes.where((node) => node.type == NodeType.department).toList();

      return departmentNodes.map((node) {
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
      }).toList();
    } catch (e) {
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
      final config = await configurationRepository.getConfiguration();

      final departmentNode = config.nodes.firstWhereOrNull(
        (node) => node.id == departmentId && node.type == NodeType.department,
      );

      if (departmentNode != null) {
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

      final beacons = beaconDataSource.getAllBeacons();
      return beacons.firstWhereOrNull((b) => b.departmentId == departmentId);
    } catch (e) {
      final beacons = beaconDataSource.getAllBeacons();
      return beacons.firstWhereOrNull((b) => b.departmentId == departmentId);
    }
  }
}
