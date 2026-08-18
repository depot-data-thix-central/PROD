// lib/presentation/thix_reservation/delivery/pages/client/delivery_home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/nav.dart';
import '../../providers/delivery_client_provider.dart';
import '../../data/delivery_models.dart';

class DeliveryHomePage extends StatefulWidget {
  const DeliveryHomePage({super.key});
  @override
  State<DeliveryHomePage> createState() => _DeliveryHomePageState();
}

class _DeliveryHomePageState extends State<DeliveryHomePage> {
  static const kPurple = Color(0xFF5B2BD6);
  static const kPurpleLight = Color(0xFFF0EBFF);
  static const kBorder = Color(0xFFE8E8F0);
  static const kMuted = Color(0xFF8B8BA3);
  static const kBg = Color(0xFFF7F7FB);

  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _formKey = GlobalKey();

  // Type de colis — en attendant un champ dédié côté provider/modèle
  final List<String> _packageTypes = const ["Documents", "Colis standard", "Fragile", "Volumineux"];
  String _selectedPackageType = "";

  // --- Hero carousel (mock, auto-scroll) ---
  final PageController _heroCtrl = PageController();
  Timer? _heroTimer;
  int _heroIndex = 0;
  final List<_HeroSlide> _heroSlides = const [
    _HeroSlide(
      title: "Envoyez ou recevez\nvos colis en toute\nsimplicité",
      subtitle: "Rapide, sécurisé et au meilleur prix.",
      icon: Icons.local_shipping_rounded,
    ),
    _HeroSlide(
      title: "Livraison Express\nen 24-48h",
      subtitle: "Vos colis livrés au plus vite.",
      icon: Icons.bolt_rounded,
    ),
    _HeroSlide(
      title: "Suivi en temps réel\nde vos envois",
      subtitle: "Sachez toujours où est votre colis.",
      icon: Icons.location_on_rounded,
    ),
    _HeroSlide(
      title: "Points relais\nprès de chez vous",
      subtitle: "Retirez ou déposez en toute liberté.",
      icon: Icons.storefront_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryClientProvider>().init();
    });
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_heroCtrl.hasClients) return;
      _heroIndex = (_heroIndex + 1) % _heroSlides.length;
      _heroCtrl.animateToPage(
        _heroIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToForm() {
    final ctx = _formKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  // Stub pour toute route pas encore créée dans AppRoutes.
  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$label — bientôt disponible")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(),
      body: Consumer<DeliveryClientProvider>(builder: (context, prov, _) {
        if (prov.isLoading) {
          return const Center(child: CircularProgressIndicator(color: kPurple));
        }
        return RefreshIndicator(
          onRefresh: () => prov.loadRoutes(),
          color: kPurple,
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildHero(prov),
              const SizedBox(height: 16),
              _buildCategories(),
              const SizedBox(height: 16),
              _buildFormCard(prov),
              const SizedBox(height: 16),
              _buildActionsRapides(prov),
              const SizedBox(height: 16),
              _buildOffres(prov),
              const SizedBox(height: 16),
              _buildCommentCaMarche(),
              const SizedBox(height: 16),
              _buildBesoinAide(),
              const SizedBox(height: 90),
            ]),
          ),
        );
      }),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ---------------- AppBar ----------------
  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 12,
        title: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: kPurple, borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(
              text: const TextSpan(children: [
                TextSpan(text: "THIX ", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                TextSpan(text: "RESERVATION", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kPurple)),
              ]),
            ),
            const Text("Livrez vos colis en toute simplicité.", style: TextStyle(fontSize: 9.5, color: kMuted)),
          ]),
        ]),
        actions: [
          InkWell(
            onTap: () => _comingSoon("Notifications"),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: kBg, shape: BoxShape.circle, border: Border.all(color: kBorder)),
              child: const Icon(Icons.notifications_none_rounded, size: 17, color: Color(0xFF1A1A2E)),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => context.push(AppRoutes.deliveryAdminDashboard),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: kPurple, shape: BoxShape.circle),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 17),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: kPurpleLight,
              child: const Icon(Icons.person_rounded, color: kPurple, size: 18),
            ),
          ),
        ],
      );

  // ---------------- Hero (mock, auto-scroll) ----------------
  Widget _buildHero(DeliveryClientProvider prov) {
    return Column(children: [
      SizedBox(
        height: 190,
        child: PageView.builder(
          controller: _heroCtrl,
          itemCount: _heroSlides.length,
          onPageChanged: (i) => setState(() => _heroIndex = i),
          itemBuilder: (_, i) {
            final s = _heroSlides[i];
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(colors: [kPurple, Color(0xFF7C4DFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Stack(children: [
                Positioned(
                  right: -10, bottom: -10,
                  child: Icon(s.icon, size: 110, color: Colors.white.withOpacity(0.12)),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text("Bonjour \u{1F44B}", style: TextStyle(color: Color(0xFFD9CCFF), fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(s.title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.15)),
                    const SizedBox(height: 6),
                    Text(s.subtitle, style: const TextStyle(color: Color(0xFFEDE7FF), fontSize: 11)),
                    const Spacer(),
                    InkWell(
                      onTap: _scrollToForm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.inventory_2_rounded, size: 14, color: kPurple),
                          SizedBox(width: 6),
                          Text("Envoyer un colis", style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 12, fontWeight: FontWeight.w800)),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, size: 15, color: kPurple),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_heroSlides.length, (i) {
          final active = i == _heroIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(color: active ? kPurple : kBorder, borderRadius: BorderRadius.circular(4)),
          );
        }),
      ),
    ]);
  }

  // ---------------- Catégories ----------------
  Widget _buildCategories() {
    final items = <_CatItem>[
      _CatItem("Hôtels", Icons.apartment_rounded, () => _comingSoon("Hôtels")),
      _CatItem("Vols", Icons.flight_rounded, () => _comingSoon("Vols")),
      _CatItem("Bus", Icons.directions_bus_filled_rounded, () => _comingSoon("Bus")),
      _CatItem("Transports", Icons.directions_car_filled_rounded, () => _comingSoon("Transports")),
      _CatItem("Livraison colis", Icons.inventory_2_rounded, () {}, selected: true),
      _CatItem("Événements", Icons.confirmation_number_rounded, () => _comingSoon("Événements")),
      _CatItem("Plus", Icons.more_horiz_rounded, () => _comingSoon("Plus")),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((it) => InkWell(
          onTap: it.onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: it.selected ? kPurple : kPurpleLight, borderRadius: BorderRadius.circular(10)),
                child: Icon(it.icon, size: 17, color: it.selected ? Colors.white : kPurple),
              ),
              const SizedBox(height: 4),
              Text(it.label, style: TextStyle(fontSize: 8.5, fontWeight: it.selected ? FontWeight.w800 : FontWeight.w500, color: it.selected ? kPurple : const Color(0xFF1A1A2E))),
            ]),
          ),
        )).toList(),
      ),
    );
  }

  // ---------------- Formulaire ----------------
  Widget _buildFormCard(DeliveryClientProvider prov) {
    return Container(
      key: _formKey,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Envoyer un colis", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          InkWell(
            onTap: () => _comingSoon("Aide"),
            child: const Row(children: [
              Icon(Icons.headset_mic_rounded, size: 13, color: kPurple),
              SizedBox(width: 4),
              Text("Besoin d'aide ?", style: TextStyle(fontSize: 10, color: kPurple, fontWeight: FontWeight.w700)),
              Icon(Icons.chevron_right_rounded, size: 13, color: kPurple),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _addressField("Expéditeur", prov.fromCity, () => _pickFrom(prov))),
        ]),
        Center(
          child: InkWell(
            onTap: () => prov.swapCities(),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              width: 30, height: 30,
              decoration: BoxDecoration(border: Border.all(color: kBorder), shape: BoxShape.circle, color: Colors.white),
              child: const Icon(Icons.swap_vert_rounded, size: 15, color: kPurple),
            ),
          ),
        ),
        Row(children: [
          Expanded(child: _addressField("Destinataire", prov.toCity, () => _pickTo(prov))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _field(Icons.category_rounded, "Type de colis", _selectedPackageType.isEmpty ? "Sélectionner" : _selectedPackageType, _pickPackageType)),
          const SizedBox(width: 8),
          Expanded(child: _field(Icons.scale_rounded, "Poids estimé", prov.weightKg == 0 ? "Sélectionner" : "0 - ${prov.weightKg} kg", () => _pickWeight(prov))),
          const SizedBox(width: 8),
          Expanded(child: _field(Icons.local_shipping_rounded, "Mode de livraison", prov.deliveryMode.label, () => _pickMode(prov))),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPurple, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              if (prov.fromCity.isEmpty || prov.toCity.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Choisis les villes admin")));
                return;
              }
              if (prov.calculatedPrice == 0) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Trajet ${prov.fromCity} → ${prov.toCity} non tarifé")));
                return;
              }
              context.push(AppRoutes.deliveryCheckout);
            },
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (prov.calculatedPrice == 0) const Icon(Icons.search_rounded, color: Colors.white, size: 16),
              if (prov.calculatedPrice == 0) const SizedBox(width: 8),
              Text(
                prov.calculatedPrice > 0 ? "${prov.calculatedPrice} FCFA - Continuer" : "Calculer le prix et continuer",
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ]),
          ),
        ),
        if (prov.popularRoutes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: prov.popularRoutes.map((r) => InkWell(
              onTap: () { prov.setFromCity(r.fromCity); prov.setToCity(r.toCity); },
              child: Chip(
                label: Text("${r.fromCity} → ${r.toCity}", style: const TextStyle(fontSize: 9)),
                backgroundColor: kPurpleLight,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide.none,
              ),
            )).toList(),
          ),
        ]
      ]),
    );
  }

  Widget _addressField(String label, String value, VoidCallback tap) => InkWell(
        onTap: tap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(color: kPurpleLight, shape: BoxShape.circle),
              child: const Icon(Icons.location_on_rounded, size: 14, color: kPurple),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 9, color: kMuted)),
                Text(value.isEmpty ? "Choisir la ville" : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              ]),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: kMuted),
          ]),
        ),
      );

  Widget _field(IconData icon, String h, String v, VoidCallback tap) => InkWell(
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 11, color: kPurple),
              const SizedBox(width: 3),
              Expanded(child: Text(h, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: kMuted))),
            ]),
            const SizedBox(height: 3),
            Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  // ---------------- Actions rapides ----------------
  Widget _buildActionsRapides(DeliveryClientProvider prov) {
    final items = <_QuickAction>[
      _QuickAction("Suivre un colis", "Suivez l'acheminement\nde votre colis", Icons.qr_code_scanner_rounded, const Color(0xFF5B2BD6), () => _comingSoon("Suivi de colis")),
      _QuickAction("Recevoir un colis", "Recevez un colis\nen attente", Icons.download_rounded, const Color(0xFF00B26A), () => _comingSoon("Recevoir un colis")),
      _QuickAction("Mes envois", "Consultez l'historique\nde vos envois", Icons.receipt_long_rounded, const Color(0xFF2D6CDF), () => _comingSoon("Mes envois")),
      _QuickAction("Points relais", "Trouvez un point\nrelais proche", Icons.location_on_rounded, const Color(0xFFE07A2D), () => _comingSoon("Points relais")),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Actions rapides", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.6,
          children: items.map((a) => InkWell(
            onTap: a.onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: a.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(a.icon, size: 14, color: a.color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(a.subtitle, style: const TextStyle(fontSize: 7.5, color: kMuted, height: 1.2)),
                  ]),
                ),
              ]),
            ),
          )).toList(),
        ),
      ]),
    );
  }

  // ---------------- Offres ----------------
  Widget _buildOffres(DeliveryClientProvider prov) {
    if (prov.offers.isEmpty) return const SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("Offres du moment", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        InkWell(
          onTap: () => _comingSoon("Toutes les offres"),
          child: const Row(children: [
            Text("Voir tout", style: TextStyle(fontSize: 10, color: kPurple, fontWeight: FontWeight.w700)),
            Icon(Icons.chevron_right_rounded, size: 14, color: kPurple),
          ]),
        ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: prov.offers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final o = prov.offers[i];
            return Container(
              width: 130,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFE6F9F1), borderRadius: BorderRadius.circular(6)),
                  child: Text("-${o.discountPercent}%", style: const TextStyle(fontSize: 8.5, color: Color(0xFF00B26A), fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 6),
                Text(o.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text("${o.newPrice} F", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  // ---------------- Comment ça marche (statique) ----------------
  Widget _buildCommentCaMarche() {
    final steps = [
      ("Renseignez les\ndétails de votre colis", Icons.inventory_2_rounded),
      ("Choisissez le mode\nde livraison", Icons.local_shipping_rounded),
      ("Payez en toute\nsécurité", Icons.credit_card_rounded),
      ("Nous livrons à\ndestination", Icons.check_circle_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Comment ça marche ?", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: List.generate(steps.length, (i) {
            final s = steps[i];
            return Expanded(
              child: Row(children: [
                Expanded(
                  child: Column(children: [
                    Container(
                      width: 26, height: 26,
                      decoration: const BoxDecoration(color: kPurple, shape: BoxShape.circle),
                      child: Center(child: Text("${i + 1}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                    ),
                    const SizedBox(height: 6),
                    Icon(s.$2, size: 20, color: const Color(0xFF1A1A2E)),
                    const SizedBox(height: 5),
                    Text(s.$1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w600, height: 1.2)),
                  ]),
                ),
                if (i != steps.length - 1) const Icon(Icons.chevron_right_rounded, size: 13, color: kBorder),
              ]),
            );
          }),
        ),
      ]),
    );
  }

  // ---------------- Besoin d'aide ----------------
  Widget _buildBesoinAide() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kPurpleLight, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: const Icon(Icons.headset_mic_rounded, color: kPurple, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Besoin d'aide ?", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
            const Text("Notre équipe est disponible 24h/24 et 7j/7", style: TextStyle(fontSize: 8.5, color: kMuted)),
          ]),
        ),
        InkWell(
          onTap: () => _comingSoon("Contact"),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: kPurple, borderRadius: BorderRadius.circular(9)),
            child: const Text("Nous contacter", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  // ---------------- Bottom Nav ----------------
  Widget _buildBottomNav() => Container(
        height: 62,
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -2))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, crossAxisAlignment: CrossAxisAlignment.center, children: [
          _navIcon(Icons.home_rounded, "Accueil", true, () => context.go(AppRoutes.home)),
          _navIcon(Icons.receipt_long_outlined, "Réservations", false, () => _comingSoon("Réservations")),
          InkWell(
            onTap: _scrollToForm,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 46, height: 46,
                decoration: const BoxDecoration(color: kPurple, shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 2),
              const Text("Envoyer", style: TextStyle(fontSize: 8, color: kPurple, fontWeight: FontWeight.w700)),
            ]),
          ),
          _navIcon(Icons.favorite_border_rounded, "Favoris", false, () => _comingSoon("Favoris")),
          _navIcon(Icons.person_outline_rounded, "Profil", false, () => context.push('/dashboard')),
        ]),
      );

  Widget _navIcon(IconData icon, String label, bool active, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: active ? kPurple : kMuted),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 8, color: active ? kPurple : kMuted, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
        ]),
      );

  // ---------------- Pickers ----------------
  void _pickFrom(DeliveryClientProvider prov) {
    final list = prov.popularRoutes.map((e) => e.fromCity).toSet().toList();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucune route - Admin doit créer")));
      return;
    }
    showModalBottomSheet(context: context, builder: (_) => ListView(children: list.map((c) => ListTile(title: Text(c), onTap: () { prov.setFromCity(c); Navigator.pop(context); })).toList()));
  }

  void _pickTo(DeliveryClientProvider prov) {
    final list = prov.popularRoutes.map((e) => e.toCity).toSet().toList();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucune route - Admin doit créer")));
      return;
    }
    showModalBottomSheet(context: context, builder: (_) => ListView(children: list.map((c) => ListTile(title: Text(c), onTap: () { prov.setToCity(c); Navigator.pop(context); })).toList()));
  }

  void _pickWeight(DeliveryClientProvider prov) => showModalBottomSheet(
        context: context,
        builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [1, 3, 5, 10, 20].map((w) => ListTile(title: Text("$w kg"), onTap: () { prov.setWeight(w); Navigator.pop(context); })).toList()),
      );

  void _pickMode(DeliveryClientProvider prov) => showModalBottomSheet(
        context: context,
        builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: DeliveryMode.values.map((m) => ListTile(title: Text(m.label), onTap: () { prov.setMode(m); Navigator.pop(context); })).toList()),
      );

  void _pickPackageType() => showModalBottomSheet(
        context: context,
        builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: _packageTypes.map((t) => ListTile(title: Text(t), onTap: () { setState(() => _selectedPackageType = t); Navigator.pop(context); })).toList()),
      );
}

class _HeroSlide {
  final String title;
  final String subtitle;
  final IconData icon;
  const _HeroSlide({required this.title, required this.subtitle, required this.icon});
}

class _CatItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  _CatItem(this.label, this.icon, this.onTap, {this.selected = false});
}

class _QuickAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _QuickAction(this.title, this.subtitle, this.icon, this.color, this.onTap);
}
