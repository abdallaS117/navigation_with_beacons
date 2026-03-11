import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/configuration_repository.dart';
import '../../domain/models/models.dart';
import 'configuration_state.dart';

class ConfigurationCubit extends Cubit<ConfigurationState> {
  final ConfigurationRepository _repository;

  ConfigurationCubit(this._repository) : super(const ConfigurationState());

  Future<void> loadConfiguration() async {
    emit(state.copyWith(status: ConfigurationStatus.loading));
    try {
      // Auto-sync from Firebase on startup
      final config = await _repository.syncWithFirebase();
      emit(state.copyWith(
        status: ConfigurationStatus.loaded,
        config: config,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> saveConfiguration() async {
    if (state.config == null) return;
    
    emit(state.copyWith(status: ConfigurationStatus.saving));
    try {
      // Save to Firebase (primary storage)
      final success = await _repository.uploadToFirebase();
      
      if (success) {
        // Also save locally as backup
        await _repository.saveConfiguration(state.config!);
        emit(state.copyWith(
          status: ConfigurationStatus.saved,
          isDirty: false,
        ));
      } else {
        emit(state.copyWith(
          status: ConfigurationStatus.error,
          errorMessage: 'Failed to save configuration to Firebase',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void selectFloor(int floor) {
    emit(state.copyWith(
      selectedFloor: floor,
      selectedNodeId: null,
      selectedBeaconId: null,
    ));
  }

  void setMode(ConfigurationMode mode) {
    emit(state.copyWith(mode: mode));
  }

  void selectNode(String? nodeId) {
    emit(state.copyWith(
      selectedNodeId: nodeId,
      selectedBeaconId: null,
    ));
  }

  void selectBeacon(String? beaconId) {
    emit(state.copyWith(
      selectedBeaconId: beaconId,
      selectedNodeId: null,
    ));
  }

  void selectRoute(String? routeId) {
    emit(state.copyWith(
      selectedRouteId: routeId,
      selectedNodeId: null,
      selectedBeaconId: null,
    ));
  }

  // Map Configuration
  Future<void> updateMapConfig(MapLayoutConfig mapConfig) async {
    try {
      final updated = await _repository.updateMapConfig(mapConfig);
      emit(state.copyWith(config: updated, isDirty: true));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // Beacon Management
  Future<void> addBeacon(ConfigurableBeacon beacon) async {
    try {
      final updated = await _repository.upsertBeacon(beacon);
      emit(state.copyWith(config: updated, isDirty: true));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> updateBeacon(ConfigurableBeacon beacon) async {
    try {
      final updated = await _repository.upsertBeacon(beacon);
      emit(state.copyWith(config: updated, isDirty: true));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> placeBeacon(String beaconId, double x, double y, int floor) async {
    if (state.config == null) return;
    
    try {
      final beacon = state.config!.beacons.firstWhere((b) => b.id == beaconId);
      final updated = await _repository.upsertBeacon(
        beacon.copyWith(x: x, y: y, floor: floor, isPlaced: true),
      );
      emit(state.copyWith(
        config: updated,
        isDirty: true,
        selectedBeaconId: null, // Deselect the placed beacon
        // Keep placeBeacon mode active so user can continue placing beacons
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> removeBeacon(String beaconId) async {
    try {
      final updated = await _repository.removeBeacon(beaconId);
      emit(state.copyWith(
        config: updated,
        isDirty: true,
        selectedBeaconId: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> unplaceBeacon(String beaconId) async {
    try {
      final config = state.config;
      if (config == null) return;
      
      final beacons = config.beacons.map((b) {
        if (b.id == beaconId) {
          return b.copyWith(
            x: null,
            y: null,
            floor: null,
            isPlaced: false,
          );
        }
        return b;
      }).toList();
      
      final updated = config.copyWith(beacons: beacons);
      await _repository.saveConfiguration(updated);
      
      emit(state.copyWith(
        config: updated,
        isDirty: true,
        selectedBeaconId: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // Node Management
  Future<void> addNode(ConfigurableNode node) async {
    try {
      final updated = await _repository.upsertNode(node);
      emit(state.copyWith(
        config: updated,
        isDirty: true,
        mode: ConfigurationMode.view,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> updateNode(ConfigurableNode node) async {
    try {
      final updated = await _repository.upsertNode(node);
      emit(state.copyWith(config: updated, isDirty: true));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> removeNode(String nodeId) async {
    try {
      final updated = await _repository.removeNode(nodeId);
      emit(state.copyWith(
        config: updated,
        isDirty: true,
        selectedNodeId: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // Connection Management
  Future<void> addConnection(
    String fromNodeId,
    String toNodeId, {
    double? weight,
    bool bidirectional = true,
    ConnectionType type = ConnectionType.normal,
  }) async {
    try {
      final updated = await _repository.addConnection(
        fromNodeId,
        toNodeId,
        weight: weight,
        bidirectional: bidirectional,
        type: type,
      );
      emit(state.copyWith(
        config: updated,
        isDirty: true,
        mode: ConfigurationMode.view,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> removeConnection(String nodeId, String targetNodeId) async {
    try {
      final updated = await _repository.removeConnection(nodeId, targetNodeId);
      emit(state.copyWith(config: updated, isDirty: true));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // Route Creation Methods
  void startRouteCreation() {
    emit(state.copyWith(
      mode: ConfigurationMode.createRoute,
      routeNodesInProgress: [],
      routeIdBeingEdited: null,
    ));
  }

  void addNodeToRoute(String nodeId) {
    if (state.routeNodesInProgress.contains(nodeId)) return;
    
    final updatedNodes = List<String>.from(state.routeNodesInProgress)..add(nodeId);
    emit(state.copyWith(routeNodesInProgress: updatedNodes));
  }

  void removeNodeFromRoute(String nodeId) {
    final updatedNodes = state.routeNodesInProgress.where((id) => id != nodeId).toList();
    emit(state.copyWith(routeNodesInProgress: updatedNodes));
  }

  void clearRouteInProgress() {
    emit(state.copyWith(
      routeNodesInProgress: [],
      mode: ConfigurationMode.view,
      routeIdBeingEdited: null,
    ));
  }

  Future<void> saveRoute(String name, String? description, RouteType type) async {
    if (state.routeNodesInProgress.length < 2) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: 'Route must have at least 2 nodes',
      ));
      return;
    }

    try {
      final route = RouteConfig(
        id: 'route_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: description,
        nodeIds: state.routeNodesInProgress,
        type: type,
      );

      final updated = await _repository.upsertRoute(route);
      emit(state.copyWith(
        config: updated,
        isDirty: true,
        routeNodesInProgress: [],
        mode: ConfigurationMode.view,
        routeIdBeingEdited: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> deleteRoute(String routeId) async {
    try {
      final updated = await _repository.removeRoute(routeId);
      emit(state.copyWith(config: updated, isDirty: true));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // Route Management
  Future<void> addRoute(RouteConfig route) async {
    try {
      final updated = await _repository.upsertRoute(route);
      emit(state.copyWith(config: updated, isDirty: true));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> removeRoute(String routeId) async {
    try {
      final updated = await _repository.removeRoute(routeId);
      emit(state.copyWith(config: updated, isDirty: true));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Clears all routes only (keeps node connections).
  Future<void> clearAllRoutes() async {
    try {
      final updated = await _repository.clearAllRoutes();
      emit(state.copyWith(config: updated, isDirty: true));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Clears all routes AND all node connections.
  Future<void> clearAllRoutesAndConnections() async {
    try {
      final updated = await _repository.clearAllRoutesAndConnections();
      emit(state.copyWith(config: updated, isDirty: true));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // Import/Export
  Future<void> importConfiguration(Map<String, dynamic> json) async {
    emit(state.copyWith(status: ConfigurationStatus.loading));
    try {
      final config = await _repository.importConfiguration(json);
      emit(state.copyWith(
        status: ConfigurationStatus.loaded,
        config: config,
        isDirty: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<Map<String, dynamic>> exportConfiguration() async {
    return await _repository.exportConfiguration();
  }

  // Firebase Sync Methods
  Future<bool> uploadToFirebase() async {
    emit(state.copyWith(status: ConfigurationStatus.saving));
    try {
      final success = await _repository.uploadToFirebase();
      if (success) {
        emit(state.copyWith(status: ConfigurationStatus.saved));
      } else {
        emit(state.copyWith(
          status: ConfigurationStatus.error,
          errorMessage: 'Failed to upload to Firebase',
        ));
      }
      return success;
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  Future<bool> downloadFromFirebase() async {
    emit(state.copyWith(status: ConfigurationStatus.loading));
    try {
      final success = await _repository.downloadFromFirebase();
      if (success) {
        final config = await _repository.getConfiguration();
        emit(state.copyWith(
          status: ConfigurationStatus.loaded,
          config: config,
          isDirty: false,
        ));
      } else {
        emit(state.copyWith(
          status: ConfigurationStatus.error,
          errorMessage: 'Failed to download from Firebase',
        ));
      }
      return success;
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  Future<void> syncWithFirebase() async {
    emit(state.copyWith(status: ConfigurationStatus.loading));
    try {
      final config = await _repository.syncWithFirebase();
      emit(state.copyWith(
        status: ConfigurationStatus.loaded,
        config: config,
        isDirty: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Reset configuration to default (clears saved data)
  Future<void> resetToDefault() async {
    emit(state.copyWith(status: ConfigurationStatus.loading));
    try {
      // Clear saved configuration
      _repository.clearCache();
      
      // Load default configuration
      final defaultConfig = NavigationConfig.empty();
      
      // Save locally
      await _repository.saveConfiguration(defaultConfig);
      
      // Also upload to Firebase to sync the reset across devices
      await _repository.uploadToFirebase();
      
      emit(state.copyWith(
        status: ConfigurationStatus.loaded,
        config: defaultConfig,
        isDirty: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ConfigurationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
