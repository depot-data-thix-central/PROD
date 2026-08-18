// lib/presentation/opportunities/opportunity_admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🌟 Ajout de Supabase

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

class OpportunityAdminDashboard extends StatefulWidget {
  const OpportunityAdminDashboard({super.key});

  @override
  State<OpportunityAdminDashboard> createState() => _OpportunityAdminDashboardState();
}

class _OpportunityAdminDashboardState extends State<OpportunityAdminDashboard> {
  // On utilise directement la liste brute de Supabase pour avoir accès au champ "status"
  late Future<List<Map<String, dynamic>>> _opportunitiesFuture;
  
  String _currentFilter = 'Toutes';
  final List<String> _filters = ['Toutes', 'Publiées', 'Brouillons', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      // 🌟 REQUÊTE DIRECTE SUR SUPABASE
      _opportunitiesFuture = Supabase.instance.client
          .from('thix_opportunities')
          .select('*')
          .order('created_at', ascending: false);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS D'ADMINISTRATION REELLES SUR SUPABASE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _deleteOpportunity(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: const Text('Supprimer définitivement ?', style: TextStyle(color: ThixPolicy.danger, fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text('Êtes-vous sûr de vouloir supprimer "${item['title']}" ? Cette action est irréversible.', style: const TextStyle(color: ThixPolicy.textMain)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: ThixPolicy.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 🌟 VRAIE SUPPRESSION SUPABASE DECOMMENTÉE
        await Supabase.instance.client.from('thix_opportunities').delete().eq('id', item['id']);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opportunité supprimée avec succès.', style: TextStyle(color: Colors.white)), backgroundColor: ThixPolicy.success));
        }
        _loadData(); // Rafraîchir la liste
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e', style: const TextStyle(color: Colors.white)), backgroundColor: ThixPolicy.danger));
        }
      }
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> item, String newStatus) async {
    try {
      // 🌟 VRAIE MISE A JOUR SUPABASE DECOMMENTÉE
      await Supabase.instance.client.from('thix_opportunities').update({'status': newStatus}).eq('id', item['id']);
      
      String msg = 'Statut mis à jour.';
      if (newStatus == 'draft') msg = 'Déplacé vers les brouillons.';
      if (newStatus == 'published') msg = 'Opportunité publiée en ligne.';
      if (newStatus == 'countdown') msg = 'Compte à rebours d\'urgence activé !';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white)), backgroundColor: newStatus == 'countdown' ? ThixPolicy.warning : ThixPolicy.success));
      }
      _loadData(); // Rafraîchit la vue
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e', style: const TextStyle(color: Colors.white)), backgroundColor: ThixPolicy.danger));
      }
    }
  }

  void _showActionMenu(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s12, ThixPolicy.s20, ThixPolicy.s32),
        decoration: const BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: ThixPolicy.s24),
            Text(item['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)),
            const SizedBox(height: ThixPolicy.s16),
            const Divider(height: 1, color: ThixPolicy.border),
            const SizedBox(height: ThixPolicy.s8),

            _buildActionItem(Icons.edit_rounded, 'Modifier l\'opportunité', ThixPolicy.textMain, () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La page de modification (Edit) arrive bientôt !')));
            }),
            
            if (item['status'] != 'draft')
              _buildActionItem(Icons.visibility_off_rounded, 'Mettre en brouillon', ThixPolicy.textMain, () {
                Navigator.pop(ctx);
                _updateStatus(item, 'draft');
              }),
            
            if (item['status'] == 'draft')
              _buildActionItem(Icons.public_rounded, 'Publier l\'opportunité', ThixPolicy.success, () {
                Navigator.pop(ctx);
                _updateStatus(item, 'published');
              }),
            
            if (item['status'] != 'countdown')
              _buildActionItem(Icons.timer_rounded, 'Activer le compte à rebours', ThixPolicy.warning, () {
                Navigator.pop(ctx);
                _updateStatus(item, 'countdown');
              }),

            _buildActionItem(Icons.delete_outline_rounded, 'Supprimer définitivement', ThixPolicy.danger, () {
              Navigator.pop(ctx);
              _deleteOpportunity(item);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI PRINCIPALE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 20),
          onPressed: () => context.pop(), // Retour à l'appli principale
        ),
        title: const Text('Gestion des Opportunités', style: TextStyle(color: ThixPolicy.textMain, fontSize: 16, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: ThixPolicy.border, height: 1)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.selectionClick();
          context.push('/opportunities/admin/create'); 
        },
        backgroundColor: ThixPolicy.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Créer', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtres Rapides
          Container(
            color: ThixPolicy.card,
            padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s16),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final isSelected = _currentFilter == _filters[i];
                  return InkWell(
                    onTap: () => setState(() => _currentFilter = _filters[i]),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? ThixPolicy.inkDeep : ThixPolicy.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? ThixPolicy.inkDeep : ThixPolicy.border),
                      ),
                      child: Text(_filters[i], style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: isSelected ? Colors.white : ThixPolicy.textSecondary)),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Liste des Opportunités
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _opportunitiesFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
                }

                final rawList = snap.data ?? [];
                
                // 🌟 LE VRAI FILTRAGE DES DONNÉES
                List<Map<String, dynamic>> filteredList = rawList;
                if (_currentFilter == 'Publiées') {
                  filteredList = rawList.where((o) => o['status'] == 'published').toList();
                } else if (_currentFilter == 'Brouillons') {
                  filteredList = rawList.where((o) => o['status'] == 'draft').toList();
                } else if (_currentFilter == 'Urgent') {
                  filteredList = rawList.where((o) => o['status'] == 'countdown').toList();
                }

                if (filteredList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 64, color: ThixPolicy.borderStrong),
                        const SizedBox(height: 16),
                        const Text('Aucune opportunité trouvée.', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(ThixPolicy.s16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    return _buildAdminCard(filteredList[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> item) {
    // Lecture des vraies valeurs de Supabase
    String status = item['status'] ?? 'published';
    Color statusColor = ThixPolicy.success;
    String statusLabel = 'Publiée';
    IconData statusIcon = Icons.check_circle_rounded;

    if (status == 'draft') {
      statusColor = ThixPolicy.textSecondary;
      statusLabel = 'Brouillon';
      statusIcon = Icons.visibility_off_rounded;
    } else if (status == 'countdown') {
      statusColor = ThixPolicy.warning;
      statusLabel = 'Urgent (Décompte)';
      statusIcon = Icons.timer_rounded;
    }

    final String title = item['title'] ?? 'Sans Titre';
    final String organizer = item['organizer'] ?? 'Organisateur inconnu';
    
    DateTime deadlineDate = DateTime.now();
    if (item['deadline'] != null) {
      deadlineDate = DateTime.parse(item['deadline']);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: ThixPolicy.s16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s12, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz_rounded, color: ThixPolicy.textSecondary),
                  onPressed: () => _showActionMenu(item),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, 0, ThixPolicy.s16, ThixPolicy.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.apartment_rounded, size: 14, color: ThixPolicy.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(organizer, style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600))),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: ThixPolicy.border),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Date limite', style: TextStyle(fontSize: 10, color: ThixPolicy.textMuted, fontWeight: FontWeight.w600)),
                        Text(DateFormat('dd MMM yyyy', 'fr_FR').format(deadlineDate), style: const TextStyle(fontSize: 12, color: ThixPolicy.textMain, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
