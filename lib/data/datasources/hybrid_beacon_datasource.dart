import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/beacon_node.dart';
import '../../domain/entities/navigation_route.dart';
import '../providers/static_beacon_configuration.dart';

// Abstract interface for beacon data sources
abstract class BeaconDataSource {
  Stream<BeaconNode?> get nearestBeaconStream;
  List<BeaconNode> getAllBeacons();
  BeaconNode? getBeaconByUid(String uid);
  List<BeaconNode> getBeaconsByFloor(int floor);
  Future<void> startScanning();
  void stopScanning();
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

  // Beacon UUIDs from centralized configuration
  static String get beaconAUuid => StaticBeaconConfiguration.beaconAUuid;
  static String get beaconBUuid => StaticBeaconConfiguration.beaconBUuid;

  // Beacon nodes from centralized configuration
  static BeaconNode get beaconANode => StaticBeaconConfiguration.navigationNodes
      .firstWhere((n) => n.uid == 'beacon_reception');
  static BeaconNode get beaconBNode => StaticBeaconConfiguration.navigationNodes
      .firstWhere((n) => n.uid == 'beacon_xray');

  int? _beaconARssi;
  int? _beaconBRssi;
  DateTime? _lastBeaconATime;
  DateTime? _lastBeaconBTime;
  
  // RSSI Kalman filter state for each beacon
  double? _kalmanARssi;
  double? _kalmanBRssi;
  double _kalmanAVariance = 1.0;
  double _kalmanBVariance = 1.0;
  static const double _kalmanProcessNoise = 0.003;  // Lower = smoother but slower response
  static const double _kalmanMeasurementNoise = 4.0;  // Higher = trusts history more
  
  // RSSI buffers for outlier detection
  final List<int> _rssiABuffer = [];
  final List<int> _rssiBBuffer = [];
  static const int _rssiBufferSize = 7;  // More samples for better outlier detection
  
  // Distance smoothing with median filter (production-ready)
  final List<double> _distanceABuffer = [];
  final List<double> _distanceBBuffer = [];
  static const int _distanceBufferSize = 12;  // More samples = more stable
  
  // Position smoothing with exponential moving average
  double? _smoothedX;
  double? _smoothedY;
  static const double _positionSmoothingFactor = 0.15;  // 0.1=very smooth, 0.5=responsive
  
  // Confidence tracking based on signal quality
  double _confidenceA = 0.0;
  double _confidenceB = 0.0;
  
  // Hysteresis for anti-flicker (AGGRESSIVE settings)
  static const double _switchThreshold = 2.5;  // 2.5m minimum difference to switch beacons
  static const int _confirmationCycles = 6;  // 6 consecutive cycles needed (~2.5 seconds)
  String? _currentNearestBeacon;  // 'A', 'B', or 'MIDDLE'
  String? _pendingNearestBeacon;
  int _pendingConfirmationCount = 0;

  Timer? _updateTimer;
  Timer? _fallbackTimer;
  BeaconNode? _currentInterpolatedPosition;
  
  // Active navigation route for snap-to-route feature
  NavigationRoute? _activeRoute;
  int _currentRouteSegmentIndex = 0;  // Which segment of the route we're on

  // Navigation nodes from centralized configuration
  List<BeaconNode> get _allBeacons => StaticBeaconConfiguration.navigationNodes;

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

    for (final result in results) {
      final manufacturerData = result.advertisementData.manufacturerData;
      
      if (manufacturerData.containsKey(0x004C)) {
        final data = manufacturerData[0x004C]!;
        
        if (data.length >= 23 && data[0] == 0x02 && data[1] == 0x15) {
          final uuid = _extractUuid(data.sublist(2, 18));
          final rssi = result.rssi;
          final normalizedUuid = uuid.toUpperCase();
          
          if (normalizedUuid == beaconAUuid.toUpperCase()) {
            final filteredRssi = _applyKalmanFilter(rssi, true);
            _beaconARssi = filteredRssi.round();
            _lastBeaconATime = now;
          } else if (normalizedUuid == beaconBUuid.toUpperCase()) {
            final filteredRssi = _applyKalmanFilter(rssi, false);
            _beaconBRssi = filteredRssi.round();
            _lastBeaconBTime = now;
          }
        }
      }
    }

    // Clear stale beacons (longer timeout for stability)
    if (_lastBeaconATime != null && now.difference(_lastBeaconATime!).inSeconds > 10) {
      _beaconARssi = null;
      _distanceABuffer.clear();
      _rssiABuffer.clear();
      _kalmanARssi = null;
      _kalmanAVariance = 1.0;
      _confidenceA = 0.0;
      debugPrint('🔴 Beacon A stale, clearing');
    }
    if (_lastBeaconBTime != null && now.difference(_lastBeaconBTime!).inSeconds > 10) {
      _beaconBRssi = null;
      _distanceBBuffer.clear();
      _rssiBBuffer.clear();
      _kalmanBRssi = null;
      _kalmanBVariance = 1.0;
      _confidenceB = 0.0;
      debugPrint('🔴 Beacon B stale, clearing');
    }
    // Reset position smoothing if both beacons are lost
    if (_beaconARssi == null && _beaconBRssi == null) {
      _smoothedX = null;
      _smoothedY = null;
    }
  }

  String _extractUuid(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
           '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Kalman filter for RSSI smoothing - reduces noise while tracking real changes
  double _applyKalmanFilter(int rawRssi, bool isBeaconA) {
    // Add to buffer for outlier detection
    final buffer = isBeaconA ? _rssiABuffer : _rssiBBuffer;
    buffer.add(rawRssi);
    if (buffer.length > _rssiBufferSize) {
      buffer.removeAt(0);
    }
    
    // Outlier rejection: if new value is too far from median, reduce its weight
    double measurementRssi = rawRssi.toDouble();
    if (buffer.length >= 3) {
      final sorted = List<int>.from(buffer)..sort();
      final median = sorted[sorted.length ~/ 2];
      final diff = (rawRssi - median).abs();
      if (diff > 10) {
        // Outlier detected - use median instead
        measurementRssi = median.toDouble();
      }
    }
    
    // Kalman filter update
    if (isBeaconA) {
      if (_kalmanARssi == null) {
        // Initialize
        _kalmanARssi = measurementRssi;
        _kalmanAVariance = 1.0;
      } else {
        // Predict
        final predictedVariance = _kalmanAVariance + _kalmanProcessNoise;
        
        // Update
        final kalmanGain = predictedVariance / (predictedVariance + _kalmanMeasurementNoise);
        _kalmanARssi = _kalmanARssi! + kalmanGain * (measurementRssi - _kalmanARssi!);
        _kalmanAVariance = (1 - kalmanGain) * predictedVariance;
      }
      return _kalmanARssi!;
    } else {
      if (_kalmanBRssi == null) {
        // Initialize
        _kalmanBRssi = measurementRssi;
        _kalmanBVariance = 1.0;
      } else {
        // Predict
        final predictedVariance = _kalmanBVariance + _kalmanProcessNoise;
        
        // Update
        final kalmanGain = predictedVariance / (predictedVariance + _kalmanMeasurementNoise);
        _kalmanBRssi = _kalmanBRssi! + kalmanGain * (measurementRssi - _kalmanBRssi!);
        _kalmanBVariance = (1 - kalmanGain) * predictedVariance;
      }
      return _kalmanBRssi!;
    }
  }

  void _startPositionUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
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
    
    // ============ SNAP-TO-ROUTE MODE ============
    // When navigating with an active route, constrain position to the route path
    if (_activeRoute != null && _activeRoute!.nodes.length >= 2) {
      final routePosition = _calculateRoutePosition(distanceA, distanceB);
      if (routePosition != null) {
        currentLocation = 'On route - A: ${distanceA?.toStringAsFixed(1) ?? "?"}m, B: ${distanceB?.toStringAsFixed(1) ?? "?"}m';
        _emitStatus(distanceA, distanceB, currentLocation);
        _emitPosition(routePosition);
        return;
      }
    }
    
    // ============ FREE POSITIONING MODE ============
    // When no active route, use beacon-based interpolation
    if (distanceA != null && distanceB != null) {
      // SNAP TO BEACON: If distance < 1m, place marker exactly on the beacon
      if (distanceA < 1.0 && distanceA < distanceB) {
        // Very close to Beacon A - snap to it
        _smoothedX = beaconANode.x;
        _smoothedY = beaconANode.y;
        currentLocation = 'At Reception (Beacon A) - A: ${distanceA.toStringAsFixed(1)}m, B: ${distanceB.toStringAsFixed(1)}m';
        _emitStatus(distanceA, distanceB, currentLocation);
        _emitPosition(beaconANode);
        return;
      } else if (distanceB < 1.0 && distanceB < distanceA) {
        // Very close to Beacon B - snap to it
        _smoothedX = beaconBNode.x;
        _smoothedY = beaconBNode.y;
        currentLocation = 'At X-Ray (Beacon B) - A: ${distanceA.toStringAsFixed(1)}m, B: ${distanceB.toStringAsFixed(1)}m';
        _emitStatus(distanceA, distanceB, currentLocation);
        _emitPosition(beaconBNode);
        return;
      }
      
      // Calculate confidence based on signal strength (stronger = more confident)
      // RSSI closer to 0 is stronger, so we invert and normalize
      _confidenceA = _beaconARssi != null ? (100 + _beaconARssi!) / 100.0 : 0.5;
      _confidenceB = _beaconBRssi != null ? (100 + _beaconBRssi!) / 100.0 : 0.5;
      _confidenceA = _confidenceA.clamp(0.1, 1.0);
      _confidenceB = _confidenceB.clamp(0.1, 1.0);
      
      // Weighted positioning: closer beacon with stronger signal has more influence
      // Weight = confidence / distance (closer + stronger = higher weight)
      final weightA = _confidenceA / (distanceA + 0.1);  // +0.1 prevents division by zero
      final weightB = _confidenceB / (distanceB + 0.1);
      final totalWeight = weightA + weightB;
      
      // Ratio based on weighted distances (0 = at A, 1 = at B)
      final ratio = (weightB / totalWeight).clamp(0.0, 1.0);
      
      final rawX = beaconANode.x + (beaconBNode.x - beaconANode.x) * ratio;
      final rawY = beaconANode.y + (beaconBNode.y - beaconANode.y) * ratio;
      
      // Apply exponential moving average for smooth position transitions
      if (_smoothedX == null || _smoothedY == null) {
        _smoothedX = rawX;
        _smoothedY = rawY;
      } else {
        _smoothedX = _smoothedX! + _positionSmoothingFactor * (rawX - _smoothedX!);
        _smoothedY = _smoothedY! + _positionSmoothingFactor * (rawY - _smoothedY!);
      }
      
      final interpolatedNode = BeaconNode(
        uid: 'interpolated',
        name: nearestBeacon == 'A' ? 'Near Reception' : (nearestBeacon == 'B' ? 'Near X-Ray' : 'Between beacons'),
        x: _smoothedX!,
        y: _smoothedY!,
        floor: 1,
        departmentId: nearestBeacon == 'A' ? 'reception' : (nearestBeacon == 'B' ? 'xray' : ''),
        connectedNodes: [],
      );
      
      if (nearestBeacon == 'A') {
        currentLocation = 'At Reception (Beacon A) - A: ${distanceA.toStringAsFixed(1)}m, B: ${distanceB.toStringAsFixed(1)}m';
      } else if (nearestBeacon == 'B') {
        currentLocation = 'At X-Ray (Beacon B) - A: ${distanceA.toStringAsFixed(1)}m, B: ${distanceB.toStringAsFixed(1)}m';
      } else {
        currentLocation = 'Between beacons - A: ${distanceA.toStringAsFixed(1)}m, B: ${distanceB.toStringAsFixed(1)}m';
      }
      
      _emitStatus(distanceA, distanceB, currentLocation);
      _emitPosition(interpolatedNode);
    } else if (distanceA != null && distanceB == null) {
      // Only Beacon A detected - position at beacon A
      currentLocation = 'At Reception (Beacon A only) - A: ${distanceA.toStringAsFixed(1)}m';
      _emitStatus(distanceA, distanceB, currentLocation);
      _emitPosition(beaconANode);
    } else if (distanceB != null && distanceA == null) {
      // Only Beacon B detected - position at beacon B
      currentLocation = 'At X-Ray (Beacon B only) - B: ${distanceB.toStringAsFixed(1)}m';
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
    // Advanced distance calculation using Apple's iBeacon ranging algorithm
    // This is based on empirical measurements and provides smooth, accurate results
    
    // txPower: Measured RSSI at exactly 1 meter from your beacon
    // CALIBRATION TIP: Stand 1m from beacon, note the RSSI - that's your txPower
    const double txPower = -59.0;  // Adjust based on your actual beacon
    
    if (rssi == 0) {
      return -1.0;  // Unknown distance
    }
    
    final double ratio = rssi / txPower;
    
    if (ratio < 1.0) {
      // Very close (< 1 meter) - use simple power model
      return pow(ratio, 10).toDouble().clamp(0.1, 1.0);
    } else {
      // Standard range - use empirically-derived formula
      // This formula is based on Apple's CoreLocation accuracy model
      const double A = 0.89976;  // Coefficient A
      const double B = 7.7095;   // Coefficient B  
      const double C = 0.111;    // Coefficient C (environmental factor)
      
      final double distance = A * pow(ratio, B) + C;
      return distance.clamp(0.1, 30.0);
    }
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
    const threshold = 25.0;  // Higher = more stable, less jitter (25 pixels)
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
    _rssiABuffer.clear();
    _rssiBBuffer.clear();
    _kalmanARssi = null;
    _kalmanBRssi = null;
    _kalmanAVariance = 1.0;
    _kalmanBVariance = 1.0;
    _smoothedX = null;
    _smoothedY = null;
    _confidenceA = 0.0;
    _confidenceB = 0.0;
    _currentNearestBeacon = null;
    _pendingNearestBeacon = null;
    _pendingConfirmationCount = 0;
    _lastBeaconATime = null;
    _lastBeaconBTime = null;
    debugPrint('🛑 Beacon scan stopped');
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

  /// Set the active navigation route for snap-to-route positioning
  void setActiveRoute(NavigationRoute? route) {
    _activeRoute = route;
    _currentRouteSegmentIndex = 0;
    if (route != null) {
      debugPrint('🗺️ Active route set: ${route.nodes.length} nodes');
      for (int i = 0; i < route.nodes.length; i++) {
        debugPrint('  Node $i: ${route.nodes[i].name} (${route.nodes[i].x}, ${route.nodes[i].y})');
      }
    } else {
      debugPrint('🗺️ Active route cleared');
      // Reset smoothed position when route is cleared
      _smoothedX = null;
      _smoothedY = null;
    }
  }
  
  /// Calculate position on route based on beacon distances
  /// Uses simple interpolation along the entire route based on relative distances
  BeaconNode? _calculateRoutePosition(double? distanceA, double? distanceB) {
    if (_activeRoute == null || _activeRoute!.nodes.isEmpty) return null;
    
    final routeNodes = _activeRoute!.nodes;
    if (routeNodes.length < 2) return null;
    
    // We need at least one distance measurement
    if (distanceA == null && distanceB == null) return null;
    
    // Calculate total route length (sum of all segment lengths)
    double totalRouteLength = 0;
    List<double> cumulativeLengths = [0];  // Distance from start to each node
    
    for (int i = 1; i < routeNodes.length; i++) {
      final segmentLength = _calculateNodeDistance(routeNodes[i - 1], routeNodes[i]);
      totalRouteLength += segmentLength;
      cumulativeLengths.add(totalRouteLength);
    }
    
    if (totalRouteLength < 1.0) return routeNodes.first;
    
    // Calculate progress along route (0 = start, 1 = end)
    // Based on relative distances to both beacons
    double progress;
    
    if (distanceA != null && distanceB != null) {
      // Both beacons detected - use ratio of distances
      // Closer to A (smaller distanceA) = closer to start
      // Closer to B (smaller distanceB) = closer to end
      final totalDistance = distanceA + distanceB;
      if (totalDistance > 0) {
        // progress = how far along route (0=at A/start, 1=at B/end)
        progress = (distanceA / totalDistance).clamp(0.0, 1.0);
      } else {
        progress = 0.5;
      }
    } else if (distanceA != null) {
      // Only beacon A detected - estimate based on distance
      // Assume max reasonable indoor distance is ~15m
      progress = (distanceA / 15.0).clamp(0.0, 1.0);
    } else {
      // Only beacon B detected
      progress = 1.0 - (distanceB! / 15.0).clamp(0.0, 1.0);
    }
    
    // Convert progress to position along route
    final targetDistance = progress * totalRouteLength;
    
    // Find which segment we're on
    int segmentIndex = 0;
    for (int i = 1; i < cumulativeLengths.length; i++) {
      if (targetDistance <= cumulativeLengths[i]) {
        segmentIndex = i - 1;
        break;
      }
      segmentIndex = i - 1;
    }
    
    // Calculate position within segment
    final segmentStart = routeNodes[segmentIndex];
    final segmentEnd = routeNodes[min(segmentIndex + 1, routeNodes.length - 1)];
    final segmentStartDist = cumulativeLengths[segmentIndex];
    final segmentLength = _calculateNodeDistance(segmentStart, segmentEnd);
    
    double segmentProgress = 0;
    if (segmentLength > 0) {
      segmentProgress = ((targetDistance - segmentStartDist) / segmentLength).clamp(0.0, 1.0);
    }
    
    // Interpolate position EXACTLY on segment - no smoothing to avoid cutting corners
    final exactX = segmentStart.x + (segmentEnd.x - segmentStart.x) * segmentProgress;
    final exactY = segmentStart.y + (segmentEnd.y - segmentStart.y) * segmentProgress;
    
    _currentRouteSegmentIndex = segmentIndex;
    
    debugPrint('📍 Route position: progress=${(progress * 100).toStringAsFixed(0)}%, segment=$segmentIndex, pos=(${exactX.toStringAsFixed(0)}, ${exactY.toStringAsFixed(0)})');
    
    return BeaconNode(
      uid: 'route_position',
      name: 'On Route',
      x: exactX,
      y: exactY,
      floor: segmentStart.floor,
      departmentId: '',
      connectedNodes: [],
    );
  }
  
  /// Calculate distance between two nodes (pixels)
  double _calculateNodeDistance(BeaconNode a, BeaconNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }
}
