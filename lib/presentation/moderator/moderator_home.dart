// lib/presentation/moderator/moderator_home.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/moderator_provider.dart';
import '../../providers/auth_provider.dart';

class ModeratorHome extends StatefulWidget {
  const ModeratorHome({super.key});

  @override
  State<ModeratorHome> createState() => _ModeratorHomeState();
}

class _ModeratorHomeState extends State<ModeratorHome> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final provider = context.read<ModeratorProvider>();
    final stats = await provider.getStats();
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace modérateur', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.go('/thix-event'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Statistiques', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  _statCard('Total', _stats['total_events']?.toString() ?? '0', Icons.event),
                  _statCard('À venir', _stats['upcoming_events']?.toString() ?? '0', Icons.upcoming),
                ],
              ),
            const SizedBox(height: 8),
            if (!_loading)
              Row(
                children: [
                  _statCard('Vues', _stats['total_views']?.toString() ?? '0', Icons.visibility),
                  _statCard('Likes', _stats['total_likes']?.toString() ?? '0', Icons.favorite),
                ],
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/moderator/events'),
              icon: const Icon(Icons.list),
              label: const Text('Gérer les événements'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF0A1F44),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.push('/moderator/event/create'),
              icon: const Icon(Icons.add),
              label: const Text('Créer un événement'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF2D6CDF),
                foregroundColor: Colors.white,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Connecté en tant que modérateur',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 28, color: const Color(0xFF2D6CDF)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}
