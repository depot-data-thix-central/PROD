// lib/presentation/admin/pages/admin_events_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../providers/event_provider.dart';
import '../../../models/event_model.dart';
import 'create_event_page.dart';

class AdminEventsDashboard extends ConsumerStatefulWidget {
  const AdminEventsDashboard({super.key});

  @override
  ConsumerState<AdminEventsDashboard> createState() => _AdminEventsDashboardState();
}

class _AdminEventsDashboardState extends ConsumerState<AdminEventsDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Event> _events = [];
  List<Event> _filteredEvents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedStatus = 'all';

  final List<String> _categories = [
    'all', 'musique', 'conference', 'culture', 'sport', 'festival', 'spectacle', 'exposition'
  ];

  final Map<String, String> _categoryNames = {
    'all': 'Toutes',
    'musique': 'Musique & Concerts',
    'conference': 'Conférences & Séminaires',
    'culture': 'Culture & Art',
    'sport': 'Sport & Loisirs',
    'festival': 'Festivals & Soirées',
    'spectacle': 'Spectacles',
    'exposition': 'Expositions',
  };

  final Map<String, String> _statusNames = {
    'all': 'Tous',
    'upcoming': 'À venir',
    'ongoing': 'En cours',
    'completed': 'Terminés',
    'cancelled': 'Annulés',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvents();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    // Utilisation du service via eventServiceProvider configuré dans ton fichier Riverpod
    final service = ref.read(eventServiceProvider);
    try {
      final fetchedEvents = await service.getEvents(page: 0, limit: 100);
      if (mounted) {
        setState(() {
          _events = fetchedEvents;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    var filtered = List<Event>.from(_events);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((e) =>
        e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        e.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        e.location.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (_selectedCategory != 'all') {
      filtered = filtered.where((e) => e.category == _selectedCategory).toList();
    }

    if (_selectedStatus != 'all') {
      filtered = filtered.where((e) => e.status == _selectedStatus).toList();
    }

    setState(() => _filteredEvents = filtered);
  }

  Future<void> _deleteEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'événement'),
        content: Text('Voulez-vous vraiment supprimer "${event.title}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(eventServiceProvider);
      await service.deleteEvent(event.id);
      await _loadEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Événement supprimé'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _toggleFeature(Event event) async {
    final service = ref.read(eventServiceProvider);
    await service.updateEvent(event.id, {'is_featured': !event.isFeatured});
    await _loadEvents();
  }

  void _createEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateEventPage()),
    ).then((_) => _loadEvents());
  }

  void _editEvent(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateEventPage(event: event)),
    ).then((_) => _loadEvents());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1B3D),
        elevation: 0,
        title: const Text(
          'Administration THIX ÉVÉNEMENT',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _createEvent,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadEvents,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4AF37),
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Événements', icon: Icon(Icons.event, size: 18)),
            Tab(text: 'Statistiques', icon: Icon(Icons.bar_chart, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEventsTab(),
          _buildStatsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createEvent,
        backgroundColor: const Color(0xFFD4AF37),
        child: const Icon(Icons.add, color: Color(0xFF0B1B3D)),
      ),
    );
  }

  Widget _buildEventsTab() {
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
              : _filteredEvents.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _filteredEvents.length,
                      itemBuilder: (context, index) => _buildEventCard(_filteredEvents[index]),
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
        decoration: const InputDecoration(
          hintText: 'Rechercher un événement...',
          hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
          prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusNames.entries.map((entry) {
          final isSelected = _selectedStatus == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(entry.value, style: const TextStyle(fontSize: 12)),
              onSelected: (_) {
                setState(() => _selectedStatus = entry.key);
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

  Widget _buildEventCard(Event event) {
    final statusColor = event.status == 'upcoming' ? Colors.green : 
                        event.status == 'ongoing' ? Colors.orange :
                        event.status == 'completed' ? Colors.grey : Colors.red;
    
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
              if (event.imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: Image.network(
                    event.imageUrl!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[200],
                      child: const Icon(Icons.event, size: 40, color: Colors.grey),
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
                        event.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _categoryNames[event.category] ?? event.category,
                              style: const TextStyle(fontSize: 9, color: Color(0xFFD4AF37)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _statusNames[event.status] ?? event.status,
                              style: TextStyle(fontSize: 9, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(event.startDate),
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            event.location,
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.visibility, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text('${event.viewsCount} vues', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          const SizedBox(width: 16),
                          Icon(Icons.favorite, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text('${event.likesCount}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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
                  icon: event.isFeatured ? Icons.star : Icons.star_border,
                  label: 'À la une',
                  color: event.isFeatured ? const Color(0xFFD4AF37) : Colors.grey,
                  onTap: () => _toggleFeature(event),
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  icon: Icons.edit,
                  label: 'Modifier',
                  color: Colors.blue,
                  onTap: () => _editEvent(event),
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  icon: Icons.delete,
                  label: 'Supprimer',
                  color: Colors.red,
                  onTap: () => _deleteEvent(event),
                ),
                const Spacer(),
                Text(
                  event.formattedPrice,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
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
    final totalEvents = _events.length;
    final upcomingEvents = _events.where((e) => e.status == 'upcoming').length;
    final ongoingEvents = _events.where((e) => e.status == 'ongoing').length;
    final completedEvents = _events.where((e) => e.status == 'completed').length;
    final cancelledEvents = _events.where((e) => e.status == 'cancelled').length;
    final featuredEvents = _events.where((e) => e.isFeatured).length;
    final freeEvents = _events.where((e) => e.isFree).length;
    final totalViews = _events.fold(0, (sum, e) => sum + e.viewsCount);
    final totalLikes = _events.fold(0, (sum, e) => sum + e.likesCount);

    final categoryStats = <String, int>{};
    for (var event in _events) {
      categoryStats[event.category] = (categoryStats[event.category] ?? 0) + 1;
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
              _buildStatCard('Total événements', totalEvents.toString(), Icons.event, Colors.blue),
              _buildStatCard('À venir', upcomingEvents.toString(), Icons.calendar_today, Colors.green),
              _buildStatCard('En cours', ongoingEvents.toString(), Icons.play_circle, Colors.orange),
              _buildStatCard('Terminés', completedEvents.toString(), Icons.check_circle, Colors.grey),
              _buildStatCard('Annulés', cancelledEvents.toString(), Icons.cancel, Colors.red),
              _buildStatCard('À la une', featuredEvents.toString(), Icons.star, const Color(0xFFD4AF37)),
              _buildStatCard('Gratuits', freeEvents.toString(), Icons.money_off, Colors.teal),
              _buildStatCard('Vues totales', _formatCount(totalViews), Icons.visibility, Colors.purple),
              _buildStatCard('Likes totaux', _formatCount(totalLikes), Icons.favorite, Colors.pink),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Événements par catégorie', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...categoryStats.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(_categoryNames[entry.key] ?? entry.key, style: const TextStyle(fontSize: 12)),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: totalEvents > 0 ? entry.value / totalEvents : 0,
                            backgroundColor: Colors.grey[200],
                            color: const Color(0xFFD4AF37),
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
          Icon(Icons.event_busy, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Aucun événement', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _createEvent,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
            child: const Text('Créer un événement', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
