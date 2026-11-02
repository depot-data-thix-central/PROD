// lib/presentation/thix_weeding/pages/provider_portal/my_activities_page.dart
// ============================================================================
// MES ACTIVITÉS PRESTATAIRE — 1 compte = plusieurs métiers (traiteur, salle…)
// Calqué sur my_weddings_page (liste + création multiple)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';

class _P {
  static const bg = Color(0xFFFFF5F8);
  static const surface = Colors.white;
  static const rose = Color(0xFFFF4D6D);
  static const roseDark = Color(0xFFC2185B);
  static const roseLight = Color(0xFFFF85A1);
  static const ink = Color(0xFF1A1A2E);
  static const inkSoft = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const green = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const purple = Color(0xFF8B5CF6);
  static const grad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF4D6D), Color(0xFFFF85A1)],
  );
  static BoxDecoration card({double r = 20}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: line),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      );
}

String _catLabel(String? k) {
  switch ((k ?? '').toLowerCase()) {
    case 'salle': return 'Salle de réception';
    case 'traiteur': return 'Traiteur';
    case 'photographe': return 'Photographe';
    case 'videaste': return 'Vidéaste';
    case 'decorateur': return 'Décorateur';
    case 'dj': return 'DJ / Sonorisation';
    case 'mc': return 'MC / Animateur';
    case 'maquilleur': return 'Maquillage / Coiffure';
    case 'patissier': return 'Pâtissier';
    case 'fleuriste': return 'Fleuriste';
    default: return k ?? 'Activité';
  }
}

IconData _catIcon(String? k) {
  switch ((k ?? '').toLowerCase()) {
    case 'salle': return Icons.villa_outlined;
    case 'traiteur': return Icons.restaurant_outlined;
    case 'photographe': return Icons.camera_alt_outlined;
    case 'videaste': return Icons.videocam_outlined;
    case 'decorateur': return Icons.auto_awesome_outlined;
    case 'dj': return Icons.music_note_outlined;
    case 'mc': return Icons.mic_outlined;
    case 'maquilleur': return Icons.face_retouching_natural_outlined;
    case 'patissier': return Icons.cake_outlined;
    case 'fleuriste': return Icons.local_florist_outlined;
    default: return Icons.storefront_outlined;
  }
}

class MyActivitiesPage extends ConsumerStatefulWidget {
  const MyActivitiesPage({super.key});
  @override
  ConsumerState<MyActivitiesPage> createState() => _MyActivitiesPageState();
}

class _MyActivitiesPageState extends ConsumerState<MyActivitiesPage> {
  Future<void> _refresh(String userId) async {
    ref.invalidate(myActivitiesProvider(userId));
    await ref.read(myActivitiesProvider(userId).future);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const _AuthRequired();
    final async = ref.watch(myActivitiesProvider(user.id));

    return Scaffold(
      backgroundColor: _P.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _P.rose,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/thix-weeding/provider/activities/new'),
        icon: const Icon(Icons.add_rounded),
        label: Text('Nouvelle activité', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _P.rose)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 40, color: _P.rose),
              const SizedBox(height: 10),
              Text('$e', textAlign: TextAlign.center, style: GoogleFonts.inter(color: _P.inkSoft)),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => _refresh(user.id), child: const Text('Réessayer')),
            ]),
          ),
        ),
        data: (activities) => CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _AppBar(count: activities.length),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (activities.isEmpty)
                    const _Empty()
                  else
                    RefreshIndicator(
                      color: _P.rose,
                      onRefresh: () => _refresh(user.id),
                      child: Column(
                        children: activities
                            .map((a) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _ActivityCard(activity: a, userId: user.id),
                                ))
                            .toList(),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  final int count;
  const _AppBar({required this.count});
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 150,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
          child: const Icon(Icons.arrow_back_ios_new, size: 14, color: _P.ink),
        ),
        onPressed: () => context.canPop() ? context.pop() : context.go('/thix-weeding/provider/dashboard'),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: _P.grad, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
        child: FlexibleSpaceBar(
          background: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.workspaces_outlined, color: Colors.white, size: 16)),
                  const SizedBox(width: 8),
                  Text('MES ACTIVITÉS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.85), letterSpacing: 2)),
                ]),
                const SizedBox(height: 6),
                Text('Gérez vos métiers', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('$count activité${count > 1 ? 's' : ''} — traiteur, salle, DJ…', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends ConsumerWidget {
  final ThixProviderModel activity;
  final String userId;
  const _ActivityCard({required this.activity, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ FIX : isPrimary existe maintenant dans le modèle
    final isPrimary = activity.isPrimary;
    // ✅ FIX : category est un enum → utiliser .name pour la string
    final catKey = activity.category.name.toLowerCase();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(selectedActivityIdProvider.notifier).state = activity.id;
          ref.invalidate(myProviderProvider(userId));
          context.go('/thix-weeding/provider/dashboard');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _P.card(),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(gradient: _P.grad, borderRadius: BorderRadius.circular(16)),
              // ✅ FIX : passer catKey (String) au lieu de activity.category (enum)
              child: Icon(_catIcon(catKey), color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(activity.businessName.isEmpty ? 'Activité sans nom' : activity.businessName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _P.ink)),
                  ),
                  if (isPrimary)
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: _P.rose.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: Text('Principale', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: _P.rose))),
                ]),
                const SizedBox(height: 4),
                // ✅ FIX : passer catKey (String) au lieu de activity.category (enum)
                Text(_catLabel(catKey), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _P.rose)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (activity.city != null && activity.city!.isNotEmpty)
                    _chip(Icons.place_outlined, activity.city!, _P.inkSoft),
                  if (activity.uniqueCode.isNotEmpty)
                    _chip(Icons.fingerprint, activity.uniqueCode, _P.purple),
                  _chip(
                    activity.verificationStatus == ProviderVerificationStatus.verified ? Icons.verified : Icons.hourglass_bottom,
                    activity.verificationStatus == ProviderVerificationStatus.verified ? 'Vérifié' : 'En vérification',
                    activity.verificationStatus == ProviderVerificationStatus.verified ? _P.green : _P.amber,
                  ),
                ]),
              ]),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: _P.inkSoft),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (v) async {
                if (v == 'open') {
                  ref.read(selectedActivityIdProvider.notifier).state = activity.id;
                  ref.invalidate(myProviderProvider(userId));
                  context.go('/thix-weeding/provider/dashboard');
                } else if (v == 'primary') {
                  // ✅ FIX : utiliser le provider Riverpod au lieu d'une fonction globale
                  await ref.read(setPrimaryActivityProvider)(activity.id, ownerId: userId);
                  ref.invalidate(myActivitiesProvider(userId));
                  if (context.mounted) _toast(context, 'Activité principale définie ✓');
                } else if (v == 'edit') {
                  context.push('/thix-weeding/provider/activities/edit/${activity.id}');
                } else if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: const Text('Supprimer cette activité ?'),
                      content: const Text('Les demandes/réservations liées seront perdues. Action irréversible.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: _P.rose), child: const Text('Supprimer')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    // ✅ FIX : utiliser le provider Riverpod au lieu d'une fonction globale
                    await ref.read(deleteActivityProvider)(activity.id, ownerId: userId);
                    if (ref.read(selectedActivityIdProvider) == activity.id) {
                      ref.read(selectedActivityIdProvider.notifier).state = null;
                    }
                    ref.invalidate(myActivitiesProvider(userId));
                    ref.invalidate(myProviderProvider(userId));
                    if (context.mounted) _toast(context, 'Activité supprimée');
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'open', child: Text('Ouvrir le tableau de bord')),
                const PopupMenuItem(value: 'primary', child: Text('Définir comme principale')),
                const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: _P.rose))),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
        ]),
      );

  void _toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(
        content: Text(m, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _P.green, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: _P.card(),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: _P.rose.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.workspaces_outline, size: 44, color: _P.rose)),
          const SizedBox(height: 16),
          Text('Aucune activité', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: _P.ink)),
          const SizedBox(height: 6),
          Text('Créez autant de métiers que vous voulez : traiteur, salle, DJ, décorateur…', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => context.push('/thix-weeding/provider/activities/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Créer ma 1ère activité'),
            style: FilledButton.styleFrom(backgroundColor: _P.rose, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ]),
      );
}

class _AuthRequired extends StatelessWidget {
  const _AuthRequired();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _P.bg,
        body: Center(child: Text('Connexion requise', style: GoogleFonts.inter(color: _P.inkSoft))),
      );
}
