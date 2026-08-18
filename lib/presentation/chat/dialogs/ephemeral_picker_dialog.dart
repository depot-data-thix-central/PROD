// lib/presentation/chat/dialogs/ephemeral_picker_dialog.dart
import 'package:flutter/material.dart';

class EphemeralPickerDialog extends StatefulWidget {
  final int? initialDuration; // durée en secondes

  const EphemeralPickerDialog({super.key, this.initialDuration});

  @override
  State<EphemeralPickerDialog> createState() => _EphemeralPickerDialogState();
}

class _EphemeralPickerDialogState extends State<EphemeralPickerDialog> {
  int? _selectedDuration;
  final TextEditingController _customController = TextEditingController();
  bool _useCustom = false;

  final List<Map<String, dynamic>> _presets = const [
    {'label': '30 secondes', 'value': 30},
    {'label': '1 minute', 'value': 60},
    {'label': '5 minutes', 'value': 300},
    {'label': '15 minutes', 'value': 900},
    {'label': '30 minutes', 'value': 1800},
    {'label': '1 heure', 'value': 3600},
    {'label': '6 heures', 'value': 21600},
    {'label': '12 heures', 'value': 43200},
    {'label': '24 heures', 'value': 86400},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.initialDuration;
    if (_selectedDuration != null) {
      final match = _presets.firstWhere(
        (p) => p['value'] == _selectedDuration,
        orElse: () => {'value': -1},
      );
      if (match['value'] == -1) {
        _useCustom = true;
        _customController.text = _selectedDuration.toString();
      }
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Icon(Icons.timer, color: Colors.orange),
          SizedBox(width: 8),
          Text('Auto-destruction'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choisissez la durée avant suppression :',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            ..._presets.map((preset) => RadioListTile<int>(
              title: Text(preset['label']),
              value: preset['value'],
              groupValue: _useCustom ? null : _selectedDuration,
              onChanged: (value) {
                setState(() {
                  _selectedDuration = value;
                  _useCustom = false;
                });
              },
              activeColor: const Color(0xFFD4AF37),
              contentPadding: EdgeInsets.zero,
            )).toList(),
            const Divider(),
            SwitchListTile(
              title: const Text('Durée personnalisée'),
              value: _useCustom,
              onChanged: (value) {
                setState(() {
                  _useCustom = value;
                  if (value) {
                    _selectedDuration = null;
                  } else {
                    _customController.clear();
                  }
                });
              },
              activeColor: const Color(0xFFD4AF37),
              contentPadding: EdgeInsets.zero,
            ),
            if (_useCustom)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Durée en secondes',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) {
                    final int? parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      _selectedDuration = parsed;
                    }
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedDuration != null && _selectedDuration! > 0) {
              Navigator.pop(context, _selectedDuration);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Veuillez sélectionner une durée valide'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}

/// Fonction utilitaire pour afficher le dialogue et obtenir la durée en secondes
Future<int?> showEphemeralPickerDialog(BuildContext context, {int? initialDuration}) {
  return showDialog<int>(
    context: context,
    builder: (context) => EphemeralPickerDialog(initialDuration: initialDuration),
  );
}
