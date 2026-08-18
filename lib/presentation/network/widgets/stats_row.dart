import 'package:flutter/material.dart';

class StatsRow extends StatelessWidget {
  final int? connexionsCount;
  final int? publicationsCount;
  final int? communautesCount;
  final int? messagesCount;
  
  final VoidCallback? onConnexionsTap;
  final VoidCallback? onPublicationsTap;
  final VoidCallback? onCommunitiesTap;
  final VoidCallback? onMessagesTap;
  final bool isLoading;

  const StatsRow({
    super.key,
    this.connexionsCount,
    this.publicationsCount,
    this.communautesCount,
    this.messagesCount,
    this.onConnexionsTap,
    this.onPublicationsTap,
    this.onCommunitiesTap,
    this.onMessagesTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStatCard(connexionsCount, 'Connexions', Icons.people_outline, onConnexionsTap),
        const SizedBox(width: 12),
        _buildStatCard(publicationsCount, 'Publications', Icons.post_add_outlined, onPublicationsTap),
        const SizedBox(width: 12),
        _buildStatCard(communautesCount, 'Communautés', Icons.groups_outlined, onCommunitiesTap),
        const SizedBox(width: 12),
        _buildStatCard(messagesCount, 'Messages', Icons.message_outlined, onMessagesTap),
      ],
    );
  }

  Widget _buildStatCard(int? value, String label, IconData icon, VoidCallback? onTap) {
    final isNull = value == null || isLoading;
    return Expanded(
      child: InkWell(
        onTap: isNull ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.04)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFD4AF37)),
              const SizedBox(height: 6),
              if (isNull)
                Container(width: 24, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))
              else
                Text(_formatNumber(value!), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B1B3D))),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int v) {
    if (v >= 1000000) return '${(v/1000000).toStringAsFixed(v%1000000==0?0:1)}M';
    if (v >= 1000) return '${(v/1000).toStringAsFixed(v%1000==0?0:1)}k';
    return v.toString();
  }
}
