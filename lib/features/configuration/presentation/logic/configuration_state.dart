import 'package:equatable/equatable.dart';
import '../../domain/models/models.dart';

enum ConfigurationStatus {
  initial,
  loading,
  loaded,
  saving,
  saved,
  error,
}

class ConfigurationState extends Equatable {
  final ConfigurationStatus status;
  final NavigationConfig? config;
  final String? errorMessage;
  final int selectedFloor;
  final String? selectedNodeId;
  final String? selectedBeaconId;
  final ConfigurationMode mode;
  final bool isDirty;

  const ConfigurationState({
    this.status = ConfigurationStatus.initial,
    this.config,
    this.errorMessage,
    this.selectedFloor = 1,
    this.selectedNodeId,
    this.selectedBeaconId,
    this.mode = ConfigurationMode.view,
    this.isDirty = false,
  });

  ConfigurationState copyWith({
    ConfigurationStatus? status,
    NavigationConfig? config,
    String? errorMessage,
    int? selectedFloor,
    String? selectedNodeId,
    String? selectedBeaconId,
    ConfigurationMode? mode,
    bool? isDirty,
  }) {
    return ConfigurationState(
      status: status ?? this.status,
      config: config ?? this.config,
      errorMessage: errorMessage,
      selectedFloor: selectedFloor ?? this.selectedFloor,
      selectedNodeId: selectedNodeId,
      selectedBeaconId: selectedBeaconId,
      mode: mode ?? this.mode,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  List<ConfigurableNode> get nodesForCurrentFloor {
    if (config == null) return [];
    return config!.nodes.where((n) => n.floor == selectedFloor).toList();
  }

  List<ConfigurableBeacon> get beaconsForCurrentFloor {
    if (config == null) return [];
    return config!.beacons.where((b) => b.floor == selectedFloor).toList();
  }

  List<ConfigurableBeacon> get unplacedBeacons {
    if (config == null) return [];
    return config!.beacons.where((b) => !b.isPlaced).toList();
  }

  ConfigurableNode? get selectedNode {
    if (config == null || selectedNodeId == null) return null;
    try {
      return config!.nodes.firstWhere((n) => n.id == selectedNodeId);
    } catch (_) {
      return null;
    }
  }

  ConfigurableBeacon? get selectedBeacon {
    if (config == null || selectedBeaconId == null) return null;
    try {
      return config!.beacons.firstWhere((b) => b.id == selectedBeaconId);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
        status,
        config,
        errorMessage,
        selectedFloor,
        selectedNodeId,
        selectedBeaconId,
        mode,
        isDirty,
      ];
}

enum ConfigurationMode {
  view,
  addNode,
  editNode,
  deleteNode,
  addBeacon,
  placeBeacon,
  addConnection,
  deleteConnection,
}
