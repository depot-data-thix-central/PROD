// lib/presentation/thix_reservation/thix_reservation_home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
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

  @override void initState() { super.initState(); _loadCounts(); _startHeroAutoScroll(); }
  void _startHeroAutoScroll() {
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||!_heroController.hasClients) return;
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
  
  @override void dispose() { _heroTimer?.cancel(); _heroController.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56, // 🌟 Compacité
        title: Row(children: [
          Container(
            width: 32, height: 32, // 🌟 Réduit
            decoration: BoxDecoration(color: ThixPolicy.primaryDeep, borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('R', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
          ),
          const SizedBox(width: 8),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text('THIX ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ThixPolicy.textMain)), Text('RÉSERVATION', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ThixPolicy.primaryDeep))]),
            Text('Plateforme nationale', style: TextStyle(fontSize: 10, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500)),
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
      body: RefreshIndicator(
        color: ThixPolicy.primary,
        backgroundColor: Colors.white,
        onRefresh: _loadCounts,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildPremiumHero(),
            const SizedBox(height: 16),

            // 🌟 CATEGORIES - TAILLE ALIGNÉE SUR LE DESIGN SYSTEM (46x46)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft()),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _CatPro(icon: Icons.directions_bus_filled_rounded, label: 'Bus', onTap: ()=> context.push('/thix-reservation/bus')),
                _CatPro(icon: Icons.flight_takeoff_rounded, label: 'Vol', onTap: ()=> context.push('/thix-reservation/flights')),
                _CatPro(icon: Icons.king_bed_rounded, label: 'Hôtel', onTap: ()=> context.push('/thix-reservation/hotels')),
                _CatPro(icon: Icons.local_taxi_rounded, label: 'Taxi', onTap: ()=> context.push('/thix-reservation/taxi')),
                _CatPro(icon: Icons.delivery_dining_rounded, label: 'Livraison', onTap: ()=> context.push(AppRoutes.deliveryHome)),
                _CatPro(icon: Icons.apps_rounded, label: 'Plus', isMore: true, onTap: ()=> showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_)=> const _MoreSheetPro())),
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
              height: 100, // 🌟 Hauteur réduite
              child: ListView(scrollDirection: Axis.horizontal, children: const [
                _OfferPro(title: 'Hôtels', discount: '-30%', subtitle: 'Séjournez plus', colors: [Color(0xFF0A3D91), Color(0xFF2A7FFF)]),
                SizedBox(width: 10),
                _OfferPro(title: 'Vols', discount: '-20%', subtitle: 'Vols nationaux', colors: [Color(0xFF123B7A), Color(0xFF3A8DFF)]),
                SizedBox(width: 10),
                _OfferPro(title: 'Bus', discount: '-15%', subtitle: 'En toute confiance', colors: [Color(0xFF0E4DA4), Color(0xFF4A90E2)]),
                SizedBox(width: 10),
                _OfferPro(title: 'Livraison', discount: '-10%', subtitle: 'Express 24h/24', colors: [Color(0xFF0A2F6B), Color(0xFF2D6CDF)]),
              ])
            ),
            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(12), // 🌟 Padding réduit
              decoration: BoxDecoration(color: ThixPolicy.tint, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border)),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ThixPolicy.primaryDeep, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 18)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Parrainez & Gagnez!', style: TextStyle(fontWeight: FontWeight.w800, color: ThixPolicy.primaryDeep, fontSize: 12)),
                  SizedBox(height: 2),
                  Text.rich(TextSpan(style: TextStyle(fontSize: 10, color: ThixPolicy.textSecondary), children: [TextSpan(text: 'Gagnez jusqu’à '), TextSpan(text: '10.000 FC', style: TextStyle(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w800)), TextSpan(text: ' par ami.')])),
                ])),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: ThixPolicy.primaryDeep),
              ]),
            ),
            const SizedBox(height: 90),
          ]),
        ),
      ),
      bottomNavigationBar: _buildProBottomBar(context),
    );
  }

  Widget _buildPremiumHero() {
    return SizedBox(
      height: 160, // 🌟 Hauteur réduite (196 -> 160)
      child: Stack(children: [
        PageView.builder(
          controller: _heroController,
          itemCount: _heroSlides.length,
          onPageChanged: (i)=> setState(()=> _heroIndex=i),
          itemBuilder: (_, index){
            final s = _heroSlides[index];
            return Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(ThixPolicy.rLg), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: s['gradient'] as List<Color>), boxShadow: ThixPolicy.shadowCard()),
              child: Stack(children: [
                Positioned(right: -10, bottom: -10, child: Opacity(opacity: 0.12, child: Icon(index==0? Icons.directions_bus_filled_rounded : Icons.verified_user_rounded, size: 120, color: Colors.white))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white30)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.bolt_rounded, size: 10, color: Colors.white), const SizedBox(width: 4), Text(s['badge'] as String, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.6))])),
                      const Spacer(),
                      Text(s['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.1)),
                      Text(s['subtitle'] as String, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(s['valid'] as String, style: const TextStyle(color: Colors.white54, fontSize: 9.5)),
                      const Spacer(),
                      SizedBox(height: 30, child: ElevatedButton(onPressed: ()=> context.push(s['route'] as String), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: ThixPolicy.primaryDeep, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12)), child: Text(s['cta'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)))),
                    ])),
                    const SizedBox(width: 8),
                    if(index==0) Image.asset('assets/bus_plane.png', width: 100, errorBuilder: (_,__,___)=> const Icon(Icons.airport_shuttle_rounded, size: 70, color: Colors.white))
                    else const Icon(Icons.shield_rounded, size: 70, color: Colors.white),
                  ]),
                ),
              ]),
            );
          },
        ),
        Positioned(bottom: 10, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_heroSlides.length, (i)=> AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 2), width: i==_heroIndex? 16:6, height: 4, decoration: BoxDecoration(color: i==_heroIndex? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(10)))))),
      ]),
    );
  }

  Widget _buildProBottomBar(BuildContext context){
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: ThixPolicy.border)), boxShadow: ThixPolicy.shadowCard()),
      child: SafeArea(child: BottomNavigationBar(
        currentIndex: 2, selectedItemColor: ThixPolicy.primaryDeep, unselectedItemColor: ThixPolicy.textSecondary, type: BottomNavigationBarType.fixed, backgroundColor: Colors.white, elevation: 0, selectedFontSize: 10, unselectedFontSize: 10,
        onTap: (i){ if(i==0) context.pop(); if(i==3) context.push('/thix-reservation/bus/bookings'); },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded, size: 22), label: 'Accueil'),
          const BottomNavigationBarItem(icon: Icon(Icons.explore_outlined, size: 22), label: 'Explorer'),
          BottomNavigationBarItem(icon: Container(margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.all(10), decoration: BoxDecoration(gradient: ThixPolicy.brandGradient, shape: BoxShape.circle, boxShadow: ThixPolicy.shadowNode()), child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20)), label: 'Réserver'),
          const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded, size: 22), label: 'Réservations'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded, size: 22), label: 'Profil'),
        ],
      )),
    );
  }
}

// --- WIDGETS PRO ---
class _CatPro extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final bool isMore;
  const _CatPro({required this.icon, required this.label, required this.onTap, this.isMore=false});
  @override Widget build(BuildContext context)=> InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Column(children: [
    Container(
      width: ThixPolicy.constellationNodeSize, // 🌟 46.0 (Taille unifiée)
      height: ThixPolicy.constellationNodeSize, 
      decoration: BoxDecoration(color: isMore ? ThixPolicy.surface : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isMore ? Colors.transparent : ThixPolicy.border), boxShadow: isMore ? null : ThixPolicy.shadowSoft()), 
      child: Icon(icon, color: isMore ? ThixPolicy.textSecondary : ThixPolicy.primaryDeep, size: ThixPolicy.constellationNodeIconSize) // 🌟 20.0
    ),
    const SizedBox(height: 6), 
    Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
  ]));
}

class _SectionPro extends StatelessWidget { final String title; final VoidCallback? onSeeAll; const _SectionPro({required this.title, this.onSeeAll}); @override Widget build(BuildContext context)=> Row(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ThixPolicy.textMain)), const Spacer(), InkWell(onTap: onSeeAll, child: const Row(children: [Text('Voir tout', style: TextStyle(fontSize: 11, color: ThixPolicy.primary, fontWeight: FontWeight.w600)), Icon(Icons.chevron_right_rounded, size: 14, color: ThixPolicy.primary)]))]); }

class _ResPro extends StatelessWidget { final String label, count; final Color color; final IconData icon; const _ResPro({required this.label, required this.count, required this.color, required this.icon}); @override Widget build(BuildContext context)=> Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft()), child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [Container(width: 24, height: 24, decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 14, color: color)), const SizedBox(height: 6), Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)), Text(label, style: const TextStyle(fontSize: 10, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600))]))); }

class _OfferPro extends StatelessWidget { final String title, discount, subtitle; final List<Color> colors; const _OfferPro({required this.title, required this.discount, required this.subtitle, required this.colors}); @override Widget build(BuildContext context)=> Container(width: 140, padding: const EdgeInsets.all(12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight), boxShadow: ThixPolicy.shadowSoft()), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 10)), const SizedBox(height: 4), Text(discount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)), const Spacer(), Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.2))])) ;}

class _MoreSheetPro extends StatelessWidget { const _MoreSheetPro(); @override Widget build(BuildContext context)=> Container(padding: const EdgeInsets.all(22), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))), child: Wrap(spacing: 24, runSpacing: 24, alignment: WrapAlignment.center, children: [
  _CatPro(icon: Icons.restaurant_rounded, label: 'Restaurant', onTap: (){}),
  _CatPro(icon: Icons.storefront_rounded, label: 'Annonces', onTap: (){}),
  _CatPro(icon: Icons.event_rounded, label: 'Événement', onTap: ()=> context.push('/thix-event')),
  _CatPro(icon: Icons.delivery_dining_rounded, label: 'Livraison', onTap: ()=> context.push(AppRoutes.deliveryHome)),
])); }
