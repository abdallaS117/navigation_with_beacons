# Beacon Navigation Documentation

## Documentation Index

Welcome to the Beacon Navigation documentation. This package provides indoor navigation using BLE beacons for Flutter applications.

---

## Getting Started

| Document | Description |
|----------|-------------|
| [Quick Start](QUICK_START.md) | Installation and basic setup guide |
| [Architecture](ARCHITECTURE.md) | Project structure and design patterns |

---

## Feature Documentation

| Document | Description |
|----------|-------------|
| [Navigation Feature](NAVIGATION_FEATURE.md) | Indoor navigation, positioning, route display |
| [Configuration Feature](CONFIGURATION_FEATURE.md) | Map editor, beacon management, route builder |

---

## Technical Reference

| Document | Description |
|----------|-------------|
| [API Reference](API_REFERENCE.md) | Public classes, methods, and interfaces |
| [Pathfinding](PATHFINDING.md) | Route calculation, Dijkstra algorithm, one-way handling |
| [Beacon Scanning](BEACON_SCANNING.md) | BLE scanning, RSSI processing, positioning |

---

## Quick Links

### Key Classes

- **Navigation**
  - `NavigationCubit` - Navigation state management
  - `BeaconCubit` - Beacon scanning state
  - `NavigationRepositoryImpl` - Route calculation
  - `PathfindingHelper` - Dijkstra algorithm

- **Configuration**
  - `ConfigurationCubit` - Configuration state management
  - `ConfigurationRepository` - CRUD operations
  - `NavigationConfig` - Root configuration model

- **Widgets**
  - `IndoorMapView` - Main navigation screen
  - `ConfigurationHomeScreen` - Configuration menu
  - `MapEditorScreen` - Visual map editor

### Key Concepts

- **Nodes**: Navigation waypoints with connections
- **Beacons**: BLE devices for positioning
- **Connections**: Links between nodes (one-way/bidirectional)
- **Routes**: Pre-configured navigation paths
- **Floors**: Multi-floor building support

---

## Version History

| Version | Changes |
|---------|---------|
| 1.0.0 | Initial release with core navigation features |
| 1.1.0 | Added one-way connection support |
| 1.2.0 | Added Base64 image storage for Firebase |
| 1.3.0 | Added refresh button and improved beacon reload |

---

## Support

- **GitHub**: https://github.com/abdallaS117/navigation_with_beacons
- **Issues**: https://github.com/abdallaS117/navigation_with_beacons/issues
