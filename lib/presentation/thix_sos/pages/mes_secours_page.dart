/// THIX SOS — Mes secours / 3 cercles (production)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sos_models.dart';
import '../providers/sos_providers.dart';
import 'ajouter_secours_page.dart';

class MesSecoursPage extends ConsumerWidget {
  const MesSecoursPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(sosContactsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mes secours',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: () => ref.invalidate(sosContactsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFEF4444),
        onPressed: () async {
          final ok = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AjouterSecoursPage()),
          );
          if (ok == true) ref.invalidate(sosContactsProvider);
        },
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: Text(
          'Ajouter',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: contactsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFEF4444)),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                'Erreur de chargement',
                style: GoogleFonts.inter(color: Colors.redAccent),
              ),
              TextButton(
                onPressed: () => ref.invalidate(sosContactsProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (contacts) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _InfoBanner(),
              const SizedBox(height: 20),
              for (final circle in [1, 2, 3]) ...[
                _CircleSection(
                  circle: circle,
                  contacts: contacts.where((c) => c.circle == circle).toList(),
                  onAdd: () async {
                    final ok = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AjouterSecoursPage(initialCircle: circle),
                      ),
                    );
                    if (ok == true) ref.invalidate(sosContactsProvider);
                  },
                  onDelete: (id) async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF16161F),
                        title: Text(
                          'Supprimer ce secours ?',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        content: Text(
                          'Il ne recevra plus les alertes SOS.',
                          style: GoogleFonts.inter(color: Colors.white60),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Supprimer',
                              style: TextStyle(color: Color(0xFFEF4444)),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(sosContactActionsProvider).delete(id);
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F).withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF60A5FA), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cercle 1 est contacté en premier. Sans réponse → Cercle 2 → Cercle 3.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white70,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleSection extends StatelessWidget {
  const _CircleSection({
    required this.circle,
    required this.contacts,
    required this.onAdd,
    required this.onDelete,
  });

  final int circle;
  final List<SosContact> contacts;
  final VoidCallback onAdd;
  final Future<void> Function(String id) onDelete;

  Color get _color {
    switch (circle) {
      case 1:
        return const Color(0xFF10B981);
      case 2:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String get _title {
    switch (circle) {
      case 1:
        return 'Cercle 1 – Prioritaire';
      case 2:
        return 'Cercle 2 – Secondaire';
      default:
        return 'Cercle 3 – Urgence';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$circle',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    color: _color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: Icon(Icons.add, size: 16, color: _color),
              label: Text(
                'Ajouter',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (contacts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16161F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              'Aucun secours dans ce cercle',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white38),
            ),
          )
        else
          ...contacts.map(
            (c) => _ContactTile(
              contact: c,
              accent: _color,
              onDelete: () => onDelete(c.id),
            ),
          ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.accent,
    required this.onDelete,
  });

  final SosContact contact;
  final Color accent;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16161F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: accent.withOpacity(0.25),
            backgroundImage:
                contact.photoUrl != null ? NetworkImage(contact.photoUrl!) : null,
            child: contact.photoUrl == null
                ? Text(
                    contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (contact.relation != null && contact.relation!.isNotEmpty)
                  Text(
                    contact.relation!,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                  ),
                if (contact.phone != null && contact.phone!.isNotEmpty)
                  Text(
                    contact.phone!,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                  ),
              ],
            ),
          ),
          if (contact.verified)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.verified, size: 18, color: Color(0xFF34D399)),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
