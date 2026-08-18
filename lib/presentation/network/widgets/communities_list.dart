import 'package:flutter/material.dart';
import 'package:thix_id/models/network_community.dart';

class CommunitiesList extends StatelessWidget {
  final List<NetworkCommunity> communities;
  final void Function(String) onCommunityTap;
  final void Function(String) onJoinTap;

  const CommunitiesList({
    super.key,
    required this.communities,
    required this.onCommunityTap,
    required this.onJoinTap,
  });

  @override
  Widget build(BuildContext context) {
    if (communities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Aucune communauté', style: TextStyle(color: Colors.grey))),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // si dans SingleChildScrollView parent
      itemCount: communities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final c = communities[i];
        final initial = c.name.isNotEmpty? c.name[0].toUpperCase() : '?';
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onCommunityTap(c.id),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text(initial, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B1B3D)))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${c.membersCount} membres', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => onJoinTap(c.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: const Color(0xFF0B1B3D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      minimumSize: const Size(78, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      elevation: 0,
                    ),
                    child: const Text('Rejoindre', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
