// lib/presentation/moderator/moderator_event_list.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/moderator_provider.dart';
import '../../models/event_model.dart';

class ModeratorEventList extends StatefulWidget {
  const ModeratorEventList({super.key});

  @override
  State<ModeratorEventList> createState() => _ModeratorEventListState();
}

class _ModeratorEventListState extends State<ModeratorEventList> {
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final provider = context.read<ModeratorProvider>();
    await provider.loadAllEvents(status: _statusFilter == 'all' ? null : _statusFilter);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ModeratorProvider>(context);
    final events = provider.events;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Événements'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.go('/moderator'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip('Tous', 'all'),
                _filterChip('À venir', 'upcoming'),
                _filterChip('En cours', 'ongoing'),
                _filterChip('Passés', 'completed'),
                _filterChip('Annulés', 'cancelled'),
              ],
            ),
          ),
          // Liste
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? Center(child: Text('Erreur: ${provider.error}'))
                    : events.isEmpty
                        ? const Center(child: Text('Aucun événement'))
                        : ListView.builder(
                            itemCount: events.length,
                            itemBuilder: (context, index) {
                              final event = events[index];
                              return _buildEventTile(event);
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/moderator/event/create'),
        child: const Icon(Icons.add),
        backgroundColor: const Color(0xFF2D6CDF),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (selected) {
          if (selected) {
            setState(() => _statusFilter = value);
            _loadEvents();
          }
        },
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF2D6CDF).withOpacity(0.15),
        side: BorderSide(color: isSelected ? const Color(0xFF2D6CDF) : Colors.grey[300]!),
      ),
    );
  }

  Widget _buildEventTile(Event event) {
    Color statusColor;
    switch (event.status) {
      case 'upcoming':
        statusColor = Colors.green;
        break;
      case 'ongoing':
        statusColor = Colors.orange;
        break;
      case 'completed':
        statusColor = Colors.grey;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return ListTile(
      leading: event.imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(event.imageUrl!, width: 50, height: 50, fit: BoxFit.cover),
            )
          : Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.event, color: Colors.grey),
            ),
      title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${event.formattedDate} • ${event.location}'),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              event.status.toUpperCase(),
              style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF2D6CDF)),
            onPressed: () => context.push('/moderator/event/edit/${event.id}'),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(event.id),
          ),
        ],
      ),
      onTap: () => context.push('/thix-event/event/${event.id}'),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cet événement ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(_);
              await context.read<ModeratorProvider>().deleteEvent(id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Événement supprimé'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
