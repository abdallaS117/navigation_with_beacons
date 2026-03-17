# Quick Start Guide

## Installation

### 1. Add Dependency

```yaml
# pubspec.yaml
dependencies:
  beacon_navigation:
    git:
      url: https://github.com/abdallaS117/navigation_with_beacons.git
```

### 2. Install

```bash
flutter pub get
```

### 3. Add Permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth for indoor navigation.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app uses location for indoor navigation.</string>
```

---

## Basic Setup

### 1. Initialize Firebase

```dart
// main.dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}
```

### 2. Create Repositories

```dart
import 'package:beacon_navigation/beacon_navigation.dart';

// Create configuration repository
final configRepository = ConfigurationRepository(
  storageService: ConfigurationStorageService(),
  firebaseService: FirebaseConfigurationService(),
);

// Create beacon data source
final beaconDataSource = HybridBeaconDataSource(
  configurationRepository: configRepository,
);

// Create repositories
final beaconRepository = BeaconRepositoryImpl(
  beaconDataSource: beaconDataSource,
);

final navigationRepository = NavigationRepositoryImpl(
  mapDataSource: StaticMapDataSource(),
  beaconDataSource: beaconDataSource,
  configurationRepository: configRepository,
);
```

### 3. Setup BLoC Providers

```dart
MultiBlocProvider(
  providers: [
    BlocProvider(
      create: (_) => ConfigurationCubit(configRepository)..loadConfiguration(),
    ),
    BlocProvider(
      create: (_) => BeaconCubit(beaconRepository)..startScanning(),
    ),
    BlocProvider(
      create: (_) => NavigationCubit(
        navigationRepository: navigationRepository,
        beaconRepository: beaconRepository,
      )..initialize(),
    ),
  ],
  child: MaterialApp(
    home: IndoorMapView(showConfigurationButton: true),
  ),
)
```

---

## Configuration Workflow

### Step 1: Open Map Editor

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => BlocProvider.value(
      value: context.read<ConfigurationCubit>(),
      child: const ConfigurationHomeScreen(),
    ),
  ),
);
```

### Step 2: Add Floor Image

1. Go to **Map Editor**
2. Tap **Floor Settings** (gear icon)
3. Select floor image from gallery
4. Adjust map dimensions if needed

### Step 3: Place Nodes

1. Select **Add Node** tool
2. Tap on map to place node
3. Set node properties:
   - Name (e.g., "Reception")
   - Type (waypoint, department, stairs, etc.)

### Step 4: Create Connections

1. Select **Connect** tool
2. Tap first node
3. Tap second node
4. Configure connection:
   - Type (normal, emergency, staff)
   - Direction (bidirectional or one-way)

### Step 5: Register Beacons

1. Go to **Beacon Management**
2. Tap **Scan for Beacons**
3. Select detected beacon
4. Link to a node
5. Set TX power (calibrate at 1 meter)

### Step 6: Save Configuration

1. Tap **Save** button
2. Configuration saves locally AND to Firebase

---

## Navigation Usage

### Select Destination

```dart
// User selects from department list
context.read<NavigationCubit>().selectDestination(department);
```

### Start Navigation

```dart
// Requires current position from beacon
context.read<NavigationCubit>().startNavigation();
```

### Cancel Navigation

```dart
context.read<NavigationCubit>().cancelNavigation();
```

### Handle Navigation Events

```dart
BlocListener<NavigationCubit, NavigationState>(
  listener: (context, state) {
    if (state.status == NavigationStatus.arrived) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Arrived!'),
          content: Text('You have reached ${state.selectedDestination?.name}'),
        ),
      );
    }
    
    if (state.errorMessage != null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Cannot Navigate'),
          content: Text(state.errorMessage!),
        ),
      );
    }
  },
  child: IndoorMapView(),
)
```

---

## Common Tasks

### Refresh Configuration from Firebase

```dart
await context.read<ConfigurationCubit>().refreshFromFirebase();
await context.read<BeaconCubit>().reloadConfiguration();
await context.read<NavigationCubit>().initialize();
```

### Change Floor

```dart
context.read<NavigationCubit>().changeFloor(2);
```

### Export Configuration

```dart
final json = await context.read<ConfigurationCubit>().exportConfiguration();
// Save to file or share
```

### Import Configuration

```dart
final json = await loadJsonFromFile();
await context.read<ConfigurationCubit>().importConfiguration(json);
```

---

## Troubleshooting

### "No route found"

- Check that nodes are connected
- Verify connection directions (one-way vs bidirectional)
- Ensure destination has a linked beacon

### Beacon not detected

- Check Bluetooth is enabled
- Verify permissions are granted
- Confirm beacon UID matches configuration
- Check beacon battery

### Position jumping

- Add more beacons for better coverage
- Calibrate TX power values
- Reduce beacon advertising interval

### Configuration not syncing

- Check Firebase connection
- Verify Firebase rules allow read/write
- Check internet connectivity
