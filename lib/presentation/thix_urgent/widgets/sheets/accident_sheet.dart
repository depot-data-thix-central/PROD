// lib/presentation/thix_urgent/widgets/sheets/accident_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/urgent_controller.dart';

class AccidentSheet extends StatelessWidget {
  const AccidentSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(color: Color(0xFF1A1D24), borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        const Text('ACCIDENT / SECOURS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 16),
        _item(context, Icons.car_crash_rounded, 'Accident de route', 'Voiture, moto, piéton'),
        _item(context, Icons.local_fire_department_rounded, 'Incendie', 'Maison, voiture, brousse'),
        _item(context, Icons.personal_injury_rounded, 'Malaise / Blessure grave', 'Besoin ambulance'),
        _item(context, Icons.water_drop_rounded, 'Inondation / Éboulement', 'Route coupée'),
      ]),
    );
  }

  Widget _item(BuildContext ctx, IconData icon, String title, String sub) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.orange, size: 18)),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      onTap: () {
        ctx.read<UrgentController>().selectType(EmergencyType.accident);
        Navigator.pop(ctx);
      },
    );
  }
}
