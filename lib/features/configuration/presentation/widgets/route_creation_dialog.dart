import 'package:flutter/material.dart';
import '../../domain/models/models.dart';

class RouteCreationDialog extends StatefulWidget {
  final List<String> nodeIds;
  final List<ConfigurableNode> allNodes;
  final RouteConfig? existingRoute;

  const RouteCreationDialog({
    super.key,
    required this.nodeIds,
    required this.allNodes,
    this.existingRoute,
  });

  @override
  State<RouteCreationDialog> createState() => _RouteCreationDialogState();
}

class _RouteCreationDialogState extends State<RouteCreationDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  RouteType _selectedType = RouteType.normal;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingRoute?.name ?? '');
    _descriptionController = TextEditingController(text: widget.existingRoute?.description ?? '');
    _selectedType = widget.existingRoute?.type ?? RouteType.normal;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _getRouteTypeLabel(RouteType type) {
    switch (type) {
      case RouteType.normal:
        return 'Normal';
      case RouteType.accessible:
        return 'Accessible';
      case RouteType.emergency:
        return 'Emergency';
      case RouteType.restricted:
        return 'Restricted';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRoute != null;
    
    return AlertDialog(
      title: Text(isEditing ? 'Update Route' : 'Save Route'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nodes in route: ${widget.nodeIds.length}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.nodeIds.map((nodeId) {
                  final node = widget.allNodes.firstWhere(
                    (n) => n.id == nodeId,
                    orElse: () => ConfigurableNode(
                      id: nodeId,
                      name: 'Unknown',
                      x: 0,
                      y: 0,
                      floor: 1,
                    ),
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('→ ${node.name}'),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Route Name *',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            const Text('Route Type', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<RouteType>(
              value: _selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: RouteType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getRouteTypeLabel(type)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
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
              'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
              'type': _selectedType,
            });
          },
          child: Text(isEditing ? 'Update Route' : 'Save Route'),
        ),
      ],
    );
  }
}
