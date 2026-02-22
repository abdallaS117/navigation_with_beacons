/// Example usage of the Beacon Navigation package
///
/// This example demonstrates how to integrate the beacon navigation
/// package into your Flutter application.
///
/// For a complete working example, see the main.dart file in the
/// package repository.

// ignore_for_file: unused_import

import 'package:beacon_navigation/beacon_navigation.dart';

/// Basic usage example:
///
/// 1. Import the package:
/// ```dart
/// import 'package:beacon_navigation/beacon_navigation.dart';
/// ```
///
/// 2. Open the Configuration Screen to set up your map:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => const ConfigurationHomeScreen(),
///   ),
/// );
/// ```
///
/// 3. Use the Map Editor to:
///    - Upload a floor plan image
///    - Add navigation nodes
///    - Create connections between nodes
///    - Configure connection direction (one-way/two-way)
///    - Set connection types (normal, emergency, staff, stairs, elevator)
///    - Register BLE beacons
///
/// 4. Use the IndoorMapView widget to display navigation:
/// ```dart
/// IndoorMapView(
///   // Your configuration here
/// )
/// ```
///
/// 5. Use NavigationRepositoryImpl for pathfinding:
/// ```dart
/// final repository = NavigationRepositoryImpl(...);
/// final route = await repository.calculateRoute(start, end);
/// ```
///
/// See the README.md for complete documentation.
