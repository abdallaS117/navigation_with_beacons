import 'package:flutter/material.dart';
import '../../domain/models/models.dart';

class NodeEditorDialog extends StatefulWidget {
  final ConfigurableNode? node;
  final double? initialX;
  final double? initialY;
  final int floor;
  final List<ConfigurableBeacon> availableBeacons;

  const NodeEditorDialog({
    super.key,
    this.node,
    this.initialX,
    this.initialY,
    required this.floor,
    required this.availableBeacons,
  });

  @override
  State<NodeEditorDialog> createState() => _NodeEditorDialogState();
}

class _NodeEditorDialogState extends State<NodeEditorDialog> {
  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _xController;
  late TextEditingController _yController;
  late TextEditingController _departmentIdController;
  NodeType _selectedType = NodeType.waypoint;
  String? _linkedBeaconId;
  bool _isNavigable = true;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(
      text: widget.node?.id ?? 'node_${DateTime.now().millisecondsSinceEpoch}',
    );
    _nameController = TextEditingController(text: widget.node?.name ?? '');
    _xController = TextEditingController(
      text: (widget.node?.x ?? widget.initialX ?? 0).toStringAsFixed(0),
    );
    _yController = TextEditingController(
      text: (widget.node?.y ?? widget.initialY ?? 0).toStringAsFixed(0),
    );
    _departmentIdController = TextEditingController(text: widget.node?.departmentId ?? '');
    _selectedType = widget.node?.type ?? NodeType.waypoint;
    _linkedBeaconId = widget.node?.linkedBeaconId;
    _isNavigable = widget.node?.isNavigable ?? true;
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _xController.dispose();
    _yController.dispose();
    _departmentIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.node == null ? 'Add Node' : 'Edit Node'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'ID',
                hintText: 'Unique identifier',
              ),
              enabled: widget.node == null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Display name',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _xController,
                    decoration: const InputDecoration(labelText: 'X'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _yController,
                    decoration: const InputDecoration(labelText: 'Y'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<NodeType>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: NodeType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedType = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _departmentIdController,
              decoration: const InputDecoration(
                labelText: 'Department ID (optional)',
                hintText: 'Link to department',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              value: _linkedBeaconId,
              decoration: const InputDecoration(labelText: 'Linked Beacon (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...widget.availableBeacons.map((beacon) {
                  return DropdownMenuItem(
                    value: beacon.id,
                    child: Text(beacon.name),
                  );
                }),
              ],
              onChanged: (value) => setState(() => _linkedBeaconId = value),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Navigable'),
              value: _isNavigable,
              onChanged: (value) => setState(() => _isNavigable = value),
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
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (_idController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID and Name are required')),
      );
      return;
    }

    final node = ConfigurableNode(
      id: _idController.text,
      name: _nameController.text,
      x: double.tryParse(_xController.text) ?? 0,
      y: double.tryParse(_yController.text) ?? 0,
      floor: widget.floor,
      type: _selectedType,
      departmentId: _departmentIdController.text.isEmpty ? null : _departmentIdController.text,
      linkedBeaconId: _linkedBeaconId,
      connections: widget.node?.connections ?? [],
      isNavigable: _isNavigable,
    );

    Navigator.pop(context, node);
  }
}
