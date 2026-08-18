// lib/presentation/opportunities/opportunity_details_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'package:thix_id/models/opportunity_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/external_link_service.dart';
import 'package:thix_id/services/opportunity_service.dart';

class OpportunityDetailsPage extends StatelessWidget {
  final String opportunityId;
  final bool applied;
  
  const OpportunityDetailsPage({super.key, required this.opportunityId, required this.applied});

  @override
  Widget build(BuildContext context) {
    final service = OpportunityService();
    
    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      body: FutureBuilder<OpportunityItem?>(
        future: service.fetchOpportunity(opportunityId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
          }
          final opp = snap.data;
          if (opp == null) {
            return _buildErrorState(context);
          }

          return Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(context, opp),
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: ThixPolicy.surface,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s24, ThixPolicy.s20, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Titre principal
                            Text(opp.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, height: 1.2, letterSpacing: -0.5)),
                            const SizedBox(height: ThixPolicy.s16),
                            
                            // Badges d'information rapide
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: [
                                _InfoPill(icon: Icons.apartment_rounded, label: opp.organizer, color: ThixPolicy.primary),
                                _InfoPill(icon: Icons.place_rounded, label: opp.location, color: ThixPolicy.info),
                                _InfoPill(icon: Icons.emoji_events_rounded, label: opp.rewardLabel, color: ThixPolicy.success),
                                _InfoPill(icon: Icons.schedule_rounded, label: opp.deadlineLabel, color: ThixPolicy.danger),
                              ],
                            ),
                            
                            const SizedBox(height: ThixPolicy.s32),
                            const Divider(color: ThixPolicy.border),
                            const SizedBox(height: ThixPolicy.s24),

                            // Description
                            const Text('À propos de cette opportunité', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)),
                            const SizedBox(height: ThixPolicy.s12),
                            Text(opp.description, style: const TextStyle(fontSize: 14, color: ThixPolicy.textSecondary, height: 1.6)),
                            
                            const SizedBox(height: ThixPolicy.s32),
                            
                            // Éligibilité
                            const Text('Critères d\'éligibilité', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)),
                            const SizedBox(height: ThixPolicy.s16),
                            Container(
                              padding: const EdgeInsets.all(ThixPolicy.s16),
                              decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border)),
                              child: Column(
                                children: opp.eligibility.map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: ThixPolicy.s12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check_circle_rounded, size: 18, color: ThixPolicy.success)),
                                      const SizedBox(width: ThixPolicy.s12),
                                      Expanded(child: Text(e, style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain, height: 1.4))),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Sticky Bottom Action Bar
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s16, ThixPolicy.s20, MediaQuery.paddingOf(context).bottom + ThixPolicy.s16),
                  decoration: BoxDecoration(
                    color: ThixPolicy.card,
                    boxShadow: [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: applied ? null : () => _handleApply(context, opp.applyUrl),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThixPolicy.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(applied ? Icons.verified_rounded : Icons.open_in_new_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(applied ? 'Candidature envoyée' : 'Postuler maintenant', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                      if (!applied)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Vous serez redirigé vers le site officiel de l\'organisateur.', style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, OpportunityItem opp) {
    final img = opp.imageAssetPath;
    return SliverAppBar(
      expandedHeight: 280.0,
      pinned: true,
      backgroundColor: ThixPolicy.inkDeep,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: ThixPolicy.card.withOpacity(0.8),
          child: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 18), onPressed: () => context.pop()),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (img != null)
              (img.startsWith('http') ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover) : Image.asset(img, fit: BoxFit.cover))
            else
              Container(color: ThixPolicy.surfaceStrong),
            // Dégradé pour assurer la lisibilité en haut et faire la transition en bas
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [ThixPolicy.surface, Colors.transparent, Colors.black45],
                  stops: const [0, 0.4, 1],
                ),
              ),
            ),
            Positioned(
              left: ThixPolicy.s20, bottom: ThixPolicy.s24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(20), boxShadow: ThixPolicy.shadowSoft()),
                child: Text(opp.category.toUpperCase(), style: const TextStyle(fontSize: 11, color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(ThixPolicy.s20),
        child: Column(
          children: [
            Align(alignment: Alignment.centerLeft, child: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => context.go(AppRoutes.opportunities))),
            const Spacer(),
            const Icon(Icons.error_outline_rounded, size: 64, color: ThixPolicy.textMuted),
            const SizedBox(height: ThixPolicy.s16),
            const Text('Opportunité introuvable.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApply(BuildContext context, String? url) async {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lien de candidature indisponible.", style: TextStyle(color: Colors.white)), backgroundColor: ThixPolicy.danger));
      return;
    }
    final ok = await ExternalLinkService.open(url);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d’ouvrir le lien.", style: TextStyle(color: Colors.white)), backgroundColor: ThixPolicy.danger));
    }
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rFull), border: Border.all(color: ThixPolicy.border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: ThixPolicy.textMain, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
