// lib/presentation/home/widgets/home_services_constellation.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// Bien que le nom du fichier reste "constellation" pour ne pas casser les imports,
// nous affichons désormais une superbe GRILLE CORPORATE CLAIRE.
class HomeServicesConstellation extends StatelessWidget {
  final SectionBadgeCounts counts;
  final String? avatarUrl;
  final void Function(String) onServiceTap;
  final VoidCallback onHomeTap;
  final VoidCallback onMiniAppsTap;
  final VoidCallback onDocumentsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;

  const HomeServicesConstellation({
    super.key,
    required this.counts,
    this.avatarUrl,
    required this.onServiceTap,
    required this.onHomeTap,
    required this.onMiniAppsTap,
    required this.onDocumentsTap,
    required this.onProfileTap,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Liste des services organisée pour la grille
    final services = [
      _ServiceItem(id: 'thixSante', label: l10n.t('serviceSante'), icon: Icons.health_and_safety_rounded, color: ThixPolicy.domainHealth, count: counts.health),
      _ServiceItem(id: 'thixMoney', label: l10n.t('serviceMoney'), icon: Icons.account_balance_wallet_rounded, color: ThixPolicy.domainMarket, count: counts.money),
      _ServiceItem(id: 'thixMarket', label: l10n.t('serviceMarket'), icon: Icons.storefront_rounded, color: ThixPolicy.gold, count: counts.market),
      _ServiceItem(id: 'reservation', label: l10n.t('serviceReservation'), icon: Icons.airplane_ticket_rounded, color: ThixPolicy.primaryDeep, count: counts.reservation),
      
      _ServiceItem(id: 'evenements', label: l10n.t('serviceEvenements'), icon: Icons.event_rounded, color: ThixPolicy.domainEvents, count: counts.events),
      _ServiceItem(id: 'monPays', label: l10n.t('serviceMonPays'), icon: Icons.flag_rounded, color: ThixPolicy.danger, count: counts.monPays),
      _ServiceItem(id: 'opportunites', label: l10n.t('serviceOpportunites'), icon: Icons.lightbulb_rounded, color: ThixPolicy.domainOpportunity, count: counts.opportunities),
      _ServiceItem(id: 'emplois', label: l10n.t('serviceEmplois'), icon: Icons.work_rounded, color: ThixPolicy.domainJobs, count: counts.jobs),
      
      _ServiceItem(id: 'reseauPro', label: 'Thix Pro', icon: Icons.people_alt_rounded, color: ThixPolicy.domainNetwork, count: counts.network),
      _ServiceItem(id: 'formations', label: l10n.t('serviceFormations'), icon: Icons.school_rounded, color: ThixPolicy.domainLearning, count: counts.formations),
      _ServiceItem(id: 'thixMedia', label: 'TDIA', icon: Icons.play_circle_filled_rounded, color: ThixPolicy.domainMedia, count: counts.media),
      _ServiceItem(id: 'thixInfo', label: 'THIX MEDIA', icon: Icons.newspaper_rounded, color: ThixPolicy.domainInfo, count: counts.info),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, // 4 colonnes parfaites
          crossAxisSpacing: 12,
          mainAxisSpacing: 20,
          childAspectRatio: 0.75, // Ajusté pour que le texte rentre bien
        ),
        itemCount: services.length,
        itemBuilder: (context, index) {
          final s = services[index];
          return _PressableScale(
            onTap: () {
              HapticFeedback.lightImpact();
              onServiceTap(s.id);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: s.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: s.color.withOpacity(0.2)),
                      ),
                      child: Icon(s.icon, color: s.color, size: 24),
                    ),
                    if (s.count > 0)
                      Positioned(
                        top: -4, right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: ThixPolicy.danger, 
                            shape: BoxShape.circle, 
                            border: Border.all(color: Colors.white, width: 1.5)
                          ),
                          child: Text('${s.count > 9 ? '9+' : s.count}', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  s.label, 
                  textAlign: TextAlign.center, 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis, 
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)) // Slate 900
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ServiceItem {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  _ServiceItem({required this.id, required this.label, required this.icon, required this.color, required this.count});
}

// ============================================================================
// WIDGET : ANIMATION DE CLIC DOUCE
// ============================================================================
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableScale({
    required this.child,
    required this.onTap,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
