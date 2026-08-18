import 'package:flutter/material.dart';
import '../models/escalation_level.dart';

class _C {
  static const bg = Colors.white;
  static const searchBg = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF1D4ED8);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
}

class AgentSelector extends StatefulWidget {
  final EscalationLevel level;
  final Function(String?) onSelected;
  const AgentSelector({Key? key, required this.level, required this.onSelected}) : super(key: key);
  @override State<AgentSelector> createState() => _AgentSelectorState();
}

class _AgentSelectorState extends State<AgentSelector> {
  String? _selectedAgentId;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _selectedAgentId,
      style: const TextStyle(fontSize: 13, color: _C.textMain, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: 'Choisir un agent',
        labelStyle: const TextStyle(color: _C.textMuted, fontSize: 12),
        filled: true,
        fillColor: _C.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.primary, width: 1.2)),
      ),
      dropdownColor: _C.bg,
      icon: const Icon(Icons.expand_more_rounded, color: _C.textMuted, size: 20),
      items: const [
        DropdownMenuItem(value: 'agent1', child: Text('Agent Senior 1', style: TextStyle(fontSize: 13))),
        DropdownMenuItem(value: 'agent2', child: Text('Agent Senior 2', style: TextStyle(fontSize: 13))),
        DropdownMenuItem(value: 'agent3', child: Text('Agent Senior 3', style: TextStyle(fontSize: 13))),
      ],
      onChanged: (value) { setState(() => _selectedAgentId = value); widget.onSelected(value); },
      validator: (value) => value == null ? 'Veuillez sélectionner un agent' : null,
    );
  }
}
