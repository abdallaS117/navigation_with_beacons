import '../entities/beacon_node.dart';
import '../repositories/beacon_repository.dart';

class GetNearestBeacon {
  final BeaconRepository repository;

  GetNearestBeacon(this.repository);

  Stream<BeaconNode?> call() {
    return repository.nearestBeaconStream;
  }
}
