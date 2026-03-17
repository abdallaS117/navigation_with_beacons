# Configuration Feature Documentation

## Overview

The configuration feature provides tools for setting up and managing indoor navigation maps, including node placement, beacon registration, connection configuration, and route management.

## Directory Structure

```
lib/features/configuration/
├── data/
│   ├── repositories/
│   │   └── configuration_repository.dart    # Configuration CRUD operations
│   └── services/
│       ├── configuration_storage_service.dart  # Local storage
│       └── firebase_configuration_service.dart # Firebase sync
├── domain/
│   └── models/
│       ├── configurable_beacon.dart         # Beacon configuration model
│       ├── configurable_node.dart           # Node with connections model
│       ├── map_layout_config.dart           # Map & floor configuration
│       ├── navigation_config.dart           # Complete configuration
│       ├── route_config.dart                # Pre-defined route model
│       └── models.dart                      # Barrel export
└── presentation/
    ├── logic/
    │   ├── configuration_cubit.dart         # State management
    │   └── configuration_state.dart
    ├── screens/
    │   ├── beacon_management_screen.dart    # Beacon list & registration
    │   ├── configuration_home_screen.dart   # Main config menu
    │   ├── map_editor_screen.dart           # Visual map editor
    │   ├── map_editor_handlers.dart         # Editor event handlers
    │   ├── node_editor_screen.dart          # Node details editor
    │   └── routes_management_screen.dart    # Route builder
    └── widgets/
        ├── add_floor_dialog.dart            # Add new floor
        ├── beacon_editor_dialog.dart        # Edit beacon details
        ├── beacon_scanner_dialog.dart       # Scan for BLE beacons
        ├── connection_config_dialog.dart    # Connection settings
        ├── connection_dialog.dart           # Create connection
        ├── edit_floor_dialog.dart           # Edit floor settings
        ├── map_editor_canvas.dart           # Interactive map canvas
        ├── map_editor_painter.dart          # Canvas rendering
        ├── map_editor_panels.dart           # Side panels
        ├── node_editor_dialog.dart          # Edit node details
        ├── route_editor_dialog.dart         # Edit route
        └── smart_map_image.dart             # Floor image display
```

---

## Domain Models

### NavigationConfig

Root configuration object containing all navigation data.

```dart
class NavigationConfig extends Equatable {
  final List<ConfigurableNode> nodes;       // All navigation nodes
  final List<ConfigurableBeacon> beacons;   // Registered beacons
  final List<RouteConfig> routes;           // Pre-defined routes
  final MapLayoutConfig mapLayout;          // Map display settings

  // Serialization
  Map<String, dynamic> toJson();
  factory NavigationConfig.fromJson(Map<String, dynamic> json);
}
```

### ConfigurableNode

Represents a navigation node with its connections.

```dart
class ConfigurableNode extends Equatable {
  final String id;                          // Unique identifier
  final String name;                        // Display name
  final double x, y;                        // Position (pixels)
  final int floor;                          // Floor number
  final NodeType type;                      // Node type enum
  final List<NodeConnection> connections;  // Outgoing connections
  final String? linkedBeaconId;             // Associated beacon

  // Copy with modifications
  ConfigurableNode copyWith({...});
  
  // Serialization
  Map<String, dynamic> toJson();
  factory ConfigurableNode.fromJson(Map<String, dynamic> json);
}
```

### NodeType

Enum defining node categories:

```dart
enum NodeType {
  waypoint,    // Navigation waypoint
  department,  // Destination (e.g., Reception, Lab)
  entrance,    // Building entrance
  exit,        // Building exit
  stairs,      // Staircase (floor transition)
  elevator,    // Elevator (floor transition)
  emergency,   // Emergency exit
}
```

### NodeConnection

Defines a connection between two nodes.

```dart
class NodeConnection extends Equatable {
  final String targetNodeId;        // Connected node ID
  final ConnectionType type;        // Connection type
  final bool isBidirectional;       // Two-way or one-way
  final double? distance;           // Optional distance override

  // Serialization
  Map<String, dynamic> toJson();
  factory NodeConnection.fromJson(Map<String, dynamic> json);
}
```

### ConnectionType

Enum defining connection access levels:

```dart
enum ConnectionType {
  normal,     // Standard corridor - anyone can use
  emergency,  // Emergency routes only
  staff,      // Staff-only access
  stairs,     // Staircase connection
  elevator,   // Elevator connection
}
```

### ConfigurableBeacon

Represents a registered BLE beacon.

```dart
class ConfigurableBeacon extends Equatable {
  final String id;              // Unique identifier
  final String name;            // Display name
  final String uid;             // Beacon UID (from BLE scan)
  final String? namespaceId;    // Eddystone namespace
  final String? instanceId;     // Eddystone instance
  final int? major;             // iBeacon major
  final int? minor;             // iBeacon minor
  final int floor;              // Floor number
  final int txPower;            // Transmission power (dBm)
  final String? linkedNodeId;   // Associated node

  // Serialization
  Map<String, dynamic> toJson();
  factory ConfigurableBeacon.fromJson(Map<String, dynamic> json);
}
```

### RouteConfig

Defines a pre-configured navigation route.

```dart
class RouteConfig extends Equatable {
  final String id;                  // Unique identifier
  final String name;                // Route name
  final List<String> nodeIds;       // Ordered list of node IDs
  final bool isActive;              // Route enabled/disabled

  // Serialization
  Map<String, dynamic> toJson();
  factory RouteConfig.fromJson(Map<String, dynamic> json);
}
```

### MapLayoutConfig

Map display and floor configuration.

```dart
class MapLayoutConfig extends Equatable {
  final double mapWidth;            // Map width in pixels
  final double mapHeight;           // Map height in pixels
  final MapOffset offset;           // Map offset
  final List<FloorConfig> floors;   // Floor configurations

  // Serialization
  Map<String, dynamic> toJson();
  factory MapLayoutConfig.fromJson(Map<String, dynamic> json);
}
```

### FloorConfig

Individual floor configuration.

```dart
class FloorConfig extends Equatable {
  final int floorNumber;            // Floor number (1, 2, 3...)
  final String name;                // Floor name ("Ground Floor")
  final String? imagePath;          // Local image path
  final String? imageBase64;        // Base64 encoded image
  final bool isActive;              // Floor enabled/disabled

  // Serialization
  Map<String, dynamic> toJson();
  factory FloorConfig.fromJson(Map<String, dynamic> json);
}
```

---

## Data Layer

### ConfigurationRepository

Central repository for all configuration operations.

```dart
class ConfigurationRepository {
  // Get current configuration
  Future<NavigationConfig> getConfiguration();
  
  // Save configuration (local + Firebase)
  Future<void> saveConfiguration(NavigationConfig config);
  
  // Force refresh from Firebase
  Future<NavigationConfig> refreshFromFirebase();
  
  // Node operations
  Future<void> addNode(ConfigurableNode node);
  Future<void> updateNode(ConfigurableNode node);
  Future<void> deleteNode(String nodeId);
  
  // Beacon operations
  Future<void> addBeacon(ConfigurableBeacon beacon);
  Future<void> updateBeacon(ConfigurableBeacon beacon);
  Future<void> deleteBeacon(String beaconId);
  
  // Connection operations
  Future<void> addConnection(String fromNodeId, NodeConnection connection);
  Future<void> removeConnection(String fromNodeId, String toNodeId);
  
  // Route operations
  Future<void> addRoute(RouteConfig route);
  Future<void> updateRoute(RouteConfig route);
  Future<void> deleteRoute(String routeId);
  
  // Import/Export
  Future<String> exportConfiguration();
  Future<void> importConfiguration(String jsonString);
}
```

### FirebaseConfigurationService

Handles Firebase Firestore synchronization.

```dart
class FirebaseConfigurationService {
  // Upload configuration to Firestore
  Future<void> uploadConfiguration(NavigationConfig config);
  
  // Download configuration from Firestore
  Future<NavigationConfig?> downloadConfiguration();
  
  // Check if remote config exists
  Future<bool> hasRemoteConfiguration();
}
```

**Base64 Image Encoding:**

When uploading, floor images are automatically encoded to Base64:

```dart
Future<NavigationConfig> _encodeFloorImages(NavigationConfig config) async {
  // For each floor with imagePath:
  // 1. Read file bytes
  // 2. Encode to Base64
  // 3. Store in imageBase64 field
  // 4. Clear imagePath (no longer needed)
}
```

### ConfigurationStorageService

Handles local storage using SharedPreferences.

```dart
class ConfigurationStorageService {
  // Save configuration locally
  Future<void> saveConfiguration(NavigationConfig config);
  
  // Load configuration from local storage
  Future<NavigationConfig?> loadConfiguration();
  
  // Clear local configuration
  Future<void> clearConfiguration();
}
```

---

## Presentation Layer

### ConfigurationCubit

Manages configuration state and operations.

**States:**
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

**Key Methods:**
```dart
// Load configuration
Future<void> loadConfiguration();

// Save configuration to local + Firebase
Future<void> saveConfiguration();

// Force refresh from Firebase
Future<void> refreshFromFirebase();

// Node operations
Future<void> addNode(ConfigurableNode node);
Future<void> updateNode(ConfigurableNode node);
Future<void> deleteNode(String nodeId);

// Beacon operations
Future<void> addBeacon(ConfigurableBeacon beacon);
Future<void> updateBeacon(ConfigurableBeacon beacon);
Future<void> deleteBeacon(String beaconId);

// Connection operations
Future<void> addConnection(String fromId, NodeConnection conn);
Future<void> updateConnection(String fromId, NodeConnection conn);
Future<void> removeConnection(String fromId, String toId);

// Route operations
Future<void> addRoute(RouteConfig route);
Future<void> updateRoute(RouteConfig route);
Future<void> deleteRoute(String routeId);

// Floor operations
Future<void> addFloor(FloorConfig floor);
Future<void> updateFloor(FloorConfig floor);
Future<void> deleteFloor(int floorNumber);

// Import/Export
Future<String> exportConfiguration();
Future<void> importConfiguration(String json);
```

### ConfigurationHomeScreen

Main configuration menu with options:

- **Map Editor** - Visual node/connection editor
- **Beacon Management** - Register and configure beacons
- **Routes Management** - Create pre-defined routes
- **Import/Export** - Backup and restore configuration
- **Save to Firebase** - Upload configuration

### MapEditorScreen

Visual editor for placing nodes and creating connections.

**Features:**
- Interactive canvas with zoom/pan
- Floor selector for multi-floor editing
- Toolbar for adding nodes, beacons, connections
- Selection panels for editing selected items
- Grid overlay for alignment
- Undo/redo support

**Toolbar Actions:**
| Action | Description |
|--------|-------------|
| Add Node | Place new navigation node |
| Add Beacon | Place beacon marker |
| Connect | Create connection between nodes |
| Delete | Remove selected item |
| Edit | Open editor dialog |

**Canvas Interactions:**
- **Tap**: Select node/beacon/connection
- **Long press**: Open context menu
- **Drag**: Move selected node
- **Two-finger**: Zoom/pan

### MapEditorCanvas

Custom widget for rendering the map editor.

```dart
class MapEditorCanvas extends StatefulWidget {
  final NavigationConfig config;
  final int currentFloor;
  final String? selectedNodeId;
  final String? selectedBeaconId;
  final Function(String) onNodeSelected;
  final Function(String) onBeaconSelected;
  final Function(Offset) onCanvasTap;
}
```

**Rendering Layers:**
1. Floor image (if configured)
2. Grid overlay
3. Connections (lines between nodes)
4. Route paths (if route selected)
5. Nodes (circles with labels)
6. Beacons (diamond markers)
7. Selection highlight

### SmartMapImage

Intelligent image widget that handles multiple sources.

```dart
class SmartMapImage extends StatelessWidget {
  final String? imagePath;      // Local file or asset path
  final String? imageBase64;    // Base64 encoded image
  final double width, height;
  final BoxFit fit;
}
```

**Image Source Priority:**
1. `imageBase64` - Decode and display
2. `imagePath` starting with `/` - Load from file
3. `imagePath` - Load from assets
4. Fallback - Show placeholder

### Connection Dialogs

#### ConnectionDialog
Create new connection between nodes.

#### ConnectionConfigDialog
Configure connection properties:
- **Type**: normal, emergency, staff, stairs, elevator
- **Direction**: bidirectional or one-way
- **Distance**: optional override

### BeaconScannerDialog

Scan for nearby BLE beacons and register them.

**Features:**
- Real-time beacon discovery
- Signal strength display
- Auto-detection of beacon type (Eddystone/iBeacon)
- One-tap registration

---

## Usage Examples

### Add a New Node

```dart
final node = ConfigurableNode(
  id: 'node_reception',
  name: 'Reception',
  x: 200,
  y: 300,
  floor: 1,
  type: NodeType.department,
  connections: [],
);

context.read<ConfigurationCubit>().addNode(node);
```

### Create a Connection

```dart
final connection = NodeConnection(
  targetNodeId: 'node_corridor',
  type: ConnectionType.normal,
  isBidirectional: true,
);

context.read<ConfigurationCubit>().addConnection(
  'node_reception',
  connection,
);
```

### Register a Beacon

```dart
final beacon = ConfigurableBeacon(
  id: 'beacon_001',
  name: 'Reception Beacon',
  uid: 'AA:BB:CC:DD:EE:FF',
  floor: 1,
  txPower: -59,
  linkedNodeId: 'node_reception',
);

context.read<ConfigurationCubit>().addBeacon(beacon);
```

### Create a Pre-defined Route

```dart
final route = RouteConfig(
  id: 'route_entrance_to_lab',
  name: 'Entrance to Lab',
  nodeIds: ['node_entrance', 'node_corridor', 'node_lab'],
  isActive: true,
);

context.read<ConfigurationCubit>().addRoute(route);
```

### Save Configuration to Firebase

```dart
await context.read<ConfigurationCubit>().saveConfiguration();
// This saves locally AND uploads to Firebase
```

### Refresh from Firebase

```dart
await context.read<ConfigurationCubit>().refreshFromFirebase();
// Downloads latest config from Firebase and updates local state
```
