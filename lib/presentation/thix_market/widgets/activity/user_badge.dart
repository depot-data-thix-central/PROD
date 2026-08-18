import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserBadge extends StatefulWidget {
  final String userId;
  final double size;

  const UserBadge({super.key, required this.userId, this.size = 40});

  @override
  State<UserBadge> createState() => _UserBadgeState();
}

class _UserBadgeState extends State<UserBadge> {
  List<Map<String, dynamic>> _badges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('user_badges')
          .select('badges(*)')
          .eq('user_id', widget.userId)
          .eq('is_active', true);
      
      setState(() {
        _badges = List<Map<String, dynamic>>.from(response.map((e) => e['badges']));
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading badges: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getBadgeIcon(String type) {
    switch (type) {
      case 'verified':
        return 'assets/icons/verified.png';
      case 'top_seller':
        return 'assets/icons/top_seller.png';
      case 'trusted':
        return 'assets/icons/trusted.png';
      case 'early_bird':
        return 'assets/icons/early_bird.png';
      default:
        return '';
    }
  }

  Color _getBadgeColor(String type) {
    switch (type) {
      case 'verified':
        return Colors.blue;
      case 'top_seller':
        return Colors.amber;
      case 'trusted':
        return Colors.green;
      case 'early_bird':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_badges.isEmpty) {
      return const SizedBox.shrink();
    }

    // Affichage sous forme de rangée d'icônes
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _badges.map((badge) {
        return Container(
          margin: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: badge['name'] ?? 'Badge',
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _getBadgeColor(badge['type']).withOpacity(0.8),
                    _getBadgeColor(badge['type']),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  _getBadgeIconFromType(badge['type']),
                  color: Colors.white,
                  size: widget.size * 0.5,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getBadgeIconFromType(String type) {
    switch (type) {
      case 'verified':
        return Icons.verified;
      case 'top_seller':
        return Icons.emoji_events;
      case 'trusted':
        return Icons.thumb_up;
      case 'early_bird':
        return Icons.access_time;
      default:
        return Icons.star;
    }
  }
}
