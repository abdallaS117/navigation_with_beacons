import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/beacon_node.dart';
import '../../domain/entities/navigation_route.dart';
import '../../../configuration/data/repositories/configuration_repository.dart';
import '../../../configuration/domain/models/configurable_beacon.dart';
import '../helpers/beacon_position_calculator.dart';
import '../helpers/eddystone_parser.dart';

/// Abstract interface for beacon data sources.
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

/// Status of a detected beacon.
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

/// Overall beacon scanning status.
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

/// Hybrid beacon data source that uses real Bluetooth scanning.
/// 
/// Refactored to use helper classes:
/// - [BeaconPositionCalculator] for position calculations
/// - [EddystoneParser] for beacon data parsing
class HybridBeaconDataSource implements BeaconDataSource {
  final ConfigurationRepository configurationRepository;
  final _beaconController = StreamController<BeaconNode?>.broadcast();
  final _statusController = StreamController<BeaconStatus>.broadcast();
  
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  
  bool _isScanning = false;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _initialized = false;

  // Dynamic beacon configuration
  List<ConfigurableBeacon> _configuredBeacons = [];
  List<BeaconNode> _navigationNodes = [];
  Map<String, String> _beaconUuidToNodeId = {};

  // Beacon tracking
  final Map<String, int> _beaconRssiMap = {};
  final Map<String, DateTime> _beaconLastSeenMap = {};

  Timer? _updateTimer;
  Timer? _fallbackTimer;
  BeaconNode? _currentInterpolatedPosition;

  // Active navigation route
  NavigationRoute? _activeRoute;
  int _currentRouteSegmentIndex = 0;

  HybridBeaconDataSource(this.configurationRepository) {
    _loadConfiguration();
  }

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

  @override
  Future<void> reloadConfiguration() async {
    await _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    try {
      final config = await configurationRepository.getConfiguration();
      _configuredBeacons = config.beacons;

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

      _beaconUuidToNodeId.clear();
      for (final node in config.nodes) {
        if (node.linkedBeaconId != null) {
          _beaconUuidToNodeId[node.linkedBeaconId!] = node.id;
          debugPrint('🔗 MAPPING: beacon "${node.linkedBeaconId}" → node "${node.id}"');
        }
      }

      debugPrint('✅ Loaded ${_configuredBeacons.length} beacons and ${_navigationNodes.length} nodes');
    } catch (e) {
      debugPrint('⚠️ Failed to load configuration: $e');
    }
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
    debugPrint('✅ HybridBeaconDataSource initialized');
  }

  @override
  Future<void> startScanning() async {
    debugPrint('🚀 HybridBeaconDataSource.startScanning() CALLED');

    await _initialize();

    if (_isScanning) {
      debugPrint('⚠️ Already scanning');
      return;
    }

    final permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      debugPrint('❌ Bluetooth permissions not granted');
      _emitStatus('Bluetooth permissions required');
      return;
    }

    if (_adapterState != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('⚠️ Could not turn on Bluetooth: $e');
      }

      if (_adapterState != BluetoothAdapterState.on) {
        _emitStatus('Bluetooth is turned off');
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
      await FlutterBluePlus.startScan(
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: true,
        continuousUpdates: true,
        continuousDivisor: 1,
      );
      debugPrint('✅ Beacon scan started successfully');
      _startPositionUpdates();
    } catch (e) {
      debugPrint('❌ Failed to start scan: $e');
      _isScanning = false;
      _emitStatus('Scan failed: $e');
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

      if (serviceData.isNotEmpty) {
        List<int>? eddystoneData;

        for (final entry in serviceData.entries) {
          final keyStr = entry.key.toString().toLowerCase();
          if (keyStr.contains('feaa')) {
            eddystoneData = entry.value;
            break;
          }
        }

        if (eddystoneData != null) {
          beaconId = EddystoneParser.parseEddystoneData(eddystoneData);
        }
      }

      if (beaconId != null && _beaconUuidToNodeId.containsKey(beaconId)) {
        _beaconRssiMap[beaconId] = rssi;
        _beaconLastSeenMap[beaconId] = now;
        final nodeId = _beaconUuidToNodeId[beaconId];
        debugPrint('✅ MATCH! Beacon $beaconId → Node $nodeId, RSSI: $rssi');
      }
    }

    _clearStaleBeacons(now);
  }

  void _clearStaleBeacons(DateTime now) {
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

  void _startPositionUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      _calculateInterpolatedPosition();
    });
  }

  void _calculateInterpolatedPosition() {
    if (_beaconRssiMap.isEmpty) {
      _emitStatus('Searching for beacons...');
      return;
    }

    // Build node distance map
    final nodeDistanceMap = <String, double>{};
    _beaconRssiMap.forEach((beaconId, rssi) {
      final nodeId = _beaconUuidToNodeId[beaconId];
      if (nodeId != null) {
        final distance = BeaconPositionCalculator.rssiToDistance(rssi);
        if (!nodeDistanceMap.containsKey(nodeId) || distance < nodeDistanceMap[nodeId]!) {
          nodeDistanceMap[nodeId] = distance;
        }
      }
    });

    if (nodeDistanceMap.isEmpty) {
      _emitStatus('No mapped beacons detected');
      return;
    }

    // Route-constrained positioning
    if (_activeRoute != null && _activeRoute!.nodes.length >= 2) {
      final routePosition = BeaconPositionCalculator.calculateRouteConstrainedPosition(
        _activeRoute!,
        nodeDistanceMap,
      );
      if (routePosition != null) {
        _emitStatus('On Route');
        _emitPosition(routePosition);
        return;
      }
    }

    // Fallback: snap to nearest beacon
    _snapToNearestBeacon(nodeDistanceMap);
  }

  void _snapToNearestBeacon(Map<String, double> nodeDistanceMap) {
    String? nearestNodeId;
    int strongestRssi = -200;

    _beaconRssiMap.forEach((beaconId, rssi) {
      final nodeId = _beaconUuidToNodeId[beaconId];
      if (nodeId != null && rssi > strongestRssi) {
        strongestRssi = rssi;
        nearestNodeId = nodeId;
      }
    });

    if (nearestNodeId == null || _navigationNodes.isEmpty) {
      _emitStatus('No beacons detected');
      return;
    }

    final node = _navigationNodes.firstWhere(
      (n) => n.uid == nearestNodeId,
      orElse: () => _navigationNodes.first,
    );

    final distance = BeaconPositionCalculator.rssiToDistance(strongestRssi);
    final currentLocation = '${node.name} - ${distance.toStringAsFixed(1)}m';

    final beaconNode = BeaconNode(
      uid: nearestNodeId!,
      name: node.name,
      x: node.x,
      y: node.y,
      floor: node.floor,
      departmentId: node.departmentId,
      connectedNodes: node.connectedNodes,
    );

    _emitStatus(currentLocation);
    _emitPosition(beaconNode);
  }

  void _emitStatus(String? location) {
    final detectedBeacons = <DetectedBeacon>[];

    _beaconRssiMap.forEach((beaconId, rssi) {
      final distance = BeaconPositionCalculator.rssiToDistance(rssi);
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

  void _emitPosition(BeaconNode node) {
    if (_currentInterpolatedPosition == null ||
        BeaconPositionCalculator.hasSignificantMovement(_currentInterpolatedPosition!, node)) {
      _currentInterpolatedPosition = node;
      _beaconController.add(node);
    }
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

  /// Set the active navigation route for snap-to-route positioning.
  void setActiveRoute(NavigationRoute? route) {
    _activeRoute = route;
    _currentRouteSegmentIndex = 0;
    if (route != null) {
      debugPrint('🗺️ Active route set: ${route.nodes.length} nodes');
    } else {
      debugPrint('🗺️ Active route cleared');
    }
  }

  int get currentRouteSegmentIndex => _currentRouteSegmentIndex;
}
