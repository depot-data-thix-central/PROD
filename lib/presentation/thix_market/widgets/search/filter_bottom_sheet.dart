import 'package:flutter/material.dart';

class FilterBottomSheet extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  final ValueChanged<Map<String, dynamic>> onApply;

  const FilterBottomSheet({super.key, required this.currentFilters, required this.onApply});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  double _minRating = 0;
  bool _freeShipping = false;
  bool _verifiedSellers = false;

  @override
  void initState() {
    super.initState();
    _minPriceController = TextEditingController(text: '${widget.currentFilters['min_price'] ?? ''}');
    _maxPriceController = TextEditingController(text: '${widget.currentFilters['max_price'] ?? ''}');
    _minRating = ((widget.currentFilters['min_rating'] ?? 0) as num).toDouble();
    _freeShipping = widget.currentFilters['free_shipping'] == true;
    _verifiedSellers = widget.currentFilters['verified_sellers'] == true;
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _minPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix min'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _maxPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix max'))),
              ],
            ),
            const SizedBox(height: 16),
            Text('Note minimale: ${_minRating.toStringAsFixed(1)}'),
            Slider(value: _minRating, min: 0, max: 5, divisions: 10, onChanged: (value) => setState(() => _minRating = value)),
            SwitchListTile(value: _freeShipping, onChanged: (value) => setState(() => _freeShipping = value), title: const Text('Livraison gratuite')),
            SwitchListTile(value: _verifiedSellers, onChanged: (value) => setState(() => _verifiedSellers = value), title: const Text('Vendeurs vérifiés')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      widget.onApply({});
                      Navigator.pop(context);
                    },
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply({
                        if (_minPriceController.text.isNotEmpty) 'min_price': num.tryParse(_minPriceController.text),
                        if (_maxPriceController.text.isNotEmpty) 'max_price': num.tryParse(_maxPriceController.text),
                        if (_minRating > 0) 'min_rating': _minRating,
                        'free_shipping': _freeShipping,
                        'verified_sellers': _verifiedSellers,
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
