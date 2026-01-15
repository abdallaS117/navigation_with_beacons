import 'package:flutter/material.dart';
import '../../domain/models/models.dart';

class ConnectionDialog extends StatefulWidget {
  final String fromNodeId;
  final List<ConfigurableNode> availableNodes;
  final NodeConnection? existingConnection;

  const ConnectionDialog({
    super.key,
    required this.fromNodeId,
    required this.availableNodes,
    this.existingConnection,
  });

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  String? _targetNodeId;
  late TextEditingController _weightController;
  bool _bidirectional = true;
  ConnectionType _connectionType = ConnectionType.normal;

  @override
  void initState() {
    super.initState();
    _targetNodeId = widget.existingConnection?.targetNodeId;
    _weightController = TextEditingController(
      text: widget.existingConnection?.weight?.toString() ?? '',
    );
    _bidirectional = widget.existingConnection?.isBidirectional ?? true;
    _connectionType = widget.existingConnection?.type ?? ConnectionType.normal;
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetNodes = widget.availableNodes
        .where((n) => n.id != widget.fromNodeId)
        .toList();

    return AlertDialog(
      title: Text(widget.existingConnection == null ? 'Add Connection' : 'Edit Connection'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _targetNodeId,
              decoration: const InputDecoration(labelText: 'Target Node'),
              items: targetNodes.map((node) {
                return DropdownMenuItem(
                  value: node.id,
                  child: Text('${node.name} (${node.id})'),
                );
              }).toList(),
              onChanged: widget.existingConnection == null
                  ? (value) => setState(() => _targetNodeId = value)
                  : null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Weight (optional)',
                hintText: 'Distance or cost',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ConnectionType>(
              value: _connectionType,
              decoration: const InputDecoration(labelText: 'Connection Type'),
              items: ConnectionType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(_getConnectionIcon(type), size: 20),
                      const SizedBox(width: 8),
                      Text(type.name.toUpperCase()),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _connectionType = value);
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Bidirectional'),
              subtitle: const Text('Connection works both ways'),
              value: _bidirectional,
              onChanged: (value) => setState(() => _bidirectional = value),
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

  IconData _getConnectionIcon(ConnectionType type) {
    switch (type) {
      case ConnectionType.stairs:
        return Icons.stairs;
      case ConnectionType.elevator:
        return Icons.elevator;
      case ConnectionType.restricted:
        return Icons.lock;
      case ConnectionType.normal:
      default:
        return Icons.arrow_forward;
    }
  }

  void _save() {
    if (_targetNodeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target node')),
      );
      return;
    }

    final result = {
      'targetNodeId': _targetNodeId!,
      'weight': double.tryParse(_weightController.text),
      'bidirectional': _bidirectional,
      'type': _connectionType,
    };

    Navigator.pop(context, result);
  }
}
