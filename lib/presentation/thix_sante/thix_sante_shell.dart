// lib/presentation/thix_sante/thix_sante_shell.dart
// =============================================================================
// Shell: ThixSanteShell
// Role: Conteneur principal module THIX SANTE, gere Patient / Medecin / Pharma
// Design: Respecte ta capture - BottomNav avec bouton central +
// =============================================================================

import 'package:flutter/material.dart';
import 'core/thix_id_validator.dart';
import 'patient/screens/mon_medecin_traitant_page.dart';

class ThixSanteShell extends StatefulWidget {
  final Widget child;
  const ThixSanteShell({super.key, required this.child});

  @override
  State<ThixSanteShell> createState() => _ThixSanteShellState();
}

class _ThixSanteShellState extends State<ThixSanteShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    // TODO: Remplacer par PatientDashboardPage quand pret
    Center(child: Text('Dashboard Patient - voir patient_dashboard_page.dart')),
    MonMedecinTraitantPage(),
    Center(child: Text('Messages')),
    Center(child: Text('Profil')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      body: _currentIndex == 0? widget.child : _pages[_currentIndex],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: ThixSanteColors.surface,
          border: const Border(top: BorderSide(color: ThixSanteColors.borderLight)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(icon: Icons.home_rounded, label: 'Accueil', index: 0, isSelected: _currentIndex == 0),
            _navItem(icon: Icons.favorite_rounded, label: 'Sante', index: 1, isSelected: _currentIndex == 1),
            _buildCentralAction(),
            _navItem(icon: Icons.chat_bubble_rounded, label: 'Messages', index: 2, isSelected: _currentIndex == 2),
            _navItem(icon: Icons.person_rounded, label: 'Profil', index: 3, isSelected: _currentIndex == 3),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected? ThixSanteColors.primary : ThixSanteColors.mutedLight,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected? FontWeight.w700 : FontWeight.w500,
                color: isSelected? ThixSanteColors.primary : ThixSanteColors.mutedLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCentralAction() {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: ThixSanteColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThixSanteColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Actions rapides',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 16),
                _quickActionTile(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Scanner THIX ID Medecin',
                  subtitle: 'Lier votre medecin traitant',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MonMedecinTraitantPage()),
                    );
                  },
                ),
                _quickActionTile(
                  icon: Icons.upload_file_rounded,
                  title: 'Uploader ordonnance',
                  subtitle: 'Photo ou PDF depuis votre telephone',
                ),
                _quickActionTile(
                  icon: Icons.sos_rounded,
                  title: 'SOS Urgence',
                  subtitle: 'Partage position + dossier urgence',
                  isDanger: true,
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ThixSanteColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: ThixSanteColors.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isDanger = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDanger? ThixSanteColors.dangerLight : ThixSanteColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isDanger? ThixSanteColors.danger : ThixSanteColors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: ThixSanteColors.muted)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
