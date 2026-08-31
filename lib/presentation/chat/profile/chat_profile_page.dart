// lib/presentation/chat/profile/chat_profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/chat_user.dart';
import 'package:thix_id/providers/chat/chat_settings_provider.dart';
import 'package:thix_id/presentation/chat/profile/edit_chat_profile_page.dart';

// ============================================================================
// PROFILE PAGE
// ============================================================================

/// Page de visualisation du profil utilisateur.
///
/// Affiche : Avatar, Nom, Username, Statut.
/// Permet d'accéder aux paramètres ou d'éditer le profil (si c'est le mien).
class ChatProfilePage extends ConsumerStatefulWidget {
  final String userId;

  const ChatProfilePage({super.key, required this.userId});

  @override
  ConsumerState<ChatProfilePage> createState() => _ChatProfilePageState();
}

class _ChatProfilePageState extends ConsumerState<ChatProfilePage> {
  @override
  void initState() {
    super.initState();
    // Chargement des données au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    debugPrint('[Profile] 🔄 Loading data for user: ${widget.userId}');
    await ref.read(chatSettingsProvider.notifier).load(widget.userId);
    
    if (!mounted) return;
    final state = ref.read(chatSettingsProvider);
    if (state.error != null) {
      debugPrint('[Profile] ❌ Load error: ${state.error}');
      // Optionnel : Afficher un SnackBar d'erreur ici
    } else {
      debugPrint('[Profile] ✓ Data loaded successfully');
    }
  }

  void _navigateToSettings() {
    HapticFeedback.selectionClick();
    // Utilisation de named route pour la robustesse
    context.pushNamed('chat_settings'); 
  }

  void _navigateToEdit(ChatUser user) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditChatProfilePage(user: user)),
    ).then((_) {
      // Recharger les données au retour pour rafraîchir l'affichage
      if (mounted) _loadData();
    });
  }

  String _getSafeInitial(String name) {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsState = ref.watch(chatSettingsProvider);
    final user = settingsState.chatUser;
    final isLoading = settingsState.isLoading;
    final error = settingsState.error;

    // État de chargement
    if (isLoading) {
      return Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        body: Center(
          child: CircularProgressIndicator(color: ThixPolicy.primary),
        ),
      );
    }

    // État d'erreur ou utilisateur non trouvé
    if (user == null) {
      return Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          title: Text(l10n.t('profile_title')),
          backgroundColor: ThixPolicy.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_rounded, size: 64, color: ThixPolicy.textMuted),
              const SizedBox(height: 16),
              Text(
                error ?? l10n.t('profile_not_found'),
                style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final initial = _getSafeInitial(user.displayName);
    final isMe = user.id == ref.read(chatSettingsProvider).currentUserId; // Vérifier si c'est mon profil

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          l10n.t('profile_title'),
          style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold),
        ),
        backgroundColor: ThixPolicy.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
          ),
        ),
        actions: [
          Semantics(
            button: true,
            label: l10n.t('settings_title'),
            child: IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: _navigateToSettings,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ─ Avatar ──
            Semantics(
              label: '${l10n.t('profile_avatar')} ${user.displayName}',
              child: CircleAvatar(
                radius: 60,
                backgroundColor: ThixPolicy.surfaceSoft,
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        initial,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: ThixPolicy.primary,
                        ),
                      )
                    : null,
              ),
            ),
            
            const SizedBox(height: 12),

            // ── Nom ─
            Text(
              user.displayName,
              style: ThixPolicy.h2Style.copyWith( 
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ThixPolicy.textMain,
              ),
              textAlign: TextAlign.center,
            ),

            // ── Username ──
            if (user.username != null) ...[
              const SizedBox(height: 4),
              Text(
                '@${user.username}',
                style: ThixPolicy.bodyStyle.copyWith(
                  color: ThixPolicy.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            // ── Statut ──
            if (user.status != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: ThixPolicy.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThixPolicy.primary.withOpacity(0.2)),
                ),
                child: Text(
                  user.status!,
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    color: ThixPolicy.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── Bouton Modifier (Seulement si c'est mon profil) ──
            if (isMe)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToEdit(user),
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(l10n.t('profile_edit_button')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else
              // Si ce n'est pas mon profil, on pourrait ajouter un bouton "Message" ou "Appeler"
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Action : Ouvrir le chat avec cet utilisateur
                    debugPrint('[Profile] 💬 Open chat with ${user.id}');
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text(l10n.t('profile_message_button')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ThixPolicy.primary,
                    side: BorderSide(color: ThixPolicy.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
