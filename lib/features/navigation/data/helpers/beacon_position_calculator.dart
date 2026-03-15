import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../domain/entities/beacon_node.dart';
import '../../domain/entities/navigation_route.dart';

/// Helper class for calculating user position based on beacon signals.
class BeaconPositionCalculator {
  /// Calculate position constrained to the active route.
  /// Follows the EXACT route path through all waypoints/turns.
  static BeaconNode? calculateRouteConstrainedPosition(
    NavigationRoute route,
    Map<String, double> nodeDistanceMap,
  ) {
    final routeNodes = route.nodes;
    if (routeNodes.length < 2) return null;

    final startNode = routeNodes.first;
    final endNode = routeNodes.last;

    final distToStart = nodeDistanceMap[startNode.uid];
    final distToEnd = nodeDistanceMap[endNode.uid];

    if (distToStart == null && distToEnd == null) {
      debugPrint('📍 No start/end beacons detected, falling back');
      return null;
    }

    // Calculate cumulative distances along the route
    double totalRouteLength = 0;
    final cumulativeLengths = <double>[0];

    for (int i = 1; i < routeNodes.length; i++) {
      final segmentLength = calculateNodeDistance(routeNodes[i - 1], routeNodes[i]);
      totalRouteLength += segmentLength;
      cumulativeLengths.add(totalRouteLength);
    }

    if (totalRouteLength < 1.0) return routeNodes.first;

    // Calculate progress along route (0 = at start, 1 = at end)
    double progress = _calculateProgress(distToStart, distToEnd);

    // Convert progress to actual position along the route
    final targetDistance = progress * totalRouteLength;

    // Find which segment we're on
    int segmentIndex = 0;
    for (int i = 1; i < cumulativeLengths.length; i++) {
      if (targetDistance <= cumulativeLengths[i]) {
        segmentIndex = i - 1;
        break;
      }
      segmentIndex = routeNodes.length - 2;
    }

    // Calculate position EXACTLY on this segment
    final segmentStart = routeNodes[segmentIndex];
    final segmentEnd = routeNodes[min(segmentIndex + 1, routeNodes.length - 1)];
    final segmentStartDist = cumulativeLengths[segmentIndex];
    final segmentLength = calculateNodeDistance(segmentStart, segmentEnd);

    double segmentProgress = 0;
    if (segmentLength > 0) {
      segmentProgress = ((targetDistance - segmentStartDist) / segmentLength).clamp(0.0, 1.0);
    }

    // Interpolate position EXACTLY on segment
    final x = segmentStart.x + (segmentEnd.x - segmentStart.x) * segmentProgress;
    final y = segmentStart.y + (segmentEnd.y - segmentStart.y) * segmentProgress;

    debugPrint('📍 Route: ${(progress * 100).toStringAsFixed(0)}% total, segment ${segmentIndex + 1}/${routeNodes.length - 1}');

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

  /// Calculate progress based on distances to start and end beacons.
  static double _calculateProgress(double? distToStart, double? distToEnd) {
    if (distToStart != null && distToEnd != null) {
      final totalDistance = distToStart + distToEnd;
      if (totalDistance > 0) {
        return (distToStart / totalDistance).clamp(0.0, 1.0);
      }
      return 0.5;
    } else if (distToStart != null) {
      return (distToStart / 20.0).clamp(0.0, 1.0);
    } else {
      return 1.0 - (distToEnd! / 20.0).clamp(0.0, 1.0);
    }
  }

  /// Calculate distance between two nodes (pixels).
  static double calculateNodeDistance(BeaconNode a, BeaconNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Check if there's significant movement between two positions.
  static bool hasSignificantMovement(BeaconNode oldPos, BeaconNode newPos) {
    const threshold = 25.0;
    final dx = oldPos.x - newPos.x;
    final dy = oldPos.y - newPos.y;
    final distance = sqrt(dx * dx + dy * dy);
    return distance > threshold;
  }

  /// Convert RSSI to distance using Apple's iBeacon ranging algorithm.
  static double rssiToDistance(int rssi) {
    const double txPower = -59.0;

    if (rssi == 0) {
      return -1.0;
    }

    final double ratio = rssi / txPower;

    if (ratio < 1.0) {
      return pow(ratio, 10).toDouble().clamp(0.1, 1.0);
    } else {
      const double A = 0.89976;
      const double B = 7.7095;
      const double C = 0.111;

      final double distance = A * pow(ratio, B) + C;
      return distance.clamp(0.1, 30.0);
    }
  }
}
