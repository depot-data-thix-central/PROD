// lib/presentation/thix_market/widgets/dispute/mediation_badge.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ IMPORT MANQUANT

class MediationBadge extends StatefulWidget {
  final String disputeId;
  final String? currentMediatorId;

  const MediationBadge({
    super.key,
    required this.disputeId,
    this.currentMediatorId,
  });

  @override
  State<MediationBadge> createState() => _MediationBadgeState();
}

class _MediationBadgeState extends State<MediationBadge> {
  Map<String, dynamic>? _mediation;
  bool _isLoading = true;

  static const Color navy = Color(0xFF1B2A4A);
  static const Color gold = Color(0xFFC9962C);
  static const Color danger = Color(0xFFE53935);
  static const Color textMuted = Color(0xFF8A8FA3);
  static const Color bgApp = Color(0xFFF6F7FB);

  @override
  void initState() {
    super.initState();
    _loadMediation();
  }

  Future<void> _loadMediation() async {
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('mediations')
          .select('*, mediator:users(name, avatar, rating)')
          .eq('dispute_id', widget.disputeId)
          .maybeSingle();

      setState(() {
        _mediation = response;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading mediation: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestMediation() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter')),
      );
      return;
    }

    try {
      await Supabase.instance.client
          .from('mediations')
          .insert({
            'dispute_id': widget.disputeId,
            'status': 'pending',
            'requested_by': userId,
            'requested_at': DateTime.now().toIso8601String(),
          });

      await _loadMediation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de médiation envoyée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error requesting mediation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: gold),
      );
    }

    if (_mediation != null) {
      final status = _mediation!['status'];
      final mediator = _mediation!['mediator'];
      final statusText = status == 'accepted'
          ? 'Médiation acceptée'
          : status == 'pending'
              ? 'Médiation en attente'
              : 'Médiation en cours';
      final statusIcon = status == 'accepted'
          ? Icons.check_circle_outline
          : status == 'pending'
              ? Icons.hourglass_empty
              : Icons.gavel;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: status == 'accepted'
              ? Colors.green.withOpacity(0.1)
              : status == 'pending'
                  ? Colors.orange.withOpacity(0.1)
                  : gold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status == 'accepted'
                ? Colors.green
                : status == 'pending'
                    ? Colors.orange
                    : gold,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              statusIcon,
              size: 18,
              color: status == 'accepted'
                  ? Colors.green
                  : status == 'pending'
                      ? Colors.orange
                      : gold,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: status == 'accepted'
                        ? Colors.green
                        : status == 'pending'
                            ? Colors.orange
                            : gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (mediator != null)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: mediator['avatar'] != null
                            ? CachedNetworkImageProvider(mediator['avatar']) // ✅ maintenant reconnu
                            : null,
                        child: mediator['avatar'] == null
                            ? Icon(Icons.person, size: 10, color: textMuted)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Médiateur: ${mediator['name']}',
                        style: TextStyle(
                          fontSize: 10,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(width: 8),
            if (status == 'accepted')
              const Icon(Icons.check_circle, size: 16, color: Colors.green),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _requestMediation,
      icon: const Icon(Icons.gavel, size: 16),
      label: const Text('Demander une médiation'),
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: navy,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
    );
  }
}
