import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/beacon_node.dart';
import '../../domain/entities/navigation_route.dart';

// Abstract interface for beacon data sources
abstract class BeaconDataSource {
  Stream<BeaconNode?> get nearestBeaconStream;
  List<BeaconNode> getAllBeacons();
  BeaconNode? getBeaconByUid(String uid);
  List<BeaconNode> getBeaconsByFloor(int floor);
  Future<void> startScanning();
  void stopScanning();
  void simulateBeaconChange(String beaconUid);
  void dispose();
}

class BeaconStatus {
  final int? beaconARssi;
  final int? beaconBRssi;
  final double? distanceA;
  final double? distanceB;
  final bool isScanning;
  final String? currentLocation;

  const BeaconStatus({
    this.beaconARssi,
    this.beaconBRssi,
    this.distanceA,
    this.distanceB,
    this.isScanning = false,
    this.currentLocation,
  });
}

class HybridBeaconDataSource implements BeaconDataSource {
  final _beaconController = StreamController<BeaconNode?>.broadcast();
  final _statusController = StreamController<BeaconStatus>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  bool _isScanning = false;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _initialized = false;

  // Beacon A: ...96E0 is physically at Reception (SWAPPED)
  static const String beaconAUuid = 'E2C56DB5-DFFB-48D2-B060-D0F5A71096E0';
  // Beacon B: ...96E1 is physically at X-Ray (SWAPPED)
  static const String beaconBUuid = 'E2C56DB5-DFFB-48D2-B060-D0F5A71096E1';

  static const BeaconNode beaconANode = BeaconNode(
    uid: 'beacon_reception',
    name: 'Reception',
    x: 400,
    y: 460,
    floor: 1,
    departmentId: 'reception',
    connectedNodes: ['beacon_entrance', 'beacon_corridor_1_1'],
  );

  static const BeaconNode beaconBNode = BeaconNode(
    uid: 'beacon_xray',
    name: 'X-Ray Department',
    x: 90,
    y: 220,
    floor: 1,
    departmentId: 'xray',
    connectedNodes: ['beacon_radiology', 'beacon_corridor_1_1'],
  );

  int? _beaconARssi;
  int? _beaconBRssi;
  DateTime? _lastBeaconATime;
  DateTime? _lastBeaconBTime;
  
  // Distance smoothing with median filter (production-ready)
  final List<double> _distanceABuffer = [];
  final List<double> _distanceBBuffer = [];
  static const int _distanceBufferSize = 15;  // MAXIMUM smoothing - odd number for median
  
  // Hysteresis for anti-flicker (AGGRESSIVE settings)
  static const double _switchThreshold = 2.5;  // 2.5m minimum difference to switch beacons
  static const int _confirmationCycles = 5;  // 5 consecutive cycles needed (2.5 seconds)
  String? _currentNearestBeacon;  // 'A', 'B', or 'MIDDLE'
  String? _pendingNearestBeacon;
  int _pendingConfirmationCount = 0;

  Timer? _updateTimer;
  Timer? _fallbackTimer;
  BeaconNode? _currentInterpolatedPosition;

  final List<BeaconNode> _allBeacons = [
    beaconANode,
    beaconBNode,
    // const BeaconNode(
    //   uid: 'beacon_xray',
    //   name: 'X-Ray Department',
    //   x: 100,
    //   y: 220,
    //   floor: 1,
    //   departmentId: 'xray',
    //   connectedNodes: ['beacon_radiology', 'beacon_corridor_1_1'],
    // ),
    const BeaconNode(
      uid: 'beacon_imaging',
      name: 'Imaging Department',
      x: 710,
      y: 220,
      floor: 2,
      departmentId: 'imaging',
      connectedNodes: ['beacon_corridor_2_1', 'beacon_lab_2'],
    ),
    const BeaconNode(
      uid: 'beacon_icu',
      name: 'ICU Department',
      x: 600,
      y: 500,
      floor: 3,
      departmentId: 'icu',
      connectedNodes: ['beacon_corridor_3_1', 'beacon_icu_waiting'],
    ),
    const BeaconNode(
      uid: 'beacon_corridor_1_1',
      name: 'Main Corridor F1',
      x: 400,
      y: 350,
      floor: 1,
      connectedNodes: ['beacon_reception', 'beacon_radiology', 'beacon_elevator_1', 'beacon_stairs_1', 'beacon_entrance'],
    ),
    const BeaconNode(
      uid: 'beacon_radiology',
      name: 'Radiology',
      x: 200,
      y: 220,
      floor: 1,
      departmentId: 'radiology',
      connectedNodes: ['beacon_corridor_1_1', 'beacon_xray'],
    ),
    const BeaconNode(
      uid: 'beacon_elevator_1',
      name: 'Elevator F1',
      x: 430,
      y: 195,
      floor: 1,
      departmentId: 'elevator',
      connectedNodes: ['beacon_corridor_1_1', 'beacon_stairs_1', 'beacon_elevator_2'],
    ),
    const BeaconNode(
      uid: 'beacon_stairs_1',
      name: 'Stairs F1',
      x: 370,
      y: 195,
      floor: 1,
      departmentId: 'stairs',
      connectedNodes: ['beacon_corridor_1_1', 'beacon_elevator_1', 'beacon_stairs_2'],
    ),
    const BeaconNode(
      uid: 'beacon_elevator_2',
      name: 'Elevator F2',
      x: 430,
      y: 195,
      floor: 2,
      departmentId: 'elevator',
      connectedNodes: ['beacon_corridor_2_1', 'beacon_stairs_2', 'beacon_elevator_1', 'beacon_elevator_3'],
    ),
    const BeaconNode(
      uid: 'beacon_stairs_2',
      name: 'Stairs F2',
      x: 370,
      y: 195,
      floor: 2,
      departmentId: 'stairs',
      connectedNodes: ['beacon_corridor_2_1', 'beacon_elevator_2', 'beacon_stairs_1', 'beacon_stairs_3'],
    ),
    const BeaconNode(
      uid: 'beacon_corridor_2_1',
      name: 'Main Corridor F2',
      x: 400,
      y: 350,
      floor: 2,
      connectedNodes: ['beacon_elevator_2', 'beacon_stairs_2', 'beacon_lab_2', 'beacon_imaging'],
    ),
    const BeaconNode(
      uid: 'beacon_lab_2',
      name: 'Lab Collection',
      x: 600,
      y: 220,
      floor: 2,
      departmentId: 'lab_2',
      connectedNodes: ['beacon_corridor_2_1', 'beacon_imaging'],
    ),
    const BeaconNode(
      uid: 'beacon_elevator_3',
      name: 'Elevator F3',
      x: 430,
      y: 195,
      floor: 3,
      departmentId: 'elevator',
      connectedNodes: ['beacon_corridor_3_1', 'beacon_stairs_3', 'beacon_elevator_2'],
    ),
    const BeaconNode(
      uid: 'beacon_stairs_3',
      name: 'Stairs F3',
      x: 370,
      y: 195,
      floor: 3,
      departmentId: 'stairs',
      connectedNodes: ['beacon_corridor_3_1', 'beacon_elevator_3', 'beacon_stairs_2'],
    ),
    const BeaconNode(
      uid: 'beacon_corridor_3_1',
      name: 'Main Corridor F3',
      x: 400,
      y: 350,
      floor: 3,
      connectedNodes: ['beacon_elevator_3', 'beacon_stairs_3', 'beacon_icu', 'beacon_cardiology'],
    ),
    const BeaconNode(
      uid: 'beacon_cardiology',
      name: 'Cardiology',
      x: 200,
      y: 220,
      floor: 3,
      departmentId: 'cardiology',
      connectedNodes: ['beacon_corridor_3_1'],
    ),
    const BeaconNode(
      uid: 'beacon_icu_waiting',
      name: 'ICU Waiting',
      x: 710,
      y: 500,
      floor: 3,
      departmentId: 'icu_waiting',
      connectedNodes: ['beacon_icu'],
    ),
  ];

  @override
  Stream<BeaconNode?> get nearestBeaconStream => _beaconController.stream;

  Stream<BeaconStatus> get beaconStatusStream => _statusController.stream;

  @override
  List<BeaconNode> getAllBeacons() => List.unmodifiable(_allBeacons);

  @override
  BeaconNode? getBeaconByUid(String uid) {
    try {
      return _allBeacons.firstWhere((b) => b.uid == uid);
    } catch (e) {
      return null;
    }
  }

  @override
  List<BeaconNode> getBeaconsByFloor(int floor) {
    return _allBeacons.where((b) => b.floor == floor).toList();
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    
    debugPrint('🔧 Initializing HybridBeaconDataSource...');
    
    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      debugPrint('🔵 Bluetooth state changed: $state');
      
      if (state == BluetoothAdapterState.off) {
        stopScanning();
      }
    });
    
    await Future.delayed(const Duration(milliseconds: 500));
    _initialized = true;
    debugPrint('✅ HybridBeaconDataSource initialized, adapter state: $_adapterState');
  }

  @override
  Future<void> startScanning() async {
    debugPrint('========================================');
    debugPrint('🚀 HybridBeaconDataSource.startScanning() CALLED');
    debugPrint('========================================');
    
    await _initialize();
    
    if (_isScanning) {
      debugPrint('⚠️ Already scanning, returning');
      return;
    }

    debugPrint('📋 Requesting Bluetooth permissions...');
    final permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      debugPrint('❌ Bluetooth permissions not granted');
      _emitStatus(null, null, 'Bluetooth permissions required');
      return;
    }

    if (_adapterState != BluetoothAdapterState.on) {
      debugPrint('❌ Bluetooth is not on: $_adapterState');
      
      try {
        await FlutterBluePlus.turnOn();
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('⚠️ Could not turn on Bluetooth: $e');
      }
      
      if (_adapterState != BluetoothAdapterState.on) {
        debugPrint('❌ Bluetooth unavailable');
        _emitStatus(null, null, 'Bluetooth is turned off');
        return;
      }
    }

    await _stopScanInternal();

    debugPrint('🔍 Starting real beacon scan...');
    _isScanning = true;

    _scanSubscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        debugPrint('📥 Received scan batch with ${results.length} results');
        _processScanResults(results);
      },
      onError: (e) => debugPrint('❌ Scan error: $e'),
    );

    try {
      debugPrint('🔄 Calling FlutterBluePlus.startScan()...');
      await FlutterBluePlus.startScan(
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: true,
        continuousUpdates: true,
        continuousDivisor: 1,
      );
      debugPrint('✅ Real beacon scan started successfully!');
      
      _startPositionUpdates();
    } catch (e) {
      debugPrint('❌ Failed to start scan: $e');
      _isScanning = false;
      _emitStatus(null, null, 'Scan failed: $e');
    }
  }

  
  Future<void> _stopScanInternal() async {
    if (_isScanning) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        debugPrint('⚠️ Error stopping scan: $e');
      }
    }
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      debugPrint('   $permission: $status');
      if (!status.isGranted) allGranted = false;
    });

    return allGranted;
  }

  void _processScanResults(List<ScanResult> results) {
    final now = DateTime.now();
    
    if (results.isNotEmpty) {
      debugPrint('🔍 Scan batch: ${results.length} devices found');
    }

    for (final result in results) {
      final deviceName = result.device.platformName.isNotEmpty 
          ? result.device.platformName 
          : result.device.remoteId.str;
      final manufacturerData = result.advertisementData.manufacturerData;
      
      if (manufacturerData.isNotEmpty) {
        debugPrint('📱 Device: $deviceName, RSSI: ${result.rssi}');
      }
      
      if (manufacturerData.containsKey(0x004C)) {
        final data = manufacturerData[0x004C]!;
        
        if (data.length >= 23 && data[0] == 0x02 && data[1] == 0x15) {
          final uuid = _extractUuid(data.sublist(2, 18));
          final rssi = result.rssi;
          
          final normalizedUuid = uuid.toUpperCase();
          
          debugPrint('📡 iBeacon FOUND: UUID=$uuid, RSSI=$rssi');
          
          if (normalizedUuid == beaconAUuid.toUpperCase()) {
            _beaconARssi = rssi;
            _lastBeaconATime = now;
            debugPrint('✅ Beacon A detected! RSSI: $rssi');
          } else if (normalizedUuid == beaconBUuid.toUpperCase()) {
            _beaconBRssi = rssi;
            _lastBeaconBTime = now;
            debugPrint('✅ Beacon B detected! RSSI: $rssi');
          }
        }
      }
    }

    // Clear stale beacons (longer timeout for stability)
    if (_lastBeaconATime != null && now.difference(_lastBeaconATime!).inSeconds > 12) {
      _beaconARssi = null;
      _distanceABuffer.clear();
      debugPrint('🔴 Beacon A stale, clearing');
    }
    if (_lastBeaconBTime != null && now.difference(_lastBeaconBTime!).inSeconds > 12) {
      _beaconBRssi = null;
      _distanceBBuffer.clear();
      debugPrint('🔴 Beacon B stale, clearing');
    }
  }

  String _extractUuid(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
           '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _startPositionUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _calculateInterpolatedPosition();
    });
  }

  void _calculateInterpolatedPosition() {
    // Convert RSSI to raw distance
    final rawDistanceA = _beaconARssi != null ? _rssiToDistance(_beaconARssi!) : null;
    final rawDistanceB = _beaconBRssi != null ? _rssiToDistance(_beaconBRssi!) : null;
    
    // Add to distance buffers for median filtering
    if (rawDistanceA != null) {
      _distanceABuffer.add(rawDistanceA);
      if (_distanceABuffer.length > _distanceBufferSize) {
        _distanceABuffer.removeAt(0);
      }
    }
    if (rawDistanceB != null) {
      _distanceBBuffer.add(rawDistanceB);
      if (_distanceBBuffer.length > _distanceBufferSize) {
        _distanceBBuffer.removeAt(0);
      }
    }
    
    // Use median-filtered distances (production-ready smoothing)
    final distanceA = _distanceABuffer.isNotEmpty ? _medianFilter(_distanceABuffer) : null;
    final distanceB = _distanceBBuffer.isNotEmpty ? _medianFilter(_distanceBBuffer) : null;
    
    String? currentLocation;

    if (distanceA == null && distanceB == null) {
      currentLocation = 'Searching for beacons...';
      _emitStatus(distanceA, distanceB, currentLocation);
      return;
    }

    // Determine nearest beacon with hysteresis and anti-flicker logic
    final nearestBeacon = _determineNearestBeaconWithHysteresis(distanceA, distanceB);
    
    // Position arrow based on stable nearest beacon determination
    if (nearestBeacon == 'A') {
      currentLocation = 'At Reception (Beacon A)';
      if (distanceA != null && distanceB != null) {
        currentLocation += ' - A: ${distanceA.toStringAsFixed(1)}m, B: ${distanceB.toStringAsFixed(1)}m';
      }
      _emitStatus(distanceA, distanceB, currentLocation);
      _emitPosition(beaconANode);
    } else if (nearestBeacon == 'B') {
      currentLocation = 'At X-Ray (Beacon B)';
      if (distanceA != null && distanceB != null) {
        currentLocation += ' - A: ${distanceA.toStringAsFixed(1)}m, B: ${distanceB.toStringAsFixed(1)}m';
      }
      _emitStatus(distanceA, distanceB, currentLocation);
      _emitPosition(beaconBNode);
    } else if (nearestBeacon == 'MIDDLE') {
      // Ambiguous state - both beacons similar distance
      // Interpolate position but don't change UI state rapidly
      if (distanceA != null && distanceB != null) {
        final totalDistance = distanceA + distanceB;
        final ratio = distanceB / totalDistance;
        
        final interpolatedX = beaconANode.x + (beaconBNode.x - beaconANode.x) * ratio;
        final interpolatedY = beaconANode.y + (beaconBNode.y - beaconANode.y) * ratio;
        
        final interpolatedNode = BeaconNode(
          uid: 'interpolated',
          name: 'Between beacons',
          x: interpolatedX,
          y: interpolatedY,
          floor: 1,
          departmentId: '',
          connectedNodes: [],
        );
        
        currentLocation = 'Between beacons - A: ${distanceA.toStringAsFixed(1)}m, B: ${distanceB.toStringAsFixed(1)}m';
        _emitStatus(distanceA, distanceB, currentLocation);
        _emitPosition(interpolatedNode);
      }
    } else if (distanceA != null && distanceB == null) {
      // Only Beacon A detected
      currentLocation = 'At Reception (Beacon A only)';
      _emitStatus(distanceA, distanceB, currentLocation);
      _emitPosition(beaconANode);
    } else if (distanceB != null && distanceA == null) {
      // Only Beacon B detected
      currentLocation = 'At X-Ray (Beacon B only)';
      _emitStatus(distanceA, distanceB, currentLocation);
      _emitPosition(beaconBNode);
    }
  }

  void _emitStatus(double? distanceA, double? distanceB, String? location) {
    _statusController.add(BeaconStatus(
      beaconARssi: _beaconARssi,
      beaconBRssi: _beaconBRssi,
      distanceA: distanceA,
      distanceB: distanceB,
      isScanning: _isScanning,
      currentLocation: location,
    ));
  }

  /// Median filter for distance smoothing (production-ready)
  /// Eliminates outliers better than moving average
  double _medianFilter(List<double> values) {
    if (values.isEmpty) return 0.0;
    if (values.length == 1) return values[0];
    
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    
    if (sorted.length.isOdd) {
      return sorted[middle];
    } else {
      return (sorted[middle - 1] + sorted[middle]) / 2.0;
    }
  }
  
  /// Determine nearest beacon with hysteresis to prevent flickering
  String? _determineNearestBeaconWithHysteresis(double? distanceA, double? distanceB) {
    if (distanceA == null && distanceB == null) return null;
    if (distanceA == null) return 'B';
    if (distanceB == null) return 'A';
    
    final distanceDiff = (distanceA - distanceB).abs();
    
    // Determine candidate nearest beacon
    String candidate;
    if (distanceDiff < _switchThreshold) {
      // Too close to call - ambiguous state
      candidate = 'MIDDLE';
    } else if (distanceA < distanceB) {
      candidate = 'A';
    } else {
      candidate = 'B';
    }
    
    // Hysteresis logic: require N consecutive confirmations before switching
    if (candidate == _currentNearestBeacon) {
      // Same as current - reset pending
      _pendingNearestBeacon = null;
      _pendingConfirmationCount = 0;
      return _currentNearestBeacon;
    }
    
    if (candidate == _pendingNearestBeacon) {
      // Same as pending - increment counter
      _pendingConfirmationCount++;
      debugPrint('🔄 Pending switch to $candidate: $_pendingConfirmationCount/$_confirmationCycles');
      
      if (_pendingConfirmationCount >= _confirmationCycles) {
        // Confirmed! Switch to new beacon
        debugPrint('✅ CONFIRMED: Switching from $_currentNearestBeacon to $candidate');
        _currentNearestBeacon = candidate;
        _pendingNearestBeacon = null;
        _pendingConfirmationCount = 0;
        return _currentNearestBeacon;
      }
      
      // Not yet confirmed - keep current
      return _currentNearestBeacon;
    } else {
      // New candidate - start pending
      _pendingNearestBeacon = candidate;
      _pendingConfirmationCount = 1;
      debugPrint('🔄 New pending switch to $candidate: 1/$_confirmationCycles');
      return _currentNearestBeacon;
    }
  }
  
  double _rssiToDistance(int rssi) {
    // Calibrated parameters for MAXIMUM accuracy
    // txPower: Measured RSSI at 1 meter - CALIBRATE THIS WITH YOUR ACTUAL BEACONS!
    // n: Path loss exponent (higher = more aggressive distance scaling)
    const txPower = -65;  // Typical for most BLE beacons at 1m (adjust if needed)
    const n = 2.7;  // Indoor with obstacles - higher for more stable readings
    
    // Log-distance path loss model
    final ratio = (txPower - rssi) / (10 * n);
    final distance = pow(10, ratio);
    
    // Clamp to reasonable indoor range
    return distance.toDouble().clamp(0.3, 30.0);
  }


  void _emitPosition(BeaconNode node) {
    if (_currentInterpolatedPosition == null ||
        _hasSignificantMovement(_currentInterpolatedPosition!, node)) {
      _currentInterpolatedPosition = node;
      _beaconController.add(node);
    }
  }

  bool _hasSignificantMovement(BeaconNode oldPos, BeaconNode newPos) {
    // Only emit position updates for significant movement
    // This prevents UI rebuilds on minor position changes
    const threshold = 15.0;  // Balanced: responsive but stable (15 pixels)
    final dx = oldPos.x - newPos.x;
    final dy = oldPos.y - newPos.y;
    final distance = sqrt(dx * dx + dy * dy);
    return distance > threshold;
  }

  @override
  void stopScanning() {
    _isScanning = false;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _adapterSubscription?.cancel();
    _adapterSubscription = null;
    _updateTimer?.cancel();
    _updateTimer = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    FlutterBluePlus.stopScan();
    _beaconARssi = null;
    _beaconBRssi = null;
    _distanceABuffer.clear();
    _distanceBBuffer.clear();
    _currentNearestBeacon = null;
    _pendingNearestBeacon = null;
    _pendingConfirmationCount = 0;
    _lastBeaconATime = null;
    _lastBeaconBTime = null;
    debugPrint('🛑 Beacon scan stopped');
  }

  @override
  void simulateBeaconChange(String beaconUid) {
    // Simulation disabled - only real beacons supported
    debugPrint('⚠️ Beacon simulation is disabled. Only real beacons are supported.');
  }

  @override
  void dispose() {
    stopScanning();
    _beaconController.close();
    _statusController.close();
  }

  Map<String, int?> getCurrentRssiValues() {
    return {
      'beaconA': _beaconARssi,
      'beaconB': _beaconBRssi,
    };
  }

  bool get isUsingRealBeacons => true;

  /// Set the active navigation route (not used - arrow shows at nearest beacon)
  void setActiveRoute(NavigationRoute? route) {
    // Route-based tracking disabled - arrow always shows at nearest beacon
    debugPrint('🗺️ Route set but not used for positioning: ${route?.nodes.length ?? 0} nodes');
  }
}
