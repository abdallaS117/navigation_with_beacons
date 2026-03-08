import 'dart:math';
import '../entities/beacon_node.dart';
import '../entities/navigation_route.dart';

class RouteProgressCalculator {
  /// Calculate position along route based on beacon distances
  /// Returns a BeaconNode representing the estimated position on the route
  BeaconNode? calculatePositionOnRoute({
    required NavigationRoute route,
    required Map<String, double> beaconDistances,
    BeaconNode? lastKnownPosition,
  }) {
    if (route.nodes.isEmpty) return null;

    // Get all beacons that we have distance measurements for
    final knownBeacons = <BeaconNode>[];
    final distances = <double>[];

    for (final entry in beaconDistances.entries) {
      final beaconNode = route.nodes.firstWhere(
        (node) => node.uid == entry.key,
        orElse: () => route.nodes.first,
      );
      
      // Check if this beacon is on or near the route
      if (_isBeaconOnRoute(beaconNode, route)) {
        knownBeacons.add(beaconNode);
        distances.add(entry.value);
      }
    }

    if (knownBeacons.isEmpty) {
      return lastKnownPosition ?? route.nodes.first;
    }

    // Single beacon: estimate position based on distance change
    if (knownBeacons.length == 1) {
      return _estimatePositionFromSingleBeacon(
        beacon: knownBeacons[0],
        distance: distances[0],
        route: route,
        lastPosition: lastKnownPosition,
      );
    }

    // Multiple beacons: use trilateration
    return _trilateratePosition(
      beacons: knownBeacons,
      distances: distances,
      route: route,
    );
  }

  /// Check if a beacon is on or near the route
  bool _isBeaconOnRoute(BeaconNode beacon, NavigationRoute route) {
    for (final node in route.nodes) {
      if (node.uid == beacon.uid) return true;
      
      // Check if beacon is close to any route node (within 50 pixels)
      final distance = _calculateDistance(beacon.x, beacon.y, node.x, node.y);
      if (distance < 50) return true;
    }
    return false;
  }

  /// Estimate position from single beacon based on distance
  BeaconNode _estimatePositionFromSingleBeacon({
    required BeaconNode beacon,
    required double distance,
    required NavigationRoute route,
    BeaconNode? lastPosition,
  }) {
    // Find beacon's position in route
    int beaconIndex = -1;
    for (int i = 0; i < route.nodes.length; i++) {
      if (route.nodes[i].uid == beacon.uid) {
        beaconIndex = i;
        break;
      }
    }

    if (beaconIndex == -1) {
      // Beacon not on route, find closest route node
      return _findClosestNodeOnRoute(beacon.x, beacon.y, route);
    }

    // Convert distance (meters) to approximate pixels (1 meter ≈ 30 pixels)
    final distancePixels = distance * 30;

    // If very close to beacon (< 2 meters), return beacon position
    if (distance < 2.0) {
      return beacon;
    }

    // Determine direction: moving forward or backward on route
    bool movingForward = true;
    if (lastPosition != null) {
      final lastDistToBeacon = _calculateDistance(
        lastPosition.x, lastPosition.y, beacon.x, beacon.y,
      );
      movingForward = distancePixels > lastDistToBeacon;
    }

    // Find position along route at approximately 'distancePixels' from beacon
    if (movingForward && beaconIndex < route.nodes.length - 1) {
      // Moving away from beacon toward destination
      return _interpolateAlongRoute(
        route: route,
        startIndex: beaconIndex,
        targetDistance: distancePixels,
        forward: true,
      );
    } else if (!movingForward && beaconIndex > 0) {
      // Moving back toward beacon
      return _interpolateAlongRoute(
        route: route,
        startIndex: beaconIndex,
        targetDistance: distancePixels,
        forward: false,
      );
    }

    return beacon;
  }

  /// Interpolate position along route segments
  BeaconNode _interpolateAlongRoute({
    required NavigationRoute route,
    required int startIndex,
    required double targetDistance,
    required bool forward,
  }) {
    double accumulatedDistance = 0;
    int currentIndex = startIndex;

    while (forward ? currentIndex < route.nodes.length - 1 : currentIndex > 0) {
      final current = route.nodes[currentIndex];
      final next = route.nodes[forward ? currentIndex + 1 : currentIndex - 1];

      final segmentDistance = _calculateDistance(
        current.x, current.y, next.x, next.y,
      );

      if (accumulatedDistance + segmentDistance >= targetDistance) {
        // Target is within this segment
        final remainingDistance = targetDistance - accumulatedDistance;
        final ratio = remainingDistance / segmentDistance;

        return BeaconNode(
          uid: 'interpolated_${current.uid}_${next.uid}',
          name: 'Moving along route',
          x: _lerp(current.x, next.x, ratio),
          y: _lerp(current.y, next.y, ratio),
          floor: current.floor,
          connectedNodes: [],
        );
      }

      accumulatedDistance += segmentDistance;
      currentIndex = forward ? currentIndex + 1 : currentIndex - 1;
    }

    // Reached end of route
    return route.nodes[forward ? route.nodes.length - 1 : 0];
  }

  /// Trilaterate position using multiple beacons
  BeaconNode _trilateratePosition({
    required List<BeaconNode> beacons,
    required List<double> distances,
    required NavigationRoute route,
  }) {
    if (beacons.length < 2) {
      return beacons[0];
    }

    // Use first two beacons for trilateration
    final beacon1 = beacons[0];
    final beacon2 = beacons[1];
    final dist1 = distances[0] * 30; // Convert to pixels
    final dist2 = distances[1] * 30;

    // Calculate intersection points of two circles
    final d = _calculateDistance(beacon1.x, beacon1.y, beacon2.x, beacon2.y);

    if (d > dist1 + dist2 || d < (dist1 - dist2).abs() || d == 0) {
      // Circles don't intersect properly, use weighted average
      final weight1 = 1 / (dist1 + 1);
      final weight2 = 1 / (dist2 + 1);
      final totalWeight = weight1 + weight2;

      final x = (beacon1.x * weight1 + beacon2.x * weight2) / totalWeight;
      final y = (beacon1.y * weight1 + beacon2.y * weight2) / totalWeight;

      return _snapToRoute(x, y, route);
    }

    // Calculate intersection point
    final a = (dist1 * dist1 - dist2 * dist2 + d * d) / (2 * d);
    final h = sqrt(dist1 * dist1 - a * a);

    final x2 = beacon1.x + a * (beacon2.x - beacon1.x) / d;
    final y2 = beacon1.y + a * (beacon2.y - beacon1.y) / d;

    // Two possible intersection points
    final x3_1 = x2 + h * (beacon2.y - beacon1.y) / d;
    final y3_1 = y2 - h * (beacon2.x - beacon1.x) / d;

    final x3_2 = x2 - h * (beacon2.y - beacon1.y) / d;
    final y3_2 = y2 + h * (beacon2.x - beacon1.x) / d;

    // Choose the point closer to the route
    final point1 = _snapToRoute(x3_1, y3_1, route);
    final point2 = _snapToRoute(x3_2, y3_2, route);

    final dist1ToRoute = _distanceToRoute(x3_1, y3_1, route);
    final dist2ToRoute = _distanceToRoute(x3_2, y3_2, route);

    return dist1ToRoute < dist2ToRoute ? point1 : point2;
  }

  /// Snap a position to the nearest point on the route
  BeaconNode _snapToRoute(double x, double y, NavigationRoute route) {
    double minDistance = double.infinity;
    BeaconNode? closestPoint;

    for (int i = 0; i < route.nodes.length - 1; i++) {
      final start = route.nodes[i];
      final end = route.nodes[i + 1];

      final point = _closestPointOnSegment(x, y, start, end);
      final distance = _calculateDistance(x, y, point.x, point.y);

      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = point;
      }
    }

    return closestPoint ?? route.nodes.first;
  }

  /// Find closest point on a line segment
  BeaconNode _closestPointOnSegment(
    double px, double py,
    BeaconNode start,
    BeaconNode end,
  ) {
    final dx = end.x - start.x;
    final dy = end.y - start.y;

    if (dx == 0 && dy == 0) return start;

    final t = ((px - start.x) * dx + (py - start.y) * dy) / (dx * dx + dy * dy);
    final clampedT = t.clamp(0.0, 1.0);

    return BeaconNode(
      uid: 'snapped_${start.uid}_${end.uid}',
      name: 'On route',
      x: start.x + clampedT * dx,
      y: start.y + clampedT * dy,
      floor: start.floor,
      connectedNodes: [],
    );
  }

  /// Calculate distance from point to route
  double _distanceToRoute(double x, double y, NavigationRoute route) {
    double minDistance = double.infinity;

    for (int i = 0; i < route.nodes.length - 1; i++) {
      final start = route.nodes[i];
      final end = route.nodes[i + 1];

      final point = _closestPointOnSegment(x, y, start, end);
      final distance = _calculateDistance(x, y, point.x, point.y);

      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  /// Find closest node on route to a position
  BeaconNode _findClosestNodeOnRoute(double x, double y, NavigationRoute route) {
    double minDistance = double.infinity;
    BeaconNode? closestNode;

    for (final node in route.nodes) {
      final distance = _calculateDistance(x, y, node.x, node.y);
      if (distance < minDistance) {
        minDistance = distance;
        closestNode = node;
      }
    }

    return closestNode ?? route.nodes.first;
  }

  double _calculateDistance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return sqrt(dx * dx + dy * dy);
  }

  double _lerp(double a, double b, double t) {
    return a + (b - a) * t.clamp(0.0, 1.0);
  }
}
