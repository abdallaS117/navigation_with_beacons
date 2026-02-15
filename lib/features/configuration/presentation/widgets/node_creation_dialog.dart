import 'package:flutter/material.dart';
import '../../domain/models/models.dart';

class NodeCreationDialog extends StatefulWidget {
  final double x;
  final double y;
  final int floor;
  final List<ConfigurableBeacon> beacons;

  const NodeCreationDialog({
    super.key,
    required this.x,
    required this.y,
    required this.floor,
    this.beacons = const [],
  });

  @override
  State<NodeCreationDialog> createState() => _NodeCreationDialogState();
}

class _NodeCreationDialogState extends State<NodeCreationDialog> {
  late TextEditingController _nameController;
  NodeType _selectedType = NodeType.waypoint;
  String? _selectedBeaconId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Node ${DateTime.now().millisecondsSinceEpoch}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _getNodeTypeLabel(NodeType type) {
    switch (type) {
      case NodeType.waypoint:
        return 'Waypoint';
      case NodeType.department:
        return 'Department';
      case NodeType.entrance:
        return 'Entrance';
      case NodeType.elevator:
        return 'Elevator';
      case NodeType.stairs:
        return 'Stairs';
      case NodeType.beacon:
        return 'Beacon';
    }
  }

  IconData _getNodeTypeIcon(NodeType type) {
    switch (type) {
      case NodeType.waypoint:
        return Icons.location_on;
      case NodeType.department:
        return Icons.business;
      case NodeType.entrance:
        return Icons.door_front_door;
      case NodeType.elevator:
        return Icons.elevator;
      case NodeType.stairs:
        return Icons.stairs;
      case NodeType.beacon:
        return Icons.bluetooth;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Node'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Position: (${widget.x.toStringAsFixed(0)}, ${widget.y.toStringAsFixed(0)})'),
            Text('Floor: ${widget.floor}'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Node Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text('Node Type', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...NodeType.values.map((type) {
              return RadioListTile<NodeType>(
                value: type,
                groupValue: _selectedType,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },
                title: Row(
                  children: [
                    Icon(_getNodeTypeIcon(type), size: 20),
                    const SizedBox(width: 8),
                    Text(_getNodeTypeLabel(type)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text('Assign Beacon (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedBeaconId,
              decoration: const InputDecoration(
                labelText: 'Select Beacon',
                border: OutlineInputBorder(),
                hintText: 'None',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('None'),
                ),
                ...widget.beacons.map((beacon) {
                  final identifier = beacon.major != null && beacon.minor != null
                      ? '${beacon.major}:${beacon.minor}'
                      : beacon.uuid.substring(0, 8);
                  return DropdownMenuItem<String>(
                    value: beacon.id,
                    child: Text('${beacon.name} ($identifier)'),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedBeaconId = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isEmpty) return;
            Navigator.pop(context, {
              'name': _nameController.text,
              'type': _selectedType,
              'linkedBeaconId': _selectedBeaconId,
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
