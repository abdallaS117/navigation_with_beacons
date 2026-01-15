import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/configuration_cubit.dart';
import '../logic/configuration_state.dart';
import 'map_editor_screen.dart';
import 'beacon_management_screen.dart';
import 'node_editor_screen.dart';

class ConfigurationHomeScreen extends StatelessWidget {
  const ConfigurationHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigurationCubit, ConfigurationState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Configuration'),
            actions: [
              if (state.isDirty)
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: () => context.read<ConfigurationCubit>().saveConfiguration(),
                  tooltip: 'Save Changes',
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<ConfigurationCubit>().loadConfiguration(),
                tooltip: 'Reload',
              ),
            ],
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ConfigurationState state) {
    if (state.status == ConfigurationStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == ConfigurationStatus.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(state.errorMessage!, style: TextStyle(color: Colors.grey[600])),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: () => context.read<ConfigurationCubit>().loadConfiguration(),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusCard(context, state),
        const SizedBox(height: 16),
        _buildConfigSection(
          context,
          title: 'Map Configuration',
          subtitle: 'Configure map layout, scale, and background',
          icon: Icons.map,
          color: Colors.blue,
          onTap: () => _navigateTo(context, const MapEditorScreen()),
        ),
        const SizedBox(height: 12),
        _buildConfigSection(
          context,
          title: 'Beacon Management',
          subtitle: '${state.config?.beacons.length ?? 0} beacons configured',
          icon: Icons.bluetooth,
          color: Colors.orange,
          onTap: () => _navigateTo(context, const BeaconManagementScreen()),
        ),
        const SizedBox(height: 12),
        _buildConfigSection(
          context,
          title: 'Navigation Nodes',
          subtitle: '${state.config?.nodes.length ?? 0} nodes configured',
          icon: Icons.location_on,
          color: Colors.green,
          onTap: () => _navigateTo(context, const NodeEditorScreen()),
        ),
        const SizedBox(height: 12),
        _buildConfigSection(
          context,
          title: 'Routes & Paths',
          subtitle: '${state.config?.routes.length ?? 0} routes defined',
          icon: Icons.route,
          color: Colors.purple,
          onTap: () => _showComingSoon(context),
        ),
        const SizedBox(height: 24),
        _buildExportImportSection(context),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context, ConfigurationState state) {
    final config = state.config;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  state.isDirty ? Icons.edit : Icons.check_circle,
                  color: state.isDirty ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  state.isDirty ? 'Unsaved Changes' : 'Configuration Saved',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (config != null) ...[
              const Divider(height: 24),
              Text('Name: ${config.name}'),
              Text('Last Modified: ${_formatDate(config.lastModified)}'),
              Text('Map: ${config.mapConfig.width.toInt()}x${config.mapConfig.height.toInt()}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfigSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildExportImportSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import / Export',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import'),
                    onPressed: () => _showComingSoon(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Export'),
                    onPressed: () => _exportConfig(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BlocProvider.value(
        value: context.read<ConfigurationCubit>(),
        child: screen,
      )),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon!')),
    );
  }

  Future<void> _exportConfig(BuildContext context) async {
    try {
      final json = await context.read<ConfigurationCubit>().exportConfiguration();
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Configuration Export'),
            content: SingleChildScrollView(
              child: SelectableText(json.toString()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
