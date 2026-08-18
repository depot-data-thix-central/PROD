import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/network_service.dart';

class SettingsNetworkPage extends StatefulWidget {
  const SettingsNetworkPage({super.key});

  @override
  State<SettingsNetworkPage> createState() => _SettingsNetworkPageState();
}

class _SettingsNetworkPageState extends State<SettingsNetworkPage> {
  late NetworkService _networkService;

  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _messageNotifications = true;
  String _privacyLevel = 'public';
  bool _loading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _networkService = NetworkService(Supabase.instance.client);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        setState(() => _loading = false);
        return;
      }

      // ✅ Correction : utiliser 'users' au lieu de 'profiles' selon votre schéma
      // Si vous utilisez 'profiles', remplacez 'users' par 'profiles'
      final response = await supabase
          .from('users')
          .select('notification_settings, privacy_settings')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        final settings = response['notification_settings'] as Map<String, dynamic>?;
        if (settings != null) {
          setState(() {
            _pushNotifications = settings['push'] ?? true;
            _emailNotifications = settings['email'] ?? true;
            _messageNotifications = settings['messages'] ?? true;
          });
        }
        final privacy = response['privacy_settings'] as Map<String, dynamic>?;
        if (privacy != null) {
          setState(() => _privacyLevel = privacy['profile_visibility'] ?? 'public');
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement paramètres: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('Utilisateur non connecté');
      }

      // ✅ Correction : utiliser 'users' ou 'profiles' selon votre table
      await supabase.from('users').update({
        'notification_settings': {
          'push': _pushNotifications,
          'email': _emailNotifications,
          'messages': _messageNotifications,
        },
        'privacy_settings': {
          'profile_visibility': _privacyLevel,
        },
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      setState(() => _hasChanges = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paramètres enregistrés'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Modifications non enregistrées'),
        content: const Text('Voulez-vous enregistrer vos modifications avant de quitter ?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) context.pop();
            },
            child: const Text('Ignorer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveSettings().then((_) {
                if (mounted) context.pop();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                // ✅ Navigation vers la page de login
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1A2E), size: 20),
          onPressed: () {
            if (_hasChanges) {
              _showDiscardDialog();
            } else {
              context.pop();
            }
          },
        ),
        title: const Text(
          'Paramètres',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_hasChanges)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '• Modifié',
                style: TextStyle(
                  color: const Color(0xFFD4AF37),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Notifications
                  _buildSection('🔔 Notifications', [
                    SwitchListTile(
                      title: const Text('Notifications push'),
                      subtitle: const Text('Recevoir les alertes en temps réel'),
                      value: _pushNotifications,
                      onChanged: (v) => setState(() {
                        _pushNotifications = v;
                        _hasChanges = true;
                      }),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.notifications, color: Color(0xFFD4AF37)),
                      ),
                    ),
                    const Divider(height: 0),
                    SwitchListTile(
                      title: const Text('Notifications email'),
                      subtitle: const Text('Recevoir les résumés par email'),
                      value: _emailNotifications,
                      onChanged: (v) => setState(() {
                        _emailNotifications = v;
                        _hasChanges = true;
                      }),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.email, color: Color(0xFFD4AF37)),
                      ),
                    ),
                    const Divider(height: 0),
                    SwitchListTile(
                      title: const Text('Messages privés'),
                      subtitle: const Text('Être notifié des nouveaux messages'),
                      value: _messageNotifications,
                      onChanged: (v) => setState(() {
                        _messageNotifications = v;
                        _hasChanges = true;
                      }),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.chat, color: Color(0xFFD4AF37)),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // Confidentialité
                  _buildSection('🔒 Confidentialité', [
                    _buildPrivacyOption(
                      title: 'Public',
                      subtitle: 'Tout le monde peut voir votre profil',
                      icon: Icons.public,
                      value: 'public',
                    ),
                    _buildPrivacyOption(
                      title: 'Mes connexions',
                      subtitle: 'Seules vos connexions peuvent voir votre profil',
                      icon: Icons.people,
                      value: 'connections',
                    ),
                    _buildPrivacyOption(
                      title: 'Privé',
                      subtitle: 'Personne ne peut voir votre profil',
                      icon: Icons.lock,
                      value: 'private',
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // Actions
                  _buildSection('⚡ Actions', [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.block, color: Colors.red),
                      ),
                      title: const Text('Utilisateurs bloqués'),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => context.push('/network/blocked'),
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.download, color: Colors.blue),
                      ),
                      title: const Text('Exporter mes données'),
                      subtitle: const Text('Télécharger vos informations personnelles'),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        // TODO: Exporter les données
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fonctionnalité bientôt disponible'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // Compte
                  _buildSection('👤 Compte', [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.logout, color: Colors.red),
                      ),
                      title: const Text(
                        'Déconnexion',
                        style: TextStyle(color: Colors.red),
                      ),
                      subtitle: const Text('Se déconnecter de votre compte'),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: _showLogoutDialog,
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // Bouton Enregistrer
                  ElevatedButton(
                    onPressed: _isSaving || !_hasChanges ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasChanges ? const Color(0xFFD4AF37) : Colors.grey.shade300,
                      foregroundColor: _hasChanges ? Colors.white : Colors.grey.shade600,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: _hasChanges ? 2 : 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _hasChanges ? Icons.save : Icons.check_circle,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _hasChanges ? 'ENREGISTRER' : 'AUCUNE MODIFICATION',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
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

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          const Divider(height: 0, thickness: 0.5),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPrivacyOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _privacyLevel == value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: RadioListTile<String>(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? const Color(0xFFD4AF37) : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.grey.shade700 : Colors.grey.shade600,
          ),
        ),
        value: value,
        groupValue: _privacyLevel,
        onChanged: (v) => setState(() {
          if (v != null) {
            _privacyLevel = v;
            _hasChanges = true;
          }
        }),
        activeColor: const Color(0xFFD4AF37),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFD4AF37).withOpacity(0.15)
                : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isSelected ? const Color(0xFFD4AF37) : Colors.grey,
          ),
        ),
        selected: isSelected,
      ),
    );
  }
}
