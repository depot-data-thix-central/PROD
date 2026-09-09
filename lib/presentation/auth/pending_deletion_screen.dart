import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingDeletionScreen extends StatefulWidget {
  const PendingDeletionScreen({super.key});

  @override
  State<PendingDeletionScreen> createState() => _PendingDeletionScreenState();
}

class _PendingDeletionScreenState extends State<PendingDeletionScreen> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    final user = context.read<AuthController>().currentUser;
    if (user?.scheduledDeletionAt != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final remaining = user!.scheduledDeletionAt!.difference(DateTime.now());
        if (remaining.isNegative) {
          timer.cancel();
          // Le cron job serveur devrait s'en charger, mais on déconnecte ici
          context.read<AuthController>().signOut();
        } else {
          setState(() {
            _timeLeft = remaining;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cancelDeletion() async {
    setState(() => _isLoading = true);
    try {
      final userService = UserService(Supabase.instance.client);
      await userService.cancelAccountDeletion();
      
      if (mounted) {
        // Rafraîchir l'utilisateur force le routeur à réévaluer la règle globale
        // et renverra l'utilisateur vers son dashboard
        await context.read<AuthController>().refreshUser();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = _timeLeft.inHours.toString().padLeft(2, '0');
    final minutes = (_timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_timeLeft.inSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91), // Couleur THIX
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.orangeAccent),
            const SizedBox(height: 24),
            const Text(
              'Compte en cours de suppression',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Votre compte sera définitivement supprimé dans :',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$hours:$minutes:$seconds',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Vous avez changé d\'avis ? Vous pouvez annuler la suppression et récupérer l\'accès immédiat à vos services THIX.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _cancelDeletion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0B3D91),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator()
                    : const Text('Annuler la suppression', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.read<AuthController>().signOut(),
              child: const Text('Se déconnecter', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}
