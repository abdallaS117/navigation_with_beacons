# Beacon Troubleshooting Guide

## Issue: "Can't find new beacons, only see old two beacons"

### Root Cause
The system is scanning and detecting beacons correctly, but they're not showing up because:
1. No beacons are saved in the configuration
2. No beacon-to-node mappings exist

### Solution Steps

#### 1. Clear Old Data (if needed)
If you want to start completely fresh:
- Go to device Settings → Apps → Your App → Storage → Clear Data
- Or uninstall and reinstall the app

#### 2. Add Beacons to Configuration

**Option A: Use Beacon Scanner (Recommended)**
1. Open the app
2. Tap the menu icon (☰)
3. Select "Configuration"
4. Tap "Beacons" tab
5. Tap the Bluetooth scan icon (🔍) in the top-right
6. Wait for beacons to appear
7. Tap "Add All New" or tap individual beacons to add them

**Option B: Add Manually**
1. Go to Configuration → Beacons
2. Tap the "+" button
3. Enter beacon details:
   - UUID: E2C56DB5-DFFB-48D2-B060-D0F5A71096E0
   - Major: 0
   - Minor: 0
   - Name: Beacon 1
4. Repeat for each beacon

#### 3. Link Beacons to Nodes
After adding beacons, you must link them to map nodes:

1. Go to Configuration → Map Editor
2. Create nodes on the map (or use existing ones)
3. For each beacon:
   - Select the beacon from the list
   - Tap "Place on Map" 
   - Tap a location on the map to place it
   - The beacon will be linked to a node at that position

#### 4. Verify Configuration
Check the logs for:
```
✅ Loaded X beacons and Y nodes from configuration
📍 Beacon-to-node mappings: {beacon_id: node_id, ...}
✅ MATCH! Beacon beacon_XXX → Node node_YYY, RSSI: -XX
```

### Current Beacon Detection
Your beacons are being detected:
- **Beacon 1**: UUID=E2C56DB5-DFFB-48D2-B060-D0F5A71096E0, Major=0, Minor=0
- **Beacon 2**: UUID=E2C56DB5-DFFB-48D2-B060-D0F5A71096E1, Major=0, Minor=0

These will create beacon IDs:
- `beacon_E2C56DB5DFFB48D2B060D0F5A71096E0_0_0`
- `beacon_E2C56DB5DFFB48D2B060D0F5A71096E1_0_0`

### How the System Works

1. **Beacon Scanning**: Scans for ALL iBeacons in range (unlimited)
2. **Configuration Storage**: Beacons are stored in SharedPreferences
3. **Beacon-to-Node Mapping**: Each beacon must be linked to a node on the map
4. **Position Calculation**: Uses the nearest beacon's node position

### Debug Commands

Check what's saved:
```dart
// In your app, print the configuration
final config = await configurationRepository.getConfiguration();
print('Beacons: ${config.beacons.length}');
print('Nodes: ${config.nodes.length}');
```

### Important Notes

- The system supports **unlimited beacons** - no hardcoded limits
- Beacons must be **added to configuration** before they can be used
- Each beacon should be **linked to a node** for navigation to work
- The old static configuration has been commented out - everything is now dynamic
