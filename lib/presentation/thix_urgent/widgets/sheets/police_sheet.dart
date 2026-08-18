// lib/presentation/thix_urgent/widgets/sheets/police_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/urgent_controller.dart';

class PoliceSheet extends StatelessWidget {
  const PoliceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(color: Color(0xFF1A1D24), borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        const Text('POLICE / AUTORITÉ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 16),
        _item(context, Icons.local_police_rounded, 'Besoin Police immédiate'),
        _item(context, Icons.security_rounded, 'Besoin Gendarmerie / Militaire'),
        _item(context, Icons.person_search_rounded, 'Personne suspecte / Voleur'),
        _item(context, Icons.volume_up_rounded, 'Tapage / Trouble à l\'ordre'),
      ]),
    );
  }

  Widget _item(BuildContext ctx, IconData icon, String label) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.blue, size: 18)),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      onTap: () {
        ctx.read<UrgentController>().selectType(EmergencyType.police);
        Navigator.pop(ctx);
      },
    );
  }
}
