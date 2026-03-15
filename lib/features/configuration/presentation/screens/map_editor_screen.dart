import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/configuration_cubit.dart';
import '../logic/configuration_state.dart';
import '../widgets/map_editor_canvas.dart';
import '../widgets/map_editor_panels.dart';
import 'map_editor_handlers.dart';

/// Map editor screen for configuring navigation nodes, beacons, and routes.
/// 
/// Refactored to use extracted components:
/// - [MapEditorToolbar] for mode selection
/// - [BeaconSelectorPanel] for beacon placement
/// - [ConnectionModePanel] for connection instructions
/// - [RouteProgressPanel] for route creation
/// - [SelectionPanel] for selected item details
/// - [RouteSelectionPanel] for route details
/// - [MapEditorHandlers] mixin for event handling
class MapEditorScreen extends StatelessWidget with MapEditorHandlers {
  const MapEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigurationCubit, ConfigurationState>(
      builder: (context, state) {
        return SafeArea(
          bottom: true,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text('Map Editor'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => showMapSettings(context, state),
                  tooltip: 'Map Settings',
                ),
              ],
            ),
            body: Column(
              children: [
                MapEditorToolbar(state: state),
                _buildFloorSelector(context, state),
                if (state.mode == ConfigurationMode.placeBeacon && state.unplacedBeacons.isNotEmpty)
                  BeaconSelectorPanel(state: state),
                if (state.mode == ConfigurationMode.addConnection)
                  ConnectionModePanel(state: state),
                if (state.mode == ConfigurationMode.createRoute)
                  RouteProgressPanel(
                    state: state,
                    onSave: () => saveRoute(context, state),
                  ),
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
                    onTap: (x, y) => handleCanvasTap(context, state, x, y),
                    onNodeTap: (id) => handleNodeTap(context, state, id),
                    onBeaconTap: (id) => handleBeaconTap(context, state, id),
                    onConnectionTap: (fromId, toId, connection) => 
                        handleConnectionTap(context, state, fromId, toId, connection),
                    onRouteSegmentTap: (routeId, segmentIndex) => 
                        handleRouteSegmentTap(context, state, routeId, segmentIndex),
                  ),
                ),
                if (state.selectedNodeId != null || state.selectedBeaconId != null)
                  SelectionPanel(
                    state: state,
                    onDeleteNode: () => confirmDeleteNode(context, state.selectedNodeId!),
                    onRemoveBeacon: () => confirmRemoveBeacon(context, state.selectedBeaconId!),
                  ),
                if (state.selectedRouteId != null && state.selectedRoute != null)
                  RouteSelectionPanel(
                    route: state.selectedRoute!,
                    onDelete: () => confirmDeleteRoute(
                      context, 
                      state.selectedRouteId!, 
                      state.selectedRoute!.name,
                    ),
                    onClose: () => context.read<ConfigurationCubit>().selectRoute(null),
                  ),
              ],
            ),
            floatingActionButton: _buildFAB(context, state),
          ),
        );
      },
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
                    onLongPress: () => showFloorOptions(context, state, floor),
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
            onPressed: () => addFloor(context, state),
            tooltip: 'Add Floor',
          ),
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
}
