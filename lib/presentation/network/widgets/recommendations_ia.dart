import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/network_service.dart';

class RecommendationsIA extends StatefulWidget {
  final VoidCallback? onPeopleTap;
  final VoidCallback? onOpportunitiesTap;
  final VoidCallback? onCommunitiesTap;

  const RecommendationsIA({
    super.key,
    this.onPeopleTap,
    this.onOpportunitiesTap,
    this.onCommunitiesTap,
  });

  @override
  State<RecommendationsIA> createState() => _RecommendationsIAState();
}

class _RecommendationsIAState extends State<RecommendationsIA> {
  int _peopleCount = 0;
  int _opportunitiesCount = 0;
  int _communitiesCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final service = NetworkService(Supabase.instance.client);
      final counts = await service.getRecommendationsCount();
      setState(() {
        _peopleCount = counts['people'] ?? 0;
        _opportunitiesCount = counts['opportunities'] ?? 0;
        _communitiesCount = counts['communities'] ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _getPeopleLabel() {
    return _peopleCount > 1 ? 'personnes à rencontrer' : 'personne à rencontrer';
  }

  String _getOpportunitiesLabel() {
    return _opportunitiesCount > 1 ? 'opportunités adaptées' : 'opportunité adaptée';
  }

  String _getCommunitiesLabel() {
    return _communitiesCount > 1 ? 'communautés pour vous' : 'communauté pour vous';
  }

  String _formatCount(int count) {
    if (count > 99) return '99+';
    if (count == 0) return '0';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1B3D), Color(0xFF1A2D56)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Recommandations IA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Row(
              children: [
                _buildRecommendationCard(
                  _peopleCount,
                  _getPeopleLabel(),
                  Icons.people,
                  widget.onPeopleTap,
                ),
                const SizedBox(width: 12),
                _buildRecommendationCard(
                  _opportunitiesCount,
                  _getOpportunitiesLabel(),
                  Icons.work,
                  widget.onOpportunitiesTap,
                ),
                const SizedBox(width: 12),
                _buildRecommendationCard(
                  _communitiesCount,
                  _getCommunitiesLabel(),
                  Icons.groups,
                  widget.onCommunitiesTap,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
    int count,
    String label,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFFD4AF37), size: 20),
              const SizedBox(height: 6),
              Text(
                _formatCount(count),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
