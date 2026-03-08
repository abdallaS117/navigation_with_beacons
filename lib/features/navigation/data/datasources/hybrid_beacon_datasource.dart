import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/beacon_node.dart';
import '../../domain/entities/navigation_route.dart';
import '../../../configuration/data/repositories/configuration_repository.dart';
import '../../../configuration/domain/models/configurable_beacon.dart';
import '../../../configuration/domain/models/configurable_node.dart';

// Abstract interface for beacon data sources
abstract class BeaconDataSource {
  Stream<BeaconNode?> get nearestBeaconStream;
  List<BeaconNode> getAllBeacons();
  BeaconNode? getBeaconByUid(String uid);
  List<BeaconNode> getBeaconsByFloor(int floor);
  Future<void> startScanning();
  void stopScanning();
  Future<void> reloadConfiguration();
  void dispose();
}

class DetectedBeacon {
  final String beaconId;
  final int rssi;
  final double distance;

  const DetectedBeacon({
    required this.beaconId,
    required this.rssi,
    required this.distance,
  });
}

class BeaconStatus {
  final List<DetectedBeacon> detectedBeacons;
  final bool isScanning;
  final String? currentLocation;

  const BeaconStatus({
    this.detectedBeacons = const [],
    this.isScanning = false,
    this.currentLocation,
  });
}

class HybridBeaconDataSource implements BeaconDataSource {
  final ConfigurationRepository configurationRepository;
  final _beaconController = StreamController<BeaconNode?>.broadcast();
  final _statusController = StreamController<BeaconStatus>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  bool _isScanning = false;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _initialized = false;

  // Dynamic beacon configuration loaded from ConfigurationRepository
  List<ConfigurableBeacon> _configuredBeacons = [];
  List<BeaconNode> _navigationNodes = [];
  Map<String, String> _beaconUuidToNodeId = {}; // Maps beacon UUID to node ID

  HybridBeaconDataSource(this.configurationRepository) {
    _loadConfiguration();
  }

  Future<void> reloadConfiguration() async {
    await _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    try {
      final config = await configurationRepository.getConfiguration();
      _configuredBeacons = config.beacons;
      
      // Convert configured nodes to BeaconNodes for navigation
      _navigationNodes = config.nodes.map((node) {
        return BeaconNode(
          uid: node.id,
          name: node.name,
          x: node.x,
          y: node.y,
          floor: node.floor,
          departmentId: node.type.name,
          connectedNodes: node.connections.map((conn) => conn.targetNodeId).toList(),
        );
      }).toList();
      
      // Build mapping of beacon UUID to node ID
      for (final node in config.nodes) {
        if (node.linkedBeaconId != null) {
          _beaconUuidToNodeId[node.linkedBeaconId!] = node.id;
          debugPrint('🔗 MAPPING: beacon "${node.linkedBeaconId}" → node "${node.id}" (${node.name}) at (${node.x}, ${node.y})');
        }
      }
      
      debugPrint('✅ Loaded ${_configuredBeacons.length} beacons and ${_navigationNodes.length} nodes from configuration');
      debugPrint('📍 Beacon-to-node mappings: $_beaconUuidToNodeId');
    } catch (e) {
      debugPrint('⚠️ Failed to load configuration: $e');
    }
  }

  // Dynamic beacon tracking - maps beacon UUID to RSSI and timestamp
  final Map<String, int> _beaconRssiMap = {};
  final Map<String, DateTime> _beaconLastSeenMap = {};
  
  // Position smoothing with exponential moving average
  double? _smoothedX;
  double? _smoothedY;
  static const double _positionSmoothingFactor = 0.15;  // 0.1=very smooth, 0.5=responsive

  Timer? _updateTimer;
  Timer? _fallbackTimer;
  BeaconNode? _currentInterpolatedPosition;
  
  // Active navigation route for snap-to-route feature
  NavigationRoute? _activeRoute;
  int _currentRouteSegmentIndex = 0;  // Which segment of the route we're on

  // Navigation nodes from dynamic configuration
  List<BeaconNode> get _allBeacons => _navigationNodes;

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
      final serviceData = result.advertisementData.serviceData;
      final rssi = result.rssi;
      
      String? beaconId;
      String? beaconType;
      
      // Only detect Eddystone beacons (Google service UUID 0xFEAA)
      // Service data keys are Guid objects, need to check by string representation
      if (serviceData.isNotEmpty) {
        List<int>? eddystoneData;
        
        // Find Eddystone service data by checking if key contains 'feaa'
        for (final entry in serviceData.entries) {
          final keyStr = entry.key.toString().toLowerCase();
          if (keyStr.contains('feaa')) {
            eddystoneData = entry.value;
            debugPrint('🔎 Found Eddystone service with key: $keyStr');
            break;
          }
        }
        
        if (eddystoneData != null) {
          final data = eddystoneData;
        
          debugPrint('🔎 Eddystone data found! Length: ${data.length}, Data: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          
          if (data.isNotEmpty) {
            final frameType = data[0];
            debugPrint('🔎 Eddystone frame type: 0x${frameType.toRadixString(16).padLeft(2, '0')}');
            
            // Eddystone-UID frame (0x00)
            if (frameType == 0x00 && data.length >= 18) {
              final namespace = data.sublist(2, 12).map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
              final instance = data.sublist(12, 18).map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
              
              // Use format compatible with stored configuration: beacon_NAMESPACE+INSTANCE_0_0
              beaconId = 'beacon_${namespace}${instance}_0_0';
              beaconType = 'Eddystone-UID';
              debugPrint('🔍 Scanned $beaconType: Namespace=$namespace, Instance=$instance → beaconId=$beaconId');
            }
            // Eddystone-URL frame (0x10)
            else if (frameType == 0x10 && data.length >= 4) {
              final urlScheme = _getEddystoneUrlScheme(data[2]);
              final urlBytes = data.sublist(3);
              final url = urlScheme + String.fromCharCodes(urlBytes);
              final urlHash = url.hashCode.toRadixString(16).padLeft(8, '0');
              
              beaconId = 'beacon_eddystone_url_$urlHash';
              beaconType = 'Eddystone-URL';
              debugPrint('🔍 Scanned $beaconType: URL=$url → beaconId=$beaconId');
            }
            // Eddystone-EID frame (0x30)
            else if (frameType == 0x30 && data.length >= 10) {
              final eid = data.sublist(2, 10).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
              
              beaconId = 'beacon_eddystone_eid_$eid';
              beaconType = 'Eddystone-EID';
              debugPrint('🔍 Scanned $beaconType: EID=$eid → beaconId=$beaconId');
            }
          }
        }
      }
      
      // Process detected Eddystone beacon
      if (beaconId != null) {
        if (_beaconUuidToNodeId.containsKey(beaconId)) {
          _beaconRssiMap[beaconId] = rssi;
          _beaconLastSeenMap[beaconId] = now;
          final nodeId = _beaconUuidToNodeId[beaconId];
          debugPrint('✅ MATCH! Beacon $beaconId ($beaconType) → Node $nodeId, RSSI: $rssi');
        } else {
          debugPrint('❌ NO MATCH for beaconId: $beaconId ($beaconType)');
          debugPrint('   Available mappings: ${_beaconUuidToNodeId.keys.toList()}');
        }
      }
    }

    // Clear stale beacons
    final staleBeacons = <String>[];
    _beaconLastSeenMap.forEach((beaconId, lastSeen) {
      if (now.difference(lastSeen).inSeconds > 10) {
        staleBeacons.add(beaconId);
      }
    });
    
    for (final beaconId in staleBeacons) {
      _beaconRssiMap.remove(beaconId);
      _beaconLastSeenMap.remove(beaconId);
      debugPrint('🔴 Beacon $beaconId stale, clearing');
    }
  }
  
  String _getEddystoneUrlScheme(int schemeByte) {
    switch (schemeByte) {
      case 0x00: return 'http://www.';
      case 0x01: return 'https://www.';
      case 0x02: return 'http://';
      case 0x03: return 'https://';
      default: return '';
    }
  }

  String _extractUuid(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
           '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _startPositionUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      _calculateInterpolatedPosition();
    });
  }

  void _calculateInterpolatedPosition() {
    // Check if any beacons are detected
    if (_beaconRssiMap.isEmpty) {
      _emitStatus(null, null, 'Searching for beacons...');
      return;
    }

    // Build a map of node IDs to their RSSI values and distances
    final nodeRssiMap = <String, int>{};
    final nodeDistanceMap = <String, double>{};
    
    _beaconRssiMap.forEach((beaconId, rssi) {
      final nodeId = _beaconUuidToNodeId[beaconId];
      if (nodeId != null) {
        // Keep the strongest RSSI for each node (in case multiple beacons map to same node)
        if (!nodeRssiMap.containsKey(nodeId) || rssi > nodeRssiMap[nodeId]!) {
          nodeRssiMap[nodeId] = rssi;
          nodeDistanceMap[nodeId] = _rssiToDistance(rssi);
        }
      }
    });
    
    if (nodeRssiMap.isEmpty) {
      _emitStatus(null, null, 'No mapped beacons detected');
      return;
    }

    // IF NAVIGATION IS ACTIVE: Use route-constrained positioning
    if (_activeRoute != null && _activeRoute!.nodes.length >= 2) {
      final routePosition = _calculateRouteConstrainedPosition(nodeDistanceMap);
      if (routePosition != null) {
        _emitStatus(nodeDistanceMap.values.isNotEmpty ? nodeDistanceMap.values.first : null, null, 'On Route');
        _emitPosition(routePosition);
        return;
      }
    }
    
    // FALLBACK: Snap to nearest beacon's node position
    String? nearestNodeId;
    int strongestRssi = -200;
    
    nodeRssiMap.forEach((nodeId, rssi) {
      if (rssi > strongestRssi) {
        strongestRssi = rssi;
        nearestNodeId = nodeId;
      }
    });
    
    if (nearestNodeId == null) {
      _emitStatus(null, null, 'No beacons detected');
      return;
    }
    
    // Find the node in navigation nodes
    final node = _navigationNodes.firstWhere(
      (n) => n.uid == nearestNodeId,
      orElse: () => _navigationNodes.first,
    );
    
    // Calculate distance from RSSI
    final distance = _rssiToDistance(strongestRssi);
    final currentLocation = '${node.name} - ${distance.toStringAsFixed(1)}m';
    
    // Emit the nearest beacon position
    final beaconNode = BeaconNode(
      uid: nearestNodeId!,
      name: node.name,
      x: node.x,
      y: node.y,
      floor: node.floor,
      departmentId: node.departmentId,
      connectedNodes: node.connectedNodes,
    );
    
    _emitStatus(distance, null, currentLocation);
    _emitPosition(beaconNode);
  }
  
  /// Calculate position constrained to the active route
  /// Follows the EXACT route path through all waypoints/turns
  /// Uses distance to start and end beacons to calculate progress along total route
  BeaconNode? _calculateRouteConstrainedPosition(Map<String, double> nodeDistanceMap) {
    if (_activeRoute == null) return null;
    
    final routeNodes = _activeRoute!.nodes;
    if (routeNodes.length < 2) return null;
    
    // Get the start and end nodes of the route (they should have beacons)
    final startNode = routeNodes.first;
    final endNode = routeNodes.last;
    
    // Get distances to start and end beacons
    final distToStart = nodeDistanceMap[startNode.uid];
    final distToEnd = nodeDistanceMap[endNode.uid];
    
    // We need at least one distance measurement
    if (distToStart == null && distToEnd == null) {
      debugPrint('📍 No start/end beacons detected, falling back');
      return null;
    }
    
    // Calculate cumulative distances along the route (following all segments)
    double totalRouteLength = 0;
    final cumulativeLengths = <double>[0]; // Distance from start to each node
    
    for (int i = 1; i < routeNodes.length; i++) {
      final segmentLength = _calculateNodeDistance(routeNodes[i - 1], routeNodes[i]);
      totalRouteLength += segmentLength;
      cumulativeLengths.add(totalRouteLength);
    }
    
    if (totalRouteLength < 1.0) return routeNodes.first;
    
    // Calculate progress along route (0 = at start, 1 = at end)
    double progress;
    
    if (distToStart != null && distToEnd != null) {
      // Both beacons detected - use ratio of distances
      final totalDistance = distToStart + distToEnd;
      if (totalDistance > 0) {
        // Closer to start (smaller distToStart) = closer to 0
        // Closer to end (smaller distToEnd) = closer to 1
        progress = (distToStart / totalDistance).clamp(0.0, 1.0);
      } else {
        progress = 0.5;
      }
    } else if (distToStart != null) {
      // Only start beacon detected - estimate based on distance
      // Assume max reasonable indoor distance is ~20m
      progress = (distToStart / 20.0).clamp(0.0, 1.0);
    } else {
      // Only end beacon detected
      progress = 1.0 - (distToEnd! / 20.0).clamp(0.0, 1.0);
    }
    
    // Convert progress to actual position along the route (following all segments)
    final targetDistance = progress * totalRouteLength;
    
    // Find which segment we're on
    int segmentIndex = 0;
    for (int i = 1; i < cumulativeLengths.length; i++) {
      if (targetDistance <= cumulativeLengths[i]) {
        segmentIndex = i - 1;
        break;
      }
      segmentIndex = routeNodes.length - 2; // Last segment
    }
    
    // Calculate position EXACTLY on this segment
    final segmentStart = routeNodes[segmentIndex];
    final segmentEnd = routeNodes[min(segmentIndex + 1, routeNodes.length - 1)];
    final segmentStartDist = cumulativeLengths[segmentIndex];
    final segmentLength = _calculateNodeDistance(segmentStart, segmentEnd);
    
    double segmentProgress = 0;
    if (segmentLength > 0) {
      segmentProgress = ((targetDistance - segmentStartDist) / segmentLength).clamp(0.0, 1.0);
    }
    
    // Interpolate position EXACTLY on segment - follows the path precisely
    final x = segmentStart.x + (segmentEnd.x - segmentStart.x) * segmentProgress;
    final y = segmentStart.y + (segmentEnd.y - segmentStart.y) * segmentProgress;
    
    debugPrint('📍 Route: ${(progress * 100).toStringAsFixed(0)}% total, segment ${segmentIndex + 1}/${routeNodes.length - 1}: ${segmentStart.name} → ${segmentEnd.name}');
    
    _currentRouteSegmentIndex = segmentIndex;
    
    return BeaconNode(
      uid: 'route_position',
      name: 'On Route: ${segmentStart.name} → ${segmentEnd.name}',
      x: x,
      y: y,
      floor: segmentStart.floor,
      departmentId: '',
      connectedNodes: [],
    );
  }

  void _emitStatus(double? distanceA, double? distanceB, String? location) {
    final detectedBeacons = <DetectedBeacon>[];
    
    _beaconRssiMap.forEach((beaconId, rssi) {
      final distance = _rssiToDistance(rssi);
      detectedBeacons.add(DetectedBeacon(
        beaconId: beaconId,
        rssi: rssi,
        distance: distance,
      ));
    });
    
    detectedBeacons.sort((a, b) => b.rssi.compareTo(a.rssi));
    
    _statusController.add(BeaconStatus(
      detectedBeacons: detectedBeacons,
      isScanning: _isScanning,
      currentLocation: location,
    ));
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
    _beaconRssiMap.clear();
    _beaconLastSeenMap.clear();
    debugPrint('🛑 Beacon scan stopped');
  }

  @override
  void dispose() {
    stopScanning();
    _beaconController.close();
    _statusController.close();
  }

  Map<String, int?> getCurrentRssiValues() {
    return Map<String, int?>.from(_beaconRssiMap);
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
