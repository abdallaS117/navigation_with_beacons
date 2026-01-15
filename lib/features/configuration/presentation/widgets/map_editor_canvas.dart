import 'package:flutter/material.dart';
import '../../domain/models/models.dart';
import '../logic/configuration_state.dart';

class MapEditorCanvas extends StatefulWidget {
  final MapLayoutConfig? mapConfig;
  final List<ConfigurableNode> nodes;
  final List<ConfigurableBeacon> beacons;
  final ConfigurationMode mode;
  final String? selectedNodeId;
  final String? selectedBeaconId;
  final Function(double x, double y) onTap;
  final Function(String nodeId) onNodeTap;
  final Function(String beaconId) onBeaconTap;

  const MapEditorCanvas({
    super.key,
    this.mapConfig,
    required this.nodes,
    required this.beacons,
    required this.mode,
    this.selectedNodeId,
    this.selectedBeaconId,
    required this.onTap,
    required this.onNodeTap,
    required this.onBeaconTap,
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

    return InteractiveViewer(
      transformationController: _transformController,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.5,
      maxScale: 3.0,
      child: GestureDetector(
        onTapUp: (details) {
          final localPosition = details.localPosition;
          widget.onTap(localPosition.dx, localPosition.dy);
        },
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: CustomPaint(
            size: Size(width, height),
            painter: _MapEditorPainter(
              nodes: widget.nodes,
              beacons: widget.beacons,
              selectedNodeId: widget.selectedNodeId,
              selectedBeaconId: widget.selectedBeaconId,
              mode: widget.mode,
            ),
            child: Stack(
              children: [
                // Node markers
                ...widget.nodes.map((node) => _buildNodeMarker(node)),
                // Beacon markers
                ...widget.beacons.where((b) => b.isPlaced).map((beacon) => _buildBeaconMarker(beacon)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNodeMarker(ConfigurableNode node) {
    final isSelected = node.id == widget.selectedNodeId;
    final color = _getNodeColor(node.type);

    return Positioned(
      left: node.x - 15,
      top: node.y - 15,
      child: GestureDetector(
        onTap: () => widget.onNodeTap(node.id),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(isSelected ? 1.0 : 0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.white,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]
                : null,
          ),
          child: Icon(
            _getNodeIcon(node.type),
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildBeaconMarker(ConfigurableBeacon beacon) {
    final isSelected = beacon.id == widget.selectedBeaconId;

    return Positioned(
      left: (beacon.x ?? 0) - 12,
      top: (beacon.y ?? 0) - 12,
      child: GestureDetector(
        onTap: () => widget.onBeaconTap(beacon.id),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(isSelected ? 1.0 : 0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.deepOrange : Colors.white,
              width: isSelected ? 3 : 2,
            ),
          ),
          child: const Icon(
            Icons.bluetooth,
            color: Colors.white,
            size: 14,
          ),
        ),
      ),
    );
  }

  Color _getNodeColor(NodeType type) {
    switch (type) {
      case NodeType.department:
        return Colors.green;
      case NodeType.entrance:
        return Colors.blue;
      case NodeType.elevator:
        return Colors.purple;
      case NodeType.stairs:
        return Colors.indigo;
      case NodeType.beacon:
        return Colors.orange;
      case NodeType.waypoint:
      default:
        return Colors.grey;
    }
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
}

class _MapEditorPainter extends CustomPainter {
  final List<ConfigurableNode> nodes;
  final List<ConfigurableBeacon> beacons;
  final String? selectedNodeId;
  final String? selectedBeaconId;
  final ConfigurationMode mode;

  _MapEditorPainter({
    required this.nodes,
    required this.beacons,
    this.selectedNodeId,
    this.selectedBeaconId,
    required this.mode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid
    _drawGrid(canvas, size);

    // Draw connections
    _drawConnections(canvas);
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

    for (final node in nodes) {
      for (final connection in node.connections) {
        final targetNode = nodes.cast<ConfigurableNode?>().firstWhere(
              (n) => n?.id == connection.targetNodeId,
              orElse: () => null,
            );

        if (targetNode != null) {
          final isSelected = node.id == selectedNodeId || targetNode.id == selectedNodeId;
          canvas.drawLine(
            Offset(node.x, node.y),
            Offset(targetNode.x, targetNode.y),
            isSelected ? selectedPaint : paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapEditorPainter oldDelegate) {
    return nodes != oldDelegate.nodes ||
        beacons != oldDelegate.beacons ||
        selectedNodeId != oldDelegate.selectedNodeId ||
        selectedBeaconId != oldDelegate.selectedBeaconId ||
        mode != oldDelegate.mode;
  }
}
