// lib/presentation/thix_urgent/widgets/sheets/agression_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/urgent_controller.dart';

class AgressionSheet extends StatelessWidget {
  const AgressionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(color: Color(0xFF1A1D24), borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        const Text('AGRESSION / INSÉCURITÉ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 16),
        _item(context, Icons.backpack_rounded, 'Vol à l\'arraché / Téléphone'),
        _item(context, Icons.sports_mma_rounded, 'Agression physique / Bagarre'),
        _item(context, Icons.home_rounded, 'Cambriolage en cours'),
        _item(context, Icons.woman_rounded, 'Femme en danger / Violence'),
        _item(context, Icons.child_care_rounded, 'Enfant en danger / Kidnapping'),
      ]),
    );
  }

  Widget _item(BuildContext ctx, IconData icon, String label) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.red, size: 18)),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      onTap: () {
        ctx.read<UrgentController>().selectType(EmergencyType.personne);
        Navigator.pop(ctx);
      },
    );
  }
}
