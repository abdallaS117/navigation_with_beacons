import '../entities/beacon_node.dart';
import '../entities/navigation_route.dart';
import '../repositories/navigation_repository.dart';

class CalculateRoute {
  final NavigationRepository repository;

  CalculateRoute(this.repository);

  Future<NavigationRoute> call(BeaconNode start, BeaconNode end) {
    return repository.calculateRoute(start, end);
  }
}
