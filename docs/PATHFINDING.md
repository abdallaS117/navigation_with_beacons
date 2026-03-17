# Pathfinding & Route Calculation

## Overview

This document explains how the navigation system calculates routes between nodes, including the algorithms used, one-way restriction handling, and multi-floor navigation.

---

## Route Calculation Flow

```
calculateRoute(start, end)
         │
         ▼
┌─────────────────────────────────┐
│  1. _tryPreConfiguredRoutes()   │
│     - Check 1: Both in route    │
│     - Check 2: Dest is last     │
│     - Check 3: Extract segment  │
└─────────────┬───────────────────┘
              │ (if not found)
              ▼
┌─────────────────────────────────┐
│  2. Check floor difference      │
│     - Same floor → Step 3       │
│     - Different → Step 4        │
└─────────────┬───────────────────┘
              │
    ┌─────────┴─────────┐
    ▼                   ▼
┌───────────────┐  ┌───────────────┐
│ 3. Same Floor │  │ 4. Multi-Floor│
│    Route      │  │    Route      │
└───────────────┘  └───────────────┘
```

---

## Pre-Configured Routes

The system first checks if a pre-configured route can be used.

### Check 1: Both Nodes in Same Route

```dart
for (final route in config.routes) {
  final startIndex = nodeIds.indexOf(start.uid);
  final endIndex = nodeIds.indexOf(end.uid);
  
  if (startIndex != -1 && endIndex != -1) {
    // Both nodes exist in this route
    if (startIndex < endIndex) {
      // Forward direction - extract segment
      pathNodeIds = nodeIds.sublist(startIndex, endIndex + 1);
    } else {
      // Reverse direction - validate one-way restrictions
      pathNodeIds = nodeIds.sublist(endIndex, startIndex + 1).reversed;
      // Validate each connection allows reverse traversal
    }
  }
}
```

### Check 2: Destination is Last Node

```dart
if (nodeIds.last == end.uid) {
  final startIndex = nodeIds.indexOf(start.uid);
  if (startIndex != -1) {
    pathNodeIds = nodeIds.sublist(startIndex);
    // Validate one-way restrictions
    if (_validatePathConnections(pathNodeIds, configurableNodeMap)) {
      return route;
    }
  }
}
```

### Check 3: Both Nodes Exist, Extract Segment

```dart
if (startIndex != -1 && endIndex != -1 && startIndex < endIndex) {
  pathNodeIds = nodeIds.sublist(startIndex, endIndex + 1);
  // Validate one-way restrictions
  if (_validatePathConnections(pathNodeIds, configurableNodeMap)) {
    return route;
  }
}
```

---

## Dijkstra's Algorithm

When no pre-configured route is found, Dijkstra's algorithm calculates the optimal path.

### Algorithm Implementation

```dart
static List<BeaconNode> dijkstraWithConfig(
  BeaconNode start,
  BeaconNode end,
  List<BeaconNode> allBeacons,
  Map<String, ConfigurableNode> configurableNodeMap,
) {
  // Initialize distances
  Map<String, double> distances = {};
  Map<String, String?> previous = {};
  Set<String> visited = {};
  PriorityQueue<NodeDistance> queue = PriorityQueue();
  
  for (final beacon in allBeacons) {
    distances[beacon.uid] = double.infinity;
  }
  distances[start.uid] = 0;
  queue.add(NodeDistance(start.uid, 0));
  
  while (queue.isNotEmpty) {
    final current = queue.removeFirst();
    
    if (visited.contains(current.uid)) continue;
    visited.add(current.uid);
    
    if (current.uid == end.uid) break;
    
    // Get valid neighbors (respecting one-way restrictions)
    final neighbors = _getValidNeighbors(current.uid, configurableNodeMap);
    
    for (final neighborUid in neighbors) {
      final distance = calculateDistance(current, neighbor);
      final newDist = distances[current.uid]! + distance;
      
      if (newDist < distances[neighborUid]!) {
        distances[neighborUid] = newDist;
        previous[neighborUid] = current.uid;
        queue.add(NodeDistance(neighborUid, newDist));
      }
    }
  }
  
  return _reconstructPath(end.uid, start.uid, previous, allBeacons);
}
```

### Valid Neighbors Logic

The key to respecting one-way restrictions is in `_getValidNeighbors`:

```dart
static Set<String> _getValidNeighbors(
  String currentUid,
  Map<String, ConfigurableNode> configurableNodeMap,
) {
  final validNeighborIds = <String>{};
  final currentNode = configurableNodeMap[currentUid];
  
  // 1. Add all DIRECT OUTGOING connections
  //    (connections defined FROM this node)
  for (final conn in currentNode?.connections ?? []) {
    validNeighborIds.add(conn.targetNodeId);
  }
  
  // 2. Add INCOMING connections ONLY if bidirectional
  //    (connections defined TO this node that allow reverse travel)
  for (final otherNode in configurableNodeMap.values) {
    for (final conn in otherNode.connections) {
      if (conn.targetNodeId == currentUid && conn.isBidirectional) {
        validNeighborIds.add(otherNode.id);
      }
    }
  }
  
  return validNeighborIds;
}
```

### Example

```
Node A ──────► Node B (one-way)
       
Node C ◄─────► Node D (bidirectional)
```

From Node B:
- Direct outgoing: none to A
- Incoming bidirectional: A→B is NOT bidirectional
- **Valid neighbors: none** (cannot go back to A)

From Node D:
- Direct outgoing: none
- Incoming bidirectional: C→D IS bidirectional
- **Valid neighbors: [C]** (can go back to C)

---

## One-Way Restriction Validation

### Path Validation

```dart
bool _validatePathConnections(
  List<String> pathNodeIds,
  Map<String, ConfigurableNode> configurableNodeMap,
) {
  for (int i = 0; i < pathNodeIds.length - 1; i++) {
    final fromId = pathNodeIds[i];
    final toId = pathNodeIds[i + 1];
    final fromNode = configurableNodeMap[fromId];

    // Check direct outgoing connection
    final hasDirectConnection = fromNode?.connections
        .any((c) => c.targetNodeId == toId) ?? false;
    
    // Check incoming bidirectional connection
    final hasIncomingBidirectional = configurableNodeMap[toId]?.connections
        .any((c) => c.targetNodeId == fromId && c.isBidirectional) ?? false;

    if (!hasDirectConnection && !hasIncomingBidirectional) {
      return false;  // Path is blocked
    }
  }
  return true;  // Path is valid
}
```

### Reachability Check

```dart
static String? checkOneWayRestriction(
  BeaconNode start,
  BeaconNode end,
  Map<String, ConfigurableNode> configurableNodeMap,
) {
  final canReachEndFromStart = _canReachNode(
    start.uid, end.uid, configurableNodeMap, <String>{},
  );

  if (!canReachEndFromStart) {
    final canReachStartFromEnd = _canReachNode(
      end.uid, start.uid, configurableNodeMap, <String>{},
    );

    if (canReachStartFromEnd) {
      // Route exists only in reverse direction
      return 'Cannot navigate to ${end.name}. Route is one-way in opposite direction.';
    }
  }

  return null;  // No restriction
}
```

---

## Multi-Floor Navigation

### Floor Transition Detection

```dart
static List<Map<String, BeaconNode>> findFloorTransitions(
  int startFloor,
  int endFloor,
  List<BeaconNode> allNodes,
  Map<String, ConfigurableNode> configurableNodeMap,
) {
  final transitions = <Map<String, BeaconNode>>[];
  
  // Find nodes that connect floors (stairs, elevators)
  for (final node in configurableNodeMap.values) {
    if (node.floor == startFloor && 
        (node.type == NodeType.stairs || node.type == NodeType.elevator)) {
      
      // Find connected node on target floor
      for (final conn in node.connections) {
        final targetNode = configurableNodeMap[conn.targetNodeId];
        if (targetNode?.floor == endFloor) {
          transitions.add({
            'startNode': nodeMap[node.id]!,
            'endNode': nodeMap[targetNode!.id]!,
          });
        }
      }
    }
  }
  
  return transitions;
}
```

### Multi-Floor Route Calculation

```dart
NavigationRoute _calculateMultiFloorRoute(
  BeaconNode start,
  BeaconNode end,
  config,
  Map<String, BeaconNode> nodeMap,
  Map<String, ConfigurableNode> configurableNodeMap,
) {
  final transitionPoints = FloorTransitionHelper.findFloorTransitions(
    start.floor, end.floor, nodeMap.values.toList(), configurableNodeMap,
  );

  NavigationRoute? bestRoute;
  double bestDistance = double.infinity;

  for (final transition in transitionPoints) {
    final startTransition = transition['startNode']!;
    final endTransition = transition['endNode']!;

    // Path from start to transition point
    final pathToTransition = PathfindingHelper.findPathOnFloor(
      start, startTransition, allNodes, configurableNodeMap,
    );

    // Path from transition point to destination
    final pathFromTransition = PathfindingHelper.findPathOnFloor(
      endTransition, end, allNodes, configurableNodeMap,
    );

    if (pathToTransition.isNotEmpty && pathFromTransition.isNotEmpty) {
      // Combine paths
      final combinedPath = [...pathToTransition, ...pathFromTransition.skip(1)];
      final totalDistance = calculateTotalDistance(combinedPath);

      if (totalDistance < bestDistance) {
        bestDistance = totalDistance;
        bestRoute = _buildNavigationRoute(combinedPath);
      }
    }
  }

  return bestRoute ?? NavigationRoute.empty();
}
```

---

## Distance Calculation

### Euclidean Distance

```dart
static double calculateDistance(BeaconNode a, BeaconNode b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  return sqrt(dx * dx + dy * dy);
}
```

### Total Path Distance

```dart
static double calculateTotalDistance(List<BeaconNode> path) {
  double total = 0;
  for (int i = 0; i < path.length - 1; i++) {
    total += calculateDistance(path[i], path[i + 1]);
  }
  return total;
}
```

---

## Error Handling

### No Route Found

```dart
return const NavigationRoute(
  nodes: [],
  totalDistance: 0,
  estimatedTimeSeconds: 0,
  instructions: ['No route found to destination.'],
);
```

### One-Way Blocked

```dart
return NavigationRoute(
  nodes: const [],
  totalDistance: 0,
  estimatedTimeSeconds: 0,
  instructions: [oneWayBlockReason],  // e.g., "Route is one-way in opposite direction"
);
```

### No Transition Points

```dart
return const NavigationRoute(
  nodes: [],
  totalDistance: 0,
  estimatedTimeSeconds: 0,
  instructions: ['No route allowed for this destination.'],
);
```

---

## Instruction Generation

```dart
static List<String> generateInstructions(List<BeaconNode> path) {
  final instructions = <String>[];
  
  if (path.isEmpty) return instructions;
  
  instructions.add('Start at ${path.first.name}');
  
  for (int i = 1; i < path.length - 1; i++) {
    final prev = path[i - 1];
    final curr = path[i];
    final next = path[i + 1];
    
    // Calculate turn direction
    final direction = _calculateTurnDirection(prev, curr, next);
    
    if (curr.departmentId == 'stairs') {
      instructions.add('Take the stairs to Floor ${next.floor}');
    } else if (curr.departmentId == 'elevator') {
      instructions.add('Take the elevator to Floor ${next.floor}');
    } else if (direction != 'straight') {
      instructions.add('Turn $direction at ${curr.name}');
    } else {
      instructions.add('Continue to ${curr.name}');
    }
  }
  
  instructions.add('You have arrived at ${path.last.name}');
  
  return instructions;
}
```
