// lib/presentation/thix_market/pages/market_settings_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/settings_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);

// ============================================================================
// VALIDATEURS
// ============================================================================
class _SettingsValidators {
  _SettingsValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static int safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }

  static String maskPhoneNumber(String? phone) {
    if (phone == null || phone.length < 6) return phone ?? '';
    return '${phone.substring(0, 3)}••••${phone.substring(phone.length - 2)}';
  }

  static String maskEmail(String? email) {
    if (email == null || !email.contains('@')) return email ?? '';
    final parts = email.split('@');
    if (parts[0].length <= 3) return email;
    return '${parts[0].substring(0, 3)}•••@${parts[1]}';
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = 1,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Settings] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[Settings] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Settings] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class MarketSettingsPage extends StatefulWidget {
  const MarketSettingsPage({super.key});

  @override
  State<MarketSettingsPage> createState() => _MarketSettingsPageState();
}

class _MarketSettingsPageState extends State<MarketSettingsPage> {
  String _appVersion = '';
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[Settings] ⚙️ Page opened');
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Charger settings + version en parallèle
      final settingsFuture = _withRetry(
        () => context.read<SettingsProvider>().loadSettings(),
        label: 'loadSettings',
      );
      final versionFuture = _loadAppVersion();

      await Future.wait([settingsFuture, versionFuture]);
      debugPrint('[Settings] ✓ Initial data loaded (v$_appVersion)');
    } catch (e) {
      debugPrint('[Settings] ❌ Load error: $e');
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = 'v${info.version} (${info.buildNumber})');
      }
    } catch (e) {
      debugPrint('[Settings] ⚠️ Version load error: $e');
      if (mounted) setState(() => _appVersion = 'v2.0.0');
    }
  }

  @override
  void dispose() {
    debugPrint('[Settings] 👋 Page disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          'Paramètres Market',
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
        ),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
          tooltip: 'Retour',
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
      ),
      body: provider.isLoading
          ? const _SkeletonSettings()
          : RefreshIndicator(
              color: ThixPolicy.primary,
              onRefresh: _loadInitialData,
              child: ListView(
                children: [
                  _SettingsSection(
                    title: 'Mon compte',
                    children: [_ProfileTile(user: provider.user, onEdit: _editProfile)],
                  ),
                  _SettingsSection(
                    title: 'Moyens de paiement',
                    children: [
                      _SettingsTile(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'THIX Money',
                        subtitle: provider.thixMoneyBalance != null
                            ? 'Solde: ${provider.thixMoneyBalance} FCFA'
                            : 'Lier votre compte THIX Money',
                        onTap: _manageThixMoney,
                        trailing: provider.isThixMoneyLinked
                            ? const Icon(Icons.check_circle_rounded, color: ThixPolicy.success, size: 22)
                            : null,
                      ),
                      _SettingsTile(
                        icon: Icons.credit_card_rounded,
                        title: 'Cartes bancaires',
                        subtitle: provider.cardsCount > 0
                            ? '${_SettingsValidators.safeInt(provider.cardsCount)} carte(s) enregistrée(s)'
                            : 'Ajouter une carte',
                        onTap: _manageCards,
                      ),
                      _SettingsTile(
                        icon: Icons.mobile_friendly_rounded,
                        title: 'Mobile Money',
                        subtitle: provider.mobileMoneyNumber != null
                            ? _SettingsValidators.maskPhoneNumber(provider.mobileMoneyNumber)
                            : 'Ajouter un numéro',
                        onTap: _manageMobileMoney,
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: 'Livraison',
                    children: [
                      _SettingsTile(
                        icon: Icons.location_on_rounded,
                        title: 'Adresses de livraison',
                        subtitle: '${_SettingsValidators.safeInt(provider.addressesCount)} adresse(s) enregistrée(s)',
                        onTap: _manageAddresses,
                      ),
                      _SettingsTile(
                        icon: Icons.store_rounded,
                        title: 'Points relais THIX',
                        subtitle: 'Trouver un point relais',
                        onTap: _findPickupPoints,
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: 'Notifications',
                    children: [
                      _CustomSwitchTile(
                        icon: Icons.notifications_active_rounded,
                        title: 'Notifications push',
                        subtitle: 'Recevoir les alertes en temps réel',
                        value: provider.pushNotifications,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          provider.togglePushNotifications(v);
                        },
                      ),
                      _CustomSwitchTile(
                        icon: Icons.message_rounded,
                        title: 'Nouveaux messages',
                        value: provider.messageNotifications,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          provider.toggleMessageNotifications(v);
                        },
                      ),
                      _CustomSwitchTile(
                        icon: Icons.local_offer_rounded,
                        title: 'Offres et promotions',
                        value: provider.promoNotifications,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          provider.togglePromoNotifications(v);
                        },
                      ),
                      _CustomSwitchTile(
                        icon: Icons.trending_down_rounded,
                        title: 'Alertes prix',
                        value: provider.priceAlertNotifications,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          provider.togglePriceAlertNotifications(v);
                        },
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: 'Sécurité',
                    children: [
                      _SettingsTile(
                        icon: Icons.security_rounded,
                        title: 'Double authentification',
                        subtitle: provider.is2FAEnabled ? 'Activée' : 'Sécurisez votre compte',
                        onTap: _manage2FA,
                        trailing: provider.is2FAEnabled
                            ? const Icon(Icons.check_circle_rounded, color: ThixPolicy.success, size: 22)
                            : null,
                      ),
                      _SettingsTile(
                        icon: Icons.lock_rounded,
                        title: 'Changer le mot de passe',
                        onTap: _changePassword,
                      ),
                      _SettingsTile(
                        icon: Icons.devices_rounded,
                        title: 'Appareils connectés',
                        subtitle: 'Gérer les sessions actives',
                        onTap: _manageDevices,
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: 'Vendeur professionnel',
                    children: [
                      _CustomSwitchTile(
                        icon: Icons.business_center_rounded,
                        title: 'Mode professionnel',
                        subtitle: 'Accédez aux fonctionnalités vendeur avancées',
                        value: provider.isProfessionalMode,
                        onChanged: (v) => _toggleProfessionalMode(v, provider),
                      ),
                      if (provider.isProfessionalMode)
                        _SettingsTile(
                          icon: Icons.subscriptions_rounded,
                          title: 'Abonnement Pro',
                          subtitle: _SettingsValidators.sanitize(provider.subscriptionStatus, maxLength: 80).isNotEmpty
                              ? provider.subscriptionStatus!
                              : 'Activer votre abonnement',
                          onTap: _manageSubscription,
                        ),
                    ],
                  ),
                  _SettingsSection(
                    title: 'Confidentialité',
                    children: [
                      _CustomSwitchTile(
                        icon: Icons.public_rounded,
                        title: 'Profil public',
                        subtitle: 'Votre profil est visible par tous',
                        value: provider.isPublicProfile,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          provider.togglePublicProfile(v);
                        },
                      ),
                      _CustomSwitchTile(
                        icon: Icons.email_rounded,
                        title: 'Afficher mon email',
                        subtitle: 'Visible par les acheteurs',
                        value: provider.showEmail,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          provider.toggleShowEmail(v);
                        },
                      ),
                      _CustomSwitchTile(
                        icon: Icons.phone_rounded,
                        title: 'Afficher mon téléphone',
                        subtitle: 'Visible par les acheteurs',
                        value: provider.showPhone,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          provider.toggleShowPhone(v);
                        },
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: 'Support & Aide',
                    children: [
                      _SettingsTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Centre d\'aide',
                        subtitle: 'FAQ et guides',
                        onTap: _openHelpCenter,
                      ),
                      _SettingsTile(
                        icon: Icons.headset_mic_rounded,
                        title: 'Contacter le support',
                        subtitle: 'Réponse sous 24h',
                        onTap: _contactSupport,
                      ),
                      _SettingsTile(
                        icon: Icons.report_problem_rounded,
                        title: 'Signaler un problème',
                        onTap: _reportIssue,
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: 'À propos',
                    children: [
                      _SettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: 'Version',
                        subtitle: 'THIX Market $_appVersion',
                        onTap: _showVersionDetails,
                      ),
                      _SettingsTile(
                        icon: Icons.description_rounded,
                        title: 'Conditions d\'utilisation',
                        onTap: _openTerms,
                      ),
                      _SettingsTile(
                        icon: Icons.privacy_tip_rounded,
                        title: 'Politique de confidentialité',
                        onTap: _openPrivacy,
                      ),
                    ],
                  ),
                  // Actions dangereuses
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Semantics(
                      button: true,
                      label: 'Supprimer mon compte',
                      child: OutlinedButton.icon(
                        onPressed: _deleteAccount,
                        icon: const Icon(Icons.delete_forever_rounded, size: 20),
                        label: const Text('Supprimer mon compte'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ThixPolicy.textMuted,
                          side: const BorderSide(color: ThixPolicy.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Semantics(
                      button: true,
                      label: 'Se déconnecter',
                      child: OutlinedButton.icon(
                        onPressed: _loggingOut ? null : _logout,
                        icon: _loggingOut
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.logout_rounded, size: 20),
                        label: Text(_loggingOut ? 'Déconnexion...' : 'Se déconnecter'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ThixPolicy.danger,
                          side: const BorderSide(color: ThixPolicy.danger),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // NAVIGATION (via go_router)
  // ============================================================
  void _navigate(String route, {String? label}) {
    HapticFeedback.selectionClick();
    debugPrint('[Settings] 🧭 Navigate to $route${label != null ? " ($label)" : ""}');
    context.push(route);
  }

  void _manageThixMoney() => _navigate('/thix-money', label: 'THIX Money');
  void _manageCards() => _navigate('/payment-methods', label: 'Cartes');
  void _manageMobileMoney() => _navigate('/mobile-money', label: 'Mobile Money');
  void _manageAddresses() => _navigate('/addresses', label: 'Adresses');
  void _findPickupPoints() => _navigate('/pickup-points', label: 'Points relais');
  void _manage2FA() => _navigate('/2fa-setup', label: '2FA');
  void _changePassword() => _navigate('/change-password', label: 'Password');
  void _manageDevices() => _navigate('/devices', label: 'Devices');
  void _manageSubscription() => _navigate('/subscription', label: 'Subscription');
  void _editProfile() => _navigate('/edit-profile', label: 'Edit Profile');
  void _openTerms() => _navigate('/terms', label: 'Terms');
  void _openPrivacy() => _navigate('/privacy', label: 'Privacy');
  void _openHelpCenter() => _navigate('/help', label: 'Help Center');
  void _contactSupport() => _navigate('/support', label: 'Support');
  void _reportIssue() => _navigate('/report-issue', label: 'Report Issue');

  void _showVersionDetails() {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text('Informations version', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('THIX Market', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 4),
            Text(_appVersion, style: ThixPolicy.bodyStyle),
            const SizedBox(height: 12),
            Text('Développé par THIX Technologies', style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIONS CRITIQUES
  // ============================================================
  Future<void> _toggleProfessionalMode(bool value, SettingsProvider provider) async {
    if (value) {
      HapticFeedback.mediumImpact();
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThixPolicy.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.business_center_rounded, color: ThixPolicy.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text('Mode professionnel', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Le mode professionnel vous donne accès à :', style: ThixPolicy.bodyStyle),
              const SizedBox(height: 12),
              _FeatureBullet('Statistiques avancées'),
              _FeatureBullet('Outils de marketing'),
              _FeatureBullet('Support prioritaire'),
              _FeatureBullet('API d\'intégration'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Activer'),
            ),
          ],
        ),
      );

      if (shouldProceed == true) {
        provider.toggleProfessionalMode(true);
        debugPrint('[Settings] ✅ Professional mode enabled');
      }
    } else {
      HapticFeedback.selectionClick();
      provider.toggleProfessionalMode(false);
      debugPrint('[Settings] ⚪ Professional mode disabled');
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    HapticFeedback.mediumImpact();
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout_rounded, color: ThixPolicy.danger, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Déconnexion', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
          ],
        ),
        content: Text('Êtes-vous sûr de vouloir vous déconnecter ?', style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    setState(() => _loggingOut = true);

    try {
      await _withRetry(
        () => Supabase.instance.client.auth.signOut(),
        label: 'signOut',
      );
      debugPrint('[Settings] ✓ Signed out successfully');
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      debugPrint('[Settings] ❌ Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Erreur lors de la déconnexion')),
            ]),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _deleteAccount() async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: ThixPolicy.danger, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Action irréversible', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.danger)),
          ],
        ),
        content: Text(
          'La suppression de votre compte est définitive. Toutes vos données, commandes et favoris seront perdus.\n\nVoulez-vous continuer ?',
          style: ThixPolicy.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _navigate('/delete-account', label: 'Delete Account');
    }
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _FeatureBullet extends StatelessWidget {
  final String text;
  const _FeatureBullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: ThixPolicy.success),
          const SizedBox(width: 8),
          Text(text, style: ThixPolicy.bodySmallStyle),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: ThixPolicy.microStyle.copyWith(
              fontSize: 11,
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onEdit;

  const _ProfileTile({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Semantics(
        button: true,
        label: 'Connectez-vous pour voir votre profil',
        child: ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: ThixPolicy.surfaceSoft,
            child: const Icon(Icons.person_outline_rounded, size: 28, color: ThixPolicy.textMuted),
          ),
          title: Text('Connectez-vous', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
          subtitle: Text('Pour voir votre profil', style: ThixPolicy.captionStyle),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: ThixPolicy.textMuted),
          onTap: () => context.push('/login'),
        ),
      );
    }

    final avatarUrl = _SettingsValidators.sanitizeUrl(user!['avatar']?.toString());
    final name = _SettingsValidators.sanitize(user!['name']?.toString() ?? 'Utilisateur', maxLength: 60);
    final email = _SettingsValidators.sanitize(user!['email']?.toString() ?? '', maxLength: 100);

    return Semantics(
      button: true,
      label: 'Profil: $name, $email. Modifier',
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: ThixPolicy.surfaceSoft,
          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
          child: avatarUrl == null
              ? const Icon(Icons.person_rounded, size: 28, color: ThixPolicy.textMuted)
              : null,
        ),
        title: Text(
          name,
          style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _SettingsValidators.maskEmail(email),
          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_rounded, size: 20, color: ThixPolicy.primary),
          tooltip: 'Modifier',
          onPressed: onEdit,
        ),
        onTap: onEdit,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title${subtitle != null ? ", $subtitle" : ""}',
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ThixPolicy.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: ThixPolicy.primary, size: 22),
        ),
        title: Text(
          title,
          style: ThixPolicy.labelStyle.copyWith(
            fontWeight: ThixPolicy.semiBold,
            fontSize: 15,
            color: ThixPolicy.textMain,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: trailing ??
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: ThixPolicy.textMuted),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );
  }
}

class _CustomSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CustomSwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: '$title, ${value ? "activé" : "désactivé"}',
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: value ? ThixPolicy.success.withOpacity(0.1) : ThixPolicy.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: value ? ThixPolicy.success : ThixPolicy.primary,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: ThixPolicy.labelStyle.copyWith(
            fontWeight: ThixPolicy.semiBold,
            fontSize: 15,
            color: ThixPolicy.textMain,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle!, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted))
            : null,
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: ThixPolicy.success,
        ),
        onTap: () => onChanged(!value),
      ),
    );
  }
}

class _SkeletonSettings extends StatelessWidget {
  const _SkeletonSettings();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile skeleton
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          ),
          child: Row(
            children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: 150, color: Colors.grey.shade200),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 200, color: Colors.grey.shade200),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Sections skeleton
        ...List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: 100, color: Colors.grey.shade200),
                const SizedBox(height: 12),
                ...List.generate(
                  3,
                  (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ThixPolicy.card,
                        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                      ),
                      child: Row(
                        children: [
                          Container(width: 40, height: 40, color: Colors.grey.shade200),
                          const SizedBox(width: 12),
                          Expanded(child: Container(height: 14, color: Colors.grey.shade200)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
