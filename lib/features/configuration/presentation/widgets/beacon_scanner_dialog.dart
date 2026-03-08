import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../../domain/models/configurable_beacon.dart';

class BeaconScannerDialog extends StatefulWidget {
  final List<ConfigurableBeacon> existingBeacons;
  
  const BeaconScannerDialog({
    super.key,
    this.existingBeacons = const [],
  });

  @override
  State<BeaconScannerDialog> createState() => _BeaconScannerDialogState();
}

class _BeaconScannerDialogState extends State<BeaconScannerDialog> {
  final Map<String, _DiscoveredBeacon> _discoveredBeacons = {};
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  String _statusMessage = 'Ready to scan';
  Set<String> _existingBeaconKeys = {};

  @override
  void initState() {
    super.initState();
    _existingBeaconKeys = widget.existingBeacons
        .map((b) => '${b.uuid}-${b.major}-${b.minor}')
        .toSet();
    _startScanning();
  }

  @override
  void dispose() {
    _stopScanning();
    super.dispose();
  }

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Requesting permissions...';
    });

    final permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      setState(() {
        _statusMessage = 'Bluetooth permissions required';
        _isScanning = false;
      });
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      setState(() {
        _statusMessage = 'Please turn on Bluetooth';
        _isScanning = false;
      });
      return;
    }

    setState(() {
      _statusMessage = 'Scanning for beacons...';
    });

    try {
      _scanSubscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          _processScanResults(results);
        },
        onError: (e) {
          setState(() {
            _statusMessage = 'Scan error: $e';
          });
        },
      );

      await FlutterBluePlus.startScan(
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: true,
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to start scan: $e';
        _isScanning = false;
      });
    }
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> _stopScanning() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('Error stopping scan: $e');
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
        _statusMessage = _discoveredBeacons.isEmpty 
            ? 'No beacons found' 
            : 'Found ${_discoveredBeacons.length} beacon(s)';
      });
    }
  }

  void _processScanResults(List<ScanResult> results) {
    for (final result in results) {
      final serviceData = result.advertisementData.serviceData;
      final rssi = result.rssi;
      
      // Only detect Eddystone beacons
      // Service data keys are Guid objects, need to check by string representation
      if (serviceData.isNotEmpty) {
        List<int>? eddystoneData;
        
        // Find Eddystone service data by checking if key contains 'feaa'
        for (final entry in serviceData.entries) {
          final keyStr = entry.key.toString().toLowerCase();
          if (keyStr.contains('feaa')) {
            eddystoneData = entry.value;
            break;
          }
        }
        
        if (eddystoneData != null) {
          final data = eddystoneData;
        
          if (data.isNotEmpty) {
            final frameType = data[0];
            
            // Eddystone-UID frame
            if (frameType == 0x00 && data.length >= 18) {
              final namespace = data.sublist(2, 12).map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
              final instance = data.sublist(12, 18).map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
              final txPower = data[1].toSigned(8);
              
              // Create a pseudo-UUID from namespace for compatibility
              final uuid = '${namespace.substring(0, 8)}-${namespace.substring(8, 12)}-${namespace.substring(12, 16)}-${namespace.substring(16, 20)}-${instance}';
              final key = 'eddystone-$namespace-$instance';
              
              setState(() {
                if (_discoveredBeacons.containsKey(key)) {
                  _discoveredBeacons[key] = _discoveredBeacons[key]!.copyWith(
                    rssi: rssi,
                    lastSeen: DateTime.now(),
                    beaconType: 'Eddystone-UID',
                  );
                } else {
                  _discoveredBeacons[key] = _DiscoveredBeacon(
                    uuid: uuid,
                    major: 0,
                    minor: 0,
                    txPower: txPower.toDouble(),
                    rssi: rssi,
                    lastSeen: DateTime.now(),
                    beaconType: 'Eddystone-UID',
                  );
                }
              });
              continue;
            }
          }
        }
      }
    }
  }

  String _extractUuid(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final uuid = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
           '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    return uuid.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.bluetooth_searching, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('Scan for Beacons'),
          if (_isScanning) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _statusMessage,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            if (_discoveredBeacons.isEmpty && !_isScanning)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      'No beacons detected',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _discoveredBeacons.length,
                  itemBuilder: (context, index) {
                    final beacon = _discoveredBeacons.values.elementAt(index);
                    return _buildBeaconCard(beacon);
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (_isScanning)
          TextButton.icon(
            icon: const Icon(Icons.stop),
            label: const Text('Stop Scanning'),
            onPressed: _stopScanning,
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        if (_discoveredBeacons.isNotEmpty)
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(_isScanning ? 'Add All & Continue' : 'Add All New'),
            onPressed: () {
              final newBeacons = _discoveredBeacons.values
                  .where((b) => !_existingBeaconKeys.contains('${b.uuid}-${b.major}-${b.minor}'))
                  .map((b) => b.toConfigurableBeacon())
                  .toList();
              if (newBeacons.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All discovered beacons are already added'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              
              if (_isScanning) {
                _existingBeaconKeys.addAll(
                  newBeacons.map((b) => '${b.uuid}-${b.major}-${b.minor}')
                );
                Navigator.pop(context, newBeacons);
              } else {
                Navigator.pop(context, newBeacons);
              }
            },
          ),
      ],
    );
  }

  Widget _buildBeaconCard(_DiscoveredBeacon beacon) {
    final distance = _calculateDistance(beacon.rssi, beacon.txPower);
    final beaconKey = '${beacon.uuid}-${beacon.major}-${beacon.minor}';
    final isAlreadyAdded = _existingBeaconKeys.contains(beaconKey);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isAlreadyAdded ? Colors.grey[100] : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAlreadyAdded ? Colors.grey : Colors.blue,
          child: Icon(
            isAlreadyAdded ? Icons.check : Icons.bluetooth,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${beacon.beaconType} ${beacon.major}-${beacon.minor}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isAlreadyAdded ? Colors.grey[600] : null,
                ),
              ),
            ),
            if (isAlreadyAdded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Added',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              beacon.uuid,
              style: TextStyle(
                fontSize: 10,
                color: isAlreadyAdded ? Colors.grey[500] : null,
              ),
            ),
            Text(
              'RSSI: ${beacon.rssi} dBm • ~${distance.toStringAsFixed(1)}m',
              style: TextStyle(
                fontSize: 12,
                color: isAlreadyAdded ? Colors.grey[500] : null,
              ),
            ),
          ],
        ),
        trailing: isAlreadyAdded
            ? null
            : IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () {
                  final beaconToAdd = beacon.toConfigurableBeacon();
                  final beaconKey = '${beacon.uuid}-${beacon.major}-${beacon.minor}';
                  
                  setState(() {
                    _existingBeaconKeys.add(beaconKey);
                  });
                  
                  Navigator.pop(context, [beaconToAdd]);
                },
                tooltip: 'Add this beacon',
              ),
      ),
    );
  }

  double _calculateDistance(int rssi, double txPower) {
    if (rssi == 0) return -1.0;
    
    final ratio = rssi / txPower;
    if (ratio < 1.0) {
      return 0.5;
    } else {
      return 0.89976 * (ratio * ratio * ratio * ratio * ratio * ratio * ratio) + 0.111;
    }
  }
}

class _DiscoveredBeacon {
  final String uuid;
  final int major;
  final int minor;
  final double txPower;
  final int rssi;
  final DateTime lastSeen;
  final String beaconType;

  _DiscoveredBeacon({
    required this.uuid,
    required this.major,
    required this.minor,
    required this.txPower,
    required this.rssi,
    required this.lastSeen,
    this.beaconType = 'iBeacon',
  });

  _DiscoveredBeacon copyWith({
    String? uuid,
    int? major,
    int? minor,
    double? txPower,
    int? rssi,
    DateTime? lastSeen,
    String? beaconType,
  }) {
    return _DiscoveredBeacon(
      uuid: uuid ?? this.uuid,
      major: major ?? this.major,
      minor: minor ?? this.minor,
      txPower: txPower ?? this.txPower,
      rssi: rssi ?? this.rssi,
      lastSeen: lastSeen ?? this.lastSeen,
      beaconType: beaconType ?? this.beaconType,
    );
  }

  ConfigurableBeacon toConfigurableBeacon() {
    // Use full UUID to ensure uniqueness (remove dashes for cleaner ID)
    final uuidClean = uuid.replaceAll('-', '');
    final beaconId = 'beacon_${uuidClean}_${major}_$minor';
    
    // Use last 4 chars of UUID for a more unique name
    final uuidSuffix = uuid.substring(uuid.length - 4);
    final beaconName = 'Beacon $major-$minor ($uuidSuffix)';
    
    debugPrint('🔵 Creating beacon with ID: $beaconId, UUID: $uuid, Major: $major, Minor: $minor');
    return ConfigurableBeacon(
      id: beaconId,
      uuid: uuid,
      major: major,
      minor: minor,
      name: beaconName,
      txPower: txPower,
      isPlaced: false,
    );
  }
}
