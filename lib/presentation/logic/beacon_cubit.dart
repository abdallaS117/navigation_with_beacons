import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/beacon_node.dart';
import '../../domain/repositories/beacon_repository.dart';
import 'beacon_state.dart';

class BeaconCubit extends Cubit<BeaconState> {
  final BeaconRepository _beaconRepository;
  StreamSubscription<BeaconNode?>? _beaconSubscription;

  BeaconCubit(this._beaconRepository) : super(const BeaconState());

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

  Future<void> stopScanning() async {
    await _beaconSubscription?.cancel();
    await _beaconRepository.stopScanning();
    emit(state.copyWith(status: BeaconStatus.initial));
  }

  void simulateBeaconChange(String beaconUid) {
    _beaconRepository.simulateBeaconChange(beaconUid);
  }

  Future<List<BeaconNode>> getAllBeacons() async {
    return _beaconRepository.getAllBeacons();
  }

  Future<List<BeaconNode>> getBeaconsByFloor(int floor) async {
    return _beaconRepository.getBeaconsByFloor(floor);
  }

  @override
  Future<void> close() {
    _beaconSubscription?.cancel();
    return super.close();
  }
}
