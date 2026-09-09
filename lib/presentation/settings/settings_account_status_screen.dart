// lib/presentation/settings/settings_account_status_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/models/account_type.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/theme.dart';

/// Page unique qui s'affiche quand le compte n'est pas actif.
/// Gère 2 états :
///   - deactivated  → simple bouton "Réactiver"
///   - pending_deletion → compte à rebours + bouton "Annuler la suppression"
class SettingsAccountStatusScreen extends StatefulWidget {
  const SettingsAccountStatusScreen({super.key});
  @override
  State<SettingsAccountStatusScreen> createState() =>
      _SettingsAccountStatusScreenState();
}

class _SettingsAccountStatusScreenState extends State<SettingsAccountStatusScreen> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _busy = false;

  // Récupération sécurisée des statuts depuis le modèle AppUser
  bool get _isPendingDeletion => context.read<AuthController>().currentUser?.isPendingDeletion ?? false;
  bool get _isDeactivated => context.read<AuthController>().currentUser?.isDeactivated ?? false;
  
  DateTime? get _scheduledDeletionAt =>
      context.read<AuthController>().currentUser?.scheduledDeletionAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Si le compte n'est ni en suppression ni désactivé, c'est qu'il est actif
      if (!_isPendingDeletion && !_isDeactivated) {
        _goHome();
        return;
      }
      if (_isPendingDeletion) {
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final target = _scheduledDeletionAt;
    if (target == null) {
      _timer?.cancel();
      return;
    }
    final remaining = target.difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) {
      _timer?.cancel();
      // Délai écoulé → forcer déconnexion, le serveur supprimera le compte
      context.read<AuthController>().signOut();
      if (mounted) context.go(AppRoutes.login);
      return;
    }
    if (mounted && remaining != _remaining) {
      setState(() => _remaining = remaining);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goHome() {
    final auth = context.read<AuthController>();
    final t = auth.currentUser?.accountType;
    context.go(t == null
        ? AppRoutes.home
        : t == AccountType.enterprise
            ? AppRoutes.enterpriseDashboard
            : AppRoutes.userDashboard);
  }

  Future<void> _reactivate() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc('reactivate_my_account');
      await context.read<AuthController>().refreshCurrentUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('settings_reactivate_done') ?? 'Compte réactivé avec succès'),
          backgroundColor: LightModeColors.success,
        ),
      );
      _goHome();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: LightModeColors.error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelDeletion() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc('cancel_account_deletion');
      await context.read<AuthController>().refreshCurrentUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('settings_cancel_deletion_done') ?? 'Suppression annulée'),
          backgroundColor: LightModeColors.success,
        ),
      );
      _goHome();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${l10n.t('settings_cancel_deletion_error') ?? 'Erreur'}: $e'),
        backgroundColor: LightModeColors.error,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    // On écoute les changements en temps réel
    final user = context.watch<AuthController>().currentUser;
    final isPending = user?.isPendingDeletion ?? false;
    // Si ce n'est pas en suppression, on suppose que c'est désactivé (puisqu'on est sur cet écran)

    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

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

              // ── Icône ──
              Icon(
                isPending ? Icons.timer_outlined : Icons.pause_circle_outline_rounded,
                size: 96,
                color: isPending ? LightModeColors.error : Colors.orange,
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Titre ──
              Text(
                isPending
                    ? (l10n.t('settings_banner_pending_deletion_title') ?? 'Suppression en cours')
                    : (l10n.t('settings_banner_deactivated_title') ?? 'Compte désactivé'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Sous-titre ──
              Text(
                isPending
                    ? (l10n.t('settings_delete_msg_24h') ?? 'Votre compte sera définitivement supprimé dans :')
                    : (l10n.t('settings_banner_deactivated_sub') ?? 'Votre compte est en pause.'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: LightModeColors.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Compteur (uniquement si pending) ──
              if (isPending) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: LightModeColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                        color: LightModeColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$h:$m:$s',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.error,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  l10n.t('settings_cancel_deletion_hint') ?? 'Vous avez changé d\'avis ? Vous pouvez annuler la suppression.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],

              const Spacer(),

              // ── Bouton principal ──
              FilledButton.icon(
                onPressed:
                    _busy ? null : (isPending ? _cancelDeletion : _reactivate),
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh_rounded),
                label: Text(
                  isPending
                      ? (l10n.t('settings_cancel_deletion') ?? 'Annuler la suppression')
                      : (l10n.t('settings_reactivate') ?? 'Réactiver mon compte'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isPending ? LightModeColors.error : Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full)),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Déconnexion ──
              OutlinedButton.icon(
                onPressed: _busy ? null : () {
                  context.read<AuthController>().signOut();
                  context.go(AppRoutes.login);
                },
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
