import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../controllers/urgent_controller.dart';

class ChambreDeCriseScreen extends StatelessWidget {
  final String criseId;
  final EmergencyType type;
  const ChambreDeCriseScreen({super.key, required this.criseId, required this.type});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<UrgentController>();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('CHAMBRE DE CRISE • ${type.name.toUpperCase()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: ()=> context.pop()),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.shield, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Alerte active: $criseId', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                const Text('Gardiens connectés: 3 en ligne', style: TextStyle(color: Colors.white38, fontSize: 10)),
              ])),
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            ]),
          ),
          Expanded(
            child: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_rounded, size: 60, color: Colors.white24),
                SizedBox(height: 16),
                Text('Salon sécurisé THIX CHAT', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Tes gardiens + Police reçoivent ta position live', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  // Annuler alerte
                  await ctrl.supabase.from('emergency_alerts').update({'status': 'annule', 'resolved_at': DateTime.now().toIso8601String()}).eq('id', criseId);
                  if(context.mounted) context.go('/thix-urgent');
                },
                child: const Text('ANNULER L\'ALERTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
