// lib/presentation/admin/pages/admin_news_dashboard.dart
import 'package:flutter/material.dart';

// Décommenter si nécessaire dans le futur
// import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
// import '../../../providers/news_provider.dart';
// import '../../../models/news_article.dart';
// import 'create_news_page.dart';

class AdminNewsDashboard extends StatefulWidget {
  const AdminNewsDashboard({super.key});

  @override
  State<AdminNewsDashboard> createState() => _AdminNewsDashboardState();
}

class _AdminNewsDashboardState extends State<AdminNewsDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Variables d'état simplifiées
  bool _isLoading = false;
  List<dynamic> _articles = [];
  List<dynamic> _filteredArticles = [];

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

  // ============================================================================
  // LOGIQUE (Bouchons / Stubs)
  // ============================================================================

  Future<void> _loadArticles() async {
    // TODO: Implémenter le chargement des articles
  }

  void _applyFilters() {
    // TODO: Implémenter le filtrage
  }

  Future<void> _deleteArticle(dynamic article) async {
    // TODO: Implémenter la suppression
  }

  Future<void> _toggleFeature(dynamic article) async {
    // TODO: Implémenter la mise à la une
  }

  Future<void> _toggleBreaking(dynamic article) async {
    // TODO: Implémenter le breaking news
  }

  Future<void> _updateStatus(dynamic article, String newStatus) async {
    // TODO: Implémenter la mise à jour du statut
  }

  void _createArticle() {
    // TODO: Navigation vers la page de création
  }

  void _editArticle(dynamic article) {
    // TODO: Navigation vers la page de modification
  }

  // ============================================================================
  // INTERFACE UTILISATEUR (Squelette)
  // ============================================================================

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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return const Center(
      child: Text('Liste des articles (Squelette)'),
    );
  }

  Widget _buildStatsTab() {
    return const Center(
      child: Text('Statistiques (Squelette)'),
    );
  }
}
