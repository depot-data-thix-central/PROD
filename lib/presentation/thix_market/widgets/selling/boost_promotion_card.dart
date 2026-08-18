import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BoostPromotionCard extends StatefulWidget {
  final String announcementId;
  final String announcementTitle;

  const BoostPromotionCard({
    super.key,
    required this.announcementId,
    required this.announcementTitle,
  });

  @override
  State<BoostPromotionCard> createState() => _BoostPromotionCardState();
}

class _BoostPromotionCardState extends State<BoostPromotionCard> {
  List<Map<String, dynamic>> _packages = [];
  bool _isLoading = true;
  String? _selectedPackageId;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await Supabase.instance.client
          .from('boost_packages')
          .select()
          .eq('is_active', true)
          .order('price', ascending: true);
      
      setState(() {
        _packages = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading packages: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _purchaseBoost() async {
    if (_selectedPackageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez une formule')),
      );
      return;
    }
    
    final selectedPackage = _packages.firstWhere((p) => p['id'] == _selectedPackageId);
    final price = selectedPackage['price'];
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer le boost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Produit: ${widget.announcementTitle}'),
            const SizedBox(height: 8),
            Text('Formule: ${selectedPackage['name']}'),
            Text('Durée: ${selectedPackage['duration_days']} jours'),
            Text('Prix: $price FCFA'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5592F)),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _isProcessing = true);
    
    try {
      // Create boost order
      final order = await Supabase.instance.client
          .from('boost_orders')
          .insert({
            'product_id': widget.announcementId,
            'package_id': _selectedPackageId,
            'price': price,
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      
      // Simulate payment (redirect to payment gateway)
      // For demo, we mark as paid directly
      await Supabase.instance.client
          .from('boost_orders')
          .update({
            'status': 'paid',
            'paid_at': DateTime.now().toIso8601String(),
          })
          .eq('id', order['id']);
      
      // Activate boost on product
      final expiryDate = DateTime.now().add(Duration(days: selectedPackage['duration_days']));
      await Supabase.instance.client
          .from('products')
          .update({
            'is_boosted': true,
            'boost_expires_at': expiryDate.toIso8601String(),
          })
          .eq('id', widget.announcementId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Boost activé jusqu\'au ${DateFormat('dd/MM/yyyy').format(expiryDate)}')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error purchasing boost: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Boostez votre annonce',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Augmentez la visibilité de "${widget.announcementTitle}"',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          
          // Packages
          ..._packages.map((pkg) => _buildPackageCard(pkg)),
          
          const SizedBox(height: 24),
          
          // Purchase button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _purchaseBoost,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5592F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  : const Text('Booster maintenant', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg) {
    final isSelected = _selectedPackageId == pkg['id'];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? const Color(0xFFE5592F) : Colors.grey[200]!, width: isSelected ? 2 : 1),
      ),
      child: RadioListTile<String>(
        value: pkg['id'],
        groupValue: _selectedPackageId,
        onChanged: (v) => setState(() => _selectedPackageId = v),
        title: Text(pkg['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${pkg['duration_days']} jours de mise en avant'),
            Text('${pkg['estimated_views']} vues garanties', style: const TextStyle(fontSize: 12)),
          ],
        ),
        secondary: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${pkg['price']} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE5592F))),
            if (pkg['original_price'] != null)
              Text(
                '${pkg['original_price']} FCFA',
                style: TextStyle(decoration: TextDecoration.lineThrough, fontSize: 11, color: Colors.grey[500]),
              ),
          ],
        ),
        activeColor: const Color(0xFFE5592F),
      ),
    );
  }
}
