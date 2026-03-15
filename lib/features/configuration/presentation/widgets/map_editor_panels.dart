import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/models.dart';
import '../logic/configuration_cubit.dart';
import '../logic/configuration_state.dart';

/// Toolbar widget for map editor mode selection.
class MapEditorToolbar extends StatelessWidget {
  final ConfigurationState state;

  const MapEditorToolbar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.grey[100],
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildModeButton(context, ConfigurationMode.view, Icons.pan_tool, 'View'),
          _buildModeButton(context, ConfigurationMode.addNode, Icons.add_location, 'Add Node'),
          _buildModeButton(context, ConfigurationMode.placeBeacon, Icons.bluetooth, 'Place Beacon'),
          _buildModeButton(context, ConfigurationMode.addConnection, Icons.link, 'Connect'),
          _buildModeButton(context, ConfigurationMode.createRoute, Icons.route, 'Create Route'),
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
}

/// Panel showing beacon selection for placement mode.
class BeaconSelectorPanel extends StatelessWidget {
  final ConfigurationState state;

  const BeaconSelectorPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
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
}

/// Panel showing connection mode instructions.
class ConnectionModePanel extends StatelessWidget {
  final ConfigurationState state;

  const ConnectionModePanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
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
}

/// Panel showing route creation progress.
class RouteProgressPanel extends StatelessWidget {
  final ConfigurationState state;
  final VoidCallback onSave;

  const RouteProgressPanel({
    super.key,
    required this.state,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
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
              onPressed: onSave,
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
}

/// Panel showing selected node or beacon details.
class SelectionPanel extends StatelessWidget {
  final ConfigurationState state;
  final VoidCallback onDeleteNode;
  final VoidCallback onRemoveBeacon;

  const SelectionPanel({
    super.key,
    required this.state,
    required this.onDeleteNode,
    required this.onRemoveBeacon,
  });

  @override
  Widget build(BuildContext context) {
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
                  onPressed: onDeleteNode,
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
                  onPressed: onRemoveBeacon,
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
}

/// Panel showing selected route details.
class RouteSelectionPanel extends StatelessWidget {
  final RouteConfig route;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const RouteSelectionPanel({
    super.key,
    required this.route,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
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
                onPressed: onDelete,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
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
}
