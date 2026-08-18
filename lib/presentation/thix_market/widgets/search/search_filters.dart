import 'package:flutter/material.dart';

class SearchFilters extends StatefulWidget {
  final Function(Map<String, dynamic> filters) onApply;
  final Map<String, dynamic>? initialFilters;

  const SearchFilters({
    super.key,
    required this.onApply,
    this.initialFilters,
  });

  @override
  State<SearchFilters> createState() => _SearchFiltersState();
}

class _SearchFiltersState extends State<SearchFilters> {
  // ============================================================
  // CHARTE ÉLITE (identique à la page d’accueil)
  // ============================================================
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color navy = Color(0xFF123B7A);
  static const Color primaryBlue = Color(0xFF2D6CDF);
  static const Color softBlue = Color(0xFFEFF5FF);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF10192E);
  static const Color mutedText = Color(0xFF7386A8);
  static const Color gold = Color(0xFFE3B23C);
  static const Color danger = Color(0xFFFF5B3D);

  RangeValues _priceRange = const RangeValues(0, 1000000);
  RangeValues _distanceRange = const RangeValues(0, 50);
  double _minRating = 0;
  String? _selectedCondition;
  String? _selectedShipping;
  List<String> _selectedPaymentMethods = [];
  bool _hasFreeShipping = false;
  bool _onlyVerifiedSellers = false;

  final List<Map<String, dynamic>> _conditions = [
    {'id': 'new', 'name': 'Neuf', 'icon': Icons.fiber_new_rounded},
    {'id': 'like_new', 'name': 'Comme neuf', 'icon': Icons.star_rounded},
    {'id': 'good', 'name': 'Bon état', 'icon': Icons.thumb_up_rounded},
    {'id': 'fair', 'name': 'État correct', 'icon': Icons.hourglass_empty_rounded},
  ];

  final List<Map<String, dynamic>> _shippingOptions = [
    {'id': 'delivery', 'name': 'Livraison', 'icon': Icons.local_shipping_rounded},
    {'id': 'pickup', 'name': 'Retrait', 'icon': Icons.storefront_rounded},
    {'id': 'both', 'name': 'Les deux', 'icon': Icons.swap_horiz_rounded},
  ];

  final List<Map<String, dynamic>> _paymentMethods = [
    {'id': 'thix_money', 'name': 'THIX Money', 'icon': Icons.account_balance_wallet_rounded},
    {'id': 'card', 'name': 'Carte bancaire', 'icon': Icons.credit_card_rounded},
    {'id': 'mobile_money', 'name': 'Mobile Money', 'icon': Icons.phone_android_rounded},
    {'id': 'cash', 'name': 'Espèces', 'icon': Icons.money_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialFilters();
  }

  void _loadInitialFilters() {
    if (widget.initialFilters != null) {
      setState(() {
        _priceRange = RangeValues(
          widget.initialFilters!['min_price']?.toDouble() ?? 0,
          widget.initialFilters!['max_price']?.toDouble() ?? 1000000,
        );
        _distanceRange = RangeValues(
          widget.initialFilters!['min_distance']?.toDouble() ?? 0,
          widget.initialFilters!['max_distance']?.toDouble() ?? 50,
        );
        _minRating = widget.initialFilters!['min_rating']?.toDouble() ?? 0;
        _selectedCondition = widget.initialFilters!['condition'];
        _selectedShipping = widget.initialFilters!['shipping_type'];
        _selectedPaymentMethods = List<String>.from(widget.initialFilters!['payment_methods'] ?? []);
        _hasFreeShipping = widget.initialFilters!['free_shipping'] ?? false;
        _onlyVerifiedSellers = widget.initialFilters!['verified_sellers'] ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: const BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── En-tête ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtres avancés',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: darkText),
              ),
              TextButton(
                onPressed: _resetFilters,
                style: TextButton.styleFrom(foregroundColor: danger),
                child: const Text('Réinitialiser', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── Prix ───────────────────────────────────────────────
          const Text(
            'Prix',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText),
          ),
          const SizedBox(height: 6),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 1000000,
            divisions: 100,
            labels: RangeLabels(
              '${_priceRange.start.toInt()} FCFA',
              '${_priceRange.end.toInt()} FCFA',
            ),
            activeColor: primaryBlue,
            inactiveColor: softBlue,
            onChanged: (values) => setState(() => _priceRange = values),
          ),
          const SizedBox(height: 6),

          // ─── Distance ───────────────────────────────────────────
          const Text(
            'Distance (km)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText),
          ),
          const SizedBox(height: 6),
          RangeSlider(
            values: _distanceRange,
            min: 0,
            max: 50,
            divisions: 50,
            labels: RangeLabels(
              '${_distanceRange.start.toInt()} km',
              '${_distanceRange.end.toInt()} km',
            ),
            activeColor: primaryBlue,
            inactiveColor: softBlue,
            onChanged: (values) => setState(() => _distanceRange = values),
          ),
          const SizedBox(height: 6),

          // ─── Note minimale ──────────────────────────────────────
          const Text(
            'Note minimum',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _minRating,
                  min: 0,
                  max: 5,
                  divisions: 10,
                  activeColor: primaryBlue,
                  inactiveColor: softBlue,
                  label: _minRating.toStringAsFixed(1),
                  onChanged: (value) => setState(() => _minRating = value),
                ),
              ),
              SizedBox(
                width: 60,
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: gold, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _minRating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: darkText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ─── État ───────────────────────────────────────────────
          const Text(
            'État',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _conditions.map((condition) {
              final isSelected = _selectedCondition == condition['id'];
              return FilterChip(
                label: Text(condition['name']),
                avatar: Icon(condition['icon'], size: 16, color: isSelected ? primaryBlue : mutedText),
                selected: isSelected,
                onSelected: (selected) => setState(() {
                  _selectedCondition = selected ? condition['id'] : null;
                }),
                selectedColor: softBlue,
                checkmarkColor: primaryBlue,
                side: BorderSide(
                  color: isSelected ? primaryBlue : Colors.grey[200]!,
                  width: isSelected ? 1.5 : 1,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // ─── Options de livraison ──────────────────────────────
          const Text(
            'Option de livraison',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _shippingOptions.map((option) {
              final isSelected = _selectedShipping == option['id'];
              return FilterChip(
                label: Text(option['name']),
                avatar: Icon(option['icon'], size: 16, color: isSelected ? primaryBlue : mutedText),
                selected: isSelected,
                onSelected: (selected) => setState(() {
                  _selectedShipping = selected ? option['id'] : null;
                }),
                selectedColor: softBlue,
                checkmarkColor: primaryBlue,
                side: BorderSide(
                  color: isSelected ? primaryBlue : Colors.grey[200]!,
                  width: isSelected ? 1.5 : 1,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // ─── Modes de paiement ──────────────────────────────────
          const Text(
            'Modes de paiement',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _paymentMethods.map((method) {
              final isSelected = _selectedPaymentMethods.contains(method['id']);
              return FilterChip(
                label: Text(method['name']),
                avatar: Icon(method['icon'], size: 16, color: isSelected ? primaryBlue : mutedText),
                selected: isSelected,
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _selectedPaymentMethods.add(method['id']);
                  } else {
                    _selectedPaymentMethods.remove(method['id']);
                  }
                }),
                selectedColor: softBlue,
                checkmarkColor: primaryBlue,
                side: BorderSide(
                  color: isSelected ? primaryBlue : Colors.grey[200]!,
                  width: isSelected ? 1.5 : 1,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // ─── Options supplémentaires ────────────────────────────
          SwitchListTile(
            title: const Text(
              'Livraison gratuite uniquement',
              style: TextStyle(fontWeight: FontWeight.w500, color: darkText),
            ),
            value: _hasFreeShipping,
            onChanged: (value) => setState(() => _hasFreeShipping = value),
            activeColor: primaryBlue,
            inactiveTrackColor: softBlue,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text(
              'Vendeurs vérifiés uniquement',
              style: TextStyle(fontWeight: FontWeight.w500, color: darkText),
            ),
            value: _onlyVerifiedSellers,
            onChanged: (value) => setState(() => _onlyVerifiedSellers = value),
            activeColor: primaryBlue,
            inactiveTrackColor: softBlue,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 20),

          // ─── Boutons ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                    foregroundColor: mutedText,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_getFilters());
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: pureWhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Appliquer', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getFilters() {
    return {
      'min_price': _priceRange.start.toInt(),
      'max_price': _priceRange.end.toInt(),
      'min_distance': _distanceRange.start.toInt(),
      'max_distance': _distanceRange.end.toInt(),
      'min_rating': _minRating,
      'condition': _selectedCondition,
      'shipping_type': _selectedShipping,
      'payment_methods': _selectedPaymentMethods,
      'free_shipping': _hasFreeShipping,
      'verified_sellers': _onlyVerifiedSellers,
    };
  }

  void _resetFilters() {
    setState(() {
      _priceRange = const RangeValues(0, 1000000);
      _distanceRange = const RangeValues(0, 50);
      _minRating = 0;
      _selectedCondition = null;
      _selectedShipping = null;
      _selectedPaymentMethods = [];
      _hasFreeShipping = false;
      _onlyVerifiedSellers = false;
    });
  }
}
