# Beacon Navigation

A Flutter package for indoor navigation using BLE beacons. Provides beacon scanning, pathfinding, map configuration, and route management for indoor navigation systems.

## Features

- **BLE Beacon Scanning** - Detect and track nearby Bluetooth Low Energy beacons
- **Indoor Positioning** - Calculate user position based on beacon signal strength (RSSI)
- **Pathfinding** - Dijkstra-based routing with support for one-way corridors
- **Map Configuration** - Visual map editor for configuring nodes, connections, and routes
- **Route Management** - Create and manage predefined routes with direction constraints
- **Connection Types** - Support for normal, emergency, staff-only, stairs, and elevator connections
- **Multi-floor Support** - Navigate across multiple floors with floor transitions

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  beacon_navigation:
    git:
      url: https://github.com/abdallaS117/navigation_with_beacons.git
```

Then run:

```bash
flutter pub get
```

## Usage

### Basic Import

```dart
import 'package:beacon_navigation/beacon_navigation.dart';
```

### Initialize Navigation

```dart
// Create repository instances
final beaconRepository = BeaconRepositoryImpl();
final navigationRepository = NavigationRepositoryImpl();

// Use with BLoC/Cubit
final navigationCubit = NavigationCubit(
  navigationRepository: navigationRepository,
  beaconRepository: beaconRepository,
);
```

### Display Indoor Map

```dart
IndoorMapView(
  floorMap: floorMap,
  userPosition: currentPosition,
  route: calculatedRoute,
  onDestinationSelected: (department) {
    // Handle destination selection
  },
)
```

### Configuration UI

```dart
// Open the map editor for configuration
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const ConfigurationHomeScreen(),
  ),
);
```

### Calculate Route

```dart
final route = await navigationRepository.calculateRoute(
  startNode: currentBeacon,
  endNode: destinationBeacon,
);
```

## Configuration Features

The package includes a complete configuration UI:

- **Map Editor** - Visual editor for placing nodes and connections
- **Beacon Management** - Register and configure BLE beacons
- **Route Builder** - Create predefined routes
- **Connection Configuration** - Set direction (one-way/two-way) and type (normal/emergency/staff)

## Permissions

Add these permissions to your app:

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to detect nearby beacons for indoor navigation.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to detect nearby beacons for indoor navigation.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app uses your location for indoor navigation.</string>
```

## Dependencies

- `flutter_bloc` - State management
- `flutter_blue_plus` - Bluetooth Low Energy scanning
- `permission_handler` - Runtime permissions
- `equatable` - Value equality
- `shared_preferences` - Local storage

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
