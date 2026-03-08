import '../entities/floor_map.dart';
import '../repositories/navigation_repository.dart';

class GetFloorMap {
  final NavigationRepository repository;

  GetFloorMap(this.repository);

  Future<FloorMap> call(int floor) {
    return repository.getFloorMap(floor);
  }
}
