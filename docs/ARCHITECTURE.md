# Beacon Navigation - Architecture Documentation

## Overview

This Flutter application provides indoor navigation using BLE (Bluetooth Low Energy) beacons. It follows **Clean Architecture** principles with a feature-based folder structure.

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── beacon_navigation.dart       # Package exports
├── core/                        # Shared utilities
│   ├── constants/
│   │   ├── app_colors.dart      # Color definitions
│   │   └── app_constants.dart   # App-wide constants
│   └── theme/
│       └── app_theme.dart       # Material theme configuration
│
└── features/
    ├── configuration/           # Map & beacon configuration
    │   ├── data/
    │   │   ├── repositories/
    │   │   └── services/
    │   ├── domain/
    │   │   └── models/
    │   └── presentation/
    │       ├── logic/           # Cubits & states
    │       ├── screens/
    │       └── widgets/
    │
    └── navigation/              # Indoor navigation
        ├── data/
        │   ├── datasources/
        │   ├── helpers/
        │   ├── providers/
        │   └── repositories/
        ├── domain/
        │   ├── entities/
        │   ├── repositories/
        │   └── usecases/
        └── presentation/
            ├── logic/           # Cubits & states
            ├── views/
            └── widgets/
```

## Architecture Layers

### 1. Domain Layer
Contains business logic and entities. No dependencies on external frameworks.

- **Entities**: Core data models (`BeaconNode`, `NavigationRoute`, `Department`)
- **Repositories**: Abstract interfaces defining data operations
- **Use Cases**: Single-purpose business logic units

### 2. Data Layer
Implements domain interfaces and handles data sources.

- **Repositories**: Concrete implementations of domain repositories
- **Data Sources**: BLE scanning, Firebase, local storage
- **Helpers**: Pathfinding algorithms, position calculation

### 3. Presentation Layer
UI components and state management.

- **Cubits**: State management using flutter_bloc
- **Views/Screens**: Full-page UI components
- **Widgets**: Reusable UI components

## State Management

Uses **flutter_bloc** with Cubit pattern:

```
┌─────────────────┐     ┌─────────────────┐
│  NavigationCubit │     │   BeaconCubit   │
│                 │     │                 │
│ - Route calc    │     │ - BLE scanning  │
│ - Floor change  │     │ - Position      │
│ - Progress      │     │ - Detection     │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     │
              ┌──────▼──────┐
              │ IndoorMapView│
              │             │
              │ - Map render │
              │ - Route draw │
              │ - User arrow │
              └─────────────┘
```

## Data Flow

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  BLE Scanner │───▶│ BeaconCubit  │───▶│   UI State   │
└──────────────┘    └──────────────┘    └──────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │ Navigation   │
                    │ Cubit        │
                    └──────┬───────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
  ┌────────────┐    ┌────────────┐    ┌────────────┐
  │ Pathfinding│    │ Floor      │    │ Instruction│
  │ Helper     │    │ Transition │    │ Generator  │
  └────────────┘    └────────────┘    └────────────┘
```

## Key Components

### Navigation Feature

| Component | Purpose |
|-----------|---------|
| `NavigationCubit` | Manages navigation state, route calculation |
| `BeaconCubit` | Manages beacon scanning and position |
| `NavigationRepositoryImpl` | Route calculation with Dijkstra algorithm |
| `HybridBeaconDataSource` | BLE beacon scanning and RSSI processing |
| `PathfindingHelper` | Dijkstra algorithm implementation |
| `OneWayRestrictionHelper` | Validates one-way connection constraints |

### Configuration Feature

| Component | Purpose |
|-----------|---------|
| `ConfigurationCubit` | Manages configuration state |
| `ConfigurationRepository` | CRUD operations for configuration |
| `FirebaseConfigurationService` | Firebase Firestore sync |
| `MapEditorScreen` | Visual map editor UI |
| `ConfigurableNode` | Node model with connections |

## Connection Types

The app supports different connection types between nodes:

| Type | Description | Use Case |
|------|-------------|----------|
| `normal` | Standard two-way corridor | Regular hallways |
| `emergency` | Emergency-only routes | Fire exits |
| `staff` | Staff-only access | Restricted areas |
| `stairs` | Staircase connection | Floor transitions |
| `elevator` | Elevator connection | Floor transitions |

## One-Way Connections

Connections can be configured as:

- **Bidirectional**: Travel allowed in both directions
- **One-way**: Travel allowed only in the defined direction

The pathfinding algorithm respects these constraints when calculating routes.

## Floor Transitions

Multi-floor navigation is supported through:

1. **Stairs nodes**: Connect floors via staircase
2. **Elevator nodes**: Connect floors via elevator
3. **FloorTransitionHelper**: Finds valid transition points

## Firebase Integration

Configuration data is synced with Firebase Firestore:

```
firestore/
└── navigation_config/
    └── main/
        ├── nodes[]
        ├── beacons[]
        ├── routes[]
        ├── connections[]
        └── mapLayout
```

### Base64 Image Storage

Floor plan images are stored as Base64 strings in Firestore to avoid Firebase Storage costs:

1. **Upload**: Image → Base64 encode → Store in `FloorConfig.imageBase64`
2. **Download**: Fetch config → Base64 decode → Display image

## Beacon Positioning

Position calculation uses weighted RSSI values:

```dart
// RSSI to distance conversion
distance = 10 ^ ((txPower - rssi) / (10 * n))

// Weighted position from multiple beacons
position = Σ(beacon.position * weight) / Σ(weight)
```

## Route Calculation Priority

1. **Pre-configured routes**: Check if start/end exist in saved routes
2. **Dijkstra pathfinding**: Calculate optimal path using connections
3. **One-way validation**: Ensure path respects direction constraints
4. **Floor transitions**: Handle multi-floor navigation

## Error Handling

Navigation errors are displayed via dialogs:

- "No route found" - No valid path exists
- "One-way restriction" - Path blocked by direction constraint
- "No beacon found" - Destination has no associated beacon
