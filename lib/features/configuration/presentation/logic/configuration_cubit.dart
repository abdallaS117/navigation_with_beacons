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
      final config = await _repository.getConfiguration();
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
      await _repository.saveConfiguration(state.config!);
      emit(state.copyWith(
        status: ConfigurationStatus.saved,
        isDirty: false,
      ));
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
        mode: ConfigurationMode.view,
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

  Future<void> removeConnection(String fromNodeId, String toNodeId) async {
    try {
      final updated = await _repository.removeConnection(fromNodeId, toNodeId);
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
}
