// lib/presentation/thix_weeding/pages/guest/infos_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/wedding_provider.dart';

class InfosPage extends ConsumerWidget {
  final String weddingId;
  const InfosPage({super.key, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weddingAsync = ref.watch(guestWeddingProvider(weddingId));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Infos'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.mounted) context.pop(); }),
          bottom: const TabBar(tabs: [Tab(text: 'Annonces'), Tab(text: 'FAQ'), Tab(text: 'Merci')]),
        ),
        body: weddingAsync.when(
          data: (wedding) {
            return TabBarView(
              children: [
                // TAB 1 - ANNONCES
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _AnnonceCard(icon: Icons.notifications, color: Colors.pink, title: 'Nouveauté!', subtitle: wedding.announcement.isEmpty? 'Le parking sera disponible à partir de 15h' : wedding.announcement),
                    _AnnonceCard(icon: Icons.info_outline, color: Colors.blue, title: 'Infos importantes', subtitle: 'Cérémonie à 14h précises, merci d’arriver 30min avant'),
                  ],
                ),
                // TAB 2 - FAQ
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    _FaqTile(question: 'Quelle est la tenue vestimentaire?', answer: 'Tenue chic, couleurs claires recommandées. Évitez le blanc et le noir intégral.'),
                    _FaqTile(question: 'Y a-t-il un parking?', answer: 'Oui, parking surveillé disponible à partir de 15h derrière la salle.'),
                    _FaqTile(question: 'Puis-je amener un +1?', answer: 'Merci de confirmer dans le RSVP le nombre exact d’invités.'),
                    _FaqTile(question: 'Les enfants sont-ils invités?', answer: 'Oui, un espace kids avec animateur est prévu.'),
                  ],
                ),
                // TAB 3 - REMERCIEMENTS
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Icon(Icons.favorite, color: Color(0xFFE25A6A), size: 48),
                    const SizedBox(height: 16),
                    Text('Un mot pour vous', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.pink.shade700)),
                    const SizedBox(height: 12),
                    Text(wedding.welcomeMessage, style: const TextStyle(height: 1.6, fontSize: 15)),
                    const SizedBox(height: 24),
                    Text('Avec tout notre amour,\n${wedding.coupleNames}', style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
        ),
      ),
    );
  }
}

class _AnnonceCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _AnnonceCard({required this.icon, required this.color, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle)),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ExpansionTile(title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text(answer, style: const TextStyle(color: Colors.grey, height: 1.4)))]),
    );
  }
}
