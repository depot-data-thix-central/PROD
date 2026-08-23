import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ POLICY THIX APPLIQUÉE
import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'models/objet_model.dart';
import 'pages/declarer_objet_page.dart';
import 'pages/carte_signalements_page.dart';
import 'pages/object_detail_page.dart';
import 'pages/mes_recherches_page.dart';
import 'providers/objet_providers.dart';

// ============================================================================
// COULEURS SPÉCIFIQUES "THIX RETROUVE" (Thème Deep Teal / Investigation)
// ============================================================================
class _RetrouveColors {
  static const Color background = Color(0xFF091418); // Bleu de Prusse extrêmement sombre
  static const Color glow = ThixPolicy.domainReservation; // Vert d'eau (Teal) / Effet Scanner
}

// ============================================================================
// COMPOSANT RÉUTILISABLE : BOÎTE EN VERRE (GLASSMORPHISM)
// ============================================================================
class GlassBox extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Border? border;

  const GlassBox({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.borderRadius = ThixPolicy.rLg,
    this.padding = ThixPolicy.cardPadding,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(color: Colors.white.withOpacity(0.12), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class ThixRetrouveScreen extends ConsumerStatefulWidget {
  const ThixRetrouveScreen({super.key});

  @override
  ConsumerState<ThixRetrouveScreen> createState() => _ThixRetrouveScreenState();
}

class _ThixRetrouveScreenState extends ConsumerState<ThixRetrouveScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final objetsAsync = ref.watch(objetsRecentsProvider);

    return Scaffold(
      backgroundColor: _RetrouveColors.background,
      body: Stack(
        children: [
          // ─── BACKGROUND GLOW (Effet de lumière Teal/Cyan) ───
          Positioned(
            top: -80, right: -50,
            child: Container(
              width: 300, height: 300, 
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                color: _RetrouveColors.glow.withOpacity(0.15),
                boxShadow: [BoxShadow(color: _RetrouveColors.glow.withOpacity(0.2), blurRadius: 120, spreadRadius: 100)]
              )
            ),
          ),
          Positioned(
            bottom: 100, left: -100,
            child: Container(
              width: 250, height: 250, 
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                color: ThixPolicy.domainInfo.withOpacity(0.1),
                boxShadow: [BoxShadow(color: ThixPolicy.domainInfo.withOpacity(0.15), blurRadius: 100, spreadRadius: 80)]
              )
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu_rounded, color: Colors.white),
                        onPressed: () {},
                      ),
                      Expanded(
                        child: Text(
                          'THIX CENTRAL',
                          textAlign: TextAlign.center,
                          style: ThixPolicy.h3Style.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold, letterSpacing: 1.0),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    color: _RetrouveColors.glow,
                    backgroundColor: _RetrouveColors.background,
                    onRefresh: () async => ref.invalidate(objetsRecentsProvider),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Logo & Titre ──────────────────────────────────────
                          Row(
                            children: [
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  color: _RetrouveColors.glow.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                                  border: Border.all(color: _RetrouveColors.glow.withOpacity(0.4)),
                                ),
                                child: const Icon(Icons.manage_search_rounded, color: Colors.white, size: 32),
                              ),
                              const SizedBox(width: ThixPolicy.s16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(text: 'THIX ', style: ThixPolicy.h1Style.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
                                        TextSpan(text: 'RETROUVE', style: ThixPolicy.h1Style.copyWith(color: _RetrouveColors.glow, fontWeight: ThixPolicy.bold)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Perdu ? Trouvé ? On vous aide !', style: ThixPolicy.bodySmallStyle.copyWith(color: Colors.white70)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: ThixPolicy.s24),

                          // ── Boutons Perdu / Trouvé (Glassmorphism) ────────────
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionCard(
                                  color: ThixPolicy.domainOpportunity, // Orange/Ambre
                                  icon: Icons.search_off_rounded,
                                  title: "J'ai perdu\nun objet",
                                  subtitle: 'Déclarez votre perte',
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const DeclarerObjetPage(type: StatutObjet.perdu)));
                                    if (result == true) ref.invalidate(objetsRecentsProvider);
                                  },
                                ),
                              ),
                              const SizedBox(width: ThixPolicy.s12),
                              Expanded(
                                child: _buildActionCard(
                                  color: ThixPolicy.success, // Vert
                                  icon: Icons.inventory_2_rounded,
                                  title: "J'ai trouvé\nun objet",
                                  subtitle: 'Aidez un propriétaire',
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const DeclarerObjetPage(type: StatutObjet.trouve)));
                                    if (result == true) ref.invalidate(objetsRecentsProvider);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: ThixPolicy.s16),

                          // ── Voir les objets autour de moi ─────────────
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CarteSignalementsPage()));
                            },
                            child: GlassBox(
                              padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s16, horizontal: ThixPolicy.s16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: _RetrouveColors.glow.withOpacity(0.2), shape: BoxShape.circle),
                                    child: const Icon(Icons.location_on_rounded, color: _RetrouveColors.glow, size: 20),
                                  ),
                                  const SizedBox(width: ThixPolicy.s12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Objets autour de moi', style: ThixPolicy.bodyStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
                                        Text('Explorer la carte interactive', style: ThixPolicy.captionStyle.copyWith(color: Colors.white54)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: ThixPolicy.s32),

                          // ── Objets récents ────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Objets récents', style: ThixPolicy.h2Style.copyWith(color: Colors.white)),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MesRecherchesPage())),
                                child: Text('Voir tout', style: ThixPolicy.labelStyle.copyWith(color: _RetrouveColors.glow, fontWeight: ThixPolicy.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: ThixPolicy.s16),

                          // ── Liste dynamique (Riverpod) ────────────────
                          objetsAsync.when(
                            data: (objets) {
                              if (objets.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.white.withOpacity(0.2)),
                                        const SizedBox(height: 12),
                                        Text('Aucun objet pour le moment', style: ThixPolicy.bodyStyle.copyWith(color: Colors.white54)),
                                        const SizedBox(height: 4),
                                        Text('Soyez le premier à déclarer !', style: ThixPolicy.captionStyle.copyWith(color: Colors.white30)),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return Column(
                                children: objets.take(8).map((obj) {
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ObjectDetailPage(
                                            title: obj.titre,
                                            status: obj.statutLabel,
                                            location: obj.lieu,
                                            time: _formatDate(obj.date),
                                            description: obj.description,
                                            reward: obj.recompense ?? '',
                                            imageUrl: obj.imageUrl,
                                          ),
                                        ),
                                      );
                                    },
                                    child: _buildObjectCard(obj),
                                  );
                                }).toList(),
                              );
                            },
                            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: _RetrouveColors.glow))),
                            error: (err, stack) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: 36),
                                    const SizedBox(height: 8),
                                    Text('Impossible de charger les objets', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger)),
                                    TextButton(onPressed: () => ref.invalidate(objetsRecentsProvider), child: Text('Réessayer', style: ThixPolicy.buttonText.copyWith(color: Colors.white))),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 120), // Espace pour la bottom nav
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🌟 BOTTOM NAV FLOTTANTE EN VERRE
          Positioned(bottom: 24, left: 16, right: 16, child: _buildFloatingBottomNav()),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final timeStr = '${date.hour}h${date.minute.toString().padLeft(2, '0')}';

    if (dateOnly == today) return 'Aujourd\'hui, $timeStr';
    if (dateOnly == today.subtract(const Duration(days: 1))) return 'Hier, $timeStr';
    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _iconForCategorie(String? cat) {
    switch (cat?.toLowerCase()) {
      case 'téléphone': return Icons.phone_android_rounded;
      case 'portefeuille / sac': return Icons.account_balance_wallet_rounded;
      case 'clés': return Icons.vpn_key_rounded;
      case 'sac à dos': return Icons.backpack_rounded;
      case 'bijoux / montre': return Icons.watch_rounded;
      case 'documents': return Icons.description_outlined;
      case 'écouteurs / accessoires': return Icons.headphones_rounded;
      default: return Icons.inventory_2_rounded;
    }
  }

  // ── Cartes d'actions supérieures ────────────────────────────────
  Widget _buildActionCard({required Color color, required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassBox(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        padding: const EdgeInsets.all(ThixPolicy.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: ThixPolicy.s24),
            Text(title, style: ThixPolicy.titleStyle.copyWith(color: Colors.white, height: 1.2)),
            const SizedBox(height: 4),
            Text(subtitle, style: ThixPolicy.captionStyle.copyWith(color: Colors.white70, height: 1.2)),
          ],
        ),
      ),
    );
  }

  // ── Carte Objet de la liste ─────────────────────────────────────
  Widget _buildObjectCard(ObjetModel obj) {
    final isLost = obj.statut == StatutObjet.perdu;
    final statusColor = isLost ? ThixPolicy.domainOpportunity : ThixPolicy.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: ThixPolicy.s12),
      child: GlassBox(
        padding: const EdgeInsets.all(ThixPolicy.s12),
        child: Row(
          children: [
            // ── Photo ou icône
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                child: obj.imageUrl != null && obj.imageUrl!.isNotEmpty
                    ? Image.network(
                        obj.imageUrl!, fit: BoxFit.cover, width: 64, height: 64,
                        loadingBuilder: (_, child, progress) => progress == null ? child : const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))),
                        errorBuilder: (_, __, ___) => Icon(_iconForCategorie(obj.categorie), size: 28, color: Colors.white30),
                      )
                    : Icon(_iconForCategorie(obj.categorie), size: 28, color: Colors.white30),
              ),
            ),
            const SizedBox(width: ThixPolicy.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(obj.titre, style: ThixPolicy.bodyStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('${obj.statutLabel} • ${_formatDate(obj.date)}', style: ThixPolicy.captionStyle.copyWith(color: statusColor, fontWeight: ThixPolicy.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 12, color: Colors.white54),
                      const SizedBox(width: 4),
                      Expanded(child: Text(obj.lieu, style: ThixPolicy.captionStyle.copyWith(color: Colors.white54), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
            if (obj.hasRecompense)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(color: ThixPolicy.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: ThixPolicy.gold.withOpacity(0.3))),
                child: const Icon(Icons.workspace_premium_rounded, color: ThixPolicy.gold, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Nav Flottante ────────────────────────────────────────
  Widget _buildFloatingBottomNav() {
    return GlassBox(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      borderRadius: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, 'Accueil', 0),
          _navItem(Icons.manage_search_rounded, 'Recherches', 1),
          // BOUTON CENTRAL "+"
          GestureDetector(
            onTap: _showAddModal,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _RetrouveColors.glow, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _RetrouveColors.glow.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),
          _navItem(Icons.chat_bubble_rounded, 'Messages', 3),
          _navItem(Icons.person_rounded, 'Profil', 4),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int idx) {
    final sel = _currentIndex == idx;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (idx == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const MesRecherchesPage()));
        else setState(() => _currentIndex = idx);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: sel ? Colors.white : Colors.white54, size: 24),
          const SizedBox(height: 4),
          Text(label, style: ThixPolicy.microStyle.copyWith(fontWeight: sel ? ThixPolicy.bold : ThixPolicy.semiBold, color: sel ? Colors.white : Colors.white54, fontSize: 9)),
        ],
      ),
    );
  }

  // ── Modal d'ajout au design sombre ──────────────────────────────
  void _showAddModal() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: _RetrouveColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 24),
                Text('Que souhaitez-vous faire ?', style: ThixPolicy.h2Style.copyWith(color: Colors.white)),
                const SizedBox(height: 24),
                _buildModalAction(
                  icon: Icons.search_off_rounded, color: ThixPolicy.domainOpportunity, title: "J'ai perdu un objet",
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const DeclarerObjetPage(type: StatutObjet.perdu)));
                    if (result == true) ref.invalidate(objetsRecentsProvider);
                  }
                ),
                const SizedBox(height: 12),
                _buildModalAction(
                  icon: Icons.inventory_2_rounded, color: ThixPolicy.success, title: "J'ai trouvé un objet",
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const DeclarerObjetPage(type: StatutObjet.trouve)));
                    if (result == true) ref.invalidate(objetsRecentsProvider);
                  }
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalAction({required IconData icon, required Color color, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassBox(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: ThixPolicy.titleStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold))),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
          ],
        ),
      ),
    );
  }
}
