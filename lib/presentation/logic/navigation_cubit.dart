import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/beacon_node.dart';
import '../../domain/entities/department.dart';
import '../../domain/repositories/navigation_repository.dart';
import '../../domain/repositories/beacon_repository.dart';
import 'navigation_state.dart';

class NavigationCubit extends Cubit<NavigationState> {
  final NavigationRepository _navigationRepository;
  final BeaconRepository _beaconRepository;
  StreamSubscription<BeaconNode?>? _beaconSubscription;

  NavigationCubit({
    required NavigationRepository navigationRepository,
    required BeaconRepository beaconRepository,
  })  : _navigationRepository = navigationRepository,
        _beaconRepository = beaconRepository,
        super(const NavigationState());

  Future<void> initialize() async {
    emit(state.copyWith(status: NavigationStatus.loading));

    try {
      final floorMaps = await _navigationRepository.getAllFloorMaps();
      final departments = await _navigationRepository.getAllDepartments();
      final currentFloorMap = await _navigationRepository.getFloorMap(1);

      emit(state.copyWith(
        status: NavigationStatus.mapLoaded,
        allFloorMaps: floorMaps,
        departments: departments,
        currentFloorMap: currentFloorMap,
        currentFloor: 1,
      ));

      // Start listening to beacon changes
      _beaconSubscription = _beaconRepository.nearestBeaconStream.listen(_onBeaconChanged);
    } catch (e) {
      emit(state.copyWith(
        status: NavigationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onBeaconChanged(BeaconNode? beacon) {
    if (beacon == null) return;

    emit(state.copyWith(currentPosition: beacon));

    // Auto-switch floor if beacon is on different floor
    if (beacon.floor != state.currentFloor && state.isNavigating) {
      changeFloor(beacon.floor);
    }

    // Check if navigating and update progress
    if (state.isNavigating && state.currentRoute != null) {
      _updateNavigationProgress(beacon);
    }
  }

  void _updateNavigationProgress(BeaconNode beacon) {
    final route = state.currentRoute!;
    
    // Find current position in route
    final index = route.nodes.indexWhere((n) => n.uid == beacon.uid);
    
    if (index >= 0) {
      final progress = (index + 1) / route.nodes.length;
      
      // Check if arrived at destination
      if (index == route.nodes.length - 1) {
        emit(state.copyWith(
          status: NavigationStatus.arrived,
          currentRouteIndex: index,
          routeProgress: 1.0,
        ));
      } else {
        emit(state.copyWith(
          currentRouteIndex: index,
          routeProgress: progress,
        ));
      }
    }
  }

  Future<void> changeFloor(int floor) async {
    try {
      final floorMap = await _navigationRepository.getFloorMap(floor);
      emit(state.copyWith(
        currentFloor: floor,
        currentFloorMap: floorMap,
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Failed to load floor $floor',
      ));
    }
  }

  Future<void> selectDestination(Department department) async {
    emit(state.copyWith(selectedDestination: department));
  }

  Future<void> startNavigation() async {
    if (state.selectedDestination == null || state.currentPosition == null) {
      emit(state.copyWith(
        errorMessage: 'Please select a destination and wait for position',
      ));
      return;
    }

    emit(state.copyWith(status: NavigationStatus.loading));

    try {
      // Get beacon for destination department
      final destinationBeacon = await _navigationRepository.getBeaconForDepartment(
        state.selectedDestination!.id,
      );

      if (destinationBeacon == null) {
        emit(state.copyWith(
          status: NavigationStatus.mapLoaded,
          errorMessage: 'No beacon found for destination',
        ));
        return;
      }

      final route = await _navigationRepository.calculateRoute(
        state.currentPosition!,
        destinationBeacon,
      );

      if (route.isEmpty) {
        emit(state.copyWith(
          status: NavigationStatus.mapLoaded,
          errorMessage: 'No route found to destination',
        ));
        return;
      }

      // Pass the active route to beacon repository for route-based tracking
      _beaconRepository.setActiveRoute(route);

      emit(state.copyWith(
        status: NavigationStatus.navigating,
        currentRoute: route,
        currentRouteIndex: 0,
        routeProgress: 0.0,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: NavigationStatus.mapLoaded,
        errorMessage: e.toString(),
      ));
    }
  }

  void cancelNavigation() {
    // Clear active route from beacon repository
    _beaconRepository.setActiveRoute(null);
    
    emit(state.copyWith(
      status: NavigationStatus.mapLoaded,
      clearCurrentRoute: true,
      clearSelectedDestination: true,
      currentRouteIndex: 0,
      routeProgress: 0.0,
    ));
  }

  void updateCompassHeading(double heading) {
    emit(state.copyWith(compassHeading: heading));
  }

  void clearError() {
    emit(state.copyWith(clearErrorMessage: true));
  }

  @override
  Future<void> close() {
    _beaconSubscription?.cancel();
    return super.close();
  }
}
