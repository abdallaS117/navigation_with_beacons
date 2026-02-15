import 'package:flutter/material.dart';

class AddFloorDialog extends StatefulWidget {
  final int floorNumber;

  const AddFloorDialog({super.key, required this.floorNumber});

  @override
  State<AddFloorDialog> createState() => _AddFloorDialogState();
}

class _AddFloorDialogState extends State<AddFloorDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Floor ${widget.floorNumber}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Floor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Floor Number: ${widget.floorNumber}'),
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
          child: const Text('Add'),
        ),
      ],
    );
  }
}
