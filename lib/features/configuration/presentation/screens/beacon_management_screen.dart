import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/models.dart';
import '../logic/configuration_cubit.dart';
import '../logic/configuration_state.dart';
import '../widgets/beacon_editor_dialog.dart';

class BeaconManagementScreen extends StatelessWidget {
  const BeaconManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigurationCubit, ConfigurationState>(
      builder: (context, state) {
        final beacons = state.config?.beacons ?? [];
        final placedBeacons = beacons.where((b) => b.isPlaced).toList();
        final unplacedBeacons = beacons.where((b) => !b.isPlaced).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Beacon Management'),
            actions: [
              IconButton(
                icon: const Icon(Icons.bluetooth_searching),
                onPressed: () => _scanForBeacons(context),
                tooltip: 'Scan for Beacons',
              ),
            ],
          ),
          body: beacons.isEmpty
              ? _buildEmptyState(context)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (unplacedBeacons.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Unplaced Beacons', Icons.bluetooth_disabled),
                      const SizedBox(height: 8),
                      ...unplacedBeacons.map((b) => _buildBeaconCard(context, b, state)),
                      const SizedBox(height: 24),
                    ],
                    if (placedBeacons.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Placed Beacons', Icons.bluetooth_connected),
                      const SizedBox(height: 8),
                      ...placedBeacons.map((b) => _buildBeaconCard(context, b, state)),
                    ],
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Add Beacon'),
            onPressed: () => _showBeaconEditor(context, null),
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
          Icon(Icons.bluetooth_disabled, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Beacons Configured',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add beacons manually or scan for nearby devices',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Beacon'),
            onPressed: () => _showBeaconEditor(context, null),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildBeaconCard(BuildContext context, ConfigurableBeacon beacon, ConfigurationState state) {
    final isSelected = state.selectedBeaconId == beacon.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.orange.withOpacity(0.1) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: beacon.isPlaced ? Colors.green : Colors.orange,
          child: Icon(
            beacon.isPlaced ? Icons.bluetooth_connected : Icons.bluetooth,
            color: Colors.white,
          ),
        ),
        title: Text(beacon.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              beacon.uuid,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            if (beacon.isPlaced)
              Text(
                'Floor ${beacon.floor} • (${beacon.x?.toInt()}, ${beacon.y?.toInt()})',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!beacon.isPlaced)
              IconButton(
                icon: const Icon(Icons.place, color: Colors.blue),
                onPressed: () {
                  context.read<ConfigurationCubit>().selectBeacon(beacon.id);
                  context.read<ConfigurationCubit>().setMode(ConfigurationMode.placeBeacon);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tap on the map to place this beacon'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                tooltip: 'Place on Map',
              ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showBeaconEditor(context, beacon),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(context, beacon),
              tooltip: 'Delete',
            ),
          ],
        ),
        onTap: () => context.read<ConfigurationCubit>().selectBeacon(
              isSelected ? null : beacon.id,
            ),
      ),
    );
  }

  void _showBeaconEditor(BuildContext context, ConfigurableBeacon? beacon) async {
    final result = await showDialog<ConfigurableBeacon>(
      context: context,
      builder: (_) => BeaconEditorDialog(beacon: beacon),
    );

    if (result != null && context.mounted) {
      if (beacon == null) {
        context.read<ConfigurationCubit>().addBeacon(result);
      } else {
        context.read<ConfigurationCubit>().updateBeacon(result);
      }
    }
  }

  void _confirmDelete(BuildContext context, ConfigurableBeacon beacon) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Beacon?'),
        content: Text('Remove "${beacon.name}" from configuration?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              context.read<ConfigurationCubit>().removeBeacon(beacon.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _scanForBeacons(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Beacon scanning - Coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
