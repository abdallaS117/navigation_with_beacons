import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/models/models.dart';
import '../logic/configuration_state.dart';

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
    
    // Get floor-specific image path
    final currentFloor = widget.mapConfig?.floors.firstWhere(
      (f) => f.floorNumber == widget.selectedFloor,
      orElse: () => widget.mapConfig!.floors.isNotEmpty 
          ? widget.mapConfig!.floors.first 
          : const FloorConfig(floorNumber: 1, name: 'Floor 1'),
    );
    final floorImagePath = currentFloor?.imagePath;

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
              // Get the actual rendered size of the AspectRatio widget
              final renderedWidth = constraints.maxWidth;
              final renderedHeight = constraints.maxHeight;
              
              // Calculate scale factors to convert from rendered size to actual map size
              final scaleX = width / renderedWidth;
              final scaleY = height / renderedHeight;
              
              return GestureDetector(
                onTapUp: (details) {
                  final localPosition = details.localPosition;
                  // Convert tap coordinates to actual map coordinates
                  final actualX = localPosition.dx * scaleX;
                  final actualY = localPosition.dy * scaleY;
                  
                  // Check if tap is on a route segment (in addConnection mode or view mode)
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
                  
                  // Check if tap is on a connection line (only in addConnection mode)
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
                },
                child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[400]!),
                image: floorImagePath != null
                    ? DecorationImage(
                        image: (floorImagePath.startsWith('assets/') || floorImagePath.startsWith('packages/'))
                            ? AssetImage(floorImagePath) as ImageProvider
                            : FileImage(File(floorImagePath)),
                        fit: BoxFit.cover,
                      )
                    : null,
                  ),
                  child: CustomPaint(
                    painter: _MapEditorPainter(
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
                        // Node markers
                        ...widget.nodes.map((node) => _buildNodeMarker(node, scaleX, scaleY)),
                        // Beacon markers
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

  Widget _buildNodeMarker(ConfigurableNode node, double scaleX, double scaleY) {
    final isSelected = widget.selectedNodeId == node.id;
    final isInRoute = widget.routeNodesInProgress.contains(node.id);
    final isInRouteMode = widget.mode == ConfigurationMode.createRoute;
    
    // Scale node coordinates from actual map size to rendered view size
    final displayX = node.x / scaleX;
    final displayY = node.y / scaleY;
    
    Color backgroundColor;
    Color borderColor;
    Color iconColor;
    
    if (isInRouteMode) {
      if (isInRoute) {
        backgroundColor = Colors.blue;
        borderColor = Colors.blue[900]!;
        iconColor = Colors.white;
      } else {
        backgroundColor = Colors.green[100]!;
        borderColor = Colors.green[700]!;
        iconColor = Colors.green[900]!;
      }
    } else {
      backgroundColor = isSelected ? Colors.green : Colors.green[100]!;
      borderColor = Colors.green[700]!;
      iconColor = isSelected ? Colors.white : Colors.green[900]!;
    }
    
    return Positioned(
      left: displayX - 15,
      top: displayY - 15,
      child: GestureDetector(
        onTap: () => widget.onNodeTap(node.id),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(
              color: borderColor,
              width: isSelected || isInRoute ? 3 : 2,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              _getNodeIcon(node.type),
              size: 16,
              color: iconColor,
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
    
    // Scale beacon coordinates from actual map size to rendered view size
    final displayX = (beacon.x ?? 0) / scaleX;
    final displayY = (beacon.y ?? 0) / scaleY;
    
    Color backgroundColor;
    Color borderColor;
    Color iconColor;
    
    if (isInRouteMode) {
      if (isInRoute) {
        backgroundColor = Colors.blue;
        borderColor = Colors.blue[900]!;
        iconColor = Colors.white;
      } else {
        backgroundColor = Colors.orange[100]!;
        borderColor = Colors.orange[700]!;
        iconColor = Colors.orange[900]!;
      }
    } else {
      backgroundColor = isSelected ? Colors.orange : Colors.orange[100]!;
      borderColor = Colors.orange[700]!;
      iconColor = isSelected ? Colors.white : Colors.orange[900]!;
    }
    
    return Positioned(
      left: displayX - 15,
      top: displayY - 15,
      child: GestureDetector(
        onTap: () => widget.onBeaconTap(beacon.id),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(
              color: borderColor,
              width: isSelected || isInRoute ? 3 : 2,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.bluetooth,
              size: 16,
              color: iconColor,
            ),
          ),
        ),
      ),
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
      default:
        return Icons.location_on;
    }
  }

  /// Find if a tap position is close to any connection line
  Map<String, dynamic>? _findTappedConnection(double tapX, double tapY, double scaleX, double scaleY) {
    const double tapThreshold = 15.0; // pixels tolerance for tap detection
    
    for (final node in widget.nodes) {
      for (final connection in node.connections) {
        final targetNode = widget.nodes.cast<ConfigurableNode?>().firstWhere(
          (n) => n?.id == connection.targetNodeId,
          orElse: () => null,
        );
        
        if (targetNode != null) {
          // Scale coordinates from actual map size to rendered view size
          final startX = node.x / scaleX;
          final startY = node.y / scaleY;
          final endX = targetNode.x / scaleX;
          final endY = targetNode.y / scaleY;
          
          // Calculate distance from tap point to line segment
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

  /// Calculate the distance from a point to a line segment
  double _pointToLineDistance(double px, double py, double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final lengthSquared = dx * dx + dy * dy;
    
    if (lengthSquared == 0) {
      // Line segment is a point
      return sqrt((px - x1) * (px - x1) + (py - y1) * (py - y1));
    }
    
    // Calculate projection of point onto line
    var t = ((px - x1) * dx + (py - y1) * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    
    // Find closest point on line segment
    final closestX = x1 + t * dx;
    final closestY = y1 + t * dy;
    
    // Return distance to closest point
    return sqrt((px - closestX) * (px - closestX) + (py - closestY) * (py - closestY));
  }

  /// Find if a tap position is close to any route segment
  Map<String, dynamic>? _findTappedRouteSegment(double tapX, double tapY, double scaleX, double scaleY) {
    const double tapThreshold = 15.0;
    
    for (final route in widget.routes) {
      for (int i = 0; i < route.nodeIds.length - 1; i++) {
        final currentId = route.nodeIds[i];
        final nextId = route.nodeIds[i + 1];

        // Find nodes or beacons
        final currentNode = widget.nodes.cast<ConfigurableNode?>().firstWhere(
          (n) => n?.id == currentId,
          orElse: () => null,
        );
        
        ConfigurableBeacon? currentBeacon;
        if (currentNode == null) {
          currentBeacon = widget.beacons.cast<ConfigurableBeacon?>().firstWhere(
            (b) => b?.id == currentId,
            orElse: () => null,
          );
        }

        final nextNode = widget.nodes.cast<ConfigurableNode?>().firstWhere(
          (n) => n?.id == nextId,
          orElse: () => null,
        );
        
        ConfigurableBeacon? nextBeacon;
        if (nextNode == null) {
          nextBeacon = widget.beacons.cast<ConfigurableBeacon?>().firstWhere(
            (b) => b?.id == nextId,
            orElse: () => null,
          );
        }

        final currentX = (currentNode?.x ?? currentBeacon?.x);
        final currentY = (currentNode?.y ?? currentBeacon?.y);
        final nextX = (nextNode?.x ?? nextBeacon?.x);
        final nextY = (nextNode?.y ?? nextBeacon?.y);

        if (currentX != null && currentY != null && nextX != null && nextY != null) {
          final scaledCurrentX = currentX / scaleX;
          final scaledCurrentY = currentY / scaleY;
          final scaledNextX = nextX / scaleX;
          final scaledNextY = nextY / scaleY;

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
}

class _MapEditorPainter extends CustomPainter {
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

  _MapEditorPainter({
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
    // Draw grid
    _drawGrid(canvas, size);

    // Draw saved routes (faded blue lines)
    _drawSavedRoutes(canvas);

    // Draw connections
    _drawConnections(canvas);
    
    // Draw route in progress
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

    for (final node in nodes) {
      for (final connection in node.connections) {
        final targetNode = nodes.cast<ConfigurableNode?>().firstWhere(
              (n) => n?.id == connection.targetNodeId,
              orElse: () => null,
            );

        if (targetNode != null) {
          final isSelected = node.id == selectedNodeId || targetNode.id == selectedNodeId;
          final isOneWay = !connection.isBidirectional;
          
          // Scale coordinates from actual map size to rendered view size
          final startX = node.x / scaleX;
          final startY = node.y / scaleY;
          final endX = targetNode.x / scaleX;
          final endY = targetNode.y / scaleY;
          
          canvas.drawLine(
            Offset(startX, startY),
            Offset(endX, endY),
            isSelected ? selectedPaint : (isOneWay ? oneWayPaint : paint),
          );
          
          // Draw arrow for one-way connections
          if (isOneWay) {
            _drawDirectionArrow(canvas, startX, startY, endX, endY, arrowPaint);
          }
        }
      }
    }
  }

  void _drawDirectionArrow(Canvas canvas, double startX, double startY, double endX, double endY, Paint paint) {
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

      // Find nodes or beacons
      ConfigurableNode? currentNode = nodes.cast<ConfigurableNode?>().firstWhere(
        (n) => n?.id == currentId,
        orElse: () => null,
      );
      
      ConfigurableBeacon? currentBeacon;
      if (currentNode == null) {
        currentBeacon = beacons.cast<ConfigurableBeacon?>().firstWhere(
          (b) => b?.id == currentId,
          orElse: () => null,
        );
      }

      ConfigurableNode? nextNode = nodes.cast<ConfigurableNode?>().firstWhere(
        (n) => n?.id == nextId,
        orElse: () => null,
      );
      
      ConfigurableBeacon? nextBeacon;
      if (nextNode == null) {
        nextBeacon = beacons.cast<ConfigurableBeacon?>().firstWhere(
          (b) => b?.id == nextId,
          orElse: () => null,
        );
      }

      // Scale coordinates from actual map size to rendered view size
      final currentX = (currentNode?.x ?? currentBeacon?.x ?? 0) / scaleX;
      final currentY = (currentNode?.y ?? currentBeacon?.y ?? 0) / scaleY;
      final nextX = (nextNode?.x ?? nextBeacon?.x ?? 0) / scaleX;
      final nextY = (nextNode?.y ?? nextBeacon?.y ?? 0) / scaleY;

      // Draw line
      canvas.drawLine(
        Offset(currentX, currentY),
        Offset(nextX, nextY),
        paint,
      );

      // Draw arrow at midpoint
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
  }

  void _drawSavedRoutes(Canvas canvas) {
    // Faded blue paint for unselected routes
    final fadedPaint = Paint()
      ..color = Colors.blue.withOpacity(0.25)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Bold blue paint for selected route
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

        // Find nodes or beacons
        final currentNode = nodes.cast<ConfigurableNode?>().firstWhere(
          (n) => n?.id == currentId,
          orElse: () => null,
        );
        
        ConfigurableBeacon? currentBeacon;
        if (currentNode == null) {
          currentBeacon = beacons.cast<ConfigurableBeacon?>().firstWhere(
            (b) => b?.id == currentId,
            orElse: () => null,
          );
        }

        final nextNode = nodes.cast<ConfigurableNode?>().firstWhere(
          (n) => n?.id == nextId,
          orElse: () => null,
        );
        
        ConfigurableBeacon? nextBeacon;
        if (nextNode == null) {
          nextBeacon = beacons.cast<ConfigurableBeacon?>().firstWhere(
            (b) => b?.id == nextId,
            orElse: () => null,
          );
        }

        final currentX = (currentNode?.x ?? currentBeacon?.x);
        final currentY = (currentNode?.y ?? currentBeacon?.y);
        final nextX = (nextNode?.x ?? nextBeacon?.x);
        final nextY = (nextNode?.y ?? nextBeacon?.y);

        if (currentX != null && currentY != null && nextX != null && nextY != null) {
          // Scale coordinates
          final scaledCurrentX = currentX / scaleX;
          final scaledCurrentY = currentY / scaleY;
          final scaledNextX = nextX / scaleX;
          final scaledNextY = nextY / scaleY;

          canvas.drawLine(
            Offset(scaledCurrentX, scaledCurrentY),
            Offset(scaledNextX, scaledNextY),
            paint,
          );

          // Draw direction arrow for selected route
          if (isSelected) {
            final midX = (scaledCurrentX + scaledNextX) / 2;
            final midY = (scaledCurrentY + scaledNextY) / 2;
            final angle = atan2(scaledNextY - scaledCurrentY, scaledNextX - scaledCurrentX);
            
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
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapEditorPainter oldDelegate) {
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
