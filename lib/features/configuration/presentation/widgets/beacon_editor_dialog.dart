import 'package:flutter/material.dart';
import '../../domain/models/models.dart';

class BeaconEditorDialog extends StatefulWidget {
  final ConfigurableBeacon? beacon;

  const BeaconEditorDialog({super.key, this.beacon});

  @override
  State<BeaconEditorDialog> createState() => _BeaconEditorDialogState();
}

class _BeaconEditorDialogState extends State<BeaconEditorDialog> {
  late TextEditingController _idController;
  late TextEditingController _uuidController;
  late TextEditingController _nameController;
  late TextEditingController _majorController;
  late TextEditingController _minorController;
  late TextEditingController _txPowerController;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(
      text: widget.beacon?.id ?? 'beacon_${DateTime.now().millisecondsSinceEpoch}',
    );
    _uuidController = TextEditingController(text: widget.beacon?.uuid ?? '');
    _nameController = TextEditingController(text: widget.beacon?.name ?? '');
    _majorController = TextEditingController(
      text: widget.beacon?.major?.toString() ?? '',
    );
    _minorController = TextEditingController(
      text: widget.beacon?.minor?.toString() ?? '',
    );
    _txPowerController = TextEditingController(
      text: (widget.beacon?.txPower ?? -59.0).toString(),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _uuidController.dispose();
    _nameController.dispose();
    _majorController.dispose();
    _minorController.dispose();
    _txPowerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.beacon == null ? 'Add Beacon' : 'Edit Beacon'),
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
              enabled: widget.beacon == null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _uuidController,
              decoration: const InputDecoration(
                labelText: 'UUID',
                hintText: 'e.g., E2C56DB5-DFFB-48D2-B060-D0F5A71096E1',
              ),
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
                    controller: _majorController,
                    decoration: const InputDecoration(labelText: 'Major'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _minorController,
                    decoration: const InputDecoration(labelText: 'Minor'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _txPowerController,
              decoration: const InputDecoration(
                labelText: 'TX Power (dBm)',
                hintText: 'e.g., -59',
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
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
    if (_idController.text.isEmpty || _uuidController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID, UUID, and Name are required')),
      );
      return;
    }

    final beacon = ConfigurableBeacon(
      id: _idController.text,
      uuid: _uuidController.text.toUpperCase(),
      name: _nameController.text,
      major: int.tryParse(_majorController.text),
      minor: int.tryParse(_minorController.text),
      txPower: double.tryParse(_txPowerController.text) ?? -59.0,
      x: widget.beacon?.x,
      y: widget.beacon?.y,
      floor: widget.beacon?.floor,
      isPlaced: widget.beacon?.isPlaced ?? false,
      linkedNodeId: widget.beacon?.linkedNodeId,
      metadata: widget.beacon?.metadata ?? {},
    );

    Navigator.pop(context, beacon);
  }
}
