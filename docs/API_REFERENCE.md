# API Reference

## Public Exports

All public APIs are exported from the main package file:

```dart
import 'package:beacon_navigation/beacon_navigation.dart';
```

---

## Navigation Feature

### NavigationCubit

State management for indoor navigation.

```dart
class NavigationCubit extends Cubit<NavigationState>
```

#### Constructor
```dart
NavigationCubit({
  required NavigationRepository navigationRepository,
  required BeaconRepository beaconRepository,
})
```

#### Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `initialize()` | Load floor maps and departments, start beacon listening | `Future<void>` |
| `startNavigation()` | Calculate route to selected destination | `Future<void>` |
| `cancelNavigation()` | Stop current navigation | `void` |
| `changeFloor(int floor)` | Switch to different floor | `Future<void>` |
| `selectDestination(Department dept)` | Set navigation target | `Future<void>` |
| `updateCompassHeading(double heading)` | Update user heading | `void` |
| `clearError()` | Clear error message | `void` |

#### State Properties

```dart
class NavigationState extends Equatable {
  final NavigationStatus status;
  final List<FloorMap> allFloorMaps;
  final FloorMap? currentFloorMap;
  final int currentFloor;
  final BeaconNode? currentPosition;
  final Department? selectedDestination;
  final List<Department> departments;
  final NavigationRoute? currentRoute;
  final int currentRouteIndex;
  final double routeProgress;
  final double compassHeading;
  final String? errorMessage;
  
  bool get isNavigating;
}
```

---

### BeaconCubit

State management for beacon scanning.

```dart
class BeaconCubit extends Cubit<BeaconState>
```

#### Constructor
```dart
BeaconCubit(BeaconRepository beaconRepository)
```

#### Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `startScanning()` | Start BLE beacon scanning | `Future<void>` |
| `stopScanning()` | Stop scanning | `Future<void>` |
| `reloadConfiguration()` | Reload config and restart scanning | `Future<void>` |
| `getAllBeacons()` | Get all registered beacons | `Future<List<BeaconNode>>` |
| `getBeaconsByFloor(int floor)` | Get beacons on specific floor | `Future<List<BeaconNode>>` |

#### State Properties

```dart
class BeaconState extends Equatable {
  final BeaconStatus status;
  final BeaconNode? currentBeacon;
  final BeaconNode? previousBeacon;
  final String? errorMessage;
}
```

---

### NavigationRepository

Abstract interface for navigation operations.

```dart
abstract class NavigationRepository {
  Future<NavigationRoute> calculateRoute(BeaconNode start, BeaconNode end);
  Future<FloorMap?> getFloorMap(int floor);
  Future<List<FloorMap>> getAllFloorMaps();
  Future<List<Department>> getAllDepartments();
  Future<BeaconNode?> getBeaconForDepartment(String departmentId);
}
```

### NavigationRepositoryImpl

Concrete implementation with pathfinding.

```dart
class NavigationRepositoryImpl implements NavigationRepository {
  NavigationRepositoryImpl({
    required MapDataSource mapDataSource,
    required BeaconDataSource beaconDataSource,
    required ConfigurationRepository configurationRepository,
  });
}
```

---

### BeaconRepository

Abstract interface for beacon operations.

```dart
abstract class BeaconRepository {
  Stream<BeaconNode?> get nearestBeaconStream;
  Future<void> startScanning();
  Future<void> stopScanning();
  Future<List<BeaconNode>> getAllBeacons();
  Future<List<BeaconNode>> getBeaconsByFloor(int floor);
  Future<void> reloadConfiguration();
  void setActiveRoute(NavigationRoute? route);
  void dispose();
}
```

---

### Entities

#### BeaconNode

```dart
class BeaconNode extends Equatable {
  const BeaconNode({
    required String uid,
    required String name,
    required double x,
    required double y,
    required int floor,
    String? departmentId,
    bool isNavigable = true,
    List<String> connectedNodes = const [],
  });
  
  BeaconNode copyWith({...});
}
```

#### NavigationRoute

```dart
class NavigationRoute extends Equatable {
  const NavigationRoute({
    required List<BeaconNode> nodes,
    required double totalDistance,
    required int estimatedTimeSeconds,
    List<String> instructions = const [],
  });
  
  bool get isEmpty;
  bool get isNotEmpty;
  BeaconNode? get startNode;
  BeaconNode? get endNode;
  int get nodeCount;
  List<int> get floorsInRoute;
  bool requiresFloorChange();
}
```

#### Department

```dart
class Department extends Equatable {
  const Department({
    required String id,
    required String name,
    required int floor,
    String? iconName,
  });
}
```

#### FloorMap

```dart
class FloorMap extends Equatable {
  const FloorMap({
    required int floor,
    required String name,
    required List<MapElement> elements,
    required List<Department> departments,
  });
}
```

---

## Configuration Feature

### ConfigurationCubit

State management for configuration.

```dart
class ConfigurationCubit extends Cubit<ConfigurationState>
```

#### Constructor
```dart
ConfigurationCubit(ConfigurationRepository repository)
```

#### Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `loadConfiguration()` | Load configuration | `Future<void>` |
| `saveConfiguration()` | Save to local + Firebase | `Future<void>` |
| `refreshFromFirebase()` | Force download from Firebase | `Future<void>` |
| `addNode(ConfigurableNode)` | Add navigation node | `Future<void>` |
| `updateNode(ConfigurableNode)` | Update node | `Future<void>` |
| `deleteNode(String id)` | Delete node | `Future<void>` |
| `addBeacon(ConfigurableBeacon)` | Add beacon | `Future<void>` |
| `updateBeacon(ConfigurableBeacon)` | Update beacon | `Future<void>` |
| `deleteBeacon(String id)` | Delete beacon | `Future<void>` |
| `addConnection(String, NodeConnection)` | Add connection | `Future<void>` |
| `updateConnection(String, NodeConnection)` | Update connection | `Future<void>` |
| `removeConnection(String, String)` | Remove connection | `Future<void>` |
| `addRoute(RouteConfig)` | Add route | `Future<void>` |
| `updateRoute(RouteConfig)` | Update route | `Future<void>` |
| `deleteRoute(String id)` | Delete route | `Future<void>` |
| `addFloor(FloorConfig)` | Add floor | `Future<void>` |
| `updateFloor(FloorConfig)` | Update floor | `Future<void>` |
| `deleteFloor(int)` | Delete floor | `Future<void>` |
| `exportConfiguration()` | Export as JSON | `Future<String>` |
| `importConfiguration(String)` | Import from JSON | `Future<void>` |

#### State Properties

```dart
class ConfigurationState extends Equatable {
  final ConfigurationStatus status;
  final NavigationConfig? config;
  final String? errorMessage;
  
  List<ConfigurableNode> get nodes;
  List<ConfigurableBeacon> get beacons;
  List<RouteConfig> get routes;
  MapLayoutConfig? get mapLayout;
}
```

---

### Models

#### NavigationConfig

```dart
class NavigationConfig extends Equatable {
  const NavigationConfig({
    List<ConfigurableNode> nodes = const [],
    List<ConfigurableBeacon> beacons = const [],
    List<RouteConfig> routes = const [],
    MapLayoutConfig mapLayout = const MapLayoutConfig(),
  });
  
  NavigationConfig copyWith({...});
  Map<String, dynamic> toJson();
  factory NavigationConfig.fromJson(Map<String, dynamic> json);
}
```

#### ConfigurableNode

```dart
class ConfigurableNode extends Equatable {
  const ConfigurableNode({
    required String id,
    required String name,
    required double x,
    required double y,
    required int floor,
    NodeType type = NodeType.waypoint,
    List<NodeConnection> connections = const [],
    String? linkedBeaconId,
  });
  
  ConfigurableNode copyWith({...});
  Map<String, dynamic> toJson();
  factory ConfigurableNode.fromJson(Map<String, dynamic> json);
}
```

#### ConfigurableBeacon

```dart
class ConfigurableBeacon extends Equatable {
  const ConfigurableBeacon({
    required String id,
    required String name,
    required String uid,
    String? namespaceId,
    String? instanceId,
    int? major,
    int? minor,
    required int floor,
    int txPower = -59,
    String? linkedNodeId,
  });
  
  ConfigurableBeacon copyWith({...});
  Map<String, dynamic> toJson();
  factory ConfigurableBeacon.fromJson(Map<String, dynamic> json);
}
```

#### NodeConnection

```dart
class NodeConnection extends Equatable {
  const NodeConnection({
    required String targetNodeId,
    ConnectionType type = ConnectionType.normal,
    bool isBidirectional = true,
    double? distance,
  });
  
  NodeConnection copyWith({...});
  Map<String, dynamic> toJson();
  factory NodeConnection.fromJson(Map<String, dynamic> json);
}
```

#### RouteConfig

```dart
class RouteConfig extends Equatable {
  const RouteConfig({
    required String id,
    required String name,
    required List<String> nodeIds,
    bool isActive = true,
  });
  
  RouteConfig copyWith({...});
  Map<String, dynamic> toJson();
  factory RouteConfig.fromJson(Map<String, dynamic> json);
}
```

#### FloorConfig

```dart
class FloorConfig extends Equatable {
  const FloorConfig({
    required int floorNumber,
    required String name,
    String? imagePath,
    String? imageBase64,
    bool isActive = true,
  });
  
  FloorConfig copyWith({...});
  Map<String, dynamic> toJson();
  factory FloorConfig.fromJson(Map<String, dynamic> json);
}
```

---

### Enums

#### NodeType
```dart
enum NodeType {
  waypoint,
  department,
  entrance,
  exit,
  stairs,
  elevator,
  emergency,
}
```

#### ConnectionType
```dart
enum ConnectionType {
  normal,
  emergency,
  staff,
  stairs,
  elevator,
}
```

#### NavigationStatus
```dart
enum NavigationStatus {
  initial,
  loading,
  mapLoaded,
  navigating,
  arrived,
  error,
}
```

#### BeaconStatus
```dart
enum BeaconStatus {
  initial,
  scanning,
  detected,
  error,
}
```

#### ConfigurationStatus
```dart
enum ConfigurationStatus {
  initial,
  loading,
  loaded,
  saving,
  saved,
  error,
}
```

---

## Widgets

### IndoorMapView

Main navigation map widget.

```dart
class IndoorMapView extends StatefulWidget {
  const IndoorMapView({
    Key? key,
    bool showConfigurationButton = false,
  });
}
```

### ConfigurationHomeScreen

Configuration menu screen.

```dart
class ConfigurationHomeScreen extends StatelessWidget {
  const ConfigurationHomeScreen({Key? key});
}
```

### MapEditorScreen

Visual map editor.

```dart
class MapEditorScreen extends StatefulWidget {
  const MapEditorScreen({Key? key});
}
```

---

## Helper Classes

### PathfindingHelper

```dart
class PathfindingHelper {
  static List<BeaconNode> dijkstraWithConfig(
    BeaconNode start,
    BeaconNode end,
    List<BeaconNode> allBeacons,
    Map<String, ConfigurableNode> configurableNodeMap,
  );
  
  static List<BeaconNode> findPathOnFloor(
    BeaconNode start,
    BeaconNode end,
    List<BeaconNode> allNodes,
    Map<String, ConfigurableNode> configurableNodeMap,
  );
  
  static double calculateDistance(BeaconNode a, BeaconNode b);
  static double calculateTotalDistance(List<BeaconNode> path);
}
```

### OneWayRestrictionHelper

```dart
class OneWayRestrictionHelper {
  static String? checkOneWayRestriction(
    BeaconNode start,
    BeaconNode end,
    Map<String, ConfigurableNode> configurableNodeMap,
  );
}
```

### FloorTransitionHelper

```dart
class FloorTransitionHelper {
  static List<Map<String, BeaconNode>> findFloorTransitions(
    int startFloor,
    int endFloor,
    List<BeaconNode> allNodes,
    Map<String, ConfigurableNode> configurableNodeMap,
  );
}
```

### InstructionGenerator

```dart
class InstructionGenerator {
  static List<String> generateInstructions(List<BeaconNode> path);
}
```
