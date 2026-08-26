// lib/presentation/thix_reservation/bus/pages/client/bus_home_page.dart
// V2.4 FIX AGENCE + Riverpod + ThixPolicy
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../providers/bus_search_provider.dart';
import '../../providers/agency_dashboard_provider.dart';
import '../../data/services/bus_public_service.dart';

class BusHomePage extends ConsumerStatefulWidget {
  const BusHomePage({super.key});
  @override
  ConsumerState<BusHomePage> createState() => _BusHomePageState();
}

class _BusHomePageState extends ConsumerState<BusHomePage> {
  final _publicService = BusPublicService();
  final PageController _heroCtrl = PageController();
  Timer? _timer;
  int _heroIndex = 0;
  List<Map<String, dynamic>> _popularRoutes = [];
  bool _loadingPopular = true;
  String _userName = "Voyageur";

  static const _heroSlides = [
    {
      "title": "Réservez votre bus en toute simplicité",
      "sub": "Voyagez confortablement",
      "cta": "Réserver un bus",
      "img": "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=1200&q=80",
    },
    {
      "title": "Bus VIP Climatisé Wi-Fi à bord",
      "sub": "Confort premium prix mini",
      "cta": "Voir les offres",
      "img": "https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=1200&q=80",
    },
    {
      "title": "Voyagez en sécurité 24h sur 24",
      "sub": "Chauffeurs vérifiés GPS",
      "cta": "Réserver maintenant",
      "img": "https://images.unsplash.com/photo-1499856871958-5b9627545d1a?w=1200&q=80",
    },
  ];

  static const _fallbackAmenities = [
    {"label": "Sièges", "icon_name": "seat"},
    {"label": "Wi-Fi", "icon_name": "wifi"},
    {"label": "Clim", "icon_name": "ac"},
    {"label": "Bagages", "icon_name": "luggage"},
    {"label": "Sécurité", "icon_name": "security"},
  ];

  static const _fallbackCities = [
    "Kinshasa",
    "Lubumbashi",
    "Goma",
    "Bukavu",
    "Kisangani",
    "Mbuji-Mayi",
    "Kananga",
    "Kolwezi",
    "Matadi",
    "Mbandaka",
    "Beni",
    "Butembo",
    "Bunia",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_heroCtrl.hasClients) return;
      _heroIndex = (_heroIndex + 1) % _heroSlides.length;
      _heroCtrl.animateToPage(
        _heroIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _init() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final p = await Supabase.instance.client
            .from("profiles")
            .select("full_name")
            .eq("id", user.id)
            .maybeSingle();
        if (p != null && mounted) {
          final full = (p["full_name"] as String?)?.trim() ?? "";
          if (full.isNotEmpty) {
            setState(() => _userName = full.split(" ").first);
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      await ref.read(agencyDashboardProvider.notifier).init();
    }

    try {
      final routes = await _publicService.getPopularRoutes();
      if (mounted) {
        setState(() {
          _popularRoutes = routes;
          _loadingPopular = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPopular = false);
    }
  }

  void _openAgencySpace() {
    final hasAgency = ref.read(agencyDashboardProvider).hasAgency;
    if (hasAgency) {
      context.push("/agency/dashboard");
    } else {
      context.push("/agency/onboarding");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _heroCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchP = ref.watch(busSearchProvider);
    final agencyState = ref.watch(agencyDashboardProvider);
    final hasAgency = agencyState.hasAgency;

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: ThixPolicy.textMain),
          onPressed: () {},
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: ThixPolicy.primaryDeep,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text("THIX ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: ThixPolicy.textMain)),
                Text("RESERVATION", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: ThixPolicy.primaryDeep)),
              ]),
              Text("Réservez simplement", style: TextStyle(fontSize: 10, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500)),
            ],
          ),
        ]),
        actions: [
          IconButton(
            tooltip: hasAgency ? "Mon agence" : "Devenir agence partenaire",
            onPressed: _openAgencySpace,
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: hasAgency ? ThixPolicy.tint : ThixPolicy.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                hasAgency ? Icons.storefront_rounded : Icons.add_business_rounded,
                size: 18,
                color: hasAgency ? ThixPolicy.primary : ThixPolicy.warning,
              ),
            ),
          ),
          IconButton(
            onPressed: () => context.push("/notifications"),
            icon: Badge(
              backgroundColor: ThixPolicy.danger,
              label: const Text("3", style: TextStyle(fontSize: 8)),
              child: const Icon(Icons.notifications_none_rounded, color: ThixPolicy.textMain),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: ThixPolicy.primary,
        backgroundColor: Colors.white,
        onRefresh: _init,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 160,
                child: Stack(children: [
                  PageView.builder(
                    controller: _heroCtrl,
                    itemCount: _heroSlides.length,
                    onPageChanged: (i) => setState(() => _heroIndex = i),
                    itemBuilder: (_, i) {
                      final s = _heroSlides[i];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                        child: Stack(children: [
                          Positioned.fill(child: Image.network(s["img"]!, fit: BoxFit.cover)),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [ThixPolicy.primaryDeep.withOpacity(0.9), Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Bonjour, $_userName", style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text(s["title"]!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.1)),
                                const SizedBox(height: 4),
                                Text(s["sub"]!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                const Spacer(),
                                SizedBox(
                                  height: 32,
                                  child: ElevatedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.directions_bus_filled_rounded, size: 14),
                                    label: Text(s["cta"]!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: ThixPolicy.primaryDeep,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _heroSlides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: i == _heroIndex ? 16 : 6,
                          height: 4,
                          decoration: BoxDecoration(
                            color: i == _heroIndex ? Colors.white : Colors.white54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _openAgencySpace,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: hasAgency ? const Color(0xFF0A3D62) : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasAgency ? const Color(0xFF0A3D62) : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasAgency ? Icons.dashboard_customize : Icons.add_business,
                        color: hasAgency ? Colors.white : Colors.orange.shade800,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasAgency
                              ? "Gérer mon Agence (${agencyState.myAgency?.name ?? 'Agence'})"
                              : "Devenir Agence Partenaire",
                          style: TextStyle(
                            color: hasAgency ? Colors.white : Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: hasAgency ? Colors.white70 : Colors.orange.shade800,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  border: Border.all(color: ThixPolicy.border),
                  boxShadow: ThixPolicy.shadowSoft(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Cat(icon: Icons.flight_rounded, label: "Vols", color: ThixPolicy.domainLearning, onTap: () {}),
                    _Cat(icon: Icons.king_bed_rounded, label: "Hôtels", color: ThixPolicy.domainNetwork, onTap: () {}),
                    _Cat(icon: Icons.directions_bus_filled_rounded, label: "Bus", color: ThixPolicy.primary, active: true, onTap: () {}),
                    _Cat(icon: Icons.local_taxi_rounded, label: "Taxis", color: ThixPolicy.domainOpportunity, onTap: () {}),
                    _Cat(icon: Icons.more_horiz_rounded, label: "Plus", color: ThixPolicy.textSecondary, isMore: true, onTap: () {}),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                  border: Border.all(color: ThixPolicy.border),
                  boxShadow: ThixPolicy.shadowSoft(),
                ),
                child: Column(children: [
                  const Row(children: [
                    Text("Réservation de bus", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: ThixPolicy.textMain)),
                    Spacer(),
                    Text("Voir tout", style: TextStyle(fontSize: 11, color: ThixPolicy.primary, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _FieldBox(
                        icon: Icons.my_location_rounded,
                        label: "Départ",
                        value: searchP.departureCity ?? "Choisir",
                        onTap: () => _showCityPicker(context, true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FieldBox(
                        icon: Icons.location_on_rounded,
                        label: "Arrivée",
                        value: searchP.arrivalCity ?? "Choisir",
                        onTap: () => _showCityPicker(context, false),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: _FieldBox(
                        icon: Icons.calendar_today_rounded,
                        label: "Date",
                        value: "\( {searchP.departureDate.day.toString().padLeft(2, '0')}/ \){searchP.departureDate.month.toString().padLeft(2, '0')}",
                        onTap: () => _pickDate(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FieldBox(
                        icon: Icons.person_outline_rounded,
                        label: "Passagers",
                        value: "${searchP.passengers}",
                        onTap: () => _pickPassengers(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () async {
                          await ref.read(busSearchProvider.notifier).search();
                          if (context.mounted) context.push("/thix-reservation/bus/search");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThixPolicy.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 24),
              const Row(children: [
                Text("Routes populaires", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ThixPolicy.textMain)),
                Spacer(),
                Text("Voir tout", style: TextStyle(fontSize: 11, color: ThixPolicy.primary, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              if (_loadingPopular)
                const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)))
              else if (_popularRoutes.isEmpty)
                Container(
                  height: 80,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    border: Border.all(color: ThixPolicy.border),
                  ),
                  child: const Text("Aucune route populaire", style: TextStyle(color: ThixPolicy.textSecondary)),
                )
              else
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _popularRoutes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final r = _popularRoutes[i];
                      final dep = r["departure_city"] ?? "Kinshasa";
                      final arr = r["arrival_city"] ?? "Matadi";
                      final label = r["next_departure_label"] ?? "08:00";
                      final price = r["min_price"] ?? 5000;
                      final img = r["arrival_city_image"] ?? "https://images.unsplash.com/photo-1480714378408-67cf0d13bc1b?w=400";
                      return _RouteCard(
                        from: dep,
                        to: arr,
                        date: label,
                        price: "$price FCFA",
                        img: img,
                        onTap: () {},
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
              const Text("Nos bus pour votre confort", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ThixPolicy.textMain)),
              const SizedBox(height: 12),
              _buildAmenities(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmenities() {
    return FutureBuilder(
      future: Supabase.instance.client.from("bus_amenities").select().eq("is_active", true).limit(5),
      builder: (context, snap) {
        List<Map<String, dynamic>> items;
        if (snap.hasData && (snap.data as List).isNotEmpty) {
          items = List<Map<String, dynamic>>.from(snap.data as List);
        } else {
          items = _fallbackAmenities.map((e) => Map<String, dynamic>.from(e)).toList();
        }
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowSoft(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((a) {
              return _ComfortItem(
                icon: _iconFrom(a["icon_name"] as String?),
                label: a["label"] as String,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showCityPicker(BuildContext context, bool isDep) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CityPicker(isDep: isDep, fallback: _fallbackCities),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: ThixPolicy.primary)),
        child: child!,
      ),
    );
    if (d != null && mounted) ref.read(busSearchProvider.notifier).setDate(d);
  }

  void _pickPassengers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return Consumer(builder: (ctx, ref, _) {
          int p = ref.watch(busSearchProvider).passengers;
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Passagers", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain)),
                    Container(
                      decoration: BoxDecoration(
                        color: ThixPolicy.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ThixPolicy.border),
                      ),
                      child: Row(children: [
                        IconButton(
                          onPressed: () {
                            if (p > 1) ref.read(busSearchProvider.notifier).setPassengers(p - 1);
                          },
                          icon: const Icon(Icons.remove_rounded, color: ThixPolicy.textMain),
                        ),
                        SizedBox(
                          width: 30,
                          child: Text("$p", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        ),
                        IconButton(
                          onPressed: () => ref.read(busSearchProvider.notifier).setPassengers(p + 1),
                          icon: const Icon(Icons.add_rounded, color: ThixPolicy.textMain),
                        ),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixPolicy.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Confirmer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  IconData _iconFrom(String? n) {
    switch (n) {
      case "wifi":
        return Icons.wifi_rounded;
      case "ac":
        return Icons.ac_unit_rounded;
      case "luggage":
        return Icons.work_rounded;
      case "seat":
        return Icons.airline_seat_recline_extra_rounded;
      case "security":
        return Icons.verified_user_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }
}

class _Cat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final bool isMore;
  final VoidCallback onTap;
  const _Cat({
    required this.icon,
    required this.label,
    required this.color,
    this.active = false,
    this.isMore = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(children: [
          Container(
            width: ThixPolicy.constellationNodeSize,
            height: ThixPolicy.constellationNodeSize,
            decoration: BoxDecoration(
              color: active ? color.withOpacity(0.1) : (isMore ? ThixPolicy.surface : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: active ? color : (isMore ? Colors.transparent : ThixPolicy.border)),
            ),
            child: Icon(icon, size: ThixPolicy.constellationNodeIconSize, color: active || isMore ? color : ThixPolicy.primaryDeep),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? color : ThixPolicy.textMain,
            ),
          ),
        ]),
      );
}

class _FieldBox extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
  const _FieldBox({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ThixPolicy.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: ThixPolicy.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 9.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThixPolicy.textMain),
                  ),
                ],
              ),
            ),
          ]),
        ),
      );
}

class _RouteCard extends StatelessWidget {
  final String from, to, date, price, img;
  final VoidCallback onTap;
  const _RouteCard({
    required this.from,
    required this.to,
    required this.date,
    required this.price,
    required this.img,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Container(
          width: 148,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowSoft(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.rMd)),
                child: Image.network(
                  img,
                  height: 80,
                  width: 148,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 80, color: ThixPolicy.surface),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$from → $to", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: ThixPolicy.textMain)),
                    const SizedBox(height: 2),
                    Text(date, style: const TextStyle(fontSize: 9.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Text(price, style: const TextStyle(fontSize: 11.5, color: ThixPolicy.success, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _ComfortItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ComfortItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ThixPolicy.tint,
            shape: BoxShape.circle,
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Icon(icon, size: 18, color: ThixPolicy.primary),
        ),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: ThixPolicy.textMain)),
      ]);
}

class _CityPicker extends ConsumerStatefulWidget {
  final bool isDep;
  final List<String> fallback;
  const _CityPicker({required this.isDep, required this.fallback});
  @override
  ConsumerState<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends ConsumerState<_CityPicker> {
  List<String> all = [], filtered = [];
  bool loading = true;
  final ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    ctrl.addListener(() {
      setState(() {
        filtered = all.where((c) => c.toLowerCase().contains(ctrl.text.toLowerCase())).toList();
      });
    });
  }

  Future<void> _load() async {
    try {
      final r = await Supabase.instance.client.from("cities").select("name").order("name").limit(80);
      final list = (r as List).map((e) => e["name"] as String).toList();
      if (list.isNotEmpty) {
        all = list;
      } else {
        all = widget.fallback;
      }
    } catch (_) {
      all = widget.fallback;
    }
    setState(() {
      filtered = all;
      loading = false;
    });
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (_, c) => Column(children: [
        const SizedBox(height: 16),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: ctrl,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: widget.isDep ? "Ville de départ" : "Ville d'arrivée",
              hintStyle: const TextStyle(color: ThixPolicy.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, color: ThixPolicy.textSecondary),
              filled: true,
              fillColor: ThixPolicy.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)))
        else
          Expanded(
            child: ListView.separated(
              controller: c,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: ThixPolicy.border),
              itemBuilder: (_, i) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                title: Text(filtered[i], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ThixPolicy.textMain)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: ThixPolicy.textSecondary),
                onTap: () {
                  if (widget.isDep) {
                    ref.read(busSearchProvider.notifier).setDeparture(filtered[i]);
                  } else {
                    ref.read(busSearchProvider.notifier).setArrival(filtered[i]);
                  }
                  Navigator.pop(context);
                },
              ),
            ),
          ),
      ]),
    );
  }
}
