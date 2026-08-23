// lib/presentation/thix_market/delivery/delivery_address_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'delivery_provider.dart';

class DeliveryAddressSelector extends ConsumerWidget {
  final Function(Map<String, dynamic>)? onAddressSelected;

  const DeliveryAddressSelector({super.key, this.onAddressSelected});

  static const Color thixOrange = Color(0xFFE5592F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    final isSelected =
                        provider.selectedAddress?['id'] == address['id'];
                    return _buildAddressCard(context, address, isSelected, ref);
                  },
                ),
        ),
        _buildAddAddressButton(context, ref),
      ],
    );
  }

  // ─── CARTE D'ADRESSE ───
  Widget _buildAddressCard(
    BuildContext context,
    Map<String, dynamic> address,
    bool isSelected,
    WidgetRef ref,
  ) {
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
          if (value == null) return;
          ref.read(deliveryProvider).selectAddress(value);
          onAddressSelected?.call(value);
        },
        title: Padding(
          padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  address['full_name'] ?? 'Destinataire',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF10192E),
                  ),
                ),
              ),
              if (address['is_default'] == true)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Par défaut',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.green,
                    ),
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
                    '\( {address['address_line']}\n \){address['commune']}, ${address['city']}',
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

  // ─── ÉTAT VIDE ───
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF10192E),
            ),
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

  // ─── BOUTON D'AJOUT ───
  Widget _buildAddAddressButton(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
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

  // ─── HELPER CHAMPS ───
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
        validator: isRequired
            ? (v) => (v == null || v.trim().isEmpty) ? 'Ce champ est requis' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            left: 20,
            right: 20,
            top: 12,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Nouvelle adresse',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10192E),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildTextField(
                    controller: fullNameCtrl,
                    label: 'Nom et Prénom',
                    isRequired: true,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: phoneCtrl,
                          label: 'Tél. principal',
                          type: TextInputType.phone,
                          isRequired: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: altPhoneCtrl,
                          label: 'Tél. alternatif',
                          type: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: cityCtrl,
                          label: 'Ville',
                          isRequired: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: communeCtrl,
                          label: 'Commune / Quartier',
                          isRequired: true,
                        ),
                      ),
                    ],
                  ),

                  _buildTextField(
                    controller: addressCtrl,
                    label: 'Avenue et Numéro (ex: De Bon 52)',
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: landmarkCtrl,
                    label: 'Point de repère (Optionnel)',
                    hint: 'Ex: En face de la pharmacie...',
                  ),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: CheckboxListTile(
                      value: isDefault,
                      onChanged: (val) =>
                          setState(() => isDefault = val ?? false),
                      activeColor: thixOrange,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Définir comme adresse par défaut',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      try {
                        await ref.read(deliveryProvider).addAddress({
                          'full_name': fullNameCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'alt_phone': altPhoneCtrl.text.trim(),
                          'city': cityCtrl.text.trim(),
                          'commune': communeCtrl.text.trim(),
                          'address_line': addressCtrl.text.trim(),
                          'landmark': landmarkCtrl.text.trim(),
                          'is_default': isDefault,
                        });

                        // Synchronise avec le checkout pour activer "Continuer"
                        final selected =
                            ref.read(deliveryProvider).selectedAddress;
                        if (selected != null) {
                          onAddressSelected?.call(selected);
                        }

                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur enregistrement : $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: thixOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Enregistrer l\'adresse',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── FORMULAIRE D'ÉDITION ───
  void _showEditAddressDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> address,
  ) {
    final formKey = GlobalKey<FormState>();
    final fullNameCtrl =
        TextEditingController(text: address['full_name']?.toString() ?? '');
    final phoneCtrl =
        TextEditingController(text: address['phone']?.toString() ?? '');
    final altPhoneCtrl =
        TextEditingController(text: address['alt_phone']?.toString() ?? '');
    final cityCtrl =
        TextEditingController(text: address['city']?.toString() ?? 'Kinshasa');
    final communeCtrl =
        TextEditingController(text: address['commune']?.toString() ?? '');
    final addressCtrl =
        TextEditingController(text: address['address_line']?.toString() ?? '');
    final landmarkCtrl =
        TextEditingController(text: address['landmark']?.toString() ?? '');
    bool isDefault = address['is_default'] == true;

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
            left: 20,
            right: 20,
            top: 12,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Modifier l\'adresse',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10192E),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildTextField(
                    controller: fullNameCtrl,
                    label: 'Nom et Prénom',
                    isRequired: true,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: phoneCtrl,
                          label: 'Tél. principal',
                          type: TextInputType.phone,
                          isRequired: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: altPhoneCtrl,
                          label: 'Tél. alternatif',
                          type: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: cityCtrl,
                          label: 'Ville',
                          isRequired: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: communeCtrl,
                          label: 'Commune / Quartier',
                          isRequired: true,
                        ),
                      ),
                    ],
                  ),
                  _buildTextField(
                    controller: addressCtrl,
                    label: 'Avenue et Numéro',
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: landmarkCtrl,
                    label: 'Point de repère (Optionnel)',
                  ),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: CheckboxListTile(
                      value: isDefault,
                      onChanged: (val) =>
                          setState(() => isDefault = val ?? false),
                      activeColor: thixOrange,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Définir comme adresse par défaut',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      try {
                        await ref.read(deliveryProvider).updateAddress(
                          address['id'].toString(),
                          {
                            'full_name': fullNameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'alt_phone': altPhoneCtrl.text.trim(),
                            'city': cityCtrl.text.trim(),
                            'commune': communeCtrl.text.trim(),
                            'address_line': addressCtrl.text.trim(),
                            'landmark': landmarkCtrl.text.trim(),
                            'is_default': isDefault,
                          },
                        );

                        final selected =
                            ref.read(deliveryProvider).selectedAddress;
                        if (selected != null) {
                          onAddressSelected?.call(selected);
                        }

                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur modification : $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: thixOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Enregistrer les modifications',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Supprimer ?'),
                          content: const Text(
                            'Voulez-vous vraiment supprimer cette adresse ?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Annuler'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'Supprimer',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await ref
                              .read(deliveryProvider)
                              .deleteAddress(address['id'].toString());
                          if (context.mounted) {
                            Navigator.pop(context); // ferme le bottom sheet
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur suppression : $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    child: const Text(
                      'Supprimer cette adresse',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
