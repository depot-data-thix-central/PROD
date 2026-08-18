// lib/presentation/home/widgets/home_headlines_carousel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class HomeHeadlinesCarousel extends StatefulWidget {
  final PageController controller;
  final String? uid;
  final VoidCallback onThixInfoTap;
  final VoidCallback onOpportunityTap;

  const HomeHeadlinesCarousel({
    super.key,
    required this.controller,
    required this.uid,
    required this.onThixInfoTap,
    required this.onOpportunityTap,
  });

  @override
  State<HomeHeadlinesCarousel> createState() => _HomeHeadlinesCarouselState();
}

class _HomeHeadlinesCarouselState extends State<HomeHeadlinesCarousel> {
  late final Stream<List<Map<String, dynamic>>> _bannersStream;
  Stream<List<Map<String, dynamic>>>? _priorityNotifStream;
  
  Timer? _autoTimer;
  int _cardCount = 0;
  bool _isAdmin = false;
  static const double _bannerHeight = 150;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
    
    final client = Supabase.instance.client;

    // 1. Écoute les Bannières dynamiques (table "banners")
    _bannersStream = client
        .from('banners')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('created_at', ascending: false);
        
    // 2. Garde l'écoute de tes Notifications Prioritaires
    final uid = widget.uid;
    if (uid != null && uid.trim().isNotEmpty) {
      try {
        _priorityNotifStream = client.from('notifications')
            .stream(primaryKey: ['id']).eq('user_id', uid).order('created_at', ascending: false).limit(5);
      } catch (e) {
        _priorityNotifStream = null;
      }
    }
    
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!widget.controller.hasClients || _cardCount <= 1) return;
      final current = widget.controller.page?.round() ?? 0;
      final next = (current + 1) % _cardCount;
      widget.controller.animateToPage(next, duration: const Duration(milliseconds: 550), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  // Vérifie si l'utilisateur est admin pour afficher la corbeille
  Future<void> _checkAdminRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('role, account_type')
          .eq('id', user.id)
          .maybeSingle();
          
      if (data != null && mounted) {
        final role = (data['role'] ?? data['account_type'] ?? '').toString().toLowerCase();
        if (role == 'admin' || role == 'entreprise' || role == 'support') {
          setState(() => _isAdmin = true);
        }
      }
    } catch (_) {}
  }

  // Fonction pour supprimer l'annonce et l'image du stockage
  Future<void> _deleteBanner(String id, String? imageUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.surface,
        title: const Text('Supprimer l\'annonce ?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Cette action est irréversible. L\'annonce sera retirée pour tout le monde.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: const Text('Annuler', style: TextStyle(color: ThixPolicy.textSecondary))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Supprimer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.from('banners').delete().eq('id', id);

      if (imageUrl != null && imageUrl.isNotEmpty) {
        final uri = Uri.parse(imageUrl);
        final segments = uri.pathSegments;
        final bucketIndex = segments.indexOf('banners');
        if (bucketIndex != -1 && bucketIndex < segments.length - 1) {
          final path = segments.sublist(bucketIndex + 1).join('/');
          await Supabase.instance.client.storage.from('banners').remove([path]);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Annonce supprimée'), backgroundColor: ThixPolicy.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: ThixPolicy.danger),
        );
      }
    }
  }

  Color _getAccentColor(String tag) {
    final t = tag.toLowerCase();
    if (t.contains('opportunit')) return ThixPolicy.domainOpportunity;
    if (t.contains('info')) return ThixPolicy.domainInfo;
    if (t.contains('urgent') || t.contains('sos')) return ThixPolicy.danger;
    return ThixPolicy.primary;
  }

  IconData _getIcon(String tag) {
    final t = tag.toLowerCase();
    if (t.contains('opportunit')) return Icons.lightbulb_rounded;
    if (t.contains('info')) return Icons.newspaper_rounded;
    if (t.contains('urgent') || t.contains('sos')) return Icons.priority_high_rounded;
    return Icons.campaign_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _priorityNotifStream,
      builder: (context, notifSnap) {
        final notifs = (notifSnap.data ?? const <Map<String, dynamic>>[])
            .where((n) => (n['priority'] == true) || (n['is_priority'] == true)).toList(growable: false);
        final priorityNotif = notifs.isEmpty ? null : notifs.first;
        
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _bannersStream,
          builder: (context, bannerSnap) {
            final banners = bannerSnap.data ?? [];
            final cards = <Widget>[];

            // 1. Ajouter la notification prioritaire (Si elle existe)
            if (priorityNotif != null) {
              cards.add(_HeadlineBanner(
                label: l10n.t('home_headline_notif_priority'),
                title: (priorityNotif['title'] as String?) ?? (priorityNotif['message'] as String?) ?? l10n.t('home_headline_new_notif'),
                imageUrl: priorityNotif['image_url'] as String?,
                icon: Icons.priority_high_rounded,
                accent: ThixPolicy.danger,
                height: _bannerHeight,
                onTap: () => NotificationsSheet.show(context),
              ));
            }

            // 2. Ajouter les bannières administratives dynamiques
            for (final b in banners) {
              final id = b['id'].toString();
              final title = b['title'] as String? ?? 'Annonce';
              final tag = b['tag'] as String? ?? 'À la une';
              final imageUrl = b['image_url'] as String?;
              final accent = _getAccentColor(tag);

              cards.add(
                Stack(
                  children: [
                    _HeadlineBanner(
                      label: tag,
                      title: title,
                      imageUrl: imageUrl,
                      icon: _getIcon(tag),
                      accent: accent,
                      height: _bannerHeight,
                      onTap: () {
                        if (tag.toLowerCase().contains('opportunit')) {
                          widget.onOpportunityTap();
                        } else {
                          widget.onThixInfoTap();
                        }
                      },
                    ),
                    
                    // Bouton Corbeille pour l'admin
                    if (_isAdmin)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: GestureDetector(
                          onTap: () => _deleteBanner(id, imageUrl),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ThixPolicy.danger,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                  ]
                )
              );
            }
            
            // 3. Fallback (Si absolument aucune annonce ni notification)
            if (cards.isEmpty) {
              return Container(
                height: _bannerHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ThixPolicy.tint,
                  borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: const Center(
                  child: Text(
                    'Aucune annonce pour le moment', 
                    style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)
                  )
                ),
              );
            }
            
            _cardCount = cards.length;
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _bannerHeight, 
                  child: PageView(controller: widget.controller, children: cards)
                ),
                if (cards.length > 1) ...[
                  const SizedBox(height: 8),
                  _CarouselDots(controller: widget.controller, count: cards.length),
                ]
              ],
            );
          },
        );
      },
    );
  }
}

class _CarouselDots extends StatefulWidget {
  final PageController controller;
  final int count;
  const _CarouselDots({required this.controller, required this.count});
  @override State<_CarouselDots> createState() => _CarouselDotsState();
}

class _CarouselDotsState extends State<_CarouselDots> {
  int _page = 0;
  
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final p = widget.controller.page?.round() ?? 0;
    if (p != _page && mounted) setState(() => _page = p);
  }
  
  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final activePage = widget.count == 0 ? 0 : _page.clamp(0, widget.count - 1);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.count, (i) {
        final active = i == activePage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? ThixPolicy.premiumAccent : ThixPolicy.border,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _HeadlineBanner extends StatelessWidget {
  final String label;
  final String title;
  final IconData icon;
  final Color accent;
  final String? imageUrl;
  final double height;
  final VoidCallback onTap;

  const _HeadlineBanner({
    required this.label,
    required this.title,
    required this.icon,
    required this.accent,
    required this.height,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = (imageUrl ?? '').trim().isNotEmpty;
    
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        child: Container(
          height: height,
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), boxShadow: ThixPolicy.shadowCard()),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image.network(
                  imageUrl!.trim(),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: accent.withValues(alpha: 0.10),
                      child: Center(
                        child: SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: accent),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: accent.withValues(alpha: 0.14),
                    alignment: Alignment.center,
                    child: Icon(icon, color: accent, size: 40),
                  ),
                )
              else
                Container(
                  color: accent.withValues(alpha: 0.14),
                  alignment: Alignment.center,
                  child: Icon(icon, color: accent, size: 40),
                ),
                
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: hasImage ? 0.55 : 0.25),
                      ],
                      stops: const [0.35, 1.0],
                    ),
                  ),
                ),
              ),
              
              Positioned(
                left: ThixPolicy.s16,
                right: ThixPolicy.s16,
                bottom: ThixPolicy.s12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        label,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, height: 1.15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              Positioned(
                right: ThixPolicy.s12,
                top: ThixPolicy.s12,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_right_rounded, size: 18, color: ThixPolicy.textMain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
