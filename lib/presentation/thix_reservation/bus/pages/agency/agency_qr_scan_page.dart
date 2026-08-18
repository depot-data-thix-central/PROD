// lib/presentation/thix_reservation/bus/pages/agency/agency_qr_scan_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../providers/agency_dashboard_provider.dart';

class AgencyQrScanPage extends ConsumerStatefulWidget {
  const AgencyQrScanPage({super.key});

  @override
  ConsumerState<AgencyQrScanPage> createState() => _AgencyQrScanPageState();
}

class _AgencyQrScanPageState extends ConsumerState<AgencyQrScanPage> {
  bool _isProcessing = false;

  Future<void> _handleScan(String qrCode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // 🌟 Utilisation moderne de Riverpod
      final booking = await ref.read(agencyDashboardProvider.notifier).validateQr(qrCode);
      
      if (!mounted) return;
      if (booking != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Billet validé avec succès !'),
            backgroundColor: ThixPolicy.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket invalide ou déjà utilisé'),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: ThixPolicy.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 Écoute moderne de l'état
    final state = ref.watch(agencyDashboardProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        title: const Text(
          'Scanner un Billet (QR)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                border: Border.all(color: ThixPolicy.border),
                boxShadow: ThixPolicy.shadowCard(),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 80,
                    color: ThixPolicy.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pointez la caméra vers le QR Code du passager',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ThixPolicy.textMain),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La validation mettra à jour le statut du billet instantanément.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  if (_isProcessing || state.isLoading)
                    const CircularProgressIndicator(color: ThixPolicy.primary)
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Simulation de test ou déclenchement du scanner physique
                          _handleScan("TEST-QR-CODE-SIMULATION");
                        },
                        icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                        label: const Text(
                          'Activer le scanner',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThixPolicy.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
