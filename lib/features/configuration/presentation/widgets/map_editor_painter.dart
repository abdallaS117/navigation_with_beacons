import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/models/models.dart';
import '../logic/configuration_state.dart';

/// Custom painter for rendering the map editor canvas.
/// Draws grid, connections, routes, and route progress.
class MapEditorPainter extends CustomPainter {
  final List<ConfigurableNode> nodes;
  final List<ConfigurableBeacon> beacons;
  final List<RouteConfig> routes;
  final String? selectedNodeId;
  final String? selectedBeaconId;
  final String? selectedRouteId;
  final ConfigurationMode mode;
  final List<String> routeNodesInProgress;
  final double scaleX;
  final double scaleY;

  MapEditorPainter({
    required this.nodes,
    required this.beacons,
    this.routes = const [],
    this.selectedNodeId,
    this.selectedBeaconId,
    this.selectedRouteId,
    required this.mode,
    this.routeNodesInProgress = const [],
    required this.scaleX,
    required this.scaleY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawSavedRoutes(canvas);
    _drawConnections(canvas);

    if (routeNodesInProgress.length >= 2) {
      _drawRouteInProgress(canvas);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    const gridSize = 50.0;

    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawConnections(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final selectedPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final oneWayPaint = Paint()
      ..color = Colors.orange.withOpacity(0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;

    final blockedPaint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final blockedSelectedPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    for (final node in nodes) {
      for (final connection in node.connections) {
        final targetNode = nodes.cast<ConfigurableNode?>().firstWhere(
          (n) => n?.id == connection.targetNodeId,
          orElse: () => null,
        );

        if (targetNode != null) {
          final isSelected = node.id == selectedNodeId || targetNode.id == selectedNodeId;
          final isOneWay = !connection.isBidirectional;
          final isBlocked = connection.type == ConnectionType.blocked;

          final startX = node.x / scaleX;
          final startY = node.y / scaleY;
          final endX = targetNode.x / scaleX;
          final endY = targetNode.y / scaleY;

          Paint linePaint;
          if (isBlocked) {
            linePaint = isSelected ? blockedSelectedPaint : blockedPaint;
          } else if (isSelected) {
            linePaint = selectedPaint;
          } else if (isOneWay) {
            linePaint = oneWayPaint;
          } else {
            linePaint = paint;
          }

          canvas.drawLine(
            Offset(startX, startY),
            Offset(endX, endY),
            linePaint,
          );

          if (isBlocked) {
            _drawBlockedIndicator(canvas, startX, startY, endX, endY);
          } else if (isOneWay) {
            _drawDirectionArrow(canvas, startX, startY, endX, endY, arrowPaint);
          }
        }
      }
    }
  }

  void _drawDirectionArrow(
    Canvas canvas,
    double startX,
    double startY,
    double endX,
    double endY,
    Paint paint,
  ) {
    final midX = (startX + endX) / 2;
    final midY = (startY + endY) / 2;
    final angle = atan2(endY - startY, endX - startX);

    final arrowPath = Path();
    arrowPath.moveTo(
      midX + 8 * cos(angle),
      midY + 8 * sin(angle),
    );
    arrowPath.lineTo(
      midX - 6 * cos(angle - 0.5),
      midY - 6 * sin(angle - 0.5),
    );
    arrowPath.lineTo(
      midX - 6 * cos(angle + 0.5),
      midY - 6 * sin(angle + 0.5),
    );
    arrowPath.close();
    canvas.drawPath(arrowPath, paint);
  }

  void _drawBlockedIndicator(
    Canvas canvas,
    double startX,
    double startY,
    double endX,
    double endY,
  ) {
    final midX = (startX + endX) / 2;
    final midY = (startY + endY) / 2;

    final blockedIconPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(midX, midY), 8, blockedIconPaint);
    canvas.drawLine(
      Offset(midX - 5, midY - 5),
      Offset(midX + 5, midY + 5),
      blockedIconPaint,
    );
  }

  void _drawRouteInProgress(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    for (int i = 0; i < routeNodesInProgress.length - 1; i++) {
      final currentId = routeNodesInProgress[i];
      final nextId = routeNodesInProgress[i + 1];

      final currentPos = _getElementPosition(currentId);
      final nextPos = _getElementPosition(nextId);

      if (currentPos != null && nextPos != null) {
        final currentX = currentPos.dx / scaleX;
        final currentY = currentPos.dy / scaleY;
        final nextX = nextPos.dx / scaleX;
        final nextY = nextPos.dy / scaleY;

        canvas.drawLine(
          Offset(currentX, currentY),
          Offset(nextX, nextY),
          paint,
        );

        _drawRouteArrow(canvas, currentX, currentY, nextX, nextY, arrowPaint);
      }
    }
  }

  void _drawRouteArrow(
    Canvas canvas,
    double currentX,
    double currentY,
    double nextX,
    double nextY,
    Paint arrowPaint,
  ) {
    final midX = (currentX + nextX) / 2;
    final midY = (currentY + nextY) / 2;
    final angle = atan2(nextY - currentY, nextX - currentX);

    final arrowPath = Path();
    arrowPath.moveTo(midX, midY);
    arrowPath.lineTo(
      midX - 8 * cos(angle + 0.5),
      midY - 8 * sin(angle + 0.5),
    );
    arrowPath.lineTo(
      midX - 8 * cos(angle - 0.5),
      midY - 8 * sin(angle - 0.5),
    );
    arrowPath.close();
    canvas.drawPath(arrowPath, arrowPaint);
  }

  void _drawSavedRoutes(Canvas canvas) {
    final fadedPaint = Paint()
      ..color = Colors.blue.withOpacity(0.25)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final selectedPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    for (final route in routes) {
      final isSelected = route.id == selectedRouteId;
      final paint = isSelected ? selectedPaint : fadedPaint;

      for (int i = 0; i < route.nodeIds.length - 1; i++) {
        final currentId = route.nodeIds[i];
        final nextId = route.nodeIds[i + 1];

        final currentPos = _getElementPosition(currentId);
        final nextPos = _getElementPosition(nextId);

        if (currentPos != null && nextPos != null) {
          final scaledCurrentX = currentPos.dx / scaleX;
          final scaledCurrentY = currentPos.dy / scaleY;
          final scaledNextX = nextPos.dx / scaleX;
          final scaledNextY = nextPos.dy / scaleY;

          canvas.drawLine(
            Offset(scaledCurrentX, scaledCurrentY),
            Offset(scaledNextX, scaledNextY),
            paint,
          );

          if (isSelected) {
            _drawSelectedRouteArrow(
              canvas,
              scaledCurrentX,
              scaledCurrentY,
              scaledNextX,
              scaledNextY,
            );
          }
        }
      }
    }
  }

  void _drawSelectedRouteArrow(
    Canvas canvas,
    double currentX,
    double currentY,
    double nextX,
    double nextY,
  ) {
    final midX = (currentX + nextX) / 2;
    final midY = (currentY + nextY) / 2;
    final angle = atan2(nextY - currentY, nextX - currentX);

    final arrowPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final arrowPath = Path();
    arrowPath.moveTo(
      midX + 8 * cos(angle),
      midY + 8 * sin(angle),
    );
    arrowPath.lineTo(
      midX - 6 * cos(angle - 0.5),
      midY - 6 * sin(angle - 0.5),
    );
    arrowPath.lineTo(
      midX - 6 * cos(angle + 0.5),
      midY - 6 * sin(angle + 0.5),
    );
    arrowPath.close();
    canvas.drawPath(arrowPath, arrowPaint);
  }

  /// Get position of a node or beacon by ID.
  Offset? _getElementPosition(String id) {
    final node = nodes.cast<ConfigurableNode?>().firstWhere(
      (n) => n?.id == id,
      orElse: () => null,
    );

    if (node != null) {
      return Offset(node.x, node.y);
    }

    final beacon = beacons.cast<ConfigurableBeacon?>().firstWhere(
      (b) => b?.id == id,
      orElse: () => null,
    );

    if (beacon != null && beacon.x != null && beacon.y != null) {
      return Offset(beacon.x!, beacon.y!);
    }

    return null;
  }

  @override
  bool shouldRepaint(covariant MapEditorPainter oldDelegate) {
    return nodes != oldDelegate.nodes ||
        beacons != oldDelegate.beacons ||
        routes != oldDelegate.routes ||
        selectedNodeId != oldDelegate.selectedNodeId ||
        selectedBeaconId != oldDelegate.selectedBeaconId ||
        selectedRouteId != oldDelegate.selectedRouteId ||
        mode != oldDelegate.mode ||
        routeNodesInProgress != oldDelegate.routeNodesInProgress ||
        scaleX != oldDelegate.scaleX ||
        scaleY != oldDelegate.scaleY;
  }
}
