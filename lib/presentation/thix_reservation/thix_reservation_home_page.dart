// lib/presentation/thix_reservation/thix_reservation_home_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'; // Utilisé uniquement pour les cartes en verre dépoli (UI statique/légère)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/nav.dart'; 

import 'package:thix_id/core/theme/thix_design_policy.dart';

class ThixReservationHomePage extends StatefulWidget {
  const ThixReservationHomePage({super.key});
  @override State<ThixReservationHomePage> createState() => _ThixReservationHomePageState();
}

class _ThixReservationHomePageState extends State<ThixReservationHomePage> {
  Map<String, int> counts = {'upcoming': 0, 'ongoing': 0, 'completed': 0, 'cancelled': 0};
  bool loadingCounts = true;
  final PageController _heroController = PageController();
  Timer? _heroTimer;
  int _heroIndex = 0;
  int _selectedNav = 0;

  final List<Map<String, dynamic>> _heroSlides = [
    {
      'badge': 'PROMO FLASH',
      'title': "Jusqu'à -40%",
      'subtitle': 'bus & vols nationaux',
      'valid': 'Valable jusqu’au 30 Juin 2026',
      'cta': 'Réserver',
      'route': '/thix-reservation/bus',
      'image': 'assets/images/hero_bus_plane.png',
      'gradient': [ThixPolicy.primaryDeep, ThixPolicy.primary],
    },
    {
      'badge': 'CONFIANCE',
      'title': 'Paiement Sécurisé',
      'subtitle': 'Mobile Money & Carte',
      'valid': 'Transactions 100% garanties',
      'cta': 'Découvrir',
      'route': '/thix-reservation/bus',
      'image': null,
      'gradient': [ThixPolicy.inkDeep, ThixPolicy.primaryDeep],
    },
  ];

  @override 
  void initState() { 
    super.initState(); 
    _loadCounts(); 
    _startHeroAutoScroll(); 
  }
  
  void _startHeroAutoScroll() {
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_heroController.hasClients) return;
      _heroIndex = (_heroIndex + 1) % _heroSlides.length;
      _heroController.animateToPage(_heroIndex, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    });
  }
  
  Future<void> _loadCounts() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final res = await Supabase.instance.client.from('bus_bookings').select('status').eq('user_id', uid);
      final map = {'upcoming': 0, 'ongoing': 0, 'completed': 0, 'cancelled': 0};
      for (final r in res as List) {
        final s = r['status'] as String;
        if (s == 'confirmed' || s == 'pending_payment') map['upcoming'] = map['upcoming']! + 1;
        else if (s == 'in_progress') map['ongoing'] = map['ongoing']! + 1;
        else if (s == 'completed') map['completed'] = map['completed']! + 1;
        else if (s == 'cancelled') map['cancelled'] = map['cancelled']! + 1;
      }
      if (mounted) setState(() { counts = map; loadingCounts = false; });
    } catch (_) { if (mounted) setState(() => loadingCounts = false); }
  }
  
  @override 
  void dispose() { 
    _heroTimer?.cancel(); 
    _heroController.dispose(); 
    super.dispose(); 
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 52,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: Colors.white.withOpacity(0.65),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.2))
              ),
            ),
          ),
        ),
        title: Row(children: [
          Container(
            width: 30, height: 30, 
            decoration: BoxDecoration(
              color: ThixPolicy.primaryDeep, 
              borderRadius: BorderRadius.circular(7),
              boxShadow: [BoxShadow(color: ThixPolicy.primaryDeep.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: const Center(child: Text('R', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))),
          ),
          const SizedBox(width: 8),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text('THIX ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: ThixPolicy.textMain, letterSpacing: -0.3)), Text('RÉSERVATION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: ThixPolicy.primaryDeep, letterSpacing: -0.3))]),
            Text('Plateforme nationale', style: TextStyle(fontSize: 9, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
          ]),
        ]),
        actions: [
          IconButton(
            onPressed: (){}, 
            icon: Badge(
              label: const Text('3', style: TextStyle(fontSize: 7)), 
              backgroundColor: ThixPolicy.danger,
              child: const Icon(Icons.notifications_none_rounded, color: ThixPolicy.textMain, size: 19)
            )
          ),
          IconButton(onPressed: (){}, icon: const Icon(Icons.account_circle_outlined, color: ThixPolicy.textMain, size: 19)), 
          const SizedBox(width: 2),
        ],
      ),
      body: Stack(
        children: [
          // 🌟 ARRIÈRE-PLAN IMMERSIF ANIMÉ ET OPTIMISÉ
          const Positioned.fill(
            child: _TravelAmbientBackground(),
          ),

          RefreshIndicator(
            color: ThixPolicy.primary,
            backgroundColor: Colors.white,
            onRefresh: _loadCounts,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(14, MediaQuery.paddingOf(context).top + 52 + 14, 14, 110),
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildPremiumHero(),
                const SizedBox(height: 16),

                // 🌟 CATEGORIES GLASSMORPHISM
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.65), 
                    borderRadius: BorderRadius.circular(20), 
                    border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2), 
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _CatPro(icon: Icons.directions_bus_filled_rounded, label: 'Bus', onTap: ()=> context.push('/thix-reservation/bus')),
                    _CatPro(icon: Icons.flight_takeoff_rounded, label: 'Vol', onTap: ()=> context.push('/thix-reservation/flights')),
                    _CatPro(icon: Icons.king_bed_rounded, label: 'Hôtel', onTap: ()=> context.push('/thix-reservation/hotels')),
                    _CatPro(icon: Icons.local_taxi_rounded, label: 'Taxi', onTap: ()=> context.push('/thix-reservation/taxi')),
                    _CatPro(icon: Icons.delivery_dining_rounded, label: 'Livraison', onTap: ()=> context.push(AppRoutes.deliveryHome)),
                    _CatPro(icon: Icons.apps_rounded, label: 'Plus', isMore: true, onTap: ()=> showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_)=> const _MoreSheetPro())),
                  ]),
                ),
                const SizedBox(height: 20),

                _SectionPro(title: 'Mes réservations', onSeeAll: ()=> context.push('/thix-reservation/bus/bookings')),
                const SizedBox(height: 10),
                Row(children: [
                  _ResPro(label: 'À venir', count: loadingCounts? '—' : '${counts['upcoming']}', color: ThixPolicy.primary, icon: Icons.luggage_rounded),
                  const SizedBox(width: 8),
                  _ResPro(label: 'En cours', count: loadingCounts? '—' : '${counts['ongoing']}', color: ThixPolicy.warning, icon: Icons.access_time_filled_rounded),
                  const SizedBox(width: 8),
                  _ResPro(label: 'Terminées', count: loadingCounts? '—' : '${counts['completed']}', color: ThixPolicy.success, icon: Icons.check_circle_rounded),
                  const SizedBox(width: 8),
                  _ResPro(label: 'Annulées', count: loadingCounts? '—' : '${counts['cancelled']}', color: ThixPolicy.textSecondary, icon: Icons.cancel_rounded),
                ]),
                const SizedBox(height: 20),

                _SectionPro(title: 'Offres spéciales', onSeeAll: (){}),
                const SizedBox(height: 10),
                SizedBox(
                  height: 92, 
                  child: ListView(
                    scrollDirection: Axis.horizontal, 
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.none,
                    children: const [
                      _OfferPro(title: 'Hôtels', discount: '-30%', subtitle: 'Séjournez plus', colors: [Color(0xFF0A3D91), Color(0xFF2A7FFF)]),
                      SizedBox(width: 10),
                      _OfferPro(title: 'Vols', discount: '-20%', subtitle: 'Vols nationaux', colors: [Color(0xFF123B7A), Color(0xFF3A8DFF)]),
                      SizedBox(width: 10),
                      _OfferPro(title: 'Bus', discount: '-15%', subtitle: 'En toute confiance', colors: [Color(0xFF0E4DA4), Color(0xFF4A90E2)]),
                      SizedBox(width: 10),
                      _OfferPro(title: 'Livraison', discount: '-10%', subtitle: 'Express 24h/24', colors: [Color(0xFF0A2F6B), Color(0xFF2D6CDF)]),
                    ]
                  )
                ),
                const SizedBox(height: 20),

                // 🌟 PARRAINAGE GLASSMORPHISM
                Container(
                  padding: const EdgeInsets.all(13), 
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.65), 
                    borderRadius: BorderRadius.circular(16), 
                    border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8), 
                      decoration: BoxDecoration(color: ThixPolicy.primaryDeep, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: ThixPolicy.primaryDeep.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 2))]), 
                      child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 17)
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Parrainez & Gagnez!', style: TextStyle(fontWeight: FontWeight.w900, color: ThixPolicy.primaryDeep, fontSize: 12, letterSpacing: -0.2)),
                      SizedBox(height: 2),
                      Text.rich(TextSpan(style: TextStyle(fontSize: 10, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500), children: [TextSpan(text: 'Gagnez jusqu’à '), TextSpan(text: '10.000 FC', style: TextStyle(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w800)), TextSpan(text: ' par ami.')])),
                    ])),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: ThixPolicy.primaryDeep),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildProBottomBar(context),
    );
  }

  Widget _buildPremiumHero() {
    return SizedBox(
      height: 130, // Réduit (était 160)
      child: Stack(children: [
        PageView.builder(
          controller: _heroController,
          itemCount: _heroSlides.length,
          onPageChanged: (i)=> setState(()=> _heroIndex=i),
          itemBuilder: (_, index){
            final s = _heroSlides[index];
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), 
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: s['gradient'] as List<Color>), 
                boxShadow: [BoxShadow(color: (s['gradient'] as List<Color>).first.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 5))]
              ),
              child: Stack(children: [
                Positioned(right: -8, bottom: -8, child: Opacity(opacity: 0.12, child: Icon(index==0? Icons.directions_bus_filled_rounded : Icons.verified_user_rounded, size: 110, color: Colors.white))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.4))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.bolt_rounded, size: 11, color: ThixPolicy.gold), const SizedBox(width: 3), Text(s['badge'] as String, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.4))])),
                      const Spacer(),
                      Text(s['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -0.5)),
                      Text(s['subtitle'] as String, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(s['valid'] as String, style: const TextStyle(color: Colors.white54, fontSize: 8.5)),
                      const Spacer(),
                      SizedBox(height: 27, child: ElevatedButton(onPressed: ()=> context.push(s['route'] as String), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: ThixPolicy.primaryDeep, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.symmetric(horizontal: 13)), child: Text(s['cta'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10.5)))),
                    ])),
                    const SizedBox(width: 6),
                    if(index==0) Image.asset('assets/bus_plane.png', width: 88, errorBuilder: (_,__,___)=> const Icon(Icons.airport_shuttle_rounded, size: 64, color: Colors.white))
                    else const Icon(Icons.shield_rounded, size: 64, color: Colors.white),
                  ]),
                ),
              ]),
            );
          },
        ),
        Positioned(bottom: 10, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_heroSlides.length, (i)=> AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 3), width: i==_heroIndex? 18:5, height: 4.5, decoration: BoxDecoration(color: i==_heroIndex? Colors.white : Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(10)))))),
      ]),
    );
  }

  // 🌟 BOTTOM NAV BAR GLASSMORPHISM
  Widget _buildProBottomBar(BuildContext context){
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                height: 56, // Réduit (était 64)
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 26, offset: const Offset(0, 8))],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _navItem(Icons.home_rounded, 'Accueil', 0),
                        _navItem(Icons.explore_outlined, 'Explorer', 1),
                        const SizedBox(width: 60), // Espace pour le bouton central
                        _navItem(Icons.receipt_long_rounded, 'Réservations', 3),
                        _navItem(Icons.person_outline_rounded, 'Profil', 4),
                      ],
                    ),
                    Positioned(
                      top: -18,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          // Action de réservation globale
                        },
                        child: Container(
                          width: 52, height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: ThixPolicy.brandGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.9), width: 3),
                            boxShadow: [BoxShadow(color: ThixPolicy.primary.withOpacity(0.35), blurRadius: 9, offset: const Offset(0, 4))],
                          ),
                          child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final sel = _selectedNav == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedNav = index);
        if(index == 0) context.pop(); 
        if(index == 3) context.push('/thix-reservation/bus/bookings');
      },
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: sel ? ThixPolicy.primaryDeep : ThixPolicy.textSecondary.withOpacity(0.8), size: 20),
            const SizedBox(height: 3),
            Text(label, maxLines: 1, style: TextStyle(fontSize: 8, color: sel ? ThixPolicy.primaryDeep : ThixPolicy.textSecondary.withOpacity(0.8), fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET : BACKGROUND VOYAGE ANIMÉ & OPTIMISÉ 100% (Zéro Flou GPU)
// ============================================================================
class _TravelAmbientBackground extends StatefulWidget {
  const _TravelAmbientBackground();

  @override
  State<_TravelAmbientBackground> createState() => _TravelAmbientBackgroundState();
}

class _TravelAmbientBackgroundState extends State<_TravelAmbientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Cycle fluide et continu (16s)
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🌟 HELPER HAUTE PERFORMANCE : Utilise un RadialGradient elliptique au lieu d'un Flou GPU
  Widget _buildPerformanceOrb(double left, double top, double width, double height, Color color, double angle) {
    return Positioned(
      left: left - (width / 2),
      top: top - (height / 2),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.elliptical(width, height)),
            gradient: RadialGradient(
              colors: [
                color,
                color.withOpacity(0.0), // Fondu doux et naturel
              ],
              stops: const [0.1, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value * 2 * math.pi;

            // ── Calcul des trajectoires (identiques à la version non-optimisée) ──
            final globeX = size.width * 0.7 + math.cos(t * 0.7) * 130.0;
            final globeY = size.height * 0.48 + math.sin(t * 0.9) * 160.0;

            final ticketX = size.width * 0.15 + math.sin(t * 0.6 + 1.2) * 90.0;
            final ticketY = size.height * 0.82 + math.cos(t * 0.5) * 110.0;

            final busX = size.width * 0.3 + math.sin(t * 1.1) * (size.width * 0.45);
            final busY = size.height * 0.62 + math.cos(t) * (size.height * 0.14);

            final planeX = size.width * 0.5 + math.cos(t * 1.4) * (size.width * 0.38);
            final planeY = size.height * 0.28 + math.sin(t * 1.8) * (size.height * 0.19);

            final planeSmallX = size.width * 0.85 + math.sin(t * 1.6 + 2.0) * 80.0;
            final planeSmallY = size.height * 0.16 + math.cos(t * 1.3) * 60.0;

            return Stack(
              children: [
                // Orbes dessinées via RadialGradient (Coût GPU = 0)
                
                // Globe (Grand Rond)
                _buildPerformanceOrb(globeX, globeY, 600, 600, ThixPolicy.primaryDeep.withOpacity(0.18), t * 0.35),
                
                // Ticket (Ovale)
                _buildPerformanceOrb(ticketX, ticketY, 450, 550, ThixPolicy.gold.withOpacity(0.15), -t * 0.25),

                // Bus (Ovale horizontal grand)
                _buildPerformanceOrb(busX, busY, 600, 450, ThixPolicy.gold.withOpacity(0.20), -t * 0.3),

                // Plane (Ovale très allongé pour simuler l'avion)
                _buildPerformanceOrb(planeX, planeY, 550, 350, ThixPolicy.primary.withOpacity(0.25), t * 0.5),

                // Small Plane (Petit ovale rapide)
                _buildPerformanceOrb(planeSmallX, planeSmallY, 350, 200, ThixPolicy.primaryDeep.withOpacity(0.18), -t * 0.6 + 1.0),

                // Voile clair très subtil par-dessus pour harmoniser les couleurs
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.10),
                          Colors.white.withOpacity(0.25),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// --- WIDGETS PRO ---
class _CatPro extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final bool isMore;
  const _CatPro({required this.icon, required this.label, required this.onTap, this.isMore=false});
  
  @override Widget build(BuildContext context)=> GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); onTap(); },
    child: Column(children: [
      Container(
        width: 40,
        height: 40, 
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7), 
          borderRadius: BorderRadius.circular(14), 
          border: Border.all(color: Colors.white), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))]
        ), 
        child: Icon(icon, color: isMore ? ThixPolicy.textSecondary : ThixPolicy.primaryDeep, size: 19)
      ),
      const SizedBox(height: 6), 
      Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: ThixPolicy.textMain, letterSpacing: -0.2)),
    ])
  );
}

class _SectionPro extends StatelessWidget { 
  final String title; final VoidCallback? onSeeAll; 
  const _SectionPro({required this.title, this.onSeeAll}); 
  @override Widget build(BuildContext context)=> Row(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: ThixPolicy.textMain, letterSpacing: -0.3)), const Spacer(), InkWell(onTap: onSeeAll, child: const Row(children: [Text('Voir tout', style: TextStyle(fontSize: 11, color: ThixPolicy.primary, fontWeight: FontWeight.w700)), Icon(Icons.chevron_right_rounded, size: 14, color: ThixPolicy.primary)]))]); 
}

class _ResPro extends StatelessWidget { 
  final String label, count; final Color color; final IconData icon; 
  const _ResPro({required this.label, required this.count, required this.color, required this.icon}); 
  @override Widget build(BuildContext context)=> Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5), 
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.65), 
      borderRadius: BorderRadius.circular(14), 
      border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.1), 
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3))]
    ), 
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(width: 24, height: 24, decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon, size: 14, color: color)), 
      const SizedBox(height: 6), 
      Text(count, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)), 
      Text(label, style: TextStyle(fontSize: 9, color: ThixPolicy.textSecondary.withOpacity(0.8), fontWeight: FontWeight.w700, letterSpacing: -0.2))
    ])
  )); 
}

class _OfferPro extends StatelessWidget { 
  final String title, discount, subtitle; final List<Color> colors; 
  const _OfferPro({required this.title, required this.discount, required this.subtitle, required this.colors}); 
  @override Widget build(BuildContext context)=> Container(
    width: 128, 
    padding: const EdgeInsets.all(12), 
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16), 
      gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight), 
      boxShadow: [BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
    ), 
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 9.5, letterSpacing: 0.4)), 
      const SizedBox(height: 3), 
      Text(discount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.8)), 
      const Spacer(), 
      Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 9, height: 1.15, fontWeight: FontWeight.w500))
    ])
  );
}

class _MoreSheetPro extends StatelessWidget { 
  const _MoreSheetPro(); 
  @override Widget build(BuildContext context)=> ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32), 
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85), 
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.9), width: 1.5))
        ), 
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 32),
            Wrap(spacing: 32, runSpacing: 32, alignment: WrapAlignment.center, children: [
              _CatPro(icon: Icons.restaurant_rounded, label: 'Restaurant', onTap: (){}),
              _CatPro(icon: Icons.storefront_rounded, label: 'Annonces', onTap: (){}),
              _CatPro(icon: Icons.event_rounded, label: 'Événement', onTap: (){ Navigator.pop(context); context.push('/thix-event');}),
              _CatPro(icon: Icons.delivery_dining_rounded, label: 'Livraison', onTap: (){ Navigator.pop(context); context.push(AppRoutes.deliveryHome);}),
            ]),
          ],
        )
      ),
    ),
  ); 
}
