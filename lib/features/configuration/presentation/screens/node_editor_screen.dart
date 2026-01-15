import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/models.dart';
import '../logic/configuration_cubit.dart';
import '../logic/configuration_state.dart';
import '../widgets/node_editor_dialog.dart';
import '../widgets/connection_dialog.dart';

class NodeEditorScreen extends StatelessWidget {
  const NodeEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigurationCubit, ConfigurationState>(
      builder: (context, state) {
        final nodes = state.config?.nodes ?? [];

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Navigation Nodes'),
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'All'),
                  Tab(text: 'Floor 1'),
                  Tab(text: 'Floor 2'),
                  Tab(text: 'Floor 3'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildNodeList(context, nodes, state),
                _buildNodeList(context, nodes.where((n) => n.floor == 1).toList(), state),
                _buildNodeList(context, nodes.where((n) => n.floor == 2).toList(), state),
                _buildNodeList(context, nodes.where((n) => n.floor == 3).toList(), state),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              icon: const Icon(Icons.add_location),
              label: const Text('Add Node'),
              onPressed: () => _showNodeEditor(context, null, state),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNodeList(BuildContext context, List<ConfigurableNode> nodes, ConfigurationState state) {
    if (nodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No Nodes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: nodes.length,
      itemBuilder: (context, index) => _buildNodeCard(context, nodes[index], state),
    );
  }

  Widget _buildNodeCard(BuildContext context, ConfigurableNode node, ConfigurationState state) {
    final isSelected = state.selectedNodeId == node.id;
    final allNodes = state.config?.nodes ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.blue.withOpacity(0.1) : null,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getNodeColor(node.type),
          child: Icon(_getNodeIcon(node.type), color: Colors.white, size: 20),
        ),
        title: Text(node.name),
        subtitle: Text(
          '${node.type.name} • Floor ${node.floor} • (${node.x.toInt()}, ${node.y.toInt()})',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.link),
              onPressed: () => _showConnectionDialog(context, node, allNodes),
              tooltip: 'Add Connection',
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showNodeEditor(context, node, state),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(context, node),
              tooltip: 'Delete',
            ),
          ],
        ),
        children: [
          if (node.connections.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No connections',
                style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
              ),
            )
          else
            ...node.connections.map((conn) {
              final targetNode = allNodes.cast<ConfigurableNode?>().firstWhere(
                    (n) => n?.id == conn.targetNodeId,
                    orElse: () => null,
                  );
              return ListTile(
                leading: Icon(_getConnectionIcon(conn.type), size: 20),
                title: Text(targetNode?.name ?? conn.targetNodeId),
                subtitle: Text(
                  '${conn.type.name}${conn.weight != null ? ' • Weight: ${conn.weight}' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.link_off, color: Colors.red, size: 20),
                  onPressed: () => context.read<ConfigurationCubit>().removeConnection(
                        node.id,
                        conn.targetNodeId,
                      ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showNodeEditor(BuildContext context, ConfigurableNode? node, ConfigurationState state) async {
    final result = await showDialog<ConfigurableNode>(
      context: context,
      builder: (_) => NodeEditorDialog(
        node: node,
        floor: state.selectedFloor,
        availableBeacons: state.config?.beacons ?? [],
      ),
    );

    if (result != null && context.mounted) {
      if (node == null) {
        context.read<ConfigurationCubit>().addNode(result);
      } else {
        context.read<ConfigurationCubit>().updateNode(result);
      }
    }
  }

  void _showConnectionDialog(
    BuildContext context,
    ConfigurableNode fromNode,
    List<ConfigurableNode> allNodes,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ConnectionDialog(
        fromNodeId: fromNode.id,
        availableNodes: allNodes,
      ),
    );

    if (result != null && context.mounted) {
      context.read<ConfigurationCubit>().addConnection(
            fromNode.id,
            result['targetNodeId'] as String,
            weight: result['weight'] as double?,
            bidirectional: result['bidirectional'] as bool,
            type: result['type'] as ConnectionType,
          );
    }
  }

  void _confirmDelete(BuildContext context, ConfigurableNode node) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Node?'),
        content: Text(
          'Remove "${node.name}" and all its connections?',
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
              context.read<ConfigurationCubit>().removeNode(node.id);
            },
            child: const Text('Delete'),
          ),
        ],
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
        return Icons.location_on;
    }
  }

  IconData _getConnectionIcon(ConnectionType type) {
    switch (type) {
      case ConnectionType.stairs:
        return Icons.stairs;
      case ConnectionType.elevator:
        return Icons.elevator;
      case ConnectionType.restricted:
        return Icons.lock;
      case ConnectionType.normal:
        return Icons.arrow_forward;
    }
  }
}
