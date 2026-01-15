import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/models.dart';
import '../logic/configuration_cubit.dart';
import '../logic/configuration_state.dart';
import '../widgets/map_editor_canvas.dart';

class MapEditorScreen extends StatelessWidget {
  const MapEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigurationCubit, ConfigurationState>(
      builder: (context, state) {
        return Scaffold(
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
              Expanded(
                child: MapEditorCanvas(
                  mapConfig: state.config?.mapConfig,
                  nodes: state.nodesForCurrentFloor,
                  beacons: state.beaconsForCurrentFloor,
                  mode: state.mode,
                  selectedNodeId: state.selectedNodeId,
                  selectedBeaconId: state.selectedBeaconId,
                  onTap: (x, y) => _handleCanvasTap(context, state, x, y),
                  onNodeTap: (id) => context.read<ConfigurationCubit>().selectNode(id),
                  onBeaconTap: (id) => context.read<ConfigurationCubit>().selectBeacon(id),
                ),
              ),
              if (state.selectedNodeId != null || state.selectedBeaconId != null)
                _buildSelectionPanel(context, state),
            ],
          ),
          floatingActionButton: _buildFAB(context, state),
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, ConfigurationState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.grey[100],
      child: Row(
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
          const Spacer(),
          Text(
            'Mode: ${state.mode.name}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
        onPressed: () => context.read<ConfigurationCubit>().setMode(mode),
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
        ),
      ),
    );
  }

  Widget _buildFloorSelector(BuildContext context, ConfigurationState state) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('Floor: '),
          ...List.generate(3, (index) {
            final floor = index + 1;
            final isSelected = state.selectedFloor == floor;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text('F$floor'),
                selected: isSelected,
                onSelected: (_) => context.read<ConfigurationCubit>().selectFloor(floor),
              ),
            );
          }),
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
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDeleteBeacon(context, beacon.id),
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
        _showAddNodeDialog(context, x, y, state.selectedFloor);
        break;
      case ConfigurationMode.placeBeacon:
        if (state.selectedBeaconId != null) {
          cubit.placeBeacon(state.selectedBeaconId!, x, y, state.selectedFloor);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select a beacon first from Beacon Management')),
          );
        }
        break;
      case ConfigurationMode.addConnection:
        // Handled by node tap
        break;
      default:
        cubit.selectNode(null);
        cubit.selectBeacon(null);
    }
  }

  void _showAddNodeDialog(BuildContext context, double x, double y, int floor) async {
    final node = await showDialog<ConfigurableNode>(
      context: context,
      builder: (_) => _NodeQuickAddDialog(x: x, y: y, floor: floor),
    );

    if (node != null && context.mounted) {
      context.read<ConfigurationCubit>().addNode(node);
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

  void _confirmDeleteBeacon(BuildContext context, String beaconId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Beacon?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              context.read<ConfigurationCubit>().removeBeacon(beaconId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _NodeQuickAddDialog extends StatefulWidget {
  final double x;
  final double y;
  final int floor;

  const _NodeQuickAddDialog({required this.x, required this.y, required this.floor});

  @override
  State<_NodeQuickAddDialog> createState() => _NodeQuickAddDialogState();
}

class _NodeQuickAddDialogState extends State<_NodeQuickAddDialog> {
  final _nameController = TextEditingController();
  NodeType _type = NodeType.waypoint;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Node'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<NodeType>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: NodeType.values.map((t) => DropdownMenuItem(
              value: t,
              child: Text(t.name),
            )).toList(),
            onChanged: (v) => setState(() => _type = v!),
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
            if (_nameController.text.isEmpty) return;
            Navigator.pop(context, ConfigurableNode(
              id: 'node_${DateTime.now().millisecondsSinceEpoch}',
              name: _nameController.text,
              x: widget.x,
              y: widget.y,
              floor: widget.floor,
              type: _type,
            ));
          },
          child: const Text('Add'),
        ),
      ],
    );
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
