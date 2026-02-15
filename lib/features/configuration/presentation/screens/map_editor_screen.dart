import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/models/models.dart';
import '../logic/configuration_cubit.dart';
import '../logic/configuration_state.dart';
import '../widgets/map_editor_canvas.dart';
import '../widgets/add_floor_dialog.dart';
import '../widgets/edit_floor_dialog.dart';
import '../widgets/node_creation_dialog.dart';
import '../widgets/route_creation_dialog.dart';
import '../widgets/connection_dialog.dart';

class MapEditorScreen extends StatelessWidget {
  const MapEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigurationCubit, ConfigurationState>(
      builder: (context, state) {
        return SafeArea(
          bottom: true,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Map Editor'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _showMapSettings(context, state),
                  tooltip: 'Map Settings',
                ),
              ],
            ),
            body: Column(
              children: [
                _buildToolbar(context, state),
                _buildFloorSelector(context, state),
                if (state.mode == ConfigurationMode.placeBeacon && state.unplacedBeacons.isNotEmpty)
                  _buildBeaconSelector(context, state),
                if (state.mode == ConfigurationMode.addConnection)
                  _buildConnectionModePanel(context, state),
                if (state.mode == ConfigurationMode.createRoute)
                  _buildRouteProgressPanel(context, state),
                Expanded(
                  child: MapEditorCanvas(
                    mapConfig: state.config?.mapConfig,
                    nodes: state.config?.nodes ?? [],
                    beacons: state.config?.beacons ?? [],
                    routes: state.config?.routes ?? [],
                    mode: state.mode,
                    selectedNodeId: state.selectedNodeId,
                    selectedBeaconId: state.selectedBeaconId,
                    selectedRouteId: state.selectedRouteId,
                    selectedFloor: state.selectedFloor,
                    routeNodesInProgress: state.routeNodesInProgress,
                    onTap: (x, y) => _handleCanvasTap(context, state, x, y),
                    onNodeTap: (id) => _handleNodeTap(context, state, id),
                    onBeaconTap: (id) => _handleBeaconTap(context, state, id),
                    onConnectionTap: (fromId, toId, connection) => _handleConnectionTap(context, state, fromId, toId, connection),
                    onRouteSegmentTap: (routeId, segmentIndex) => _handleRouteSegmentTap(context, state, routeId, segmentIndex),
                  ),
                ),
                if (state.selectedNodeId != null || state.selectedBeaconId != null)
                  _buildSelectionPanel(context, state),
                if (state.selectedRouteId != null)
                  _buildRouteSelectionPanel(context, state),
              ],
            ),
            floatingActionButton: _buildFAB(context, state),
          ),
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, ConfigurationState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.grey[100],
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildModeButton(
            context,
            state,
            ConfigurationMode.view,
            Icons.pan_tool,
            'View',
          ),
          _buildModeButton(
            context,
            state,
            ConfigurationMode.addNode,
            Icons.add_location,
            'Add Node',
          ),
          _buildModeButton(
            context,
            state,
            ConfigurationMode.placeBeacon,
            Icons.bluetooth,
            'Place Beacon',
          ),
          _buildModeButton(
            context,
            state,
            ConfigurationMode.addConnection,
            Icons.link,
            'Connect',
          ),
          _buildModeButton(
            context,
            state,
            ConfigurationMode.createRoute,
            Icons.route,
            'Create Route',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Center(
              child: Text(
                'Mode: ${state.mode.name}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context,
    ConfigurationState state,
    ConfigurationMode mode,
    IconData icon,
    String tooltip,
  ) {
    final isSelected = state.mode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: Icon(icon),
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
        onPressed: () {
          if (mode == ConfigurationMode.createRoute) {
            context.read<ConfigurationCubit>().startRouteCreation();
          } else {
            context.read<ConfigurationCubit>().setMode(mode);
          }
        },
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
        ),
      ),
    );
  }

  Widget _buildFloorSelector(BuildContext context, ConfigurationState state) {
    final floors = state.config?.mapConfig.floors ?? [];
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('Floor: '),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: floors.length,
              itemBuilder: (context, index) {
                final floor = floors[index];
                final isSelected = state.selectedFloor == floor.floorNumber;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onLongPress: () => _showFloorOptions(context, state, floor),
                    child: ChoiceChip(
                      label: Text(floor.name),
                      selected: isSelected,
                      onSelected: (_) => context.read<ConfigurationCubit>().selectFloor(floor.floorNumber),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
            onPressed: () => _addFloor(context, state),
            tooltip: 'Add Floor',
          ),
        ],
      ),
    );
  }

  Widget _buildBeaconSelector(BuildContext context, ConfigurationState state) {
    final unplacedBeacons = state.unplacedBeacons;
    
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border(
          bottom: BorderSide(color: Colors.orange[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bluetooth, size: 16, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Text(
                'Select a beacon to place on the map:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: unplacedBeacons.length,
              itemBuilder: (context, index) {
                final beacon = unplacedBeacons[index];
                final isSelected = state.selectedBeaconId == beacon.id;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(beacon.name),
                    selected: isSelected,
                    onSelected: (_) {
                      context.read<ConfigurationCubit>().selectBeacon(
                        isSelected ? null : beacon.id,
                      );
                    },
                    avatar: Icon(
                      Icons.bluetooth,
                      size: 16,
                      color: isSelected ? Colors.white : Colors.orange[700],
                    ),
                    selectedColor: Colors.orange[700],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.orange[900],
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionPanel(BuildContext context, ConfigurationState state) {
    final node = state.selectedNode;
    final beacon = state.selectedBeacon;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (node != null) ...[
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.green[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(node.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${node.type.name} • (${node.x.toInt()}, ${node.y.toInt()})',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDeleteNode(context, node.id),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.read<ConfigurationCubit>().selectNode(null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Connections: ${node.connections.length}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
          if (beacon != null) ...[
            Row(
              children: [
                Icon(Icons.bluetooth, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(beacon.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(beacon.uuid, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                  onPressed: () => _confirmRemoveBeacon(context, beacon.id),
                  tooltip: 'Remove from map',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.read<ConfigurationCubit>().selectBeacon(null),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildFAB(BuildContext context, ConfigurationState state) {
    if (state.mode == ConfigurationMode.addConnection && state.selectedNodeId != null) {
      return FloatingActionButton.extended(
        icon: const Icon(Icons.check),
        label: const Text('Done'),
        onPressed: () => context.read<ConfigurationCubit>().setMode(ConfigurationMode.view),
      );
    }
    return null;
  }

  void _handleCanvasTap(BuildContext context, ConfigurationState state, double x, double y) {
    final cubit = context.read<ConfigurationCubit>();

    switch (state.mode) {
      case ConfigurationMode.addNode:
        _showNodeCreationDialog(context, x, y, state.selectedFloor);
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
        // Handled by node tap
        break;
      case ConfigurationMode.createRoute:
        // Route creation is handled by node/beacon tap
        break;
      default:
        cubit.selectNode(null);
        cubit.selectBeacon(null);
    }
  }

  void _handleNodeTap(BuildContext context, ConfigurationState state, String nodeId) {
    if (state.mode == ConfigurationMode.createRoute) {
      context.read<ConfigurationCubit>().addNodeToRoute(nodeId);
    } else if (state.mode == ConfigurationMode.addConnection) {
      if (state.selectedNodeId == null) {
        context.read<ConfigurationCubit>().selectNode(nodeId);
      } else if (state.selectedNodeId != nodeId) {
        _showConnectionDialog(context, state, state.selectedNodeId!, nodeId);
      }
    } else {
      context.read<ConfigurationCubit>().selectNode(nodeId);
    }
  }

  void _handleConnectionTap(BuildContext context, ConfigurationState state, String fromNodeId, String toNodeId, NodeConnection connection) {
    final fromNode = state.config?.nodes.firstWhere((n) => n.id == fromNodeId);
    final toNode = state.config?.nodes.firstWhere((n) => n.id == toNodeId);
    
    showDialog(
      context: context,
      builder: (_) => _ConnectionConfigDialog(
        fromNodeName: fromNode?.name ?? fromNodeId,
        toNodeName: toNode?.name ?? toNodeId,
        fromNodeId: fromNodeId,
        toNodeId: toNodeId,
        currentConnection: connection,
        onSave: (direction, type) {
          if (direction == 'delete') {
            context.read<ConfigurationCubit>().removeConnection(fromNodeId, toNodeId);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Connection deleted')),
            );
          } else {
            _updateConnection(context, fromNodeId, toNodeId, direction, type);
          }
        },
      ),
    );
  }

  void _updateConnection(BuildContext context, String fromNodeId, String toNodeId, String direction, ConnectionType type) async {
    await context.read<ConfigurationCubit>().removeConnection(fromNodeId, toNodeId);
    
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

  void _handleRouteSegmentTap(BuildContext context, ConfigurationState state, String routeId, int segmentIndex) {
    // Find the route and get the two nodes of this segment
    final route = state.config?.routes.firstWhere((r) => r.id == routeId);
    if (route == null || segmentIndex >= route.nodeIds.length - 1) return;
    
    final fromNodeId = route.nodeIds[segmentIndex];
    final toNodeId = route.nodeIds[segmentIndex + 1];
    
    // Find the connection between these nodes
    final fromNode = state.config?.nodes.firstWhere((n) => n.id == fromNodeId);
    if (fromNode == null) return;
    
    // Check if there's a direct connection from fromNode to toNode
    NodeConnection? connection;
    try {
      connection = fromNode.connections.firstWhere((c) => c.targetNodeId == toNodeId);
    } catch (_) {
      // No direct connection, check reverse
      final toNode = state.config?.nodes.firstWhere((n) => n.id == toNodeId);
      if (toNode != null) {
        try {
          final reverseConnection = toNode.connections.firstWhere((c) => c.targetNodeId == fromNodeId);
          // If reverse exists, use it but swap the nodes for the dialog
          _handleConnectionTap(context, state, toNodeId, fromNodeId, reverseConnection);
          return;
        } catch (_) {
          // No connection exists at all - create a default one for the dialog
          connection = NodeConnection(targetNodeId: toNodeId);
        }
      }
    }
    
    if (connection != null) {
      _handleConnectionTap(context, state, fromNodeId, toNodeId, connection);
    }
  }

  Widget _buildRouteSelectionPanel(BuildContext context, ConfigurationState state) {
    final route = state.selectedRoute;
    if (route == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${route.nodeIds.length} nodes • ${route.type.name}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDeleteRoute(context, route.id, route.name),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.read<ConfigurationCubit>().selectRoute(null),
              ),
            ],
          ),
          if (route.description != null && route.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(route.description!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ],
      ),
    );
  }

  void _confirmDeleteRoute(BuildContext context, String routeId, String routeName) {
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

  Widget _buildConnectionModePanel(BuildContext context, ConfigurationState state) {
    final selectedNode = state.selectedNode;
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.purple[50],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, color: Colors.purple[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedNode == null
                      ? 'Tap a node to start a new connection'
                      : 'Tap the second node to connect from "${selectedNode.name}"',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[900],
                  ),
                ),
              ),
              if (selectedNode != null)
                TextButton(
                  onPressed: () => context.read<ConfigurationCubit>().selectNode(null),
                  child: const Text('Cancel'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '💡 Tap on an existing line to configure: one-way, two-way, or delete',
            style: TextStyle(
              fontSize: 12,
              color: Colors.purple[700],
            ),
          ),
        ],
      ),
    );
  }

  void _showConnectionDialog(BuildContext context, ConfigurationState state, String fromNodeId, String toNodeId) async {
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

  void _handleBeaconTap(BuildContext context, ConfigurationState state, String beaconId) {
    if (state.mode == ConfigurationMode.createRoute) {
      context.read<ConfigurationCubit>().addNodeToRoute(beaconId);
    } else {
      context.read<ConfigurationCubit>().selectBeacon(beaconId);
    }
  }

  void _showNodeCreationDialog(BuildContext context, double x, double y, int floor) async {
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

  Widget _buildRouteProgressPanel(BuildContext context, ConfigurationState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.blue[50],
      child: Row(
        children: [
          const Icon(Icons.route, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            'Route: ${state.routeNodesInProgress.length} nodes selected',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (state.routeNodesInProgress.length >= 2)
            ElevatedButton(
              onPressed: () => _saveRoute(context, state),
              child: const Text('Save Route'),
            ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.read<ConfigurationCubit>().clearRouteInProgress(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _saveRoute(BuildContext context, ConfigurationState state) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RouteCreationDialog(
        nodeIds: state.routeNodesInProgress,
        allNodes: state.config?.nodes ?? [],
      ),
    );

    if (result != null && context.mounted) {
      await context.read<ConfigurationCubit>().saveRoute(
        result['name'],
        result['description'],
        result['type'],
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Route "${result['name']}" saved successfully')),
        );
      }
    }
  }


  void _showMapSettings(BuildContext context, ConfigurationState state) {
    showDialog(
      context: context,
      builder: (_) => _MapSettingsDialog(config: state.config?.mapConfig),
    ).then((result) {
      if (result != null && context.mounted) {
        context.read<ConfigurationCubit>().updateMapConfig(result as MapLayoutConfig);
      }
    });
  }

  void _confirmDeleteNode(BuildContext context, String nodeId) {
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

  void _confirmRemoveBeacon(BuildContext context, String beaconId) {
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

  void _showFloorOptions(BuildContext context, ConfigurationState state, FloorConfig floor) {
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
                _editFloor(context, state, floor);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.green),
              title: Text(floor.imagePath == null ? 'Set Floor Image' : 'Change Floor Image'),
              onTap: () {
                Navigator.pop(context);
                _setFloorImage(context, state, floor);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Floor'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteFloor(context, state, floor);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addFloor(BuildContext context, ConfigurationState state) async {
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

  void _editFloor(BuildContext context, ConfigurationState state, FloorConfig floor) async {
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

  void _setFloorImage(BuildContext context, ConfigurationState state, FloorConfig floor) async {
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

  void _confirmDeleteFloor(BuildContext context, ConfigurationState state, FloorConfig floor) {
    final config = state.config;
    if (config == null) return;
    
    // Check if there are beacons or nodes on this floor
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
              _deleteFloor(context, state, floor);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteFloor(BuildContext context, ConfigurationState state, FloorConfig floor) async {
    final config = state.config;
    if (config == null) return;
    
    final mapConfig = config.mapConfig;
    
    // Remove the floor
    final floors = mapConfig.floors.where((f) => f.floorNumber != floor.floorNumber).toList();
    
    final updatedMapConfig = mapConfig.copyWith(floors: floors);
    
    // Update the map config which will save the configuration
    await context.read<ConfigurationCubit>().updateMapConfig(updatedMapConfig);
    
    // Unplace beacons from this floor so they can be placed on other floors
    for (final beacon in config.beacons.where((b) => b.floor == floor.floorNumber)) {
      await context.read<ConfigurationCubit>().unplaceBeacon(beacon.id);
    }
    
    // Remove nodes from this floor (nodes are floor-specific)
    for (final node in config.nodes.where((n) => n.floor == floor.floorNumber)) {
      await context.read<ConfigurationCubit>().removeNode(node.id);
    }
    
    // Switch to first available floor if current floor was deleted
    if (context.mounted) {
      if (state.selectedFloor == floor.floorNumber && floors.isNotEmpty) {
        context.read<ConfigurationCubit>().selectFloor(floors.first.floorNumber);
      } else if (floors.isEmpty) {
        context.read<ConfigurationCubit>().selectFloor(1);
      }
    }
  }
}

class _MapSettingsDialog extends StatefulWidget {
  final MapLayoutConfig? config;

  const _MapSettingsDialog({this.config});

  @override
  State<_MapSettingsDialog> createState() => _MapSettingsDialogState();
}

class _MapSettingsDialogState extends State<_MapSettingsDialog> {
  late TextEditingController _nameController;
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late TextEditingController _scaleController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.config?.name ?? 'Hospital Layout');
    _widthController = TextEditingController(text: (widget.config?.width ?? 800).toString());
    _heightController = TextEditingController(text: (widget.config?.height ?? 600).toString());
    _scaleController = TextEditingController(text: (widget.config?.scale ?? 1.0).toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Map Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Map Name'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _widthController,
                  decoration: const InputDecoration(labelText: 'Width'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _heightController,
                  decoration: const InputDecoration(labelText: 'Height'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _scaleController,
            decoration: const InputDecoration(labelText: 'Scale'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, MapLayoutConfig(
              id: widget.config?.id ?? 'default_map',
              name: _nameController.text,
              width: double.tryParse(_widthController.text) ?? 800,
              height: double.tryParse(_heightController.text) ?? 600,
              scale: double.tryParse(_scaleController.text) ?? 1.0,
              floors: widget.config?.floors ?? [],
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ConnectionConfigDialog extends StatefulWidget {
  final String fromNodeName;
  final String toNodeName;
  final String fromNodeId;
  final String toNodeId;
  final NodeConnection currentConnection;
  final Function(String direction, ConnectionType type) onSave;

  const _ConnectionConfigDialog({
    required this.fromNodeName,
    required this.toNodeName,
    required this.fromNodeId,
    required this.toNodeId,
    required this.currentConnection,
    required this.onSave,
  });

  @override
  State<_ConnectionConfigDialog> createState() => _ConnectionConfigDialogState();
}

class _ConnectionConfigDialogState extends State<_ConnectionConfigDialog> {
  late String _direction;
  late ConnectionType _type;

  @override
  void initState() {
    super.initState();
    _direction = widget.currentConnection.isBidirectional ? 'two-way' : 'one-way-forward';
    _type = widget.currentConnection.type;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure Connection'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.fromNodeName} ↔ ${widget.toNodeName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Direction:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            _buildDirectionOption(
              'two-way',
              'Two-way (Bidirectional)',
              Icons.swap_horiz,
              Colors.blue,
            ),
            _buildDirectionOption(
              'one-way-forward',
              'One-way: ${widget.fromNodeName} → ${widget.toNodeName}',
              Icons.arrow_forward,
              Colors.orange,
            ),
            _buildDirectionOption(
              'one-way-reverse',
              'One-way: ${widget.toNodeName} → ${widget.fromNodeName}',
              Icons.arrow_back,
              Colors.orange,
            ),
            _buildDirectionOption(
              'delete',
              'No connection (Delete)',
              Icons.block,
              Colors.red,
            ),
            const SizedBox(height: 16),
            const Text('Type:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            _buildTypeOption(ConnectionType.normal, 'Normal', Icons.arrow_forward),
            _buildTypeOption(ConnectionType.emergency, 'Emergency', Icons.emergency),
            _buildTypeOption(ConnectionType.staff, 'Staff Only', Icons.badge),
            _buildTypeOption(ConnectionType.stairs, 'Stairs', Icons.stairs),
            _buildTypeOption(ConnectionType.elevator, 'Elevator', Icons.elevator),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onSave(_direction, _type);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildDirectionOption(String value, String label, IconData icon, Color color) {
    final isSelected = _direction == value;
    return InkWell(
      onTap: () => setState(() => _direction = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color, width: 2) : Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: isSelected ? color : null))),
            if (isSelected) Icon(Icons.check, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(ConnectionType type, String label, IconData icon) {
    final isSelected = _type == type;
    return InkWell(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            if (isSelected) const Icon(Icons.check, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}
