import 'package:flutter/material.dart';
import '../../domain/models/models.dart';

/// Dialog for configuring connection direction and type between nodes.
class ConnectionConfigDialog extends StatefulWidget {
  final String fromNodeName;
  final String toNodeName;
  final String fromNodeId;
  final String toNodeId;
  final NodeConnection currentConnection;
  final Function(String direction, ConnectionType type) onSave;

  const ConnectionConfigDialog({
    super.key,
    required this.fromNodeName,
    required this.toNodeName,
    required this.fromNodeId,
    required this.toNodeId,
    required this.currentConnection,
    required this.onSave,
  });

  @override
  State<ConnectionConfigDialog> createState() => _ConnectionConfigDialogState();
}

class _ConnectionConfigDialogState extends State<ConnectionConfigDialog> {
  late String _direction;
  late ConnectionType _type;

  @override
  void initState() {
    super.initState();
    _direction = widget.currentConnection.isBidirectional ? 'two-way' : 'one-way-forward';
    _type = widget.currentConnection.type;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure Connection'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.fromNodeName} ↔ ${widget.toNodeName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Direction:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            _buildDirectionOption(
              'two-way',
              'Two-way (Bidirectional)',
              Icons.swap_horiz,
              Colors.blue,
            ),
            _buildDirectionOption(
              'one-way-forward',
              'One-way: ${widget.fromNodeName} → ${widget.toNodeName}',
              Icons.arrow_forward,
              Colors.orange,
            ),
            _buildDirectionOption(
              'one-way-reverse',
              'One-way: ${widget.toNodeName} → ${widget.fromNodeName}',
              Icons.arrow_back,
              Colors.orange,
            ),
            _buildDirectionOption(
              'delete',
              'No connection (Delete)',
              Icons.block,
              Colors.red,
            ),
            const SizedBox(height: 16),
            const Text('Type:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            _buildTypeOption(ConnectionType.normal, 'Normal', Icons.arrow_forward),
            _buildTypeOption(ConnectionType.emergency, 'Emergency', Icons.emergency),
            _buildTypeOption(ConnectionType.staff, 'Staff Only', Icons.badge),
            _buildTypeOption(ConnectionType.stairs, 'Stairs', Icons.stairs),
            _buildTypeOption(ConnectionType.elevator, 'Elevator', Icons.elevator),
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
            Navigator.pop(context);
            widget.onSave(_direction, _type);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildDirectionOption(String value, String label, IconData icon, Color color) {
    final isSelected = _direction == value;
    return InkWell(
      onTap: () => setState(() => _direction = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color, width: 2) : Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: isSelected ? color : null))),
            if (isSelected) Icon(Icons.check, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(ConnectionType type, String label, IconData icon) {
    final isSelected = _type == type;
    return InkWell(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            if (isSelected) const Icon(Icons.check, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}
