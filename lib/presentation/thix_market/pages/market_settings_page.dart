import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ Import manquant
import '../providers/settings_provider.dart';

class MarketSettingsPage extends StatefulWidget {
  const MarketSettingsPage({super.key});

  @override
  State<MarketSettingsPage> createState() => _MarketSettingsPageState();
}

class _MarketSettingsPageState extends State<MarketSettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Paramètres Market',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Profile Section
          _buildSection(
            title: 'Mon compte',
            children: [
              _buildProfileTile(settingsProvider.user),
            ],
          ),
          
          // Payment Section
          _buildSection(
            title: 'Moyens de paiement',
            children: [
              _buildSettingsTile(
                icon: Icons.account_balance_wallet,
                title: 'THIX Money',
                subtitle: settingsProvider.thixMoneyBalance != null
                    ? 'Solde: ${settingsProvider.thixMoneyBalance} FCFA'
                    : 'Lier votre compte THIX Money',
                onTap: () => _manageThixMoney(),
                trailing: settingsProvider.isThixMoneyLinked
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
              _buildSettingsTile(
                icon: Icons.credit_card,
                title: 'Cartes bancaires',
                subtitle: settingsProvider.cardsCount > 0
                    ? '${settingsProvider.cardsCount} carte(s) enregistrée(s)'
                    : 'Ajouter une carte',
                onTap: () => _manageCards(),
              ),
              _buildSettingsTile(
                icon: Icons.mobile_friendly,
                title: 'Mobile Money',
                subtitle: settingsProvider.mobileMoneyNumber != null
                    ? settingsProvider.mobileMoneyNumber
                    : 'Ajouter un numéro',
                onTap: () => _manageMobileMoney(),
              ),
            ],
          ),
          
          // Delivery Section
          _buildSection(
            title: 'Livraison',
            children: [
              _buildSettingsTile(
                icon: Icons.location_on,
                title: 'Adresses de livraison',
                subtitle: '${settingsProvider.addressesCount} adresse(s) enregistrée(s)',
                onTap: () => _manageAddresses(),
              ),
              _buildSettingsTile(
                icon: Icons.store,
                title: 'Points relais THIX',
                subtitle: 'Trouver un point relais',
                onTap: () => _findPickupPoints(),
              ),
            ],
          ),
          
          // Notifications
          _buildSection(
            title: 'Notifications',
            children: [
              SwitchListTile(
                title: const Text('Notifications push'),
                subtitle: const Text('Recevoir les alertes en temps réel'),
                value: settingsProvider.pushNotifications,
                onChanged: (value) => settingsProvider.togglePushNotifications(value),
                secondary: const Icon(Icons.notifications_active),
              ),
              SwitchListTile(
                title: const Text('Nouveaux messages'),
                value: settingsProvider.messageNotifications,
                onChanged: (value) => settingsProvider.toggleMessageNotifications(value),
                secondary: const Icon(Icons.message),
              ),
              SwitchListTile(
                title: const Text('Offres et promotions'),
                value: settingsProvider.promoNotifications,
                onChanged: (value) => settingsProvider.togglePromoNotifications(value),
                secondary: const Icon(Icons.local_offer),
              ),
              SwitchListTile(
                title: const Text('Alertes prix'),
                value: settingsProvider.priceAlertNotifications,
                onChanged: (value) => settingsProvider.togglePriceAlertNotifications(value),
                secondary: const Icon(Icons.trending_down),
              ),
            ],
          ),
          
          // Security
          _buildSection(
            title: 'Sécurité',
            children: [
              _buildSettingsTile(
                icon: Icons.security,
                title: 'Double authentification',
                subtitle: settingsProvider.is2FAEnabled
                    ? 'Activée'
                    : 'Sécurisez votre compte',
                onTap: () => _manage2FA(),
                trailing: settingsProvider.is2FAEnabled
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
              _buildSettingsTile(
                icon: Icons.lock,
                title: 'Changer le mot de passe',
                onTap: () => _changePassword(),
              ),
              _buildSettingsTile(
                icon: Icons.devices,
                title: 'Appareils connectés',
                subtitle: 'Gérer les sessions actives',
                onTap: () => _manageDevices(),
              ),
            ],
          ),
          
          // Professional Mode
          _buildSection(
            title: 'Vendeur professionnel',
            children: [
              SwitchListTile(
                title: const Text('Mode professionnel'),
                subtitle: const Text('Accédez aux fonctionnalités vendeur avancées'),
                value: settingsProvider.isProfessionalMode,
                onChanged: (value) => _toggleProfessionalMode(value),
                secondary: const Icon(Icons.business_center),
              ),
              if (settingsProvider.isProfessionalMode)
                _buildSettingsTile(
                  icon: Icons.subscriptions,
                  title: 'Abonnement Pro',
                  subtitle: settingsProvider.subscriptionStatus ?? 'Activer votre abonnement',
                  onTap: () => _manageSubscription(),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
            ],
          ),
          
          // Privacy
          _buildSection(
            title: 'Confidentialité',
            children: [
              SwitchListTile(
                title: const Text('Profil public'),
                subtitle: const Text('Votre profil est visible par tous'),
                value: settingsProvider.isPublicProfile,
                onChanged: (value) => settingsProvider.togglePublicProfile(value),
                secondary: const Icon(Icons.public),
              ),
              SwitchListTile(
                title: const Text('Afficher mon email'),
                subtitle: const Text('Visible par les acheteurs'),
                value: settingsProvider.showEmail,
                onChanged: (value) => settingsProvider.toggleShowEmail(value),
                secondary: const Icon(Icons.email),
              ),
              SwitchListTile(
                title: const Text('Afficher mon téléphone'),
                subtitle: const Text('Visible par les acheteurs'),
                value: settingsProvider.showPhone,
                onChanged: (value) => settingsProvider.toggleShowPhone(value),
                secondary: const Icon(Icons.phone),
              ),
            ],
          ),
          
          // About
          _buildSection(
            title: 'À propos',
            children: [
              _buildSettingsTile(
                icon: Icons.info,
                title: 'Version',
                subtitle: 'THIX Market v2.0.0',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.description,
                title: 'Conditions d\'utilisation',
                onTap: () => _openTerms(),
              ),
              _buildSettingsTile(
                icon: Icons.privacy_tip,
                title: 'Politique de confidentialité',
                onTap: () => _openPrivacy(),
              ),
            ],
          ),
          
          // Logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => _logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey[200]!),
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildProfileTile(Map<String, dynamic>? user) {
    if (user == null) return const SizedBox();
    
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: user['avatar'] != null
            ? CachedNetworkImageProvider(user['avatar'])
            : null,
        child: user['avatar'] == null
            ? Icon(Icons.person, size: 28, color: Colors.grey[400])
            : null,
      ),
      title: Text(user['name'] ?? user['email']),
      subtitle: Text(user['email'] ?? ''),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () => _editProfile(),
      ),
      onTap: () => _editProfile(),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFE5592F)),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _manageThixMoney() {
    Navigator.pushNamed(context, '/thix-money');
  }

  void _manageCards() {
    Navigator.pushNamed(context, '/payment-methods');
  }

  void _manageMobileMoney() {
    Navigator.pushNamed(context, '/mobile-money');
  }

  void _manageAddresses() {
    Navigator.pushNamed(context, '/addresses');
  }

  void _findPickupPoints() {
    Navigator.pushNamed(context, '/pickup-points');
  }

  void _manage2FA() {
    Navigator.pushNamed(context, '/2fa-setup');
  }

  void _changePassword() {
    Navigator.pushNamed(context, '/change-password');
  }

  void _manageDevices() {
    Navigator.pushNamed(context, '/devices');
  }

  void _toggleProfessionalMode(bool value) async {
    if (value) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Activer le mode professionnel'),
          content: const Text(
            'Le mode professionnel vous donne accès à:\n'
            '• Statistiques avancées\n'
            '• Outils de marketing\n'
            '• Support prioritaire\n'
            '• API d\'intégration\n\n'
            'Souhaitez-vous continuer ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Non'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Oui'),
            ),
          ],
        ),
      );
      
      if (shouldProceed == true) {
        context.read<SettingsProvider>().toggleProfessionalMode(true);
      }
    } else {
      context.read<SettingsProvider>().toggleProfessionalMode(false);
    }
  }

  void _manageSubscription() {
    Navigator.pushNamed(context, '/subscription');
  }

  void _editProfile() {
    Navigator.pushNamed(context, '/edit-profile');
  }

  void _openTerms() {
    Navigator.pushNamed(context, '/terms');
  }

  void _openPrivacy() {
    Navigator.pushNamed(context, '/privacy');
  }

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    
    if (shouldLogout == true) {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }
}
