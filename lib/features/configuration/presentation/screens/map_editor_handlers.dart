import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/models/models.dart';
import '../logic/configuration_cubit.dart';
import '../logic/configuration_state.dart';
import '../widgets/map_settings_dialog.dart';
import '../widgets/connection_config_dialog.dart';
import '../widgets/add_floor_dialog.dart';
import '../widgets/edit_floor_dialog.dart';
import '../widgets/node_creation_dialog.dart';
import '../widgets/route_creation_dialog.dart';
import '../widgets/connection_dialog.dart';

/// Mixin containing all event handlers for MapEditorScreen.
/// Extracted to reduce the main screen file size.
mixin MapEditorHandlers {
  void handleCanvasTap(BuildContext context, ConfigurationState state, double x, double y) {
    final cubit = context.read<ConfigurationCubit>();

    switch (state.mode) {
      case ConfigurationMode.addNode:
        showNodeCreationDialog(context, x, y, state.selectedFloor);
        break;
      case ConfigurationMode.placeBeacon:
        if (state.selectedBeaconId != null) {
          cubit.placeBeacon(state.selectedBeaconId!, x, y, state.selectedFloor);
        } else {
          final hasUnplacedBeacons = state.unplacedBeacons.isNotEmpty;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hasUnplacedBeacons
                    ? 'Select a beacon from the list above first'
                    : 'No unplaced beacons available. Add beacons in Beacon Management first.',
              ),
              action: hasUnplacedBeacons ? null : SnackBarAction(
                label: 'Go to Beacon Management',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          );
        }
        break;
      case ConfigurationMode.addConnection:
      case ConfigurationMode.createRoute:
        break;
      default:
        cubit.selectNode(null);
        cubit.selectBeacon(null);
    }
  }

  void handleNodeTap(BuildContext context, ConfigurationState state, String nodeId) {
    if (state.mode == ConfigurationMode.createRoute) {
      context.read<ConfigurationCubit>().addNodeToRoute(nodeId);
    } else if (state.mode == ConfigurationMode.addConnection) {
      if (state.selectedNodeId == null) {
        context.read<ConfigurationCubit>().selectNode(nodeId);
      } else if (state.selectedNodeId != nodeId) {
        showConnectionDialog(context, state, state.selectedNodeId!, nodeId);
      }
    } else {
      context.read<ConfigurationCubit>().selectNode(nodeId);
    }
  }

  void handleBeaconTap(BuildContext context, ConfigurationState state, String beaconId) {
    if (state.mode == ConfigurationMode.createRoute) {
      context.read<ConfigurationCubit>().addNodeToRoute(beaconId);
    } else {
      context.read<ConfigurationCubit>().selectBeacon(beaconId);
    }
  }

  void handleConnectionTap(
    BuildContext context,
    ConfigurationState state,
    String fromNodeId,
    String toNodeId,
    NodeConnection connection,
  ) {
    final fromNode = state.config?.nodes.firstWhere((n) => n.id == fromNodeId);
    final toNode = state.config?.nodes.firstWhere((n) => n.id == toNodeId);

    showDialog(
      context: context,
      builder: (_) => ConnectionConfigDialog(
        fromNodeName: fromNode?.name ?? fromNodeId,
        toNodeName: toNode?.name ?? toNodeId,
        fromNodeId: fromNodeId,
        toNodeId: toNodeId,
        currentConnection: connection,
        onSave: (direction, type) {
          if (direction == 'blocked') {
            updateConnection(context, fromNodeId, toNodeId, 'two-way', ConnectionType.blocked);
          } else {
            updateConnection(context, fromNodeId, toNodeId, direction, type);
          }
        },
      ),
    );
  }

  void handleRouteSegmentTap(
    BuildContext context,
    ConfigurationState state,
    String routeId,
    int segmentIndex,
  ) {
    final route = state.config?.routes.firstWhere((r) => r.id == routeId);
    if (route == null || segmentIndex >= route.nodeIds.length - 1) return;

    final fromNodeId = route.nodeIds[segmentIndex];
    final toNodeId = route.nodeIds[segmentIndex + 1];

    final fromNode = state.config?.nodes.firstWhere((n) => n.id == fromNodeId);
    if (fromNode == null) return;

    NodeConnection? connection;
    try {
      connection = fromNode.connections.firstWhere((c) => c.targetNodeId == toNodeId);
    } catch (_) {
      final toNode = state.config?.nodes.firstWhere((n) => n.id == toNodeId);
      if (toNode != null) {
        try {
          final reverseConnection = toNode.connections.firstWhere((c) => c.targetNodeId == fromNodeId);
          handleConnectionTap(context, state, toNodeId, fromNodeId, reverseConnection);
          return;
        } catch (_) {
          connection = NodeConnection(targetNodeId: toNodeId);
        }
      }
    }

    if (connection != null) {
      handleConnectionTap(context, state, fromNodeId, toNodeId, connection);
    }
  }

  Future<void> updateConnection(
    BuildContext context,
    String fromNodeId,
    String toNodeId,
    String direction,
    ConnectionType type,
  ) async {
    await context.read<ConfigurationCubit>().removeConnection(fromNodeId, toNodeId);
    await context.read<ConfigurationCubit>().removeConnection(toNodeId, fromNodeId);

    if (direction == 'two-way') {
      await context.read<ConfigurationCubit>().addConnection(
        fromNodeId,
        toNodeId,
        bidirectional: true,
        type: type,
      );
    } else if (direction == 'one-way-forward') {
      await context.read<ConfigurationCubit>().addConnection(
        fromNodeId,
        toNodeId,
        bidirectional: false,
        type: type,
      );
    } else if (direction == 'one-way-reverse') {
      await context.read<ConfigurationCubit>().addConnection(
        toNodeId,
        fromNodeId,
        bidirectional: false,
        type: type,
      );
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection updated: $direction, ${type.name}')),
      );
    }
  }

  void showMapSettings(BuildContext context, ConfigurationState state) {
    showDialog(
      context: context,
      builder: (_) => MapSettingsDialog(config: state.config?.mapConfig),
    ).then((result) {
      if (result != null && context.mounted) {
        context.read<ConfigurationCubit>().updateMapConfig(result as MapLayoutConfig);
      }
    });
  }

  void showNodeCreationDialog(BuildContext context, double x, double y, int floor) async {
    final state = context.read<ConfigurationCubit>().state;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => NodeCreationDialog(
        x: x,
        y: y,
        floor: floor,
        beacons: state.config?.beacons ?? [],
      ),
    );

    if (result != null && context.mounted) {
      final node = ConfigurableNode(
        id: 'node_${DateTime.now().millisecondsSinceEpoch}',
        name: result['name'],
        type: result['type'],
        x: x,
        y: y,
        floor: floor,
        linkedBeaconId: result['linkedBeaconId'],
      );
      await context.read<ConfigurationCubit>().addNode(node);
    }
  }

  void showConnectionDialog(
    BuildContext context,
    ConfigurationState state,
    String fromNodeId,
    String toNodeId,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ConnectionDialog(
        fromNodeId: fromNodeId,
        availableNodes: state.config?.nodes ?? [],
        existingConnection: NodeConnection(targetNodeId: toNodeId),
      ),
    );

    if (result != null && context.mounted) {
      await context.read<ConfigurationCubit>().addConnection(
        fromNodeId,
        result['targetNodeId'] as String,
        weight: result['weight'] as double?,
        bidirectional: result['bidirectional'] as bool,
        type: result['type'] as ConnectionType,
      );

      if (context.mounted) {
        final directionText = (result['bidirectional'] as bool) ? 'bidirectional' : 'one-way';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection added ($directionText)')),
        );
      }
    }
  }

  void saveRoute(BuildContext context, ConfigurationState state) async {
    // Get existing route if we're editing
    RouteConfig? existingRoute;
    if (state.routeIdBeingEdited != null) {
      existingRoute = state.config?.routes.firstWhere(
        (r) => r.id == state.routeIdBeingEdited,
      );
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RouteCreationDialog(
        nodeIds: state.routeNodesInProgress,
        allNodes: state.config?.nodes ?? [],
        existingRoute: existingRoute,
      ),
    );

    if (result != null && context.mounted) {
      await context.read<ConfigurationCubit>().saveRoute(
        result['name'],
        result['description'],
        result['type'],
      );

      if (context.mounted) {
        final action = existingRoute != null ? 'updated' : 'saved';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Route "${result['name']}" $action successfully')),
        );
      }
    }
  }

  void confirmDeleteNode(BuildContext context, String nodeId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Node?'),
        content: const Text('This will also remove all connections to this node.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              context.read<ConfigurationCubit>().removeNode(nodeId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void confirmRemoveBeacon(BuildContext context, String beaconId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Beacon from Map?'),
        content: const Text('The beacon will be removed from the map but will remain in your beacon list for future placement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(context);
              context.read<ConfigurationCubit>().unplaceBeacon(beaconId);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void confirmDeleteRoute(BuildContext context, String routeId, String routeName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Route?'),
        content: Text('Are you sure you want to delete "$routeName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              context.read<ConfigurationCubit>().deleteRoute(routeId);
              context.read<ConfigurationCubit>().selectRoute(null);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Route "$routeName" deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void showFloorOptions(BuildContext context, ConfigurationState state, FloorConfig floor) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Floor Name'),
              onTap: () {
                Navigator.pop(context);
                editFloor(context, state, floor);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.green),
              title: Text(floor.imagePath == null ? 'Set Floor Image' : 'Change Floor Image'),
              onTap: () {
                Navigator.pop(context);
                setFloorImage(context, state, floor);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Floor'),
              onTap: () {
                Navigator.pop(context);
                confirmDeleteFloor(context, state, floor);
              },
            ),
          ],
        ),
      ),
    );
  }

  void addFloor(BuildContext context, ConfigurationState state) async {
    final config = state.config;
    if (config == null) return;

    final mapConfig = config.mapConfig;
    final floors = List<FloorConfig>.from(mapConfig.floors);
    final nextFloorNumber = floors.isEmpty ? 1 : floors.map((f) => f.floorNumber).reduce((a, b) => a > b ? a : b) + 1;

    final floorName = await showDialog<String>(
      context: context,
      builder: (_) => AddFloorDialog(floorNumber: nextFloorNumber),
    );

    if (floorName != null && context.mounted) {
      floors.add(FloorConfig(
        floorNumber: nextFloorNumber,
        name: floorName,
      ));

      final updatedMapConfig = mapConfig.copyWith(floors: floors);
      context.read<ConfigurationCubit>().updateMapConfig(updatedMapConfig);
    }
  }

  void editFloor(BuildContext context, ConfigurationState state, FloorConfig floor) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => EditFloorDialog(floor: floor),
    );

    if (newName != null && context.mounted) {
      final config = state.config;
      if (config == null) return;

      final mapConfig = config.mapConfig;
      final floors = mapConfig.floors.map((f) {
        if (f.floorNumber == floor.floorNumber) {
          return FloorConfig(
            floorNumber: f.floorNumber,
            name: newName,
            imagePath: f.imagePath,
            isActive: f.isActive,
          );
        }
        return f;
      }).toList();

      final updatedMapConfig = mapConfig.copyWith(floors: floors);
      context.read<ConfigurationCubit>().updateMapConfig(updatedMapConfig);
    }
  }

  void setFloorImage(BuildContext context, ConfigurationState state, FloorConfig floor) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null && context.mounted) {
        final imagePath = result.files.single.path!;
        final config = state.config;
        if (config == null) return;

        final mapConfig = config.mapConfig;
        final floors = mapConfig.floors.map((f) {
          if (f.floorNumber == floor.floorNumber) {
            return FloorConfig(
              floorNumber: f.floorNumber,
              name: f.name,
              imagePath: imagePath,
              isActive: f.isActive,
            );
          }
          return f;
        }).toList();

        final updatedMapConfig = mapConfig.copyWith(floors: floors);
        await context.read<ConfigurationCubit>().updateMapConfig(updatedMapConfig);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Floor image set for ${floor.name}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void confirmDeleteFloor(BuildContext context, ConfigurationState state, FloorConfig floor) {
    final config = state.config;
    if (config == null) return;

    final beaconsOnFloor = config.beacons.where((b) => b.floor == floor.floorNumber).length;
    final nodesOnFloor = config.nodes.where((n) => n.floor == floor.floorNumber).length;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Floor?'),
        content: Text(
          beaconsOnFloor > 0 || nodesOnFloor > 0
              ? 'This floor has $beaconsOnFloor beacon(s) and $nodesOnFloor node(s). Deleting it will remove all items on this floor.'
              : 'Are you sure you want to delete "${floor.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              deleteFloor(context, state, floor);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void deleteFloor(BuildContext context, ConfigurationState state, FloorConfig floor) async {
    final config = state.config;
    if (config == null) return;

    final mapConfig = config.mapConfig;

    if (mapConfig.floors.length == 1) {
      for (final beacon in config.beacons.where((b) => b.floor == floor.floorNumber)) {
        await context.read<ConfigurationCubit>().unplaceBeacon(beacon.id);
      }

      for (final node in config.nodes.where((n) => n.floor == floor.floorNumber)) {
        await context.read<ConfigurationCubit>().removeNode(node.id);
      }

      final clearedFloor = FloorConfig(
        floorNumber: floor.floorNumber,
        name: floor.name,
        imagePath: null,
        isActive: floor.isActive,
      );

      final updatedFloors = [clearedFloor];
      final updatedMapConfig = mapConfig.copyWith(floors: updatedFloors);
      await context.read<ConfigurationCubit>().updateMapConfig(updatedMapConfig);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Floor cleared - all elements removed')),
        );
      }
      return;
    }

    final floors = mapConfig.floors.where((f) => f.floorNumber != floor.floorNumber).toList();
    final updatedMapConfig = mapConfig.copyWith(floors: floors);

    await context.read<ConfigurationCubit>().updateMapConfig(updatedMapConfig);

    for (final beacon in config.beacons.where((b) => b.floor == floor.floorNumber)) {
      await context.read<ConfigurationCubit>().unplaceBeacon(beacon.id);
    }

    for (final node in config.nodes.where((n) => n.floor == floor.floorNumber)) {
      await context.read<ConfigurationCubit>().removeNode(node.id);
    }

    if (context.mounted) {
      if (state.selectedFloor == floor.floorNumber && floors.isNotEmpty) {
        context.read<ConfigurationCubit>().selectFloor(floors.first.floorNumber);
      } else if (floors.isEmpty) {
        context.read<ConfigurationCubit>().selectFloor(1);
      }
    }
  }
}
