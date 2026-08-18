// lib/presentation/thix_urgent/widgets/sheets/denoncer_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/urgent_controller.dart';

class DenoncerSheet extends StatelessWidget {
  const DenoncerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1D24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.visibility_off_rounded, color: Colors.green, size: 16)),
              const SizedBox(width: 10),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('DÉNONCER - Anonyme', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                Text('Ton identité ne sera jamais révélée', style: TextStyle(color: Colors.white54, fontSize: 10)),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          _item(context, Icons.money_off_rounded, 'Corruption / Barrage abusif'),
          _item(context, Icons.local_drink_rounded, 'Drogue / Gang / Fumette'),
          _item(context, Icons.warning_amber_rounded, 'Route dangereuse / Nid de poule'),
          _item(context, Icons.bolt_rounded, 'Danger public / Poteau / Incendie'),
          _item(context, Icons.gavel_rounded, 'Injustice / Abus autorité'),
        ],
      ),
    );
  }

  Widget _item(BuildContext ctx, IconData icon, String label) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.white70, size: 18)),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
      onTap: () {
        ctx.read<UrgentController>().selectType(EmergencyType.denoncer);
        Navigator.pop(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Signalement anonyme: $label prêt à envoyer')));
      },
    );
  }
}
