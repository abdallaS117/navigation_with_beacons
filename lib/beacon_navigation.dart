/// Beacon Navigation Package
///
/// A Flutter package for indoor navigation using BLE beacons.
/// Provides beacon scanning, pathfinding, map configuration,
/// and route management for indoor navigation systems.
library beacon_navigation;

// Core - Constants
export 'core/constants/app_colors.dart';
export 'core/constants/app_constants.dart';

// Navigation Feature - Domain - Entities
export 'features/navigation/domain/entities/beacon_node.dart';
export 'features/navigation/domain/entities/department.dart';
export 'features/navigation/domain/entities/floor_map.dart';
export 'features/navigation/domain/entities/map_element.dart';
export 'features/navigation/domain/entities/navigation_route.dart';

// Navigation Feature - Domain - Repositories (interfaces)
export 'features/navigation/domain/repositories/navigation_repository.dart';
export 'features/navigation/domain/repositories/beacon_repository.dart';

// Navigation Feature - Domain - Use Cases
export 'features/navigation/domain/usecases/calculate_route.dart';
export 'features/navigation/domain/usecases/calculate_route_progress.dart';
export 'features/navigation/domain/usecases/get_departments.dart';
export 'features/navigation/domain/usecases/get_floor_map.dart';
export 'features/navigation/domain/usecases/get_nearest_beacon.dart';

// Navigation Feature - Data - Repositories (implementations)
export 'features/navigation/data/repositories/navigation_repository_impl.dart';
export 'features/navigation/data/repositories/beacon_repository_impl.dart';

// Navigation Feature - Data - Providers
export 'features/navigation/data/providers/static_beacon_configuration.dart';
export 'features/navigation/data/providers/static_map_provider.dart';

// Configuration Feature (Map Editor, Beacon Management, etc.)
export 'features/configuration/configuration.dart';

// Navigation Feature - Presentation - Views
export 'features/navigation/presentation/views/indoor_map_view.dart';

// Navigation Feature - Presentation - Widgets
export 'features/navigation/presentation/widgets/beacon_status_widget.dart';
export 'features/navigation/presentation/widgets/destination_selector.dart';
export 'features/navigation/presentation/widgets/floor_selector.dart';
export 'features/navigation/presentation/widgets/indoor_map_painter.dart';
export 'features/navigation/presentation/widgets/navigation_info_panel.dart';
export 'features/navigation/presentation/widgets/route_painter.dart';
export 'features/navigation/presentation/widgets/search_header.dart';
export 'features/navigation/presentation/widgets/user_arrow.dart';

// Navigation Feature - Presentation - State Management (Cubit)
export 'features/navigation/presentation/logic/beacon_cubit.dart';
export 'features/navigation/presentation/logic/beacon_state.dart';
export 'features/navigation/presentation/logic/navigation_cubit.dart';
export 'features/navigation/presentation/logic/navigation_state.dart';
