// ================================================================
// CHEMIN: lib/presentation/thix_reservation/delivery/widgets/delivery_widgets.dart
// ROLE: Tous les widgets CLIENT fusionnés en 1 fichier
//       Contient tout ce que tu vois sur ta maquette
//       Hero + Categories + Form + Actions rapides + Offres + Stepper
// SCALABLE: const constructor + ListView.builder + pas de setState interne
// ================================================================

import 'package:flutter/material.dart';
import '../data/delivery_models.dart';

// Couleurs de ta maquette THIX
const _primary = Color(0xFF6D28D9);
const _primaryLight = Color(0xFFF5F3FF);
const _bgGrey = Color(0xFFF9FAFB);

// --------------------------------------------------------------
// WIDGET 1: HERO SLIDER VIOLET - "Bonjour Michel"
// C'est le gros bloc violet en haut de ta maquette
// --------------------------------------------------------------
class DeliveryHeroSlider extends StatefulWidget {
  final String userName;
  final VoidCallback onSendTap;
  const DeliveryHeroSlider({super.key, required this.userName, required this.onSendTap});

  @override
  State<DeliveryHeroSlider> createState() => _DeliveryHeroSliderState();
}

class _DeliveryHeroSliderState extends State<DeliveryHeroSlider> {
  // --- PageController pour auto-scroll comme sur ta maquette ---
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Auto-scroll toutes les 4s pour effet slider
    Future.delayed(const Duration(seconds: 4), _autoScroll);
  }

  void _autoScroll() {
    if (!mounted) return;
    _currentIndex = (_currentIndex + 1) % 3;
    _pageController.animateToPage(_currentIndex, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    Future.delayed(const Duration(seconds: 4), _autoScroll);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: PageView(
        controller: _pageController,
        children: [
          // Slide 1 - Principal "Envoyez ou recevez"
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Texte à gauche
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Petit "Bonjour Michel"
                      Text("Bonjour, ${widget.userName} 👋", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 8),
                      const Text("Envoyez ou recevez\nvos colis en toute\nsimplicité", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2)),
                      const SizedBox(height: 6),
                      const Text("Rapide, sécurisé et au meilleur prix.", style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 12),
                      // Bouton blanc "Envoyer un colis"
                      InkWell(
                        onTap: widget.onSendTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2, size: 18, color: _primary),
                              SizedBox(width: 6),
                              Text("Envoyer un colis", style: TextStyle(color: _primary, fontWeight: FontWeight.bold, fontSize: 12)),
                              Icon(Icons.chevron_right, size: 18, color: _primary),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                // Image van à droite (tu mettras ton asset)
                const Icon(Icons.local_shipping, size: 80, color: Colors.white),
              ],
            ),
          ),
          // Slide 2 et 3 - même design pour auto-scroll
          const Center(child: Text("Express 24-48h disponible", style: TextStyle(color: Colors.white))),
          const Center(child: Text("Points relais partout en CI", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------
// WIDGET 2: CATEGORIES - Hôtels / Vols / Bus / Transports etc
// C'est la ligne d'icônes sous le hero
// --------------------------------------------------------------
class DeliveryCategoryRow extends StatelessWidget {
  final String selected; // Livraison colis est sélectionné par défaut
  final Function(String) onSelect;
  const DeliveryCategoryRow({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    // --- Liste des catégories de ton app THIX ---
    final cats = [
      {"label": "Hôtels", "icon": Icons.apartment, "color": Colors.blue},
      {"label": "Vols", "icon": Icons.flight, "color": Colors.green},
      {"label": "Bus", "icon": Icons.directions_bus, "color": Colors.orange},
      {"label": "Transports", "icon": Icons.directions_car, "color": Colors.purple},
      {"label": "Livraison colis", "icon": Icons.inventory_2, "color": _primary},
      {"label": "Évènements", "icon": Icons.local_activity, "color": Colors.red},
      {"label": "Plus", "icon": Icons.more_horiz, "color": Colors.grey},
    ];

    return SizedBox(
      height: 80,
      child: ListView.builder(
        // ListView.builder scalable pour 1M users
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        itemBuilder: (context, i) {
          final cat = cats[i];
          final isSel = selected == cat["label"];
          return GestureDetector(
            onTap: () => onSelect(cat["label"] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? _primaryLight : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSel ? _primary : Colors.grey.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(cat["icon"] as IconData, color: cat["color"] as Color, size: 26),
                  const SizedBox(height: 4),
                  Text(cat["label"] as String, style: TextStyle(fontSize: 10, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? _primary : Colors.black87)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --------------------------------------------------------------
// WIDGET 3: FORM CARD - "Envoyer un colis" avec National/Inter
// C'est le coeur de ta maquette, le formulaire
// --------------------------------------------------------------
class DeliveryFormCard extends StatelessWidget {
  final bool isNational;
  final String fromCity;
  final String toCity;
  final int weight;
  final DeliveryMode mode;
  final bool isCalculating;
  final int price;
  final VoidCallback onSwap;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;
  final Function(int) onWeightChanged;
  final Function(DeliveryMode) onModeChanged;
  final Function(bool) onNationalChanged;
  final VoidCallback onCalculate;

  const DeliveryFormCard({
    super.key,
    required this.isNational,
    required this.fromCity,
    required this.toCity,
    required this.weight,
    required this.mode,
    required this.isCalculating,
    required this.price,
    required this.onSwap,
    required this.onFromTap,
    required this.onToTap,
    required this.onWeightChanged,
    required this.onNationalChanged,
    required this.onModeChanged,
    required this.onCalculate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Envoyer un colis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(onPressed: () {}, icon: const Icon(Icons.headset_mic, size: 16), label: const Text("Besoin d'aide ?", style: TextStyle(fontSize: 11))),
            ],
          ),
          // Toggle National / International
          Row(
            children: [
              ChoiceChip(label: const Text("National"), selected: isNational, onSelected: (v) => onNationalChanged(true)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text("International"), selected: !isNational, onSelected: (v) => onNationalChanged(false)),
            ],
          ),
          const SizedBox(height: 12),

          // --- From / To avec bouton swap au milieu ---
          Row(
            children: [
              Expanded(child: _CityField(label: "Expéditeur", value: fromCity, onTap: onFromTap)),
              // Bouton swap
              IconButton(onPressed: onSwap, icon: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _primary)), child: const Icon(Icons.swap_horiz, size: 18, color: _primary))),
              Expanded(child: _CityField(label: "Destinataire", value: toCity, onTap: onToTap)),
            ],
          ),
          const SizedBox(height: 12),

          // --- Type / Poids / Mode en 3 colonnes ---
          Row(
            children: [
              Expanded(child: _SmallDropdown(label: "Type de colis", value: "Sélectionner", onTap: () {})),
              const SizedBox(width: 8),
              Expanded(child: _SmallDropdown(label: "Poids estimé", value: "$weight kg", onTap: () {})),
              const SizedBox(width: 8),
              Expanded(child: _SmallDropdown(label: "Mode de livraison", value: mode.label, onTap: () {})),
            ],
          ),
          const SizedBox(height: 16),

          // --- Bouton violet CALCULER PRIX ---
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: isCalculating ? null : onCalculate,
              icon: isCalculating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search, color: Colors.white),
              label: Text(price > 0 ? "$price FCFA - Continuer" : "Calculer le prix et continuer", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

// Sous-widgets privés pour FormCard
class _CityField extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _CityField({required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _bgGrey, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _SmallDropdown extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _SmallDropdown({required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _bgGrey, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey)),
          Row(children: [Expanded(child: Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), const Icon(Icons.keyboard_arrow_down, size: 14)]),
        ]),
      ),
    );
  }
}

// --------------------------------------------------------------
// WIDGET 4: ACTIONS RAPIDES - 4 tuiles de ta maquette
// --------------------------------------------------------------
class DeliveryQuickActions extends StatelessWidget {
  const DeliveryQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {"title": "Suivre un colis", "sub": "Suivez l'acheminement", "icon": Icons.inventory_2_outlined, "color": _primary},
      {"title": "Recevoir un colis", "sub": "Recevez un colis en attente", "icon": Icons.download, "color": Colors.green},
      {"title": "Mes envois", "sub": "Consultez l'historique", "icon": Icons.assignment_outlined, "color": Colors.purple},
      {"title": "Points relais", "sub": "Trouvez un point proche", "icon": Icons.location_on, "color": Colors.orange},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Actions rapides", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.6, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: actions.length,
          itemBuilder: (context, i) {
            final a = actions[i];
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: (a["color"] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(a["icon"] as IconData, size: 20, color: a["color"] as Color)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a["title"] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), Text(a["sub"] as String, style: const TextStyle(fontSize: 9, color: Colors.grey), maxLines: 2)])),
              ]),
            );
          },
        )
      ],
    );
  }
}

// --------------------------------------------------------------
// WIDGET 5: OFFRES DU MOMENT - Cards -20% -15% etc
// --------------------------------------------------------------
class DeliveryOffersList extends StatelessWidget {
  final List<DeliveryOffer> offers;
  const DeliveryOffersList({super.key, required this.offers});

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Offres du moment", style: TextStyle(fontWeight: FontWeight.bold)), TextButton(onPressed: () {}, child: const Text("Voir tout", style: TextStyle(fontSize: 11)))]),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: offers.length,
            itemBuilder: (context, i) {
              final o = offers[i];
              return Container(
                width: 130,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)), child: Text("-${o.discountPercent}%", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 8),
                  const Icon(Icons.card_giftcard, size: 40, color: _primary),
                  const Spacer(),
                  Text(o.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Text("${o.newPrice} FCFA", style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                ]),
              );
            },
          ),
        )
      ],
    );
  }
}

// --------------------------------------------------------------
// WIDGET 6: COMMENT ÇA MARCHE ? - Stepper 1-2-3-4
// --------------------------------------------------------------
class DeliveryHowItWorks extends StatelessWidget {
  const DeliveryHowItWorks({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      {"n": "1", "icon": Icons.inventory_2, "text": "Renseignez les détails"},
      {"n": "2", "icon": Icons.credit_card, "text": "Choisissez le mode"},
      {"n": "3", "icon": Icons.payment, "text": "Payez en sécurité"},
      {"n": "4", "icon": Icons.local_shipping, "text": "Nous livrons à destination"},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Comment ça marche ?", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (i) {
              final s = steps[i];
              return Row(
                children: [
                  Column(children: [
                    CircleAvatar(radius: 10, backgroundColor: _primary, child: Text(s["n"] as String, style: const TextStyle(fontSize: 10, color: Colors.white))),
                    const SizedBox(height: 6),
                    Icon(s["icon"] as IconData, size: 28),
                    const SizedBox(height: 4),
                    SizedBox(width: 70, child: Text(s["text"] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9))),
                  ]),
                  if (i != steps.length - 1) const Padding(padding: EdgeInsets.only(bottom: 20), child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey)),
                ],
              );
            }),
          )
        ],
      ),
    );
  }
}
