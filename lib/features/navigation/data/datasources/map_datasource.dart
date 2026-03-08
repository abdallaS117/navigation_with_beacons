import '../../domain/entities/department.dart';
import '../../domain/entities/floor_map.dart';
import '../providers/static_map_provider.dart';

abstract class MapDataSource {
  FloorMap getFloorMap(int floor);
  List<FloorMap> getAllFloorMaps();
  List<Department> getAllDepartments();
  Department? getDepartmentById(String id);
}

/// StaticMapDataSource now delegates to StaticMapProvider
/// to avoid duplicate hardcoded data.
class StaticMapDataSource implements MapDataSource {
  final StaticMapProvider _provider = StaticMapProvider();

  @override
  FloorMap getFloorMap(int floor) => _provider.getFloorMap(floor);

  @override
  List<FloorMap> getAllFloorMaps() => _provider.getAllFloorMaps();

  @override
  List<Department> getAllDepartments() => _provider.getAllDepartments();

  @override
  Department? getDepartmentById(String id) => _provider.getDepartmentById(id);
}
