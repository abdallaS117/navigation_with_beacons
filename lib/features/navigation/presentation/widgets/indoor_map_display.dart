import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/entities/beacon_node.dart';
import '../../domain/entities/navigation_route.dart';
import '../../../configuration/domain/models/models.dart';
import 'route_painter.dart';
import 'user_arrow.dart';

/// Widget that displays the indoor map with user position and route.
class IndoorMapDisplay extends StatelessWidget {
  final MapLayoutConfig? mapConfig;
  final int selectedFloor;
  final BeaconNode? userPosition;
  final NavigationRoute? activeRoute;
  final TransformationController transformController;
  final List<ConfigurableNode> nodes;
  final List<ConfigurableBeacon> beacons;
  final bool showBeacons;

  const IndoorMapDisplay({
    super.key,
    required this.mapConfig,
    required this.selectedFloor,
    this.userPosition,
    this.activeRoute,
    required this.transformController,
    required this.nodes,
    required this.beacons,
    this.showBeacons = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = mapConfig?.width ?? 800;
    final height = mapConfig?.height ?? 600;
    final aspectRatio = width / height;

    final currentFloor = mapConfig?.floors.firstWhere(
      (f) => f.floorNumber == selectedFloor,
      orElse: () => mapConfig!.floors.isNotEmpty
          ? mapConfig!.floors.first
          : const FloorConfig(floorNumber: 1, name: 'Floor 1'),
    );
    final floorImagePath = currentFloor?.imagePath;

    return InteractiveViewer(
      transformationController: transformController,
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

              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey[400]!),
                  image: floorImagePath != null
                      ? DecorationImage(
                          image: _getImageProvider(floorImagePath),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: CustomPaint(
                  painter: activeRoute != null
                      ? RoutePainter(
                          route: activeRoute,
                          currentFloor: selectedFloor,
                        )
                      : null,
                  child: Stack(
                    children: [
                      // Beacon markers (optional)
                      if (showBeacons)
                        ...beacons
                            .where((b) => b.isPlaced && b.floor == selectedFloor)
                            .map((beacon) => _buildBeaconMarker(beacon, scaleX, scaleY)),
                      
                      // User position
                      if (userPosition != null && userPosition!.floor == selectedFloor)
                        UserArrow(
                          x: userPosition!.x / scaleX,
                          y: userPosition!.y / scaleY,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  ImageProvider _getImageProvider(String imagePath) {
    if (imagePath.startsWith('assets/') || imagePath.startsWith('packages/')) {
      return AssetImage(imagePath);
    }
    return FileImage(File(imagePath));
  }

  Widget _buildBeaconMarker(ConfigurableBeacon beacon, double scaleX, double scaleY) {
    final displayX = (beacon.x ?? 0) / scaleX;
    final displayY = (beacon.y ?? 0) / scaleY;

    return Positioned(
      left: displayX - 12,
      top: displayY - 12,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blue, width: 2),
        ),
        child: const Icon(
          Icons.bluetooth,
          size: 14,
          color: Colors.blue,
        ),
      ),
    );
  }
}
