import '../entities/beacon_node.dart';
import '../entities/navigation_route.dart';

abstract class BeaconRepository {
  Stream<BeaconNode?> get nearestBeaconStream;
  Future<List<BeaconNode>> getAllBeacons();
  Future<BeaconNode?> getBeaconByUid(String uid);
  Future<List<BeaconNode>> getBeaconsByFloor(int floor);
  Future<void> startScanning();
  Future<void> stopScanning();
  void setActiveRoute(NavigationRoute? route);
}
