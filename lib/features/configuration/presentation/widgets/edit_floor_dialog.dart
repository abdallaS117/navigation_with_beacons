import 'package:flutter/material.dart';
import '../../domain/models/models.dart';

class EditFloorDialog extends StatefulWidget {
  final FloorConfig floor;

  const EditFloorDialog({super.key, required this.floor});

  @override
  State<EditFloorDialog> createState() => _EditFloorDialogState();
}

class _EditFloorDialogState extends State<EditFloorDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.floor.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Floor Name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Floor Number: ${widget.floor.floorNumber}'),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Floor Name',
              hintText: 'e.g., Ground Floor, First Floor',
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isEmpty) return;
            Navigator.pop(context, _nameController.text);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
