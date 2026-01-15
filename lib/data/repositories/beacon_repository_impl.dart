import '../../domain/entities/beacon_node.dart';
import '../../domain/entities/navigation_route.dart';
import '../../domain/repositories/beacon_repository.dart';
import '../datasources/hybrid_beacon_datasource.dart';

class BeaconRepositoryImpl implements BeaconRepository {
  final BeaconDataSource dataSource;

  BeaconRepositoryImpl(this.dataSource);

  @override
  Stream<BeaconNode?> get nearestBeaconStream => dataSource.nearestBeaconStream;

  @override
  Future<List<BeaconNode>> getAllBeacons() async {
    return dataSource.getAllBeacons();
  }

  @override
  Future<BeaconNode?> getBeaconByUid(String uid) async {
    return dataSource.getBeaconByUid(uid);
  }

  @override
  Future<List<BeaconNode>> getBeaconsByFloor(int floor) async {
    return dataSource.getBeaconsByFloor(floor);
  }

  @override
  Future<void> startScanning() async {
    await dataSource.startScanning();
  }

  @override
  Future<void> stopScanning() async {
    dataSource.stopScanning();
  }

  @override
  void setActiveRoute(NavigationRoute? route) {
    // Only HybridBeaconDataSource supports route-based tracking
    if (dataSource is HybridBeaconDataSource) {
      (dataSource as HybridBeaconDataSource).setActiveRoute(route);
    }
  }
}
