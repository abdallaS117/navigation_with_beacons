import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/models.dart';
import '../logic/configuration_cubit.dart';
import '../logic/configuration_state.dart';

class RoutesManagementScreen extends StatelessWidget {
  const RoutesManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigurationCubit, ConfigurationState>(
      builder: (context, state) {
        final routes = state.config?.routes ?? [];
        final nodes = state.config?.nodes ?? [];
        final beacons = state.config?.beacons ?? [];

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Routes & Paths'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                onPressed: () => _showClearAllDialog(context, state),
                tooltip: 'Clear All',
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showCreateRouteInfo(context),
                tooltip: 'Create Route',
              ),
            ],
          ),
          body: routes.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: routes.length,
                  itemBuilder: (context, index) {
                    final route = routes[index];
                    return _buildRouteCard(context, route, nodes, beacons);
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Routes Created',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create routes in the Map Editor',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.map),
            label: const Text('Go to Map Editor'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(
    BuildContext context,
    RouteConfig route,
    List<ConfigurableNode> nodes,
    List<ConfigurableBeacon> beacons,
  ) {
    final routeNodes = route.nodeIds
        .map((id) {
          final node = nodes.cast<ConfigurableNode?>().firstWhere(
            (n) => n?.id == id,
            orElse: () => null,
          );
          if (node != null) return node.name;

          final beacon = beacons.cast<ConfigurableBeacon?>().firstWhere(
            (b) => b?.id == id,
            orElse: () => null,
          );
          return beacon?.name ?? 'Unknown';
        })
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getRouteTypeColor(route.type).withOpacity(0.2),
          child: Icon(
            _getRouteTypeIcon(route.type),
            color: _getRouteTypeColor(route.type),
          ),
        ),
        title: Text(route.name),
        subtitle: Text(
          '${route.nodeIds.length} nodes • ${_getRouteTypeLabel(route.type)}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (route.description != null && route.description!.isNotEmpty) ...[
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(route.description!),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Route Path',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...routeNodes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final nodeName = entry.value;
                  final isLast = index == routeNodes.length - 1;
                  
                  return Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: index == 0
                                ? Colors.green
                                : isLast
                                    ? Colors.red
                                    : Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(nodeName)),
                        if (index == 0)
                          const Chip(
                            label: Text('Start', style: TextStyle(fontSize: 10)),
                            backgroundColor: Colors.green,
                            labelStyle: TextStyle(color: Colors.white),
                            visualDensity: VisualDensity.compact,
                          )
                        else if (isLast)
                          const Chip(
                            label: Text('End', style: TextStyle(fontSize: 10)),
                            backgroundColor: Colors.red,
                            labelStyle: TextStyle(color: Colors.white),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      label: const Text('Edit', style: TextStyle(color: Colors.blue)),
                      onPressed: () => _editRoute(context, route),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      onPressed: () => _confirmDeleteRoute(context, route),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateRouteInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Route'),
        content: const Text(
          'To create a new route:\n\n'
          '1. Go to Map Editor\n'
          '2. Click "Create Route" button\n'
          '3. Select nodes/beacons in order\n'
          '4. Click "Save Route"\n'
          '5. Enter route details',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to config home
            },
            child: const Text('Go to Map Editor'),
          ),
        ],
      ),
    );
  }

  void _editRoute(BuildContext context, RouteConfig route) {
    // Load the route for editing and navigate to map editor
    context.read<ConfigurationCubit>().startEditingRoute(route.id);
    Navigator.pop(context); // Go back to config home, which will show map editor
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editing "${route.name}" - modify nodes on the map'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _confirmDeleteRoute(BuildContext context, RouteConfig route) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Route?'),
        content: Text('Are you sure you want to delete "${route.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<ConfigurationCubit>().deleteRoute(route.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Route "${route.name}" deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(BuildContext context, ConfigurationState state) {
    final hasRoutes = (state.config?.routes ?? []).isNotEmpty;
    final hasConnections = (state.config?.nodes ?? []).any((n) => n.connections.isNotEmpty);
    
    if (!hasRoutes && !hasConnections) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to clear - no routes or connections exist')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear All'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What would you like to clear?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (hasRoutes)
              Text('• Routes: ${state.config?.routes.length ?? 0} routes'),
            if (hasConnections)
              Text('• Connections: Lines between nodes on the map'),
            const SizedBox(height: 16),
            const Text(
              'Choose an option below:',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (hasRoutes)
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
              onPressed: () {
                context.read<ConfigurationCubit>().clearAllRoutes();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All routes cleared')),
                );
              },
              child: const Text('Clear Routes Only'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<ConfigurationCubit>().clearAllRoutesAndConnections();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All routes and connections cleared')),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Color _getRouteTypeColor(RouteType type) {
    switch (type) {
      case RouteType.normal:
        return Colors.blue;
      case RouteType.accessible:
        return Colors.green;
      case RouteType.emergency:
        return Colors.red;
      case RouteType.restricted:
        return Colors.orange;
    }
  }

  IconData _getRouteTypeIcon(RouteType type) {
    switch (type) {
      case RouteType.normal:
        return Icons.route;
      case RouteType.accessible:
        return Icons.accessible;
      case RouteType.emergency:
        return Icons.emergency;
      case RouteType.restricted:
        return Icons.lock;
    }
  }

  String _getRouteTypeLabel(RouteType type) {
    switch (type) {
      case RouteType.normal:
        return 'Normal';
      case RouteType.accessible:
        return 'Accessible';
      case RouteType.emergency:
        return 'Emergency';
      case RouteType.restricted:
        return 'Restricted';
    }
  }
}
