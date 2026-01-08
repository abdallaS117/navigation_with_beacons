import 'package:equatable/equatable.dart';
import '../../domain/entities/beacon_node.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/floor_map.dart';
import '../../domain/entities/navigation_route.dart';

enum NavigationStatus { 
  initial, 
  loading, 
  mapLoaded, 
  navigating, 
  arrived, 
  error 
}

class NavigationState extends Equatable {
  final NavigationStatus status;
  final int currentFloor;
  final FloorMap? currentFloorMap;
  final List<FloorMap> allFloorMaps;
  final List<Department> departments;
  final Department? selectedDestination;
  final NavigationRoute? currentRoute;
  final BeaconNode? currentPosition;
  final int currentRouteIndex;
  final double routeProgress;
  final String? errorMessage;
  final double compassHeading;

  const NavigationState({
    this.status = NavigationStatus.initial,
    this.currentFloor = 1,
    this.currentFloorMap,
    this.allFloorMaps = const [],
    this.departments = const [],
    this.selectedDestination,
    this.currentRoute,
    this.currentPosition,
    this.currentRouteIndex = 0,
    this.routeProgress = 0.0,
    this.errorMessage,
    this.compassHeading = 0.0,
  });

  bool get isNavigating => status == NavigationStatus.navigating;
  bool get hasArrived => status == NavigationStatus.arrived;
  
  String? get currentInstruction {
    if (currentRoute == null || currentRoute!.instructions.isEmpty) return null;
    if (currentRouteIndex >= currentRoute!.instructions.length) return null;
    return currentRoute!.instructions[currentRouteIndex];
  }

  BeaconNode? get nextNode {
    if (currentRoute == null || currentRoute!.nodes.isEmpty) return null;
    final nextIndex = currentRouteIndex + 1;
    if (nextIndex >= currentRoute!.nodes.length) return null;
    return currentRoute!.nodes[nextIndex];
  }

  NavigationState copyWith({
    NavigationStatus? status,
    int? currentFloor,
    FloorMap? currentFloorMap,
    List<FloorMap>? allFloorMaps,
    List<Department>? departments,
    Department? selectedDestination,
    bool clearSelectedDestination = false,
    NavigationRoute? currentRoute,
    bool clearCurrentRoute = false,
    BeaconNode? currentPosition,
    int? currentRouteIndex,
    double? routeProgress,
    String? errorMessage,
    bool clearErrorMessage = false,
    double? compassHeading,
  }) {
    return NavigationState(
      status: status ?? this.status,
      currentFloor: currentFloor ?? this.currentFloor,
      currentFloorMap: currentFloorMap ?? this.currentFloorMap,
      allFloorMaps: allFloorMaps ?? this.allFloorMaps,
      departments: departments ?? this.departments,
      selectedDestination: clearSelectedDestination ? null : (selectedDestination ?? this.selectedDestination),
      currentRoute: clearCurrentRoute ? null : (currentRoute ?? this.currentRoute),
      currentPosition: currentPosition ?? this.currentPosition,
      currentRouteIndex: currentRouteIndex ?? this.currentRouteIndex,
      routeProgress: routeProgress ?? this.routeProgress,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      compassHeading: compassHeading ?? this.compassHeading,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentFloor,
        currentFloorMap,
        allFloorMaps,
        departments,
        selectedDestination,
        currentRoute,
        currentPosition,
        currentRouteIndex,
        routeProgress,
        errorMessage,
        compassHeading,
      ];
}
