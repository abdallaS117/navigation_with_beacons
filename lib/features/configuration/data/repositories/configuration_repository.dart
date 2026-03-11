import '../../domain/models/models.dart';
import '../services/configuration_storage_service.dart';
import '../services/firebase_configuration_service.dart';

/// Repository for managing navigation configuration.
class ConfigurationRepository {
  final ConfigurationStorageService _storageService;
  final FirebaseConfigurationService? _firebaseService;
  NavigationConfig? _cachedConfig;

  ConfigurationRepository(
    this._storageService, {
    FirebaseConfigurationService? firebaseService,
  }) : _firebaseService = firebaseService;

  /// Gets the current configuration, loading from storage if needed.
  Future<NavigationConfig> getConfiguration() async {
    if (_cachedConfig != null) return _cachedConfig!;
    
    _cachedConfig = await _storageService.loadConfiguration();
    _cachedConfig ??= NavigationConfig.empty();
    
    // Migrate old asset paths to package-prefixed paths
    _cachedConfig = _migrateAssetPaths(_cachedConfig!);
    
    return _cachedConfig!;
  }
  
  /// Removes old asset paths and invalid file picker cache paths
  NavigationConfig _migrateAssetPaths(NavigationConfig config) {
    bool needsMigration = false;
    
    final migratedFloors = config.mapConfig.floors.map((floor) {
      if (floor.imagePath != null) {
        // Remove asset paths (both assets/ and packages/ prefixes)
        if (floor.imagePath!.startsWith('assets/') || 
            floor.imagePath!.startsWith('packages/')) {
          needsMigration = true;
          print('🔄 Removing asset path: ${floor.imagePath}');
          return FloorConfig(
            floorNumber: floor.floorNumber,
            name: floor.name,
            imagePath: null,
            isActive: floor.isActive,
          );
        }
        
        // Remove file picker cache paths (temporary paths that no longer exist)
        if (floor.imagePath!.contains('/cache/file_picker/')) {
          needsMigration = true;
          print('🔄 Removing invalid cache path: ${floor.imagePath}');
          return FloorConfig(
            floorNumber: floor.floorNumber,
            name: floor.name,
            imagePath: null,
            isActive: floor.isActive,
          );
        }
      }
      return floor;
    }).toList();
    
    if (needsMigration) {
      print('✅ Migration complete - invalid image paths removed');
      final updatedMapConfig = config.mapConfig.copyWith(floors: migratedFloors);
      final migratedConfig = config.copyWith(mapConfig: updatedMapConfig);
      
      // Save the migrated configuration
      saveConfiguration(migratedConfig);
      
      return migratedConfig;
    }
    
    return config;
  }

  /// Updates the cached configuration without saving to storage
  void updateCachedConfig(NavigationConfig config) {
    _cachedConfig = config;
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
    
    print('📍 upsertBeacon called for beacon ID: ${beacon.id}');
    print('📍 Current beacons count: ${beacons.length}');
    print('📍 Existing beacon IDs: ${beacons.map((b) => b.id).toList()}');
    print('📍 Index found: $index');
    
    if (index >= 0) {
      print('📍 Updating existing beacon at index $index');
      beacons[index] = beacon;
    } else {
      print('📍 Adding new beacon');
      beacons.add(beacon);
    }
    
    print('📍 New beacons count: ${beacons.length}');
    print('📍 New beacon IDs: ${beacons.map((b) => b.id).toList()}');
    
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

  /// Clears all routes and their associated connections.
  Future<NavigationConfig> clearAllRoutes() async {
    final config = await getConfiguration();
    
    // Clear all routes
    final updated = config.copyWith(routes: []);
    await saveConfiguration(updated);
    return updated;
  }

  /// Clears all routes AND all node connections.
  Future<NavigationConfig> clearAllRoutesAndConnections() async {
    final config = await getConfiguration();
    
    // Clear connections from all nodes
    final nodesWithoutConnections = config.nodes.map((node) {
      return node.copyWith(connections: []);
    }).toList();
    
    // Clear all routes and update nodes
    final updated = config.copyWith(
      routes: [],
      nodes: nodesWithoutConnections,
    );
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

  // ========== Firebase Sync Methods ==========

  /// Upload current configuration to Firebase Firestore
  Future<bool> uploadToFirebase() async {
    if (_firebaseService == null) {
      print('⚠️ Firebase service not configured');
      return false;
    }

    final config = await getConfiguration();
    return await _firebaseService!.uploadConfiguration(config);
  }

  /// Download configuration from Firebase Firestore
  /// If successful, saves to local storage and updates cache
  Future<bool> downloadFromFirebase() async {
    if (_firebaseService == null) {
      print('⚠️ Firebase service not configured');
      return false;
    }

    final config = await _firebaseService!.downloadConfiguration();
    if (config == null) {
      return false;
    }

    // Save to local storage and update cache
    await saveConfiguration(config);
    return true;
  }

  /// Sync configuration: Download from Firebase if available, otherwise use local
  Future<NavigationConfig> syncWithFirebase() async {
    if (_firebaseService == null) {
      print('⚠️ Firebase service not configured, using local storage');
      return await getConfiguration();
    }

    // Try to download from Firebase
    final firebaseConfig = await _firebaseService!.downloadConfiguration();
    
    if (firebaseConfig != null) {
      // Apply migration to remove old asset paths
      final migratedConfig = _migrateAssetPaths(firebaseConfig);
      
      // Save migrated config locally
      await saveConfiguration(migratedConfig);
      return migratedConfig;
    } else {
      // No Firebase config, use local
      print('ℹ️ No Firebase config found, using local configuration');
      return await getConfiguration();
    }
  }

  /// Check if Firebase configuration exists
  Future<bool> hasFirebaseConfig() async {
    if (_firebaseService == null) return false;
    return await _firebaseService!.configurationExists();
  }

  /// Get last Firebase update time
  Future<DateTime?> getFirebaseUpdateTime() async {
    if (_firebaseService == null) return null;
    return await _firebaseService!.getLastUpdateTime();
  }

  /// Stream configuration changes from Firebase
  Stream<NavigationConfig?>? streamFirebaseConfig() {
    return _firebaseService?.streamConfiguration();
  }
}
