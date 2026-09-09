import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/user_service.dart';
import 'package:thix_id/theme.dart'; // Assurez-vous du bon chemin vers votre theme.dart

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
      // Déclenchement immédiat pour éviter le délai d'une seconde à l'affichage
      _updateTimeLeft(user!.scheduledDeletionAt!);
      
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateTimeLeft(user.scheduledDeletionAt!);
      });
    }
  }

  void _updateTimeLeft(DateTime targetDate) {
    final remaining = targetDate.difference(DateTime.now());
    if (remaining.isNegative) {
      _timer?.cancel();
      // Le délai est écoulé, on déconnecte l'utilisateur
      context.read<AuthController>().signOut();
    } else {
      if (mounted) {
        setState(() {
          _timeLeft = remaining;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cancelDeletion() async {
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context);
    
    try {
      final userService = UserService(Supabase.instance.client);
      await userService.cancelAccountDeletion();
      
      if (mounted) {
        // Rafraîchir l'utilisateur force le routeur à réévaluer la règle globale
        // Le GoRouter redirigera automatiquement vers le dashboard (isPendingDeletion deviendra false)
        await context.read<AuthController>().refreshCurrentUser();

      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('settings_cancel_deletion_error') ?? 'Erreur lors de l\'annulation : $e'),
            backgroundColor: LightModeColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context); // ou context.theme si vous avez l'extension ici

    final hours = _timeLeft.inHours.toString().padLeft(2, '0');
    final minutes = (_timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_timeLeft.inSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Icône d'avertissement
              Icon(
                Icons.timer_outlined, 
                size: 80, 
                color: LightModeColors.error,
              ),
              const SizedBox(height: AppSpacing.lg),
              
              // Titre
              Text(
                l10n.t('settings_banner_pending_deletion_title') ?? 'Compte en cours de suppression',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Sous-titre
              Text(
                l10n.t('settings_delete_msg_24h') ?? 'Votre compte sera définitivement supprimé dans :',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: LightModeColors.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              
              // Compteur (façon bloc code/digital)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: LightModeColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: LightModeColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$hours:$minutes:$seconds',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.error,
                    fontFeatures: const [FontFeature.tabularFigures()], // Empêche le texte de bouger à chaque seconde
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              
              // Message informatif
              Text(
                l10n.t('settings_cancel_deletion_hint') ?? 'Vous avez changé d\'avis ? Vous pouvez annuler la suppression et récupérer l\'accès immédiat à vos services THIX.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              
              const Spacer(),
              
              // Bouton Annuler la suppression
              FilledButton.icon(
                onPressed: _isLoading ? null : _cancelDeletion,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(
                  l10n.t('settings_cancel_deletion') ?? 'Annuler la suppression',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              
              const SizedBox(height: AppSpacing.md),
              
              // Bouton Déconnexion
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => context.read<AuthController>().signOut(),
                icon: const Icon(Icons.logout_rounded),
                label: Text(l10n.t('settings_sign_out') ?? 'Se déconnecter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: LightModeColors.secondaryText,
                  side: const BorderSide(color: Colors.transparent),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
