import 'package:flutter/material.dart';
import '../../domain/models/models.dart';

/// Dialog for configuring map settings (name, dimensions, scale).
class MapSettingsDialog extends StatefulWidget {
  final MapLayoutConfig? config;

  const MapSettingsDialog({super.key, this.config});

  @override
  State<MapSettingsDialog> createState() => _MapSettingsDialogState();
}

class _MapSettingsDialogState extends State<MapSettingsDialog> {
  late TextEditingController _nameController;
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late TextEditingController _scaleController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.config?.name ?? 'Hospital Layout');
    _widthController = TextEditingController(text: (widget.config?.width ?? 800).toString());
    _heightController = TextEditingController(text: (widget.config?.height ?? 600).toString());
    _scaleController = TextEditingController(text: (widget.config?.scale ?? 1.0).toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Map Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Map Name'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _widthController,
                  decoration: const InputDecoration(labelText: 'Width'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _heightController,
                  decoration: const InputDecoration(labelText: 'Height'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _scaleController,
            decoration: const InputDecoration(labelText: 'Scale'),
            keyboardType: TextInputType.number,
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
            Navigator.pop(context, MapLayoutConfig(
              id: widget.config?.id ?? 'default_map',
              name: _nameController.text,
              width: double.tryParse(_widthController.text) ?? 800,
              height: double.tryParse(_heightController.text) ?? 600,
              scale: double.tryParse(_scaleController.text) ?? 1.0,
              floors: widget.config?.floors ?? [],
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
