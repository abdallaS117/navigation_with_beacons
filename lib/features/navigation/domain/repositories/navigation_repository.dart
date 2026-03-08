import '../entities/beacon_node.dart';
import '../entities/navigation_route.dart';
import '../entities/floor_map.dart';
import '../entities/department.dart';

abstract class NavigationRepository {
  Future<NavigationRoute> calculateRoute(BeaconNode start, BeaconNode end);
  Future<FloorMap> getFloorMap(int floor);
  Future<List<FloorMap>> getAllFloorMaps();
  Future<List<Department>> getAllDepartments();
  Future<Department?> getDepartmentById(String id);
  Future<BeaconNode?> getBeaconForDepartment(String departmentId);
}
