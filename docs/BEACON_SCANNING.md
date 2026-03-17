# Beacon Scanning & Positioning

## Overview

This document explains how the app scans for BLE beacons, processes signal data, and calculates user position.

---

## Beacon Types Supported

### Eddystone

Google's open beacon format.

```dart
class EddystoneBeacon {
  final String namespaceId;  // 10-byte namespace
  final String instanceId;   // 6-byte instance
  final int txPower;         // Calibrated TX power at 0m
}
```

### iBeacon

Apple's beacon format.

```dart
class IBeacon {
  final String uuid;    // 16-byte UUID
  final int major;      // 2-byte major value
  final int minor;      // 2-byte minor value
  final int txPower;    // Calibrated TX power at 1m
}
```

---

## Scanning Process

### 1. Start Scanning

```dart
Future<void> startScanning() async {
  // Check Bluetooth permissions
  final hasPermission = await _checkBluetoothPermissions();
  if (!hasPermission) {
    throw Exception('Bluetooth permission denied');
  }
  
  // Start BLE scan
  await FlutterBluePlus.startScan(
    timeout: const Duration(seconds: 30),
    androidScanMode: AndroidScanMode.lowLatency,
  );
  
  // Listen to scan results
  _scanSubscription = FlutterBluePlus.scanResults.listen(_processScanResults);
}
```

### 2. Process Scan Results

```dart
void _processScanResults(List<ScanResult> results) {
  for (final result in results) {
    // Parse beacon data
    final beaconData = _parseBeaconData(result);
    if (beaconData == null) continue;
    
    // Match to configured beacon
    final configuredBeacon = _findConfiguredBeacon(beaconData.uid);
    if (configuredBeacon == null) continue;
    
    // Update RSSI history for smoothing
    _updateRssiHistory(configuredBeacon.id, result.rssi);
    
    // Calculate smoothed RSSI
    final smoothedRssi = _calculateSmoothedRssi(configuredBeacon.id);
    
    // Convert to distance
    final distance = _rssiToDistance(smoothedRssi, configuredBeacon.txPower);
    
    // Store beacon with distance
    _detectedBeacons[configuredBeacon.id] = DetectedBeacon(
      beacon: configuredBeacon,
      rssi: smoothedRssi,
      distance: distance,
      lastSeen: DateTime.now(),
    );
  }
  
  // Calculate position and emit nearest beacon
  _calculatePosition();
}
```

### 3. Parse Beacon Data

```dart
BeaconData? _parseBeaconData(ScanResult result) {
  final manufacturerData = result.advertisementData.manufacturerData;
  final serviceData = result.advertisementData.serviceData;
  
  // Try Eddystone
  if (serviceData.containsKey('0xFEAA')) {
    return EddystoneParser.parse(serviceData['0xFEAA']!);
  }
  
  // Try iBeacon (Apple manufacturer ID: 0x004C)
  if (manufacturerData.containsKey(0x004C)) {
    return IBeaconParser.parse(manufacturerData[0x004C]!);
  }
  
  // Fallback to device address
  return BeaconData(uid: result.device.remoteId.str);
}
```

---

## RSSI Processing

### Signal Smoothing

Raw RSSI values are noisy. We use exponential moving average (EMA) for smoothing:

```dart
double _calculateSmoothedRssi(String beaconId) {
  final history = _rssiHistory[beaconId] ?? [];
  if (history.isEmpty) return -100;
  
  // Exponential moving average
  const alpha = 0.3;  // Smoothing factor
  double smoothed = history.first.toDouble();
  
  for (int i = 1; i < history.length; i++) {
    smoothed = alpha * history[i] + (1 - alpha) * smoothed;
  }
  
  return smoothed;
}
```

### RSSI to Distance Conversion

```dart
double _rssiToDistance(double rssi, int txPower) {
  // Path loss model: RSSI = TxPower - 10 * n * log10(d)
  // Solving for d: d = 10 ^ ((TxPower - RSSI) / (10 * n))
  
  const n = 2.0;  // Path loss exponent (2.0 for free space, higher for obstacles)
  
  if (rssi >= txPower) {
    return 0.1;  // Very close
  }
  
  final distance = pow(10, (txPower - rssi) / (10 * n));
  return distance.toDouble();
}
```

### Path Loss Exponent (n)

| Environment | n Value |
|-------------|---------|
| Free space | 2.0 |
| Indoor (line of sight) | 2.0 - 2.5 |
| Indoor (obstacles) | 2.5 - 3.0 |
| Indoor (walls) | 3.0 - 4.0 |

---

## Position Calculation

### Single Beacon (Nearest)

When only one beacon is detected or for simple positioning:

```dart
BeaconNode? _findNearestBeacon() {
  if (_detectedBeacons.isEmpty) return null;
  
  // Filter by signal strength threshold
  final validBeacons = _detectedBeacons.values
      .where((b) => b.rssi > _rssiThreshold)
      .where((b) => DateTime.now().difference(b.lastSeen).inSeconds < 5)
      .toList();
  
  if (validBeacons.isEmpty) return null;
  
  // Sort by distance (closest first)
  validBeacons.sort((a, b) => a.distance.compareTo(b.distance));
  
  return validBeacons.first.beacon;
}
```

### Weighted Position (Multiple Beacons)

For more accurate positioning using multiple beacons:

```dart
Position _calculateWeightedPosition() {
  final validBeacons = _getValidBeacons();
  if (validBeacons.isEmpty) return Position.unknown;
  
  double totalWeight = 0;
  double weightedX = 0;
  double weightedY = 0;
  
  for (final detected in validBeacons) {
    // Weight inversely proportional to distance squared
    final weight = 1.0 / (detected.distance * detected.distance);
    
    weightedX += detected.beacon.x * weight;
    weightedY += detected.beacon.y * weight;
    totalWeight += weight;
  }
  
  return Position(
    x: weightedX / totalWeight,
    y: weightedY / totalWeight,
    floor: validBeacons.first.beacon.floor,
  );
}
```

### Route-Constrained Positioning

When navigating, position is constrained to the route path:

```dart
BeaconNode _calculateRouteConstrainedPosition(
  List<DetectedBeacon> detectedBeacons,
  NavigationRoute activeRoute,
) {
  // Find which route segment we're on
  final nearestSegment = _findNearestRouteSegment(detectedBeacons, activeRoute);
  
  // Project position onto segment
  final projectedPosition = _projectOntoSegment(
    _calculateWeightedPosition(),
    nearestSegment.start,
    nearestSegment.end,
  );
  
  return BeaconNode(
    uid: 'interpolated',
    name: 'Current Position',
    x: projectedPosition.x,
    y: projectedPosition.y,
    floor: nearestSegment.start.floor,
  );
}
```

---

## Beacon Configuration

### Registering a Beacon

```dart
final beacon = ConfigurableBeacon(
  id: 'beacon_reception',
  name: 'Reception Beacon',
  uid: 'AA:BB:CC:DD:EE:FF',  // From BLE scan
  floor: 1,
  txPower: -59,  // Calibrated at 1 meter
  linkedNodeId: 'node_reception',
);
```

### TX Power Calibration

1. Place phone exactly 1 meter from beacon
2. Record average RSSI over 30 seconds
3. Use this value as `txPower`

Typical values:
- Strong beacon: -50 to -60 dBm
- Medium beacon: -60 to -70 dBm
- Weak beacon: -70 to -80 dBm

---

## Beacon Status Widget

Displays current beacon connection status:

```dart
class BeaconStatusWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    return BlocBuilder<BeaconCubit, BeaconState>(
      builder: (context, state) {
        switch (state.status) {
          case BeaconStatus.initial:
            return _buildStatus('Initializing...', Colors.grey);
          case BeaconStatus.scanning:
            return _buildStatus('Scanning...', Colors.blue);
          case BeaconStatus.detected:
            return _buildStatus(
              'Connected: ${state.currentBeacon?.name}',
              Colors.green,
            );
          case BeaconStatus.error:
            return _buildStatus('Error: ${state.errorMessage}', Colors.red);
        }
      },
    );
  }
}
```

---

## Permissions

### Android

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

### iOS

```xml
<!-- Info.plist -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to detect nearby beacons.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to detect nearby beacons.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app uses your location for indoor navigation.</string>
```

### Runtime Permission Check

```dart
Future<bool> _checkBluetoothPermissions() async {
  // Check Bluetooth status
  final bluetoothStatus = await Permission.bluetooth.status;
  if (!bluetoothStatus.isGranted) {
    final result = await Permission.bluetooth.request();
    if (!result.isGranted) return false;
  }
  
  // Check Bluetooth scan permission (Android 12+)
  final scanStatus = await Permission.bluetoothScan.status;
  if (!scanStatus.isGranted) {
    final result = await Permission.bluetoothScan.request();
    if (!result.isGranted) return false;
  }
  
  // Check location permission
  final locationStatus = await Permission.locationWhenInUse.status;
  if (!locationStatus.isGranted) {
    final result = await Permission.locationWhenInUse.request();
    if (!result.isGranted) return false;
  }
  
  return true;
}
```

---

## Troubleshooting

### Beacon Not Detected

1. **Check beacon battery** - Low battery reduces signal strength
2. **Check beacon advertising interval** - Should be 100-300ms
3. **Check permissions** - Bluetooth and location must be granted
4. **Check beacon UID** - Must match configured value exactly

### Inaccurate Position

1. **Calibrate TX power** - Measure at exactly 1 meter
2. **Adjust path loss exponent** - Higher for more obstacles
3. **Add more beacons** - Better coverage improves accuracy
4. **Check beacon placement** - Avoid metal surfaces and corners

### Slow Detection

1. **Reduce advertising interval** - Faster detection but more battery
2. **Increase scan window** - More time scanning
3. **Check for interference** - WiFi, other Bluetooth devices
