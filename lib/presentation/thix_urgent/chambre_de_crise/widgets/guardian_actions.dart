// lib/presentation/thix_urgent/chambre_de_crise/widgets/guardian_actions.dart
import 'package:flutter/material.dart';
import '../../controllers/urgent_controller.dart';

class GuardianActions extends StatelessWidget {
  final String criseId;
  final EmergencyType type;
  const GuardianActions({super.key, required this.criseId, required this.type});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ACTIONS GARDIEN', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.5,
        children: [
          _btn(context, '📢 Sirène à distance', 'Déclenche 110db chez victime', Colors.orange, () => debugPrint('sirene $criseId')),
          _btn(context, '📹 Demander caméra', 'Active caméra arrière', Colors.blue, () {}),
          _btn(context, '🚔 Alerter Police', 'Envoi dossier + position', Colors.red, () {}),
          _btn(context, '👥 Inviter Gardien', 'Ajoute un proche au live', Colors.green, () {}),
        ],
      ),
    ]);
  }

  Widget _btn(BuildContext ctx, String title, String sub, Color c, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withOpacity(0.4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 11)), const SizedBox(height: 2), Text(sub, style: TextStyle(color: c.withOpacity(0.7), fontSize: 8))])),
    );
  }
}
