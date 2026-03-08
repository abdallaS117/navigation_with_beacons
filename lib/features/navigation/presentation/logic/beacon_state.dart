import 'package:equatable/equatable.dart';
import '../../domain/entities/beacon_node.dart';

enum BeaconStatus { initial, scanning, detected, error }

class BeaconState extends Equatable {
  final BeaconStatus status;
  final BeaconNode? currentBeacon;
  final BeaconNode? previousBeacon;
  final String? errorMessage;
  final bool isSimulating;

  const BeaconState({
    this.status = BeaconStatus.initial,
    this.currentBeacon,
    this.previousBeacon,
    this.errorMessage,
    this.isSimulating = false,
  });

  BeaconState copyWith({
    BeaconStatus? status,
    BeaconNode? currentBeacon,
    BeaconNode? previousBeacon,
    String? errorMessage,
    bool? isSimulating,
  }) {
    return BeaconState(
      status: status ?? this.status,
      currentBeacon: currentBeacon ?? this.currentBeacon,
      previousBeacon: previousBeacon ?? this.previousBeacon,
      errorMessage: errorMessage ?? this.errorMessage,
      isSimulating: isSimulating ?? this.isSimulating,
    );
  }

  @override
  List<Object?> get props => [status, currentBeacon, previousBeacon, errorMessage, isSimulating];
}
