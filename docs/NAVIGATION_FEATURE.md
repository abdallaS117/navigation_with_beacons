# Navigation Feature Documentation

## Overview

The navigation feature handles indoor positioning using BLE beacons and provides pathfinding capabilities for indoor navigation.

## Directory Structure

```
lib/features/navigation/
├── data/
│   ├── datasources/
│   │   ├── hybrid_beacon_datasource.dart   # BLE beacon scanning
│   │   └── map_datasource.dart             # Map data interface
│   ├── helpers/
│   │   ├── beacon_position_calculator.dart # Position interpolation
│   │   ├── eddystone_parser.dart           # Eddystone beacon parsing
│   │   ├── floor_transition_helper.dart    # Multi-floor navigation
│   │   ├── instruction_generator.dart      # Turn-by-turn instructions
│   │   ├── one_way_restriction_helper.dart # One-way validation
│   │   └── pathfinding_helper.dart         # Dijkstra algorithm
│   ├── providers/
│   │   ├── static_beacon_configuration.dart
│   │   └── static_map_provider.dart
│   └── repositories/
│       ├── beacon_repository_impl.dart     # Beacon data management
│       └── navigation_repository_impl.dart # Route calculation
├── domain/
│   ├── entities/
│   │   ├── beacon_node.dart                # Beacon/node entity
│   │   ├── department.dart                 # Department/destination
│   │   ├── floor_map.dart                  # Floor map data
│   │   ├── map_element.dart                # Map UI elements
│   │   └── navigation_route.dart           # Calculated route
│   ├── repositories/
│   │   ├── beacon_repository.dart          # Abstract interface
│   │   └── navigation_repository.dart      # Abstract interface
│   └── usecases/
│       ├── calculate_route.dart
│       ├── calculate_route_progress.dart
│       ├── get_departments.dart
│       ├── get_floor_map.dart
│       └── get_nearest_beacon.dart
└── presentation/
    ├── logic/
    │   ├── beacon_cubit.dart               # Beacon state management
    │   ├── beacon_state.dart
    │   ├── navigation_cubit.dart           # Navigation state management
    │   └── navigation_state.dart
    ├── views/
    │   └── indoor_map_view.dart            # Main map screen
    └── widgets/
        ├── beacon_status_widget.dart       # Beacon connection status
        ├── department_selector.dart        # Destination picker
        ├── floor_selector.dart             # Floor switcher
        ├── indoor_map_painter.dart         # Map rendering
        ├── navigation_info_panel.dart      # Route info display
        ├── route_painter.dart              # Route line drawing
        └── user_arrow.dart                 # User position indicator
```

---

## Domain Layer

### Entities

#### `BeaconNode`
Represents a physical beacon or navigation node.

```dart
class BeaconNode extends Equatable {
  final String uid;              // Unique identifier
  final String name;             // Display name
  final double x, y;             // Position coordinates (pixels)
  final int floor;               // Floor number
  final String? departmentId;    // Associated department
  final bool isNavigable;        // Can be used for navigation
  final List<String> connectedNodes;  // Connected node IDs
}
```

#### `NavigationRoute`
Represents a calculated navigation path.

```dart
class NavigationRoute extends Equatable {
  final List<BeaconNode> nodes;      // Ordered list of nodes in path
  final double totalDistance;         // Total distance in pixels
  final int estimatedTimeSeconds;     // Estimated travel time
  final List<String> instructions;    // Turn-by-turn instructions

  bool get isEmpty => nodes.isEmpty;
  bool get isNotEmpty => nodes.isNotEmpty;
  BeaconNode? get startNode;
  BeaconNode? get endNode;
  List<int> get floorsInRoute;
  bool requiresFloorChange();
}
```

#### `Department`
Represents a navigable destination.

```dart
class Department extends Equatable {
  final String id;
  final String name;
  final int floor;
  final String? iconName;
}
```

### Repository Interfaces

#### `BeaconRepository`
```dart
abstract class BeaconRepository {
  Stream<BeaconNode?> get nearestBeaconStream;
  Future<void> startScanning();
  Future<void> stopScanning();
  Future<List<BeaconNode>> getAllBeacons();
  Future<List<BeaconNode>> getBeaconsByFloor(int floor);
  Future<void> reloadConfiguration();
  void setActiveRoute(NavigationRoute? route);
}
```

#### `NavigationRepository`
```dart
abstract class NavigationRepository {
  Future<NavigationRoute> calculateRoute(BeaconNode start, BeaconNode end);
  Future<FloorMap?> getFloorMap(int floor);
  Future<List<FloorMap>> getAllFloorMaps();
  Future<List<Department>> getAllDepartments();
  Future<BeaconNode?> getBeaconForDepartment(String departmentId);
}
```

---

## Data Layer

### HybridBeaconDataSource

Handles BLE beacon scanning and position calculation.

**Key Methods:**
```dart
// Start scanning for beacons
Future<void> startScanning();

// Stop scanning
Future<void> stopScanning();

// Stream of nearest detected beacon
Stream<BeaconNode?> get nearestBeaconStream;

// Reload beacon configuration from repository
Future<void> reloadConfiguration();
```

**RSSI Processing:**
- Filters beacons by signal strength threshold
- Applies smoothing to reduce noise
- Converts RSSI to distance estimate
- Calculates weighted position from multiple beacons

### NavigationRepositoryImpl

Implements route calculation with multiple strategies.

**Route Calculation Flow:**
```
calculateRoute(start, end)
    │
    ├─► _tryPreConfiguredRoutes()
    │       │
    │       ├─► Check 1: Both nodes in same route
    │       ├─► Check 2: Destination is last node
    │       └─► Check 3: Both nodes exist, extract segment
    │
    ├─► (if multi-floor) _calculateMultiFloorRoute()
    │       │
    │       └─► Find transition points (stairs/elevator)
    │
    └─► _calculateSameFloorRoute()
            │
            ├─► OneWayRestrictionHelper.checkOneWayRestriction()
            └─► PathfindingHelper.dijkstraWithConfig()
```

### PathfindingHelper

Implements Dijkstra's algorithm with connection constraints.

```dart
/// Dijkstra algorithm respecting connection directions
static List<BeaconNode> dijkstraWithConfig(
  BeaconNode start,
  BeaconNode end,
  List<BeaconNode> allBeacons,
  Map<String, ConfigurableNode> configurableNodeMap,
);

/// Get valid neighbors considering one-way restrictions
static Set<String> _getValidNeighbors(
  String currentUid,
  Map<String, ConfigurableNode> configurableNodeMap,
);
```

**Valid Neighbors Logic:**
1. Add all direct outgoing connections
2. Add incoming connections ONLY if they are bidirectional

### OneWayRestrictionHelper

Validates that routes respect one-way connection constraints.

```dart
/// Check if route is blocked by one-way restrictions
/// Returns error message if blocked, null if allowed
static String? checkOneWayRestriction(
  BeaconNode start,
  BeaconNode end,
  Map<String, ConfigurableNode> configurableNodeMap,
);

/// Recursive check if target is reachable from source
static bool _canReachNode(
  String sourceId,
  String targetId,
  Map<String, ConfigurableNode> configurableNodeMap,
  Set<String> visited,
);
```

### FloorTransitionHelper

Handles navigation across multiple floors.

```dart
/// Find all valid floor transition points
static List<Map<String, BeaconNode>> findFloorTransitions(
  int startFloor,
  int endFloor,
  List<BeaconNode> allNodes,
  Map<String, ConfigurableNode> configurableNodeMap,
);
```

### InstructionGenerator

Generates human-readable navigation instructions.

```dart
/// Generate turn-by-turn instructions from path
static List<String> generateInstructions(List<BeaconNode> path);
```

**Example Output:**
- "Start at Reception"
- "Turn left and continue to Corridor"
- "Take the elevator to Floor 2"
- "You have arrived at Radiology"

---

## Presentation Layer

### NavigationCubit

Manages navigation state and coordinates with beacon scanning.

**States:**
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

**Key Methods:**
```dart
// Initialize navigation system
Future<void> initialize();

// Start navigation to selected destination
Future<void> startNavigation();

// Cancel current navigation
void cancelNavigation();

// Change current floor
Future<void> changeFloor(int floor);

// Select destination department
Future<void> selectDestination(Department department);

// Update compass heading
void updateCompassHeading(double heading);
```

**Navigation Progress:**
- Listens to beacon position changes
- Updates `currentRouteIndex` as user progresses
- Detects arrival at destination (within threshold)
- Auto-switches floor when beacon detected on different floor

### BeaconCubit

Manages beacon scanning state.

**States:**
```dart
enum BeaconStatus {
  initial,
  scanning,
  detected,
  error,
}
```

**Key Methods:**
```dart
// Start BLE scanning
Future<void> startScanning();

// Stop scanning
Future<void> stopScanning();

// Reload configuration and restart scanning
Future<void> reloadConfiguration();
```

### IndoorMapView

Main map display widget with navigation UI.

**Features:**
- Interactive map with zoom/pan (InteractiveViewer)
- Floor selector for multi-floor buildings
- Department selector for choosing destination
- Route visualization with RoutePainter
- User position arrow with compass heading
- Navigation info panel with progress
- Refresh button for Firebase sync
- Configuration button for map editor

**Key Widgets Used:**
- `SmartMapImage` - Displays floor plan image
- `RoutePainter` - Draws navigation path
- `UserArrow` - Shows user position and heading
- `NavigationInfoPanel` - Shows route info and progress
- `FloorSelector` - Floor switching buttons
- `DepartmentSelector` - Destination picker
- `BeaconStatusWidget` - Connection status indicator

### RoutePainter

Custom painter for drawing navigation routes.

```dart
class RoutePainter extends CustomPainter {
  final NavigationRoute? route;
  final int currentFloor;
  final int currentNodeIndex;
  final double animationProgress;
  final BeaconNode? destinationNode;

  void paint(Canvas canvas, Size size) {
    // Draw route line from current position to destination
    _drawRouteLine(canvas, floorNodes);
    
    // Draw destination marker with animation
    _drawDestinationMarker(canvas, destinationNode);
  }
}
```

**Drawing Behavior:**
- Only draws path from current position forward
- Uses glow effect for visibility
- Animated destination marker with pulsing effect

### UserArrow

Displays user position with directional arrow.

```dart
class UserArrow extends StatelessWidget {
  final double x, y;      // Position coordinates
  final double heading;   // Compass heading in degrees
  final bool isAnimating; // Animation state
}
```

---

## Usage Examples

### Start Navigation

```dart
// 1. Select destination
context.read<NavigationCubit>().selectDestination(department);

// 2. Start navigation (requires current position from beacon)
context.read<NavigationCubit>().startNavigation();
```

### Handle Navigation Events

```dart
BlocListener<NavigationCubit, NavigationState>(
  listener: (context, state) {
    if (state.status == NavigationStatus.arrived) {
      // Show arrival notification
    }
    if (state.errorMessage != null) {
      // Show error dialog (e.g., "No route found")
    }
  },
  child: // ...
)
```

### Refresh Configuration

```dart
// Refresh from Firebase and restart beacon scanning
await context.read<ConfigurationCubit>().refreshFromFirebase();
await context.read<BeaconCubit>().reloadConfiguration();
await context.read<NavigationCubit>().initialize();
```
