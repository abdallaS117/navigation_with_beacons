# Multi-Beacon Protocol Support

## Overview
The app now supports **multiple beacon protocols**, not just iBeacon. This allows you to use various types of Bluetooth beacons for indoor navigation.

## Supported Beacon Types

### 1. **iBeacon** (Apple)
- **Manufacturer ID**: `0x004C` (Apple)
- **Signature**: `0x02 0x15`
- **Data**: UUID (16 bytes) + Major (2 bytes) + Minor (2 bytes) + TX Power (1 byte)
- **Beacon ID Format**: `beacon_{UUID}_{Major}_{Minor}`
- **Example**: `beacon_E2C56DB5DFFB48D2B060D0F5A71096E0_0_0`

### 2. **Eddystone** (Google)
- **Service UUID**: `0xFEAA`
- **Supported Frames**:
  - **Eddystone-UID** (0x00): Namespace + Instance
  - **Eddystone-URL** (0x10): Broadcasts a URL
  - **Eddystone-EID** (0x30): Encrypted ephemeral identifier
- **Beacon ID Format**: 
  - UID: `beacon_eddystone_{Namespace}_{Instance}`
  - URL: `beacon_eddystone_url_{URLHash}`
  - EID: `beacon_eddystone_eid_{EID}`

### 3. **AltBeacon** (Open Source)
- **Signature**: `0xBEAC`
- **Data**: UUID (16 bytes) + Major (2 bytes) + Minor (2 bytes) + TX Power (1 byte)
- **Beacon ID Format**: `beacon_{UUID}_{Major}_{Minor}`
- **Compatible with iBeacon format**

## How It Works

### Detection Process
The system scans all BLE devices and applies these filters in order:

1. **Check for iBeacon** (Apple manufacturer data with iBeacon signature)
2. **Check for Eddystone** (Service UUID 0xFEAA with frame types)
3. **Check for AltBeacon** (Any manufacturer data with 0xBEAC signature)

### Code Location
- **Main Detection**: `@/Users/abdallasamir/StudioProjects/navigation_with_becons/lib/features/navigation/data/datasources/hybrid_beacon_datasource.dart:263-385`
- **Scanner Dialog**: `@/Users/abdallasamir/StudioProjects/navigation_with_becons/lib/features/configuration/presentation/widgets/beacon_scanner_dialog.dart:123-236`

## Your Eddystone Beacons

Based on the nRF Connect screenshots, your beacons are **Eddystone beacons**. They should now be detected by the app.

### What You'll See
When you scan for beacons, you should now see:
```
🔍 Scanned Eddystone-UID: Namespace=..., Instance=... → beaconId=beacon_eddystone_...
```

### Adding Eddystone Beacons
1. Open the app
2. Go to **Configuration** → **Beacons**
3. Tap the **Bluetooth scan icon** (🔍)
4. You should now see your Eddystone beacons listed as **"Eddystone-UID 0-0"**
5. Tap **"Add All New"** to add them
6. Place them on the map by linking to nodes

## Beacon ID Generation

### iBeacon
```dart
beaconId = 'beacon_${UUID}_${Major}_${Minor}'
// Example: beacon_E2C56DB5DFFB48D2B060D0F5A71096E0_0_0
```

### Eddystone-UID
```dart
beaconId = 'beacon_eddystone_${Namespace}_${Instance}'
// Example: beacon_eddystone_A3C87500BED34BDF_8A39A01BEBEDE295
```

### AltBeacon
```dart
beaconId = 'beacon_${UUID}_${Major}_${Minor}'
// Same format as iBeacon
```

## Configuration Storage

All beacon types are stored in the same `ConfigurableBeacon` model with:
- **UUID**: Unique identifier (or pseudo-UUID for Eddystone)
- **Major/Minor**: Set to 0 for Eddystone beacons
- **TX Power**: Signal strength calibration
- **Beacon Type**: Displayed in UI (iBeacon, Eddystone-UID, AltBeacon)

## Testing

After the code changes, you should:
1. **Hot restart** the app (not just hot reload)
2. Open the beacon scanner
3. Look for logs showing:
   ```
   🔍 Scanned Eddystone-UID: ...
   🔍 Scanned iBeacon: ...
   🔍 Scanned AltBeacon: ...
   ```

## Troubleshooting

### Eddystone Beacons Not Appearing
- Ensure beacons are broadcasting **Eddystone-UID** frames (not just TLM or URL)
- Check that Bluetooth and location permissions are granted
- Verify beacons are powered on and in range

### Beacon Not Matching
- The beacon must be **added to configuration** first
- The beacon must be **linked to a node** on the map
- Check logs for "Available mappings" to see configured beacons

## Future Enhancements

Potential additions:
- **Eddystone-TLM**: Telemetry data (battery, temperature)
- **Eddystone-URL**: URL-based beacons
- **Custom Protocols**: Support for proprietary beacon formats
- **Beacon Filtering**: Filter by beacon type in UI
