// lib/presentation/network/settings_network_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const String _kDefaultPushKey = 'push';
const String _kDefaultEmailKey = 'email';
const String _kDefaultMessagesKey = 'messages';
const String _kDefaultVisibilityKey = 'profile_visibility';

// ============================================================================
// PROVIDER (cache les settings pour éviter rechargement)
// ============================================================================
class UserSettings {
  final bool push;
  final bool email;
  final bool messages;
  final String visibility;

  const UserSettings({
    this.push = true,
    this.email = true,
    this.messages = true,
    this.visibility = 'public',
  });

  UserSettings copyWith({bool? push, bool? email, bool? messages, String? visibility}) {
    return UserSettings(
      push: push ?? this.push,
      email: email ?? this.email,
      messages: messages ?? this.messages,
      visibility: visibility ?? this.visibility,
    );
  }

  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettings &&
          runtimeType == other.runtimeType &&
          push == other.push &&
          email == other.email &&
          messages == other.messages &&
          visibility == other.visibility;

  @override
  int get hashCode => Object.hash(push, email, messages, visibility);
}

class UserSettingsNotifier extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() async {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if (uid == null) throw Exception('Non authentifié');

    try {
      final response = await supa
          .from('profiles')
          .select('notification_settings, privacy_settings')
          .eq('id', uid)
          .maybeSingle()
          .timeout(_kRequestTimeout);

      if (response == null) return const UserSettings();

      final notif = response['notification_settings'] as Map<String, dynamic>? ?? {};
      final priv = response['privacy_settings'] as Map<String, dynamic>? ?? {};

      return UserSettings(
        push: notif[_kDefaultPushKey] as bool? ?? true,
        email: notif[_kDefaultEmailKey] as bool? ?? true,
        messages: notif[_kDefaultMessagesKey] as bool? ?? true,
        visibility: priv[_kDefaultVisibilityKey]?.toString() ?? 'public',
      );
    } catch (e) {
      debugPrint('[Settings] Load error: $e');
      rethrow;
    }
  }

  Future<void> update(UserSettings newSettings) async {
    final current = state.valueOrNull ?? const UserSettings();
    if (current == newSettings) return;

    // Optimistic UI
    state = AsyncData(newSettings);

    try {
      final supa = Supabase.instance.client;
      final uid = supa.auth.currentUser?.id;
      if (uid == null) throw Exception('Non authentifié');

      await supa
          .from('profiles')
          .update({
            'notification_settings': {
              _kDefaultPushKey: newSettings.push,
              _kDefaultEmailKey: newSettings.email,
              _kDefaultMessagesKey: newSettings.messages,
            },
            'privacy_settings': {
              _kDefaultVisibilityKey: newSettings.visibility,
            },
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', uid)
          .timeout(_kRequestTimeout);

      debugPrint('[Settings] Saved successfully');
    } catch (e) {
      debugPrint('[Settings] Save error: $e');
      state = AsyncData(current); // Rollback
      rethrow;
    }
  }
}

final userSettingsProvider =
    AsyncNotifierProvider<UserSettingsNotifier, UserSettings>(UserSettingsNotifier.new);

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class SettingsNetworkPage extends ConsumerStatefulWidget {
  const SettingsNetworkPage({super.key});

  @override
  ConsumerState<SettingsNetworkPage> createState() => _SettingsNetworkPageState();
}

class _SettingsNetworkPageState extends ConsumerState<SettingsNetworkPage> {
  UserSettings _draft = const UserSettings();
  bool _hasInitialized = false;
  bool _isSaving = false;
  bool _isLoggingOut = false;

  bool get _hasChanges {
    final original = ref.read(userSettingsProvider).valueOrNull;
    if (original == null) return false;
    return original != _draft;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(userSettingsProvider);

    // Initialisation du draft
    if (!_hasInitialized) {
      settingsAsync.whenData((s) {
        if (_draft == const UserSettings()) {
          _draft = s;
          _hasInitialized = true;
        }
      });
    }

    return PopScope(
      canPop: !_isSaving && !_isLoggingOut,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isSaving || _isLoggingOut) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opération en cours...')),
          );
          return;
        }
        if (_hasChanges) {
          _showDiscardDialog();
        } else {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          backgroundColor: ThixPolicy.card,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 20),
            onPressed: (_isSaving || _isLoggingOut)
                ? null
                : () {
                    if (_hasChanges) {
                      _showDiscardDialog();
                    } else {
                      HapticFeedback.selectionClick();
                      context.pop();
                    }
                  },
          ),
          title: Text(
            'Paramètres',
            style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
          actions: [
            if (_hasChanges)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ThixPolicy.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                    ),
                    child: Text(
                      'Modifié',
                      style: ThixPolicy.microStyle.copyWith(
                        color: ThixPolicy.gold,
                        fontWeight: ThixPolicy.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
          error: (e, _) => _buildErrorState(e.toString()),
          data: (_) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text('Erreur de chargement', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(userSettingsProvider),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSection(
            icon: Icons.notifications_rounded,
            iconColor: ThixPolicy.primary,
            title: 'Notifications',
            children: [
              _buildSwitchTile(
                title: 'Notifications push',
                subtitle: 'Recevoir les alertes en temps réel',
                icon: Icons.notifications_active_rounded,
                iconColor: ThixPolicy.primary,
                value: _draft.push,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _draft = _draft.copyWith(push: v));
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                title: 'Notifications email',
                subtitle: 'Recevoir les résumés par email',
                icon: Icons.email_rounded,
                iconColor: ThixPolicy.domainLearning,
                value: _draft.email,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _draft = _draft.copyWith(email: v));
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                title: 'Messages privés',
                subtitle: 'Être notifié des nouveaux messages',
                icon: Icons.chat_rounded,
                iconColor: ThixPolicy.gold,
                value: _draft.messages,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _draft = _draft.copyWith(messages: v));
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildSection(
            icon: Icons.lock_rounded,
            iconColor: ThixPolicy.domainHealth,
            title: 'Confidentialité',
            children: [
              _buildPrivacyOption(
                title: 'Public',
                subtitle: 'Tout le monde peut voir votre profil',
                icon: Icons.public_rounded,
                value: 'public',
              ),
              _buildDivider(),
              _buildPrivacyOption(
                title: 'Mes connexions',
                subtitle: 'Seules vos connexions peuvent voir votre profil',
                icon: Icons.people_alt_rounded,
                value: 'connections',
              ),
              _buildDivider(),
              _buildPrivacyOption(
                title: 'Privé',
                subtitle: 'Personne ne peut voir votre profil',
                icon: Icons.lock_rounded,
                value: 'private',
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildSection(
            icon: Icons.tune_rounded,
            iconColor: ThixPolicy.domainNetwork,
            title: 'Actions',
            children: [
              _buildActionTile(
                title: 'Utilisateurs bloqués',
                subtitle: null,
                icon: Icons.block_rounded,
                iconColor: ThixPolicy.danger,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/network/blocked');
                },
              ),
              _buildDivider(),
              _buildActionTile(
                title: 'Exporter mes données',
                subtitle: 'Télécharger vos informations personnelles',
                icon: Icons.download_rounded,
                iconColor: ThixPolicy.info,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.construction_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('Fonctionnalité bientôt disponible')),
                        ],
                      ),
                      backgroundColor: ThixPolicy.warning,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildSection(
            icon: Icons.account_circle_rounded,
            iconColor: ThixPolicy.textSecondary,
            title: 'Compte',
            children: [
              _buildActionTile(
                title: 'Déconnexion',
                subtitle: 'Se déconnecter de votre compte',
                icon: Icons.logout_rounded,
                iconColor: ThixPolicy.danger,
                titleColor: ThixPolicy.danger,
                onTap: _showLogoutDialog,
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildSaveButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Text(title, style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
              ],
            ),
          ),
          _buildDivider(),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      title: Text(title, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMain)),
      subtitle: Text(subtitle, style: ThixPolicy.captionStyle),
      value: value,
      onChanged: onChanged,
      activeColor: ThixPolicy.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(ThixPolicy.rXs),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }

  Widget _buildPrivacyOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _draft.visibility == value;

    return RadioListTile<String>(
      title: Text(
        title,
        style: ThixPolicy.labelStyle.copyWith(
          fontWeight: isSelected ? ThixPolicy.bold : ThixPolicy.semiBold,
          color: isSelected ? ThixPolicy.gold : ThixPolicy.textMain,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: ThixPolicy.captionStyle.copyWith(fontSize: 12),
      ),
      value: value,
      groupValue: _draft.visibility,
      onChanged: (v) {
        HapticFeedback.selectionClick();
        setState(() {
          if (v != null) _draft = _draft.copyWith(visibility: v);
        });
      },
      activeColor: ThixPolicy.gold,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? ThixPolicy.gold.withOpacity(0.15) : ThixPolicy.surfaceSoft,
          borderRadius: BorderRadius.circular(ThixPolicy.rXs),
        ),
        child: Icon(icon, size: 20, color: isSelected ? ThixPolicy.gold : ThixPolicy.textSecondary),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String? subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(ThixPolicy.rXs),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(
        title,
        style: ThixPolicy.labelStyle.copyWith(
          fontWeight: ThixPolicy.semiBold,
          color: titleColor ?? ThixPolicy.textMain,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle, style: ThixPolicy.captionStyle) : null,
      trailing: const Icon(Icons.chevron_right_rounded, size: 22, color: ThixPolicy.textMuted),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 0, thickness: 0.5, indent: 16, endIndent: 16);
  }

  Widget _buildSaveButton() {
    final hasChanges = _hasChanges;

    return SizedBox(
      width: double.infinity,
      height: ThixPolicy.buttonHeightLarge,
      child: ElevatedButton.icon(
        onPressed: (_isSaving || !hasChanges) ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: hasChanges ? ThixPolicy.gold : ThixPolicy.surfaceStrong,
          foregroundColor: hasChanges ? ThixPolicy.inkDeep : ThixPolicy.textDisabled,
          elevation: hasChanges ? 2 : 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
        ),
        icon: _isSaving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.inkDeep))
            : Icon(hasChanges ? Icons.save_rounded : Icons.check_circle_outline_rounded, size: 20),
        label: Text(
          _isSaving ? 'ENREGISTREMENT...' : (hasChanges ? 'ENREGISTRER' : 'AUCUNE MODIFICATION'),
          style: ThixPolicy.labelStyle.copyWith(
            color: hasChanges ? ThixPolicy.inkDeep : ThixPolicy.textDisabled,
            fontWeight: ThixPolicy.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ─── SAVE ───
  Future<void> _saveSettings() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(userSettingsProvider.notifier).update(_draft);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Paramètres enregistrés'),
            ],
          ),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
        ),
      );
    } catch (e) {
      debugPrint('[Settings] Save error: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Erreur lors de l\'enregistrement')),
            ],
          ),
          backgroundColor: ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── DISCARD DIALOG ───
  void _showDiscardDialog() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: ThixPolicy.warning, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Modifications non enregistrées', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous enregistrer vos modifications avant de quitter ?',
          style: ThixPolicy.bodyStyle.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Ignorer', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              await _saveSettings();
              if (mounted) context.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.gold,
              foregroundColor: ThixPolicy.inkDeep,
            ),
            child: const Text('Enregistrer & quitter'),
          ),
        ],
      ),
    );
  }

  // ─── LOGOUT DIALOG ───
  void _showLogoutDialog() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: ThixPolicy.danger, size: 24),
            const SizedBox(width: 8),
            Text('Déconnexion', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.danger)),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment vous déconnecter de votre compte ?',
          style: ThixPolicy.bodyStyle.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              await _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: _isLoggingOut
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    setState(() => _isLoggingOut = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(authControllerProvider.notifier).signOut();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      debugPrint('[Settings] Logout error: $e');
      // Fallback : signOut direct Supabase
      try {
        await Supabase.instance.client.auth.signOut();
        if (mounted) context.go('/login');
      } catch (fallbackError) {
        debugPrint('[Settings] Fallback logout error: $fallbackError');
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }
}
