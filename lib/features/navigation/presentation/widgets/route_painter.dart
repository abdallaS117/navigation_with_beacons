import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/entities/beacon_node.dart';
import '../../domain/entities/navigation_route.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

/// AutoCAD-style route painter - thin lines, smooth paths
class RoutePainter extends CustomPainter {
  final NavigationRoute? route;
  final int currentFloor;
  final int currentNodeIndex;
  final double animationProgress;
  final BeaconNode? destinationNode;

  RoutePainter({
    this.route,
    required this.currentFloor,
    this.currentNodeIndex = 0,
    this.animationProgress = 1.0,
    this.destinationNode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (route == null || route!.nodes.isEmpty) return;

    final floorNodes =
        route!.nodes.where((n) => n.floor == currentFloor).toList();
    if (floorNodes.isEmpty) return;

    // Draw route line (thin, architectural style)
    _drawRouteLine(canvas, floorNodes);

    // Draw destination marker
    if (destinationNode != null && destinationNode!.floor == currentFloor) {
      _drawDestinationMarker(canvas, destinationNode!);
    }
  }

  void _drawRouteLine(Canvas canvas, List<BeaconNode> nodes) {
    if (nodes.length < 2) return;

    // Always draw the full route on this floor from first to last node
    // The route already represents the path from current position to destination
    // No need to skip nodes - just draw the entire floor segment
    const int startIndex = 0;

    // Subtle glow/shadow under remaining route
    final glowPaint = Paint()
      ..color = AppColors.routeLineGlow
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppConstants.routeGlowWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final routePath = Path();
    routePath.moveTo(nodes[startIndex].x, nodes[startIndex].y);

    for (int i = startIndex + 1; i < nodes.length; i++) {
      routePath.lineTo(nodes[i].x, nodes[i].y);
    }

    canvas.drawPath(routePath, glowPaint);

    // Draw remaining route (blue) - from current position to destination
    final pendingPaint = Paint()
      ..color = AppColors.routeLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppConstants.routeLineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(routePath, pendingPaint);
  }

  void _drawDestinationMarker(Canvas canvas, BeaconNode destination) {
    final center = Offset(destination.x, destination.y);

    // Subtle pulsating glow
    final glowRadius = 14 + (2 * sin(animationProgress * 2 * pi));
    final glowPaint = Paint()
      ..color = AppColors.destinationGlow
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, glowRadius, glowPaint);

    // Simple destination pin
    final pinPath = Path();
    pinPath.moveTo(center.dx, center.dy - 20);
    pinPath.quadraticBezierTo(
      center.dx + 10,
      center.dy - 20,
      center.dx + 10,
      center.dy - 10,
    );
    pinPath.quadraticBezierTo(
      center.dx + 10,
      center.dy - 3,
      center.dx,
      center.dy,
    );
    pinPath.quadraticBezierTo(
      center.dx - 10,
      center.dy - 3,
      center.dx - 10,
      center.dy - 10,
    );
    pinPath.quadraticBezierTo(
      center.dx - 10,
      center.dy - 20,
      center.dx,
      center.dy - 20,
    );

    final pinPaint = Paint()
      ..color = AppColors.destination
      ..style = PaintingStyle.fill;

    canvas.drawPath(pinPath, pinPaint);

    // Inner circle
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(center.dx, center.dy - 12), 4, innerPaint);
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.route != route ||
        oldDelegate.currentFloor != currentFloor ||
        oldDelegate.currentNodeIndex != currentNodeIndex ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.destinationNode != destinationNode;
  }
}
