/// Beacon Navigation Package
///
/// A Flutter package for indoor navigation using BLE beacons.
/// Provides beacon scanning, pathfinding, map configuration,
/// and route management for indoor navigation systems.
library beacon_navigation;

// Core - Constants
export 'core/constants/app_colors.dart';
export 'core/constants/app_constants.dart';

// Domain - Entities
export 'domain/entities/beacon_node.dart';
export 'domain/entities/department.dart';
export 'domain/entities/floor_map.dart';
export 'domain/entities/map_element.dart';
export 'domain/entities/navigation_route.dart';

// Domain - Repositories (interfaces)
export 'domain/repositories/navigation_repository.dart';
export 'domain/repositories/beacon_repository.dart';

// Domain - Use Cases
export 'domain/usecases/calculate_route.dart';
export 'domain/usecases/calculate_route_progress.dart';
export 'domain/usecases/get_departments.dart';
export 'domain/usecases/get_floor_map.dart';
export 'domain/usecases/get_nearest_beacon.dart';

// Data - Repositories (implementations)
export 'data/repositories/navigation_repository_impl.dart';
export 'data/repositories/beacon_repository_impl.dart';

// Data - Providers
export 'data/providers/static_beacon_configuration.dart';
export 'data/providers/static_map_provider.dart';

// Configuration Feature (Map Editor, Beacon Management, etc.)
export 'features/configuration/configuration.dart';

// Presentation - Views
export 'presentation/views/indoor_map_view.dart';

// Presentation - Widgets
export 'presentation/widgets/beacon_status_widget.dart';
export 'presentation/widgets/destination_selector.dart';
export 'presentation/widgets/floor_selector.dart';
export 'presentation/widgets/indoor_map_painter.dart';
export 'presentation/widgets/navigation_info_panel.dart';
export 'presentation/widgets/route_painter.dart';
export 'presentation/widgets/search_header.dart';
export 'presentation/widgets/user_arrow.dart';

// Presentation - State Management (Cubit)
export 'presentation/logic/beacon_cubit.dart';
export 'presentation/logic/beacon_state.dart';
export 'presentation/logic/navigation_cubit.dart';
export 'presentation/logic/navigation_state.dart';
