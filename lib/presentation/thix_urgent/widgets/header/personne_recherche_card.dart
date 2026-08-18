// lib/presentation/thix_urgent/widgets/header/personne_recherche_card.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersonneRechercheCard extends StatelessWidget {
  const PersonneRechercheCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Stream paginé pour ne pas charger tous les avis de recherche d'un coup (scale 1M)
    final stream = Supabase.instance.client
        .from('personnes_recherchees')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final data = snap.data?.isNotEmpty == true ? snap.data!.first : null;
        
        return Container(
          margin: const EdgeInsets.all(14),
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 4),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              // Photo 1
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                  child: data?['photo_url'] != null
                      ? Image.network(
                          data!['photo_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _Placeholder(),
                          loadingBuilder: (c, child, loading) => loading == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : const _Placeholder(),
                ),
              ),
              Container(width: 4, color: Colors.black),
              // Photo 2 / Info
              Expanded(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: data != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              (data['nom'] ?? 'PERSONNE').toString().toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vu: ${data['derniere_zone'] ?? 'Inconnu'}',
                              style: const TextStyle(fontSize: 8, color: Colors.black54),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                              child: const Text('URGENT', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        )
                      : const Center(child: Text('Photo ici', style: TextStyle(fontSize: 10, color: Colors.black38))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.white, child: const Center(child: Icon(Icons.person, size: 50, color: Colors.black26)));
  }
}
