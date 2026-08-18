// lib/presentation/mon_pays/admin/admin_authorities_page.dart
// Administration des autorités avec :
// - Liste complète avec actions CRUD
// - Recherche et filtres
// - Confirmation de suppression
// - Compteur et statistiques
// - Mode édition

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/authorities_provider.dart';
import '../providers/favorites_provider.dart';
import '../models/authority.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'admin_authority_form_page.dart';
import 'widgets/admin_confirmation_dialog.dart';

class AdminAuthoritiesPage extends ConsumerStatefulWidget {
  const AdminAuthoritiesPage({super.key});

  @override
  ConsumerState<AdminAuthoritiesPage> createState() => _AdminAuthoritiesPageState();
}

class _AdminAuthoritiesPageState extends ConsumerState<AdminAuthoritiesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Tous';
  String _selectedFilter = 'Tous'; // 'Tous', 'Avec photo', 'Sans photo'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminAuthoritiesProvider);
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterBar(),
          const Divider(height: 1),
          // Statistiques
          _buildStatsBar(adminState, favorites),
          // Liste
          Expanded(
            child: adminState.when(
              loading: () => _buildLoadingState(),
              error: (error, stack) => _buildErrorState(error),
              data: (authorities) => _buildListState(authorities, favorites),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // ==================== APP BAR ====================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Administration – Autorités'),
      backgroundColor: Colors.red.shade700,
      foregroundColor: Colors.white,
      actions: [
        // Bouton rafraîchir
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.read(adminAuthoritiesProvider.notifier).loadAuthorities();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Rafraîchissement en cours...'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          tooltip: 'Rafraîchir',
        ),
        // Bouton exporter (TODO)
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Exportation en cours de développement'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          tooltip: 'Exporter',
        ),
        // Bouton aide
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: () {
            _showHelpDialog(context);
          },
          tooltip: 'Aide',
        ),
      ],
      elevation: 4,
    );
  }

  // ==================== SEARCH BAR ====================

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une autorité...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A5276).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Color(0xFF1A5276)),
              onPressed: () {
                print('🛠️ Clic sur le + de la barre de recherche');
                // 🔧 Correction : utilisation de Navigator.push
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminAuthorityFormPage()),
                );
              },
              tooltip: 'Ajouter',
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FILTER BAR ====================

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Filtre par catégorie
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Tous', _selectedCategory == 'Tous', () {
                    setState(() => _selectedCategory = 'Tous');
                  }),
                  ...MonPaysConstants.authorityCategories
                      .where((cat) => cat != 'Tous')
                      .map((cat) => _buildFilterChip(cat, _selectedCategory == cat, () {
                        setState(() => _selectedCategory = cat);
                      }))
                      .toList(),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filtre photo
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_alt),
            tooltip: 'Filtres avancés',
            onSelected: (value) {
              setState(() => _selectedFilter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Tous', child: Text('Tous')),
              const PopupMenuItem(value: 'Avec photo', child: Text('Avec photo')),
              const PopupMenuItem(value: 'Sans photo', child: Text('Sans photo')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.grey.shade100,
        selectedColor: const Color(0xFF1A5276).withOpacity(0.12),
        checkmarkColor: const Color(0xFF1A5276),
        side: selected
            ? const BorderSide(color: Color(0xFF1A5276), width: 1.5)
            : BorderSide(color: Colors.grey.shade300, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  // ==================== STATS BAR ====================

  Widget _buildStatsBar(AsyncValue<List<Authority>> state, Set<String> favorites) {
    final total = state.hasValue ? state.value!.length : 0;
    final withPhoto = state.hasValue
        ? state.value!.where((a) => a.imageUrl != null && a.imageUrl!.isNotEmpty).length
        : 0;
    final favorited = state.hasValue
        ? state.value!.where((a) => favorites.contains(a.id)).length
        : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.people,
            label: 'Total',
            value: total.toString(),
            color: Colors.blue,
          ),
          _buildStatItem(
            icon: Icons.image,
            label: 'Avec photo',
            value: withPhoto.toString(),
            color: Colors.green,
          ),
          _buildStatItem(
            icon: Icons.favorite,
            label: 'Favoris',
            value: favorited.toString(),
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ==================== LOADING STATE ====================

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A5276)),
          ),
          SizedBox(height: 16),
          Text('Chargement des autorités...'),
        ],
      ),
    );
  }

  // ==================== ERROR STATE ====================

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              color: Colors.red.shade400,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(adminAuthoritiesProvider.notifier).loadAuthorities();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== LIST STATE ====================

  Widget _buildListState(List<Authority> authorities, Set<String> favorites) {
    // Appliquer les filtres
    List<Authority> filteredList = authorities;

    // Filtre par catégorie
    if (_selectedCategory != 'Tous') {
      filteredList = filteredList.where((a) => a.title == _selectedCategory).toList();
    }

    // Filtre de recherche
    final searchQuery = _searchController.text.trim().toLowerCase();
    if (searchQuery.isNotEmpty) {
      filteredList = filteredList.where((a) =>
          a.name.toLowerCase().contains(searchQuery) ||
          a.title.toLowerCase().contains(searchQuery) ||
          (a.party.toLowerCase().contains(searchQuery))).toList();
    }

    // Filtre photo
    if (_selectedFilter == 'Avec photo') {
      filteredList = filteredList.where((a) => a.imageUrl != null && a.imageUrl!.isNotEmpty).toList();
    } else if (_selectedFilter == 'Sans photo') {
      filteredList = filteredList.where((a) => a.imageUrl == null || a.imageUrl!.isEmpty).toList();
    }

    if (filteredList.isEmpty) {
      return _buildEmptyState(searchQuery.isNotEmpty);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final authority = filteredList[index];
        final isFavorite = favorites.contains(authority.id);
        return _buildAuthorityCard(authority, isFavorite);
      },
    );
  }

  // ==================== AUTHORITY CARD ====================

  Widget _buildAuthorityCard(Authority authority, bool isFavorite) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: authority.imageUrl != null && authority.imageUrl!.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(authority.imageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
            color: Colors.grey.shade300,
          ),
          child: authority.imageUrl == null || authority.imageUrl!.isEmpty
              ? Center(
                  child: Text(
                    MonPaysHelpers.getInitials(authority.name),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A5276),
                    ),
                  ),
                )
              : null,
        ),
        title: Text(
          authority.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authority.title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (authority.party.isNotEmpty)
                    Text(
                      authority.party,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicateur de favori
            if (isFavorite)
              const Icon(
                Icons.star,
                color: Colors.amber,
                size: 16,
              ),
            const SizedBox(width: 4),
            // Bouton favori rapide
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : Colors.grey,
                size: 18,
              ),
              onPressed: () {
                ref.read(favoritesProvider.notifier).toggleFavorite(authority.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isFavorite
                          ? 'Retiré des favoris'
                          : 'Ajouté aux favoris ⭐',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            // Bouton modifier
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: () {
                print('🛠️ Clic sur Modifier pour ${authority.name}');
                // 🔧 Correction : utilisation de Navigator.push avec extra
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminAuthorityFormPage(authority: authority),
                  ),
                );
              },
              tooltip: 'Modifier',
            ),
            // Bouton supprimer
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () {
                _showDeleteConfirmation(context, authority.id);
              },
              tooltip: 'Supprimer',
            ),
          ],
        ),
        onTap: () {
          // TODO: Voir le détail
        },
      ),
    );
  }

  // ==================== EMPTY STATE ====================

  Widget _buildEmptyState(bool isSearching) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? 'Aucun résultat trouvé' : 'Aucune autorité enregistrée',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? 'Essayez de modifier votre recherche'
                : 'Appuyez sur le bouton + pour ajouter',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
          ),
          if (isSearching) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Effacer la recherche'),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== FLOATING ACTION BUTTON ====================

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () {
        print('🛠️ Clic sur le FAB +');
        // 🔧 Correction : utilisation de Navigator.push
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminAuthorityFormPage()),
        );
      },
      backgroundColor: Colors.red.shade700,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add),
      tooltip: 'Ajouter une autorité',
    );
  }

// ==================== DELETE CONFIRMATION ====================

void _showDeleteConfirmation(BuildContext context, String id) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirmer la suppression'),
      content: const Text(
        'Voulez-vous vraiment supprimer cette autorité ?\n\nCette action est irréversible.',
        style: TextStyle(fontSize: 14),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () async {
            // Fermer le dialogue
            Navigator.pop(ctx);
            // Afficher un indicateur de chargement
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Suppression en cours...'),
                duration: Duration(milliseconds: 500),
              ),
            );
            try {
              // Appeler la suppression
              await ref.read(adminAuthoritiesProvider.notifier).deleteAuthority(id);
              // Notification de succès
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Autorité supprimée avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              // Gestion d'erreur
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors de la suppression : ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
}
  // ==================== HELP DIALOG ====================

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Administration - Aide'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🔍 Rechercher: Utilisez la barre de recherche pour filtrer.'),
            SizedBox(height: 8),
            Text('🏷️ Filtres: Cliquez sur les chips pour filtrer par catégorie.'),
            SizedBox(height: 8),
            Text('📊 Statistiques: Visualisez le nombre total, avec photo et favoris.'),
            SizedBox(height: 8),
            Text('✏️ Modifier: Cliquez sur l\'icône crayon.'),
            SizedBox(height: 8),
            Text('🗑️ Supprimer: Cliquez sur l\'icône poubelle (confirmation requise).'),
            SizedBox(height: 8),
            Text('⭐ Favoris: Ajoutez/retirez des favoris en un clic.'),
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
}
