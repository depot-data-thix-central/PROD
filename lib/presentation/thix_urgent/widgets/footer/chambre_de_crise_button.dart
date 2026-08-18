// lib/presentation/thix_urgent/widgets/footer/chambre_de_crise_button.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/urgent_controller.dart';
import '../../chambre_de_crise/chambre_de_crise_screen.dart';

class ChambreDeCriseButton extends StatelessWidget {
  const ChambreDeCriseButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UrgentController>(
      builder: (_, ctrl, __) {
        final hasActiveAlert = ctrl.criseId != null || ctrl.isAlertActive;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (ctrl.selectedType != null && !hasActiveAlert)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Type sélectionné: ${ctrl.selectedType!.name.toUpperCase()} • Maintiens le bouton rouge',
                    style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasActiveAlert ? const Color(0xFFFF2D2D) : const Color(0xFF2A2D36),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: hasActiveAlert ? 8 : 0,
                    shadowColor: const Color(0xFFFF2D2D).withOpacity(0.5),
                  ),
                  onPressed: () {
                    if (ctrl.criseId == null && !ctrl.isAlertActive) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Déclenche d\'abord l\'alerte rouge pour ouvrir la Chambre de Crise')),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: ctrl,
                          child: ChambreDeCriseScreen(
                            criseId: ctrl.criseId ?? 'preview_${DateTime.now().millisecondsSinceEpoch}',
                            type: ctrl.selectedType ?? EmergencyType.police,
                          ),
                        ),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(hasActiveAlert ? Icons.headset_mic_rounded : Icons.lock_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        hasActiveAlert ? 'CHAMBRE DE CRISE - LIVE' : 'CHAMBRE DE CRISE',
                        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12),
                      ),
                      if (hasActiveAlert) ...[
                        const SizedBox(width: 8),
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Salon d\'écoute sécurisé dans THIX CHAT • Gardiens + Police',
                style: TextStyle(color: Colors.white24, fontSize: 8),
              ),
            ],
          ),
        );
      },
    );
  }
}
