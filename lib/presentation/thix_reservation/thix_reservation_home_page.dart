// lib/presentation/thix_reservation/thix_reservation_home_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'; // ✅ NÉCESSAIRE POUR LE GLASSMORPHISM ET LE FLOU
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/nav.dart'; 

// ✅ Import de la Policy de Design
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

  // 🌟 HELPER POUR LES ORBES DE FOND FIXES (si besoin en complément)
  Widget _buildBlurOrb(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: Container(color: Colors.transparent)),
    );
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB), // Fond Premium de base
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
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
            width: 34, height: 34, 
            decoration: BoxDecoration(
              color: ThixPolicy.primaryDeep, 
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: ThixPolicy.primaryDeep.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: const Center(child: Text('R', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text('THIX ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ThixPolicy.textMain, letterSpacing: -0.3)), Text('RÉSERVATION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ThixPolicy.primaryDeep, letterSpacing: -0.3))]),
            Text('Plateforme nationale', style: TextStyle(fontSize: 10, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
          ]),
        ]),
        actions: [
          IconButton(
            onPressed: (){}, 
            icon: Badge(
              label: const Text('3', style: TextStyle(fontSize: 8)), 
              backgroundColor: ThixPolicy.danger,
              child: const Icon(Icons.notifications_none_rounded, color: ThixPolicy.textMain, size: 22)
            )
          ),
          IconButton(onPressed: (){}, icon: const Icon(Icons.account_circle_outlined, color: ThixPolicy.textMain, size: 22)), 
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // 🌟 ARRIÈRE-PLAN IMMERSIF ANIMÉ (Avions, Bus floutés)
          const Positioned.fill(
            child: _TravelAmbientBackground(),
          ),

          RefreshIndicator(
            color: ThixPolicy.primary,
            backgroundColor: Colors.white,
            onRefresh: _loadCounts,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 56 + 16, 16, 120),
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildPremiumHero(),
                const SizedBox(height: 20),

                // 🌟 CATEGORIES GLASSMORPHISM
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.65), 
                    borderRadius: BorderRadius.circular(24), 
                    border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2), 
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))]
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
                const SizedBox(height: 24),

                _SectionPro(title: 'Mes réservations', onSeeAll: ()=> context.push('/thix-reservation/bus/bookings')),
                const SizedBox(height: 12),
                Row(children: [
                  _ResPro(label: 'À venir', count: loadingCounts? '—' : '${counts['upcoming']}', color: ThixPolicy.primary, icon: Icons.luggage_rounded),
                  const SizedBox(width: 10),
                  _ResPro(label: 'En cours', count: loadingCounts? '—' : '${counts['ongoing']}', color: ThixPolicy.warning, icon: Icons.access_time_filled_rounded),
                  const SizedBox(width: 10),
                  _ResPro(label: 'Terminées', count: loadingCounts? '—' : '${counts['completed']}', color: ThixPolicy.success, icon: Icons.check_circle_rounded),
                  const SizedBox(width: 10),
                  _ResPro(label: 'Annulées', count: loadingCounts? '—' : '${counts['cancelled']}', color: ThixPolicy.textSecondary, icon: Icons.cancel_rounded),
                ]),
                const SizedBox(height: 24),

                _SectionPro(title: 'Offres spéciales', onSeeAll: (){}),
                const SizedBox(height: 12),
                SizedBox(
                  height: 110, 
                  child: ListView(
                    scrollDirection: Axis.horizontal, 
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.none,
                    children: const [
                      _OfferPro(title: 'Hôtels', discount: '-30%', subtitle: 'Séjournez plus', colors: [Color(0xFF0A3D91), Color(0xFF2A7FFF)]),
                      SizedBox(width: 12),
                      _OfferPro(title: 'Vols', discount: '-20%', subtitle: 'Vols nationaux', colors: [Color(0xFF123B7A), Color(0xFF3A8DFF)]),
                      SizedBox(width: 12),
                      _OfferPro(title: 'Bus', discount: '-15%', subtitle: 'En toute confiance', colors: [Color(0xFF0E4DA4), Color(0xFF4A90E2)]),
                      SizedBox(width: 12),
                      _OfferPro(title: 'Livraison', discount: '-10%', subtitle: 'Express 24h/24', colors: [Color(0xFF0A2F6B), Color(0xFF2D6CDF)]),
                    ]
                  )
                ),
                const SizedBox(height: 24),

                // 🌟 PARRAINAGE GLASSMORPHISM
                Container(
                  padding: const EdgeInsets.all(16), 
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.65), 
                    borderRadius: BorderRadius.circular(20), 
                    border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10), 
                      decoration: BoxDecoration(color: ThixPolicy.primaryDeep, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: ThixPolicy.primaryDeep.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]), 
                      child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20)
                    ),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Parrainez & Gagnez!', style: TextStyle(fontWeight: FontWeight.w900, color: ThixPolicy.primaryDeep, fontSize: 13, letterSpacing: -0.2)),
                      SizedBox(height: 2),
                      Text.rich(TextSpan(style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500), children: [TextSpan(text: 'Gagnez jusqu’à '), TextSpan(text: '10.000 FC', style: TextStyle(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w800)), TextSpan(text: ' par ami.')])),
                    ])),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: ThixPolicy.primaryDeep),
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
      height: 160, 
      child: Stack(children: [
        PageView.builder(
          controller: _heroController,
          itemCount: _heroSlides.length,
          onPageChanged: (i)=> setState(()=> _heroIndex=i),
          itemBuilder: (_, index){
            final s = _heroSlides[index];
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24), 
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: s['gradient'] as List<Color>), 
                boxShadow: [BoxShadow(color: (s['gradient'] as List<Color>).first.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))]
              ),
              child: Stack(children: [
                Positioned(right: -10, bottom: -10, child: Opacity(opacity: 0.12, child: Icon(index==0? Icons.directions_bus_filled_rounded : Icons.verified_user_rounded, size: 140, color: Colors.white))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.4))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.bolt_rounded, size: 12, color: ThixPolicy.gold), const SizedBox(width: 4), Text(s['badge'] as String, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5))])),
                      const Spacer(),
                      Text(s['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -0.5)),
                      Text(s['subtitle'] as String, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(s['valid'] as String, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      const Spacer(),
                      SizedBox(height: 32, child: ElevatedButton(onPressed: ()=> context.push(s['route'] as String), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: ThixPolicy.primaryDeep, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16)), child: Text(s['cta'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                    ])),
                    const SizedBox(width: 8),
                    if(index==0) Image.asset('assets/bus_plane.png', width: 110, errorBuilder: (_,__,___)=> const Icon(Icons.airport_shuttle_rounded, size: 80, color: Colors.white))
                    else const Icon(Icons.shield_rounded, size: 80, color: Colors.white),
                  ]),
                ),
              ]),
            );
          },
        ),
        Positioned(bottom: 12, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_heroSlides.length, (i)=> AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 3), width: i==_heroIndex? 20:6, height: 5, decoration: BoxDecoration(color: i==_heroIndex? Colors.white : Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(10)))))),
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10))],
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
                        const SizedBox(width: 70), // Espace pour le bouton central
                        _navItem(Icons.receipt_long_rounded, 'Réservations', 3),
                        _navItem(Icons.person_outline_rounded, 'Profil', 4),
                      ],
                    ),
                    Positioned(
                      top: -20,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          // Action de réservation globale
                        },
                        child: Container(
                          width: 60, height: 60,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: ThixPolicy.brandGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.9), width: 3.5),
                            boxShadow: [BoxShadow(color: ThixPolicy.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 26),
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
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: sel ? ThixPolicy.primaryDeep : ThixPolicy.textSecondary.withOpacity(0.8), size: 24),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, style: TextStyle(fontSize: 9.5, color: sel ? ThixPolicy.primaryDeep : ThixPolicy.textSecondary.withOpacity(0.8), fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET : BACKGROUND VOYAGE ANIMÉ & FLOUTÉ (CORRIGÉ)
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
    // 🌟 Animation plus rapide (12s au lieu de 30s) pour bien voir le mouvement !
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

            // Avion (Bleu)
            final planeX = size.width * 0.5 + math.cos(t) * (size.width * 0.4);
            final planeY = size.height * 0.3 + math.sin(t * 1.5) * (size.height * 0.2);

            // Bus (Doré)
            final busX = size.width * 0.3 + math.sin(t * 1.2) * (size.width * 0.5);
            final busY = size.height * 0.6 + math.cos(t) * (size.height * 0.15);

            // Globe/Localisation (Indigo)
            final globeX = size.width * 0.7 + math.cos(t * 0.8) * 120.0;
            final globeY = size.height * 0.5 + math.sin(t * 1.1) * 150.0;

            // 🌟 CORRECTION: On utilise ImageFiltered au lieu de BackdropFilter.
            // C'est 100% compatible partout (Web/Mobile) et beaucoup plus net !
            return ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
              child: Stack(
                children: [
                  Positioned(
                    left: planeX - 150, top: planeY - 150,
                    child: Transform.rotate(
                      angle: t * 0.5,
                      // Opacité plus forte pour bien voir les couleurs bouger
                      child: Icon(Icons.flight_rounded, size: 300, color: ThixPolicy.primary.withOpacity(0.55)),
                    ),
                  ),
                  Positioned(
                    left: busX - 150, top: busY - 150,
                    child: Transform.rotate(
                      angle: -t * 0.3,
                      child: Icon(Icons.directions_bus_filled_rounded, size: 300, color: ThixPolicy.gold.withOpacity(0.45)),
                    ),
                  ),
                  Positioned(
                    left: globeX - 150, top: globeY - 150,
                    child: Transform.rotate(
                      angle: t * 0.4,
                      child: Icon(Icons.public_rounded, size: 300, color: ThixPolicy.primaryDeep.withOpacity(0.40)),
                    ),
                  ),
                ],
              ),
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
        width: 48,
        height: 48, 
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7), 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: Colors.white), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]
        ), 
        child: Icon(icon, color: isMore ? ThixPolicy.textSecondary : ThixPolicy.primaryDeep, size: 22)
      ),
      const SizedBox(height: 8), 
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textMain, letterSpacing: -0.2)),
    ])
  );
}

class _SectionPro extends StatelessWidget { 
  final String title; final VoidCallback? onSeeAll; 
  const _SectionPro({required this.title, this.onSeeAll}); 
  @override Widget build(BuildContext context)=> Row(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain, letterSpacing: -0.3)), const Spacer(), InkWell(onTap: onSeeAll, child: const Row(children: [Text('Voir tout', style: TextStyle(fontSize: 12, color: ThixPolicy.primary, fontWeight: FontWeight.w700)), Icon(Icons.chevron_right_rounded, size: 16, color: ThixPolicy.primary)]))]); 
}

class _ResPro extends StatelessWidget { 
  final String label, count; final Color color; final IconData icon; 
  const _ResPro({required this.label, required this.count, required this.color, required this.icon}); 
  @override Widget build(BuildContext context)=> Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6), 
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.65), 
      borderRadius: BorderRadius.circular(16), 
      border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2), 
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))]
    ), 
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon, size: 16, color: color)), 
      const SizedBox(height: 8), 
      Text(count, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)), 
      Text(label, style: TextStyle(fontSize: 10, color: ThixPolicy.textSecondary.withOpacity(0.8), fontWeight: FontWeight.w700, letterSpacing: -0.2))
    ])
  )); 
}

class _OfferPro extends StatelessWidget { 
  final String title, discount, subtitle; final List<Color> colors; 
  const _OfferPro({required this.title, required this.discount, required this.subtitle, required this.colors}); 
  @override Widget build(BuildContext context)=> Container(
    width: 150, 
    padding: const EdgeInsets.all(14), 
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20), 
      gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight), 
      boxShadow: [BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
    ), 
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)), 
      const SizedBox(height: 4), 
      Text(discount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1)), 
      const Spacer(), 
      Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w500))
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
