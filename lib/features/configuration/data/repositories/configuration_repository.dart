import '../../domain/models/models.dart';
import '../services/configuration_storage_service.dart';

/// Repository for managing navigation configuration.
class ConfigurationRepository {
  final ConfigurationStorageService _storageService;
  NavigationConfig? _cachedConfig;

  ConfigurationRepository(this._storageService);

  /// Gets the current configuration, loading from storage if needed.
  Future<NavigationConfig> getConfiguration() async {
    if (_cachedConfig != null) return _cachedConfig!;
    
    _cachedConfig = await _storageService.loadConfiguration();
    _cachedConfig ??= NavigationConfig.empty();
    return _cachedConfig!;
  }

  /// Saves the configuration to storage.
  Future<void> saveConfiguration(NavigationConfig config) async {
    _cachedConfig = config;
    await _storageService.saveConfiguration(config);
  }

  /// Updates the map configuration.
  Future<NavigationConfig> updateMapConfig(MapLayoutConfig mapConfig) async {
    final config = await getConfiguration();
    final updated = config.copyWith(mapConfig: mapConfig);
    await saveConfiguration(updated);
    return updated;
  }

  /// Adds or updates a beacon.
  Future<NavigationConfig> upsertBeacon(ConfigurableBeacon beacon) async {
    final config = await getConfiguration();
    final beacons = List<ConfigurableBeacon>.from(config.beacons);
    final index = beacons.indexWhere((b) => b.id == beacon.id);
    
    if (index >= 0) {
      beacons[index] = beacon;
    } else {
      beacons.add(beacon);
    }
    
    final updated = config.copyWith(beacons: beacons);
    await saveConfiguration(updated);
    return updated;
  }

  /// Removes a beacon.
  Future<NavigationConfig> removeBeacon(String beaconId) async {
    final config = await getConfiguration();
    final beacons = config.beacons.where((b) => b.id != beaconId).toList();
    final updated = config.copyWith(beacons: beacons);
    await saveConfiguration(updated);
    return updated;
  }

  /// Adds or updates a node.
  Future<NavigationConfig> upsertNode(ConfigurableNode node) async {
    final config = await getConfiguration();
    final nodes = List<ConfigurableNode>.from(config.nodes);
    final index = nodes.indexWhere((n) => n.id == node.id);
    
    if (index >= 0) {
      nodes[index] = node;
    } else {
      nodes.add(node);
    }
    
    final updated = config.copyWith(nodes: nodes);
    await saveConfiguration(updated);
    return updated;
  }

  /// Removes a node and its connections from other nodes.
  Future<NavigationConfig> removeNode(String nodeId) async {
    final config = await getConfiguration();
    
    // Remove the node
    final nodes = config.nodes.where((n) => n.id != nodeId).toList();
    
    // Remove connections to this node from other nodes
    final updatedNodes = nodes.map((node) {
      final connections = node.connections
          .where((c) => c.targetNodeId != nodeId)
          .toList();
      return node.copyWith(connections: connections);
    }).toList();
    
    final updated = config.copyWith(nodes: updatedNodes);
    await saveConfiguration(updated);
    return updated;
  }

  /// Adds a connection between two nodes.
  Future<NavigationConfig> addConnection(
    String fromNodeId,
    String toNodeId, {
    double? weight,
    bool bidirectional = true,
    ConnectionType type = ConnectionType.normal,
  }) async {
    final config = await getConfiguration();
    final nodes = List<ConfigurableNode>.from(config.nodes);
    
    // Add connection to source node
    final fromIndex = nodes.indexWhere((n) => n.id == fromNodeId);
    if (fromIndex >= 0) {
      final fromNode = nodes[fromIndex];
      final connections = List<NodeConnection>.from(fromNode.connections);
      
      // Remove existing connection if any
      connections.removeWhere((c) => c.targetNodeId == toNodeId);
      connections.add(NodeConnection(
        targetNodeId: toNodeId,
        weight: weight,
        isBidirectional: bidirectional,
        type: type,
      ));
      
      nodes[fromIndex] = fromNode.copyWith(connections: connections);
    }
    
    // Add reverse connection if bidirectional
    if (bidirectional) {
      final toIndex = nodes.indexWhere((n) => n.id == toNodeId);
      if (toIndex >= 0) {
        final toNode = nodes[toIndex];
        final connections = List<NodeConnection>.from(toNode.connections);
        
        connections.removeWhere((c) => c.targetNodeId == fromNodeId);
        connections.add(NodeConnection(
          targetNodeId: fromNodeId,
          weight: weight,
          isBidirectional: true,
          type: type,
        ));
        
        nodes[toIndex] = toNode.copyWith(connections: connections);
      }
    }
    
    final updated = config.copyWith(nodes: nodes);
    await saveConfiguration(updated);
    return updated;
  }

  /// Removes a connection between two nodes.
  Future<NavigationConfig> removeConnection(
    String fromNodeId,
    String toNodeId, {
    bool removeBidirectional = true,
  }) async {
    final config = await getConfiguration();
    final nodes = List<ConfigurableNode>.from(config.nodes);
    
    // Remove connection from source
    final fromIndex = nodes.indexWhere((n) => n.id == fromNodeId);
    if (fromIndex >= 0) {
      final fromNode = nodes[fromIndex];
      final connections = fromNode.connections
          .where((c) => c.targetNodeId != toNodeId)
          .toList();
      nodes[fromIndex] = fromNode.copyWith(connections: connections);
    }
    
    // Remove reverse connection if requested
    if (removeBidirectional) {
      final toIndex = nodes.indexWhere((n) => n.id == toNodeId);
      if (toIndex >= 0) {
        final toNode = nodes[toIndex];
        final connections = toNode.connections
            .where((c) => c.targetNodeId != fromNodeId)
            .toList();
        nodes[toIndex] = toNode.copyWith(connections: connections);
      }
    }
    
    final updated = config.copyWith(nodes: nodes);
    await saveConfiguration(updated);
    return updated;
  }

  /// Adds or updates a route.
  Future<NavigationConfig> upsertRoute(RouteConfig route) async {
    final config = await getConfiguration();
    final routes = List<RouteConfig>.from(config.routes);
    final index = routes.indexWhere((r) => r.id == route.id);
    
    if (index >= 0) {
      routes[index] = route;
    } else {
      routes.add(route);
    }
    
    final updated = config.copyWith(routes: routes);
    await saveConfiguration(updated);
    return updated;
  }

  /// Removes a route.
  Future<NavigationConfig> removeRoute(String routeId) async {
    final config = await getConfiguration();
    final routes = config.routes.where((r) => r.id != routeId).toList();
    final updated = config.copyWith(routes: routes);
    await saveConfiguration(updated);
    return updated;
  }

  /// Clears the cached configuration.
  void clearCache() {
    _cachedConfig = null;
  }

  /// Imports configuration from JSON.
  Future<NavigationConfig> importConfiguration(Map<String, dynamic> json) async {
    final config = NavigationConfig.fromJson(json);
    await saveConfiguration(config);
    return config;
  }

  /// Exports configuration to JSON.
  Future<Map<String, dynamic>> exportConfiguration() async {
    final config = await getConfiguration();
    return config.toJson();
  }
}
