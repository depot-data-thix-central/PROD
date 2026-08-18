// lib/presentation/admin/pages/admin_news_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../providers/news_provider.dart';
import '../../../models/news_article.dart';
import 'create_news_page.dart';

class AdminNewsDashboard extends StatefulWidget {
  const AdminNewsDashboard({super.key});

  @override
  State<AdminNewsDashboard> createState() => _AdminNewsDashboardState();
}

class _AdminNewsDashboardState extends State<AdminNewsDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<NewsArticle> _articles = [];
  List<NewsArticle> _filteredArticles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedStatus = 'all';

  final List<String> _categories = [
    'all', 'featured', 'politique', 'economie', 'societe', 'tech', 'sport', 'culture', 'international'
  ];

  final Map<String, String> _categoryNames = {
    'all': 'Toutes',
    'featured': 'À la une',
    'politique': 'Politique',
    'economie': 'Économie',
    'societe': 'Société',
    'tech': 'Tech',
    'sport': 'Sport',
    'culture': 'Culture',
    'international': 'International',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadArticles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadArticles() async {
    setState(() => _isLoading = true);
    final provider = context.read<NewsProvider>();
    await provider.fetchArticles();
    setState(() {
      _articles = provider.articles;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    var filtered = List<NewsArticle>.from(_articles);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((a) =>
        a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (a.summary?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    if (_selectedCategory != 'all') {
      filtered = filtered.where((a) => a.category == _selectedCategory).toList();
    }

    if (_selectedStatus != 'all') {
      filtered = filtered.where((a) => a.status == _selectedStatus).toList();
    }

    setState(() => _filteredArticles = filtered);
  }

  Future<void> _deleteArticle(NewsArticle article) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'article'),
        content: Text('Voulez-vous vraiment supprimer "${article.title}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = context.read<NewsProvider>();
      await provider.deleteArticle(article.id);
      await _loadArticles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Article supprimé'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _toggleFeature(NewsArticle article) async {
    final provider = context.read<NewsProvider>();
    await provider.updateArticle(article.id, {'is_featured': !article.isFeatured});
    await _loadArticles();
  }

  Future<void> _toggleBreaking(NewsArticle article) async {
    final provider = context.read<NewsProvider>();
    await provider.updateArticle(article.id, {'is_breaking': !article.isBreaking});
    await _loadArticles();
  }

  Future<void> _updateStatus(NewsArticle article, String newStatus) async {
    final provider = context.read<NewsProvider>();
    await provider.updateArticle(article.id, {'status': newStatus});
    await _loadArticles();
  }

  void _createArticle() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateNewsPage()),
    ).then((_) => _loadArticles());
  }

  void _editArticle(NewsArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateNewsPage(article: article)),
    ).then((_) => _loadArticles());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1B3D),
        elevation: 0,
        title: const Text(
          'Administration THIX INFO',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _createArticle,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadArticles,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4AF37),
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Articles', icon: Icon(Icons.article, size: 18)),
            Tab(text: 'Statistiques', icon: Icon(Icons.bar_chart, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildArticlesTab(),
          _buildStatsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createArticle,
        backgroundColor: const Color(0xFFD4AF37),
        child: const Icon(Icons.add, color: Color(0xFF0B1B3D)),
      ),
    );
  }

  Widget _buildArticlesTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 12),
              _buildCategoryFilter(),
              const SizedBox(height: 8),
              _buildStatusFilter(),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredArticles.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _filteredArticles.length,
                      itemBuilder: (context, index) => _buildArticleCard(_filteredArticles[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _applyFilters();
        },
        decoration: InputDecoration(
          hintText: 'Rechercher un article...',
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(_categoryNames[cat]!, style: const TextStyle(fontSize: 12)),
              onSelected: (_) {
                setState(() => _selectedCategory = cat);
                _applyFilters();
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFFD4AF37).withOpacity(0.15),
              side: BorderSide(color: isSelected ? const Color(0xFFD4AF37) : Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusFilter() {
    final statuses = [
      {'value': 'all', 'label': 'Tous'},
      {'value': 'published', 'label': 'Publiés'},
      {'value': 'draft', 'label': 'Brouillons'},
      {'value': 'archived', 'label': 'Archivés'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.map((status) {
          final isSelected = _selectedStatus == status['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(status['label'] as String, style: const TextStyle(fontSize: 12)),
              onSelected: (_) {
                setState(() => _selectedStatus = status['value'] as String);
                _applyFilters();
              },
              backgroundColor: Colors.white,
              selectedColor: Colors.blue.withOpacity(0.1),
              side: BorderSide(color: isSelected ? Colors.blue : Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildArticleCard(NewsArticle article) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: Image.network(
                    article.imageUrl!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(article.category).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _categoryNames[article.category] ?? article.category,
                              style: TextStyle(fontSize: 9, color: _getCategoryColor(article.category)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: article.status == 'published' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              article.status == 'published' ? 'Publié' : (article.status == 'draft' ? 'Brouillon' : 'Archivé'),
                              style: TextStyle(
                                fontSize: 9,
                                color: article.status == 'published' ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.visibility, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text('${article.viewsCount}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          const SizedBox(width: 16),
                          Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(article.publishedAt),
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 1, color: Colors.grey[200]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildActionButton(
                  icon: article.isFeatured ? Icons.star : Icons.star_border,
                  label: 'À la une',
                  color: article.isFeatured ? const Color(0xFFD4AF37) : Colors.grey,
                  onTap: () => _toggleFeature(article),
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  icon: article.isBreaking ? Icons.flash_on : Icons.flash_off,
                  label: 'Breaking',
                  color: article.isBreaking ? Colors.red : Colors.grey,
                  onTap: () => _toggleBreaking(article),
                ),
                const Spacer(),
                _buildActionButton(
                  icon: Icons.edit,
                  label: 'Modifier',
                  color: Colors.blue,
                  onTap: () => _editArticle(article),
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  icon: Icons.delete,
                  label: 'Supprimer',
                  color: Colors.red,
                  onTap: () => _deleteArticle(article),
                ),
                const SizedBox(width: 16),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  onSelected: (value) => _updateStatus(article, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'published', child: Text('Publier', style: TextStyle(fontSize: 12))),
                    const PopupMenuItem(value: 'draft', child: Text('Mettre en brouillon', style: TextStyle(fontSize: 12))),
                    const PopupMenuItem(value: 'archived', child: Text('Archiver', style: TextStyle(fontSize: 12))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    final totalArticles = _articles.length;
    final publishedArticles = _articles.where((a) => a.status == 'published').length;
    final draftArticles = _articles.where((a) => a.status == 'draft').length;
    final archivedArticles = _articles.where((a) => a.status == 'archived').length;
    final totalViews = _articles.fold(0, (sum, a) => sum + a.viewsCount);
    final featuredArticles = _articles.where((a) => a.isFeatured).length;
    final breakingArticles = _articles.where((a) => a.isBreaking).length;

    final categoryStats = <String, int>{};
    for (var article in _articles) {
      categoryStats[article.category] = (categoryStats[article.category] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Total articles', totalArticles.toString(), Icons.article, Colors.blue),
              _buildStatCard('Publiés', publishedArticles.toString(), Icons.published_with_changes, Colors.green),
              _buildStatCard('Brouillons', draftArticles.toString(), Icons.edit, Colors.orange),
              _buildStatCard('Archivés', archivedArticles.toString(), Icons.archive, Colors.grey),
              _buildStatCard('Vues totales', _formatCount(totalViews), Icons.visibility, Colors.purple),
              _buildStatCard('À la une', featuredArticles.toString(), Icons.star, const Color(0xFFD4AF37)),
              _buildStatCard('Breaking', breakingArticles.toString(), Icons.flash_on, Colors.red),
              _buildStatCard('Moyenne vues', _formatCount(totalArticles > 0 ? totalViews ~/ totalArticles : 0), Icons.bar_chart, Colors.teal),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Articles par catégorie', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...categoryStats.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 100,
                          child: Text(_categoryNames[entry.key] ?? entry.key, style: const TextStyle(fontSize: 12)),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: totalArticles > 0 ? entry.value / totalArticles : 0,
                            backgroundColor: Colors.grey[200],
                            color: _getCategoryColor(entry.key),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(entry.value.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Aucun article', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _createArticle,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
            child: const Text('Créer un article', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'featured': return const Color(0xFFD4AF37);
      case 'politique': return Colors.blue;
      case 'economie': return Colors.green;
      case 'societe': return Colors.purple;
      case 'tech': return Colors.cyan;
      case 'sport': return Colors.orange;
      case 'culture': return Colors.pink;
      case 'international': return Colors.indigo;
      default: return Colors.grey;
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
