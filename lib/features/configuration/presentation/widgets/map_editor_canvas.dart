import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../domain/models/models.dart';
import '../logic/configuration_state.dart';
import 'map_editor_painter.dart';

/// Interactive canvas for the map editor.
/// Displays nodes, beacons, connections, and routes with tap detection.
class MapEditorCanvas extends StatefulWidget {
  final MapLayoutConfig? mapConfig;
  final List<ConfigurableNode> nodes;
  final List<ConfigurableBeacon> beacons;
  final List<RouteConfig> routes;
  final ConfigurationMode mode;
  final String? selectedNodeId;
  final String? selectedBeaconId;
  final String? selectedRouteId;
  final int selectedFloor;
  final List<String> routeNodesInProgress;
  final Function(double x, double y) onTap;
  final Function(String nodeId) onNodeTap;
  final Function(String beaconId) onBeaconTap;
  final Function(String fromNodeId, String toNodeId, NodeConnection connection)? onConnectionTap;
  final Function(String routeId, int segmentIndex)? onRouteSegmentTap;

  const MapEditorCanvas({
    super.key,
    this.mapConfig,
    required this.nodes,
    required this.beacons,
    this.routes = const [],
    required this.mode,
    this.selectedNodeId,
    this.selectedBeaconId,
    this.selectedRouteId,
    required this.selectedFloor,
    this.routeNodesInProgress = const [],
    required this.onTap,
    required this.onNodeTap,
    required this.onBeaconTap,
    this.onConnectionTap,
    this.onRouteSegmentTap,
  });

  @override
  State<MapEditorCanvas> createState() => _MapEditorCanvasState();
}

class _MapEditorCanvasState extends State<MapEditorCanvas> {
  final TransformationController _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.mapConfig?.width ?? 800;
    final height = widget.mapConfig?.height ?? 600;
    final aspectRatio = width / height;

    final currentFloor = widget.mapConfig?.floors.firstWhere(
      (f) => f.floorNumber == widget.selectedFloor,
      orElse: () => widget.mapConfig!.floors.isNotEmpty
          ? widget.mapConfig!.floors.first
          : const FloorConfig(floorNumber: 1, name: 'Floor 1'),
    );
    final floorImagePath = currentFloor?.imagePath;
    final floorImageBase64 = currentFloor?.imageBase64;

    return InteractiveViewer(
      transformationController: _transformController,
      boundaryMargin: const EdgeInsets.all(20),
      minScale: 0.5,
      maxScale: 3.0,
      child: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final renderedWidth = constraints.maxWidth;
              final renderedHeight = constraints.maxHeight;
              final scaleX = width / renderedWidth;
              final scaleY = height / renderedHeight;

              return GestureDetector(
                onTapUp: (details) => _handleTap(details, scaleX, scaleY),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: Colors.grey[400]!),
                    image: _getFloorDecorationImage(floorImagePath, floorImageBase64),
                  ),
                  child: CustomPaint(
                    painter: MapEditorPainter(
                      nodes: widget.nodes,
                      beacons: widget.beacons,
                      routes: widget.routes,
                      selectedNodeId: widget.selectedNodeId,
                      selectedBeaconId: widget.selectedBeaconId,
                      selectedRouteId: widget.selectedRouteId,
                      mode: widget.mode,
                      routeNodesInProgress: widget.routeNodesInProgress,
                      scaleX: scaleX,
                      scaleY: scaleY,
                    ),
                    child: Stack(
                      children: [
                        ...widget.nodes.map((node) => _buildNodeMarker(node, scaleX, scaleY)),
                        ...widget.beacons.where((b) => b.isPlaced).map((beacon) => _buildBeaconMarker(beacon, scaleX, scaleY)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  DecorationImage? _getFloorDecorationImage(String? imagePath, String? imageBase64) {
    // Priority 1: Base64 encoded image (from Firestore)
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(imageBase64);
        return DecorationImage(
          image: MemoryImage(bytes),
          fit: BoxFit.cover,
        );
      } catch (e) {
        debugPrint('❌ Error decoding Base64 floor image: $e');
      }
    }

    // Priority 2: Local file or asset path
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('assets/') || imagePath.startsWith('packages/')) {
        return DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.cover,
        );
      }
      return DecorationImage(
        image: FileImage(File(imagePath)),
        fit: BoxFit.cover,
      );
    }

    return null;
  }

  void _handleTap(TapUpDetails details, double scaleX, double scaleY) {
    final localPosition = details.localPosition;
    final actualX = localPosition.dx * scaleX;
    final actualY = localPosition.dy * scaleY;

    // Check route segment tap
    if (widget.onRouteSegmentTap != null) {
      final tappedRoute = _findTappedRouteSegment(localPosition.dx, localPosition.dy, scaleX, scaleY);
      if (tappedRoute != null) {
        widget.onRouteSegmentTap!(
          tappedRoute['routeId'] as String,
          tappedRoute['segmentIndex'] as int,
        );
        return;
      }
    }

    // Check connection tap (only in addConnection mode)
    if (widget.mode == ConfigurationMode.addConnection && widget.onConnectionTap != null) {
      final tappedConnection = _findTappedConnection(localPosition.dx, localPosition.dy, scaleX, scaleY);
      if (tappedConnection != null) {
        widget.onConnectionTap!(
          tappedConnection['fromNodeId'] as String,
          tappedConnection['toNodeId'] as String,
          tappedConnection['connection'] as NodeConnection,
        );
        return;
      }
    }

    widget.onTap(actualX, actualY);
  }

  Widget _buildNodeMarker(ConfigurableNode node, double scaleX, double scaleY) {
    final isSelected = widget.selectedNodeId == node.id;
    final isInRoute = widget.routeNodesInProgress.contains(node.id);
    final isInRouteMode = widget.mode == ConfigurationMode.createRoute;

    final displayX = node.x / scaleX;
    final displayY = node.y / scaleY;

    final colors = _getMarkerColors(isSelected, isInRoute, isInRouteMode, isNode: true);

    return Positioned(
      left: displayX - 15,
      top: displayY - 15,
      child: GestureDetector(
        onTap: () => widget.onNodeTap(node.id),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: colors.background,
            border: Border.all(
              color: colors.border,
              width: isSelected || isInRoute ? 3 : 2,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              _getNodeIcon(node.type),
              size: 16,
              color: colors.icon,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBeaconMarker(ConfigurableBeacon beacon, double scaleX, double scaleY) {
    final isSelected = widget.selectedBeaconId == beacon.id;
    final isInRoute = widget.routeNodesInProgress.contains(beacon.id);
    final isInRouteMode = widget.mode == ConfigurationMode.createRoute;

    final displayX = (beacon.x ?? 0) / scaleX;
    final displayY = (beacon.y ?? 0) / scaleY;

    final colors = _getMarkerColors(isSelected, isInRoute, isInRouteMode, isNode: false);

    return Positioned(
      left: displayX - 15,
      top: displayY - 15,
      child: GestureDetector(
        onTap: () => widget.onBeaconTap(beacon.id),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: colors.background,
            border: Border.all(
              color: colors.border,
              width: isSelected || isInRoute ? 3 : 2,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.bluetooth,
              size: 16,
              color: colors.icon,
            ),
          ),
        ),
      ),
    );
  }

  _MarkerColors _getMarkerColors(bool isSelected, bool isInRoute, bool isInRouteMode, {required bool isNode}) {
    final baseColor = isNode ? Colors.green : Colors.orange;

    if (isInRouteMode) {
      if (isInRoute) {
        return _MarkerColors(
          background: Colors.blue,
          border: Colors.blue[900]!,
          icon: Colors.white,
        );
      }
      return _MarkerColors(
        background: baseColor[100]!,
        border: baseColor[700]!,
        icon: baseColor[900]!,
      );
    }

    return _MarkerColors(
      background: isSelected ? baseColor : baseColor[100]!,
      border: baseColor[700]!,
      icon: isSelected ? Colors.white : baseColor[900]!,
    );
  }

  IconData _getNodeIcon(NodeType type) {
    switch (type) {
      case NodeType.department:
        return Icons.business;
      case NodeType.entrance:
        return Icons.door_front_door;
      case NodeType.elevator:
        return Icons.elevator;
      case NodeType.stairs:
        return Icons.stairs;
      case NodeType.beacon:
        return Icons.bluetooth;
      case NodeType.waypoint:
        return Icons.location_on;
    }
  }

  Map<String, dynamic>? _findTappedConnection(double tapX, double tapY, double scaleX, double scaleY) {
    const double tapThreshold = 15.0;

    for (final node in widget.nodes) {
      for (final connection in node.connections) {
        final targetNode = widget.nodes.cast<ConfigurableNode?>().firstWhere(
          (n) => n?.id == connection.targetNodeId,
          orElse: () => null,
        );

        if (targetNode != null) {
          final startX = node.x / scaleX;
          final startY = node.y / scaleY;
          final endX = targetNode.x / scaleX;
          final endY = targetNode.y / scaleY;

          final distance = _pointToLineDistance(tapX, tapY, startX, startY, endX, endY);

          if (distance <= tapThreshold) {
            return {
              'fromNodeId': node.id,
              'toNodeId': targetNode.id,
              'connection': connection,
            };
          }
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? _findTappedRouteSegment(double tapX, double tapY, double scaleX, double scaleY) {
    const double tapThreshold = 15.0;

    for (final route in widget.routes) {
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

          final distance = _pointToLineDistance(
            tapX, tapY,
            scaledCurrentX, scaledCurrentY,
            scaledNextX, scaledNextY,
          );

          if (distance <= tapThreshold) {
            return {
              'routeId': route.id,
              'segmentIndex': i,
            };
          }
        }
      }
    }
    return null;
  }

  Offset? _getElementPosition(String id) {
    final node = widget.nodes.cast<ConfigurableNode?>().firstWhere(
      (n) => n?.id == id,
      orElse: () => null,
    );

    if (node != null) {
      return Offset(node.x, node.y);
    }

    final beacon = widget.beacons.cast<ConfigurableBeacon?>().firstWhere(
      (b) => b?.id == id,
      orElse: () => null,
    );

    if (beacon != null && beacon.x != null && beacon.y != null) {
      return Offset(beacon.x!, beacon.y!);
    }

    return null;
  }

  double _pointToLineDistance(double px, double py, double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final lengthSquared = dx * dx + dy * dy;

    if (lengthSquared == 0) {
      return sqrt((px - x1) * (px - x1) + (py - y1) * (py - y1));
    }

    var t = ((px - x1) * dx + (py - y1) * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);

    final closestX = x1 + t * dx;
    final closestY = y1 + t * dy;

    return sqrt((px - closestX) * (px - closestX) + (py - closestY) * (py - closestY));
  }
}

/// Helper class for marker colors.
class _MarkerColors {
  final Color background;
  final Color border;
  final Color icon;

  _MarkerColors({
    required this.background,
    required this.border,
    required this.icon,
  });
}
