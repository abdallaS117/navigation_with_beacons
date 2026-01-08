import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/beacon_node.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/datasources/hybrid_beacon_datasource.dart';
import '../logic/navigation_cubit.dart';
import '../logic/navigation_state.dart';
import '../logic/beacon_cubit.dart';
import '../logic/beacon_state.dart';
import '../widgets/indoor_map_painter.dart';
import '../widgets/route_painter.dart';
import '../widgets/user_arrow.dart';
import '../widgets/floor_selector.dart';
import '../widgets/destination_selector.dart';
import '../widgets/navigation_info_panel.dart';
import '../widgets/search_header.dart';
import '../widgets/beacon_status_widget.dart';

class IndoorMapView extends StatefulWidget {
  const IndoorMapView({super.key});

  @override
  State<IndoorMapView> createState() => _IndoorMapViewState();
}

class _IndoorMapViewState extends State<IndoorMapView>
    with TickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _routeAnimationController;
  late Animation<double> _routeAnimation;
  bool _isAutoPlaying = false;
  bool _showBeaconStatus = true;
  Timer? _autoPlayTimer;
  int _currentAutoPlayIndex = 0;

  @override
  void initState() {
    super.initState();
    _routeAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _routeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _routeAnimationController,
        curve: Curves.linear,
      ),
    );

    // Initialize navigation and start beacon scanning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavigationCubit>().initialize();
      context.read<BeaconCubit>().startScanning();

      // Center the map initially
      final screenSize = MediaQuery.of(context).size;
      final mapWidth = AppConstants.mapWidth;
      final mapHeight = AppConstants.mapHeight;

      // Calculate center offset
      // We want the center of the map (mapWidth/2, mapHeight/2)
      // to be at the center of the screen (screenWidth/2, screenHeight/2)
      final x = (screenSize.width - mapWidth) / 2;
      final y = (screenSize.height - mapHeight) / 2;

      _transformationController.value = Matrix4.identity()..translate(x, y);
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _routeAnimationController.dispose();
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  void _toggleAutoPlay(BuildContext context) {
    setState(() {
      _isAutoPlaying = !_isAutoPlaying;
    });

    if (_isAutoPlaying) {
      _startAutoPlay(context);
    } else {
      _stopAutoPlay();
    }
  }

  void _startAutoPlay(BuildContext context) {
    final navState = context.read<NavigationCubit>().state;
    
    // Check if there's an active route to follow
    if (navState.currentRoute == null || navState.currentRoute!.nodes.isEmpty) {
      // No route, stop auto-play
      setState(() {
        _isAutoPlaying = false;
      });
      return;
    }

    final routeNodes = navState.currentRoute!.nodes;
    _currentAutoPlayIndex = 0;
    
    // Immediately move to first node
    context.read<BeaconCubit>().simulateBeaconChange(routeNodes[0].uid);
    
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final navState = context.read<NavigationCubit>().state;
      
      // Check if route still exists
      if (navState.currentRoute == null || navState.currentRoute!.nodes.isEmpty) {
        _stopAutoPlay();
        setState(() {
          _isAutoPlaying = false;
        });
        return;
      }
      
      final nodes = navState.currentRoute!.nodes;
      _currentAutoPlayIndex++;
      
      // Stop at destination
      if (_currentAutoPlayIndex >= nodes.length) {
        _stopAutoPlay();
        setState(() {
          _isAutoPlaying = false;
        });
        return;
      }

      context.read<BeaconCubit>().simulateBeaconChange(nodes[_currentAutoPlayIndex].uid);
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  void _showDestinationSelector(BuildContext context) {
    final navigationState = context.read<NavigationCubit>().state;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DestinationSelector(
          departments: navigationState.departments,
          selectedDepartment: navigationState.selectedDestination,
          onDepartmentSelected: (department) {
            context.read<NavigationCubit>().selectDestination(department);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _centerOnUser(BeaconNode? currentPosition) {
    if (currentPosition == null) return;

    final screenSize = MediaQuery.of(context).size;
    final scale = _transformationController.value.getMaxScaleOnAxis();

    final offsetX = screenSize.width / 2 - currentPosition.x * scale;
    final offsetY = screenSize.height / 2 - currentPosition.y * scale;

    _transformationController.value = Matrix4.identity()
      ..translate(offsetX, offsetY)
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final navState = context.read<NavigationCubit>().state;
        
        // If navigating, cancel navigation
        if (navState.isNavigating || navState.selectedDestination != null) {
          context.read<NavigationCubit>().cancelNavigation();
          return;
        }
        
        // Otherwise, allow exit
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: BlocConsumer<NavigationCubit, NavigationState>(
          listener: (context, state) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Dismiss',
                  textColor: Colors.white,
                  onPressed: () {
                    context.read<NavigationCubit>().clearError();
                  },
                ),
              ),
            );
          }
        },
        builder: (context, navState) {
          return BlocBuilder<BeaconCubit, BeaconState>(
            builder: (context, beaconState) {
              return Stack(
                children: [
                  // Map with interactive viewer
                  _buildMap(navState, beaconState),

                  // Top bar with info
                  _buildTopBar(navState, beaconState),

                  // Floor selector
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 90,
                    left: 16,
                    child: FloorSelector(
                      currentFloor: navState.currentFloor,
                      floors: const [1, 2, 3],
                      highlightedFloors: navState.currentRoute?.floorsInRoute,
                      onFloorSelected: (floor) {
                        context.read<NavigationCubit>().changeFloor(floor);
                      },
                    ),
                  ),

                  // Beacon Status Widget
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 90,
                    right: 16,
                    child: BeaconStatusWidget(
                      statusStream: context.read<HybridBeaconDataSource>().beaconStatusStream,
                      isVisible: _showBeaconStatus,
                      onToggle: () {
                        setState(() {
                          _showBeaconStatus = !_showBeaconStatus;
                        });
                      },
                    ),
                  ),

                  // Auto-play button (visible when route exists)
                  if (navState.currentRoute != null && navState.currentRoute!.nodes.isNotEmpty)
                    Positioned(
                      left: 16,
                      bottom: (navState.isNavigating ? 90 : 16) + MediaQuery.of(context).padding.bottom,
                      child: FloatingActionButton(
                        heroTag: 'route_auto_play',
                        backgroundColor: _isAutoPlaying
                            ? AppColors.routeLine
                            : Colors.white,
                        foregroundColor: _isAutoPlaying
                            ? Colors.white
                            : AppColors.primary,
                        onPressed: () => _toggleAutoPlay(context),
                        child: Icon(
                          _isAutoPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                      ),
                    ),

                  // Center on User Button
                  Positioned(
                    right: 16,
                    bottom: (navState.selectedDestination != null ? 220 : 100) +
                        MediaQuery.of(context).padding.bottom,
                    child: FloatingActionButton.small(
                      heroTag: 'center_user',
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      onPressed: () => _centerOnUser(beaconState.currentBeacon),
                      child: const Icon(Icons.my_location),
                    ),
                  ),

                  // Navigation info panel
                  if (navState.isNavigating && navState.currentRoute != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: NavigationInfoPanel(
                        route: navState.currentRoute!,
                        destination: navState.selectedDestination!,
                        currentInstructionIndex: navState.currentRouteIndex,
                        hasArrived: navState.hasArrived,
                        onCancel: () {
                          context.read<NavigationCubit>().cancelNavigation();
                        },
                      ),
                    ),

                  // Bottom action buttons (when not navigating)
                  if (!navState.isNavigating && !navState.hasArrived)
                    _buildBottomActions(navState, beaconState),

                  // Loading overlay
                  if (navState.status == NavigationStatus.loading)
                    Container(
                      color: Colors.black26,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    ),
    );
  }

  Widget _buildMap(NavigationState navState, BeaconState beaconState) {
    if (navState.currentFloorMap == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.1, // Allow zooming out far
      maxScale: 5.0, // Allow zooming in close
      boundaryMargin: const EdgeInsets.all(5000), // Infinite-feeling pan space
      constrained: false, // Map size is independent of screen size
      panEnabled: true,
      scaleEnabled: true,
      child: SizedBox(
        width: AppConstants.mapWidth,
        height: AppConstants.mapHeight,
        child: Stack(
          children: [
            // Indoor map base
            CustomPaint(
              size: const Size(AppConstants.mapWidth, AppConstants.mapHeight),
              painter: IndoorMapPainter(
                floorMap: navState.currentFloorMap!,
                selectedDepartment: navState.selectedDestination,
              ),
            ),

            // Route overlay
            if (navState.currentRoute != null)
              AnimatedBuilder(
                animation: _routeAnimation,
                builder: (context, child) {
                  final destinationNode =
                      navState.currentRoute!.nodes.isNotEmpty
                          ? navState.currentRoute!.nodes.last
                          : null;
                  return CustomPaint(
                    size: const Size(
                        AppConstants.mapWidth, AppConstants.mapHeight),
                    painter: RoutePainter(
                      route: navState.currentRoute,
                      currentFloor: navState.currentFloor,
                      currentNodeIndex: navState.currentRouteIndex,
                      animationProgress: _routeAnimation.value,
                      destinationNode: destinationNode,
                    ),
                  );
                },
              ),

            // Beacon markers
            _buildBeaconMarker(
              x: 400,
              y: 460,
              label: 'A',
              color: Colors.green,
              floor: 1,
              currentFloor: navState.currentFloor,
            ),
            _buildBeaconMarker(
              x: 90,
              y: 220,
              label: 'B',
              color: Colors.orange,
              floor: 1,
              currentFloor: navState.currentFloor,
            ),

            // User position arrow
            if (beaconState.currentBeacon != null &&
                beaconState.currentBeacon!.floor == navState.currentFloor)
              AnimatedUserArrow(
                x: beaconState.currentBeacon!.x,
                y: beaconState.currentBeacon!.y,
                heading: navState.compassHeading,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeaconMarker({
    required double x,
    required double y,
    required String label,
    required Color color,
    required int floor,
    required int currentFloor,
  }) {
    if (floor != currentFloor) return const SizedBox.shrink();

    return Positioned(
      left: x - 20,
      top: y - 20,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: color, width: 2),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(NavigationState navState, BeaconState beaconState) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 0,
      right: 0,
      child: SearchHeader(
        selectedDestination: navState.selectedDestination,
        currentLocationName: beaconState.currentBeacon?.name,
        onSearchTap: () => _showDestinationSelector(context),
        onBackTap: () {
          // If in navigation or destination selected, clear it
          context.read<NavigationCubit>().cancelNavigation();
        },
      ),
    );
  }

  Widget _buildBottomActions(
      NavigationState navState, BeaconState beaconState) {
    return Stack(
      children: [
        // Demo panel removed - only real beacons supported
        if (navState.selectedDestination != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: navState.selectedDestination!.color
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          navState.selectedDestination!.icon,
                          color: navState.selectedDestination!.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              navState.selectedDestination!.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'Tap Start to begin navigation',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: beaconState.currentBeacon != null
                          ? () {
                              context.read<NavigationCubit>().startNavigation();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.navigation),
                          SizedBox(width: 8),
                          Text(
                            'Start Navigation',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

}
