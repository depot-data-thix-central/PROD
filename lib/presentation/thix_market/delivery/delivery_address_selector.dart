// lib/presentation/thix_market/delivery/delivery_address_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'delivery_provider.dart'; // CORRECTION ICI : Import direct dans le même dossier

class DeliveryAddressSelector extends ConsumerWidget {
  final Function(Map<String, dynamic>)? onAddressSelected;

  const DeliveryAddressSelector({super.key, this.onAddressSelected});

  // Couleur principale THIX
  static const Color thixOrange = Color(0xFFE5592F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Écoute réactive du provider
    final provider = ref.watch(deliveryProvider);

    if (provider.isLoadingAddresses) {
      return const Center(child: CircularProgressIndicator(color: thixOrange));
    }

    return Column(
      children: [
        Expanded(
          child: provider.addresses.isEmpty
              ? _buildEmptyState(context, ref)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.addresses.length,
                  itemBuilder: (context, index) {
                    final address = provider.addresses[index];
                    final isSelected = provider.selectedAddress?['id'] == address['id'];
                    return _buildAddressCard(context, address, isSelected, ref);
                  },
                ),
        ),
        _buildAddAddressButton(context, ref),
      ],
    );
  }

  // ─── CARTE D'ADRESSE (DESIGN AMÉLIORÉ) ───
  Widget _buildAddressCard(BuildContext context, Map<String, dynamic> address, bool isSelected, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? thixOrange : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: RadioListTile<Map<String, dynamic>>(
        value: address,
        groupValue: ref.watch(deliveryProvider).selectedAddress,
        onChanged: (value) {
          ref.read(deliveryProvider).selectAddress(value!);
          onAddressSelected?.call(value);
        },
        title: Padding(
          padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  address['full_name'] ?? 'Destinataire',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF10192E)),
                ),
              ),
              if (address['is_default'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Par défaut',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green),
                  ),
                ),
            ],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${address['address_line']}\n${address['commune']}, ${address['city']}',
                    style: TextStyle(color: Colors.grey[700], height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  address['phone'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        activeColor: thixOrange,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        secondary: IconButton(
          icon: Icon(Icons.edit_note_rounded, size: 28, color: Colors.grey[600]),
          onPressed: () => _showEditAddressDialog(context, ref, address),
        ),
      ),
    );
  }

  // ─── ÉTAT VIDE (DESIGN AMÉLIORÉ) ───
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: thixOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.map_rounded, size: 64, color: thixOrange),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucune adresse',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF10192E)),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre première adresse\npour être livré rapidement.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ─── BOUTON D'AJOUT (DESIGN AMÉLIORÉ) ───
  Widget _buildAddAddressButton(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: OutlinedButton.icon(
        onPressed: () => _showAddAddressDialog(context, ref),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text(
          'Ajouter une adresse',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: thixOrange,
          side: const BorderSide(color: thixOrange, width: 2),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // ─── HELPER POUR LES CHAMPS DE TEXTE ───
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType type = TextInputType.text,
    bool isRequired = false,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        validator: isRequired ? (v) => v!.isEmpty ? 'Ce champ est requis' : null : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: thixOrange, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
        ),
      ),
    );
  }

  // ─── FORMULAIRE D'AJOUT ───
  void _showAddAddressDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final fullNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final altPhoneCtrl = TextEditingController(); 
    final cityCtrl = TextEditingController(text: 'Kinshasa'); 
    final communeCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final landmarkCtrl = TextEditingController();
    bool isDefault = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 12,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  const Text('Nouvelle adresse', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF10192E))),
                  const SizedBox(height: 24),
                  
                  _buildTextField(controller: fullNameCtrl, label: 'Nom et Prénom', isRequired: true),
                  
                  Row(
                    children: [
                      Expanded(child: _buildTextField(controller: phoneCtrl, label: 'Tél. principal', type: TextInputType.phone, isRequired: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField(controller: altPhoneCtrl, label: 'Tél. alternatif', type: TextInputType.phone)),
                    ],
                  ),
                  
                  Row(
                    children: [
                      Expanded(child: _buildTextField(controller: cityCtrl, label: 'Ville', isRequired: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField(controller: communeCtrl, label: 'Commune / Quartier', isRequired: true)),
                    ],
                  ),

                  _buildTextField(controller: addressCtrl, label: 'Avenue et Numéro (ex: De Bon 52)', isRequired: true),
                  _buildTextField(controller: landmarkCtrl, label: 'Point de repère (Optionnel)', hint: 'Ex: En face de la pharmacie...'),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: CheckboxListTile(
                      value: isDefault, 
                      onChanged: (val) => setState(() => isDefault = val ?? false),
                      activeColor: thixOrange,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Définir comme adresse par défaut', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        await ref.read(deliveryProvider).addAddress({
                          'full_name': fullNameCtrl.text,
                          'phone': phoneCtrl.text,
                          'alt_phone': altPhoneCtrl.text,
                          'city': cityCtrl.text,
                          'commune': communeCtrl.text,
                          'address_line': addressCtrl.text,
                          'landmark': landmarkCtrl.text,
                          'is_default': isDefault,
                        });
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: thixOrange, 
                      foregroundColor: Colors.white, 
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Enregistrer l\'adresse', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── FORMULAIRE DE MODIFICATION ───
  void _showEditAddressDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> address) {
    final formKey = GlobalKey<FormState>();
    final fullNameCtrl = TextEditingController(text: address['full_name']);
    final phoneCtrl = TextEditingController(text: address['phone']);
    final altPhoneCtrl = TextEditingController(text: address['alt_phone'] ?? ''); 
    final cityCtrl = TextEditingController(text: address['city']);
    final communeCtrl = TextEditingController(text: address['commune'] ?? '');
    final addressCtrl = TextEditingController(text: address['address_line']);
    final landmarkCtrl = TextEditingController(text: address['landmark'] ?? '');
    bool isDefault = address['is_default'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 12),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  const Text('Modifier l\'adresse', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF10192E))),
                  const SizedBox(height: 24),
                  
                  _buildTextField(controller: fullNameCtrl, label: 'Nom complet', isRequired: true),
                  
                  Row(
                    children: [
                      Expanded(child: _buildTextField(controller: phoneCtrl, label: 'Tél. principal', type: TextInputType.phone, isRequired: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField(controller: altPhoneCtrl, label: 'Tél. alternatif', type: TextInputType.phone)),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(child: _buildTextField(controller: cityCtrl, label: 'Ville', isRequired: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField(controller: communeCtrl, label: 'Commune / Quartier', isRequired: true)),
                    ],
                  ),

                  _buildTextField(controller: addressCtrl, label: 'Avenue et Numéro', isRequired: true),
                  _buildTextField(controller: landmarkCtrl, label: 'Point de repère (Optionnel)'),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: CheckboxListTile(
                      value: isDefault, 
                      onChanged: (val) => setState(() => isDefault = val ?? false),
                      activeColor: thixOrange,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Définir comme adresse par défaut', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref.read(deliveryProvider).deleteAddress(address['id']);
                            if (context.mounted) Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red, 
                            side: const BorderSide(color: Colors.red, width: 2), 
                            minimumSize: const Size(0, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              await ref.read(deliveryProvider).updateAddress(address['id'], {
                                'full_name': fullNameCtrl.text,
                                'phone': phoneCtrl.text,
                                'alt_phone': altPhoneCtrl.text,
                                'city': cityCtrl.text,
                                'commune': communeCtrl.text,
                                'address_line': addressCtrl.text,
                                'landmark': landmarkCtrl.text,
                                'is_default': isDefault,
                              });
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: thixOrange, 
                            foregroundColor: Colors.white, 
                            minimumSize: const Size(0, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('Mettre à jour', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
