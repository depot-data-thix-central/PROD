// lib/presentation/thix_market/widgets/dispute/dispute_tile.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DisputeTile extends StatefulWidget {
  final Map<String, dynamic> dispute;
  final Function(Map<String, dynamic>)? onTap;
  final Function(String)? onStatusChange;

  const DisputeTile({
    super.key,
    required this.dispute,
    this.onTap,
    this.onStatusChange,
  });

  @override
  State<DisputeTile> createState() => _DisputeTileState();
}

class _DisputeTileState extends State<DisputeTile> {
  bool _isLoading = false;

  static const Color navy = Color(0xFF1B2A4A);
  static const Color gold = Color(0xFFC9962C);
  static const Color danger = Color(0xFFE53935);
  static const Color textMuted = Color(0xFF8A8FA3);
  static const Color bgApp = Color(0xFFF6F7FB);

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client
          .from('disputes')
          .update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', widget.dispute['id']);

      widget.onStatusChange?.call(newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Litige mis à jour : $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating dispute: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${e.toString()}'),
            backgroundColor: danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showStatusDialog() {
    final statuses = [
      {'value': 'open', 'label': 'Ouvert', 'color': Colors.orange},
      {'value': 'mediation', 'label': 'En médiation', 'color': Colors.blue},
      {'value': 'resolved', 'label': 'Résolu', 'color': Colors.green},
      {'value': 'closed', 'label': 'Fermé', 'color': Colors.grey},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Changer le statut',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy),
            ),
            const SizedBox(height: 16),
            ...statuses.map((status) => ListTile(
              leading: Icon(Icons.circle, color: status['color'] as Color, size: 16),
              title: Text(
                status['label'] as String,
                style: const TextStyle(color: navy),
              ),
              trailing: widget.dispute['status'] == status['value']
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _updateStatus(status['value'] as String);
              },
            )),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'mediation':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'open':
        return 'Ouvert';
      case 'mediation':
        return 'Médiation';
      case 'resolved':
        return 'Résolu';
      case 'closed':
        return 'Fermé';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = widget.dispute['created_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(widget.dispute['created_at']))
        : '';
    final updatedAt = widget.dispute['updated_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(widget.dispute['updated_at']))
        : '';

    return GestureDetector(
      onTap: () => widget.onTap?.call(widget.dispute),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Litige #${widget.dispute['id']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: navy,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(widget.dispute['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusText(widget.dispute['status']),
                      style: TextStyle(
                        color: _getStatusColor(widget.dispute['status']),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.dispute['reason'] ?? 'Motif non spécifié',
                style: const TextStyle(fontSize: 14, color: navy),
              ),
              const SizedBox(height: 8),
              Text(
                'Commande #${widget.dispute['order_id']}',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Ouvert le $createdAt',
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                ],
              ),
              if (widget.dispute['status'] != 'open' && updatedAt.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.update, size: 14, color: textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Dernière mise à jour : $updatedAt',
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              if (widget.dispute['last_message'] != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgApp,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.message, size: 14, color: textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.dispute['last_message'],
                          style: const TextStyle(fontSize: 12, color: navy),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _showStatusDialog,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit, color: navy),
                      label: const Text('Changer statut'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!),
                        foregroundColor: navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _contactSupport,
                      icon: const Icon(Icons.support_agent, color: navy),
                      label: const Text('Contacter support'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!),
                        foregroundColor: navy,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _contactSupport() {
    // À implémenter avec une vraie logique de support
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Support bientôt disponible.'),
        backgroundColor: Color(0xFF1B2A4A),
      ),
    );
  }
}
