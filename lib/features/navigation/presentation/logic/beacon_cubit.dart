import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/beacon_node.dart';
import '../../domain/repositories/beacon_repository.dart';
import 'beacon_state.dart';

/// Cubit for managing BLE beacon scanning and detection state.
/// 
/// [BeaconCubit] handles:
/// - Starting and stopping BLE beacon scanning
/// - Tracking the currently detected beacon (user's position)
/// - Reloading configuration when beacons are updated
/// 
/// ## Usage
/// 
/// ```dart
/// // Start scanning for beacons
/// context.read<BeaconCubit>().startScanning();
/// 
/// // Listen to beacon state changes
/// BlocBuilder<BeaconCubit, BeaconState>(
///   builder: (context, state) {
///     if (state.status == BeaconStatus.detected) {
///       print('At: ${state.currentBeacon?.name}');
///     }
///     return ...;
///   },
/// );
/// 
/// // Reload after configuration changes
/// await context.read<BeaconCubit>().reloadConfiguration();
/// ```
/// 
/// ## State Flow
/// 
/// ```
/// initial → scanning → detected
///              ↓
///            error
/// ```
class BeaconCubit extends Cubit<BeaconState> {
  final BeaconRepository _beaconRepository;
  StreamSubscription<BeaconNode?>? _beaconSubscription;

  /// Creates a [BeaconCubit] with the given [BeaconRepository].
  BeaconCubit(this._beaconRepository) : super(const BeaconState());

  /// Starts BLE beacon scanning.
  /// 
  /// This will:
  /// 1. Set status to [BeaconStatus.scanning]
  /// 2. Start the BLE scan via repository
  /// 3. Listen for detected beacons
  /// 
  /// When a beacon is detected, status changes to [BeaconStatus.detected]
  /// and [BeaconState.currentBeacon] is updated.
  Future<void> startScanning() async {
    emit(state.copyWith(status: BeaconStatus.scanning));
    
    await _beaconRepository.startScanning();
    
    _beaconSubscription?.cancel();
    _beaconSubscription = _beaconRepository.nearestBeaconStream.listen(
      _onBeaconDetected,
      onError: _onError,
    );
  }

  void _onBeaconDetected(BeaconNode? beacon) {
    if (beacon != null) {
      emit(state.copyWith(
        status: BeaconStatus.detected,
        previousBeacon: state.currentBeacon,
        currentBeacon: beacon,
      ));
    }
  }

  void _onError(dynamic error) {
    emit(state.copyWith(
      status: BeaconStatus.error,
      errorMessage: error.toString(),
    ));
  }

  /// Stops BLE beacon scanning.
  /// 
  /// Cancels the beacon subscription and resets status to initial.
  Future<void> stopScanning() async {
    await _beaconSubscription?.cancel();
    await _beaconRepository.stopScanning();
    emit(state.copyWith(status: BeaconStatus.initial));
  }

  /// Gets all registered beacons from the repository.
  Future<List<BeaconNode>> getAllBeacons() async {
    return _beaconRepository.getAllBeacons();
  }

  /// Gets beacons on a specific floor.
  Future<List<BeaconNode>> getBeaconsByFloor(int floor) async {
    return _beaconRepository.getBeaconsByFloor(floor);
  }

  /// Reloads beacon configuration and restarts scanning.
  /// 
  /// Call this after saving new configuration to ensure
  /// the scanner uses the updated beacon list.
  /// 
  /// This will:
  /// 1. Stop current scanning
  /// 2. Reload configuration from repository
  /// 3. Restart scanning with new beacons
  Future<void> reloadConfiguration() async {
    // Stop current scanning
    await stopScanning();
    
    // Reload configuration from repository
    await _beaconRepository.reloadConfiguration();
    
    // Restart scanning with new configuration
    await startScanning();
  }

  @override
  Future<void> close() {
    _beaconSubscription?.cancel();
    return super.close();
  }
}
