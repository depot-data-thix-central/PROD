// lib/presentation/thix_market/delivery/delivery_address_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'delivery_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const int _kMaxNameLength = 80;
const int _kMaxAddressLength = 200;
const int _kMaxLandmarkLength = 100;
const int _kMaxPhoneLength = 20;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _AddressValidators {
  _AddressValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  /// Validation téléphone RDC : +243 suivi de 9 chiffres (8x ou 9x)
  static bool isValidDrcPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return RegExp(r'^\+243[89]\d{8}$').hasMatch(cleaned);
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est requis';
    }
    return null;
  }

  static String? validatePhone(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est requis';
    }
    if (!isValidDrcPhone(value)) {
      return 'Format invalide (+243 8X XXX XXXX)';
    }
    return null;
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('duplicate') || msg.contains('unique')) return 'Cette adresse existe déjà.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _AddressL10n on BuildContext {
  String addrT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class DeliveryAddressSelector extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>)? onAddressSelected;

  const DeliveryAddressSelector({super.key, this.onAddressSelected});

  @override
  ConsumerState<DeliveryAddressSelector> createState() => _DeliveryAddressSelectorState();
}

class _DeliveryAddressSelectorState extends ConsumerState<DeliveryAddressSelector> {
  bool _isSubmitting = false;
  String? _submittingAddressId;

  @override
  void initState() {
    super.initState();
    debugPrint('[DeliveryAddress] 📍 Selector opened');
  }

  @override
  void dispose() {
    debugPrint('[DeliveryAddress] 👋 Selector disposed');
    super.dispose();
  }

  // ============================================================
  // SELECT ADDRESS
  // ============================================================
  void _selectAddress(Map<String, dynamic> address) {
    final id = address['id']?.toString();
    if (!_AddressValidators.isValidId(id)) {
      _showError(context.addrT('Adresse invalide', 'Invalid address'));
      return;
    }

    HapticFeedback.selectionClick();
    ref.read(deliveryProvider).selectAddress(address);
    widget.onAddressSelected?.call(address);
    debugPrint('[DeliveryAddress] ✓ Selected: ${_AddressValidators.shortId(id!)}');
  }

  // ============================================================
  // FEEDBACK
  // ============================================================
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // SUBMIT FORM (shared add/edit)
  // ============================================================
  Future<bool> _submitAddressForm({
    required GlobalKey<FormState> formKey,
    required Map<String, TextEditingController> controllers,
    required bool isDefault,
    required bool isEdit,
    String? addressId,
  }) async {
    if (_isSubmitting) return false;
    if (!formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return false;
    }

    setState(() {
      _isSubmitting = true;
      _submittingAddressId = addressId;
    });
    HapticFeedback.mediumImpact();

    final payload = {
      'full_name': _AddressValidators.sanitize(controllers['fullName']!.text, maxLength: _kMaxNameLength),
      'phone': _AddressValidators.sanitize(controllers['phone']!.text, maxLength: _kMaxPhoneLength),
      'alt_phone': _AddressValidators.sanitize(controllers['altPhone']!.text, maxLength: _kMaxPhoneLength),
      'city': _AddressValidators.sanitize(controllers['city']!.text, maxLength: 40),
      'commune': _AddressValidators.sanitize(controllers['commune']!.text, maxLength: 60),
      'address_line': _AddressValidators.sanitize(controllers['addressLine']!.text, maxLength: _kMaxAddressLength),
      'landmark': _AddressValidators.sanitize(controllers['landmark']!.text, maxLength: _kMaxLandmarkLength),
      'is_default': isDefault,
    };

    try {
      final provider = ref.read(deliveryProvider);
      if (isEdit && addressId != null) {
        await provider.updateAddress(addressId, payload);
        debugPrint('[DeliveryAddress] ✏️ Address updated: ${_AddressValidators.shortId(addressId)}');
      } else {
        await provider.addAddress(payload);
        debugPrint('[DeliveryAddress] ➕ New address added');
      }

      final selected = provider.selectedAddress;
      if (selected != null) widget.onAddressSelected?.call(selected);

      if (mounted) {
        _showSuccess(
          isEdit
              ? context.addrT('Adresse modifiée', 'Address updated')
              : context.addrT('Adresse ajoutée', 'Address added'),
        );
      }
      return true;
    } catch (e) {
      debugPrint('[DeliveryAddress] ❌ Submit error: $e');
      if (mounted) _showError(_AddressValidators.friendlyError(e));
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingAddressId = null;
        });
      }
    }
  }

  // ============================================================
  // DELETE CONFIRMATION
  // ============================================================
  Future<bool> _confirmDelete(String addressId) async {
    HapticFeedback.mediumImpact();
    final short = _AddressValidators.shortId(addressId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: ThixPolicy.danger, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.addrT('Supprimer l\'adresse ?', 'Delete address?'),
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          context.addrT(
            'Voulez-vous vraiment supprimer cette adresse (#$short) ? Cette action est irréversible.',
            'Do you really want to delete this address (#$short)? This action is irreversible.',
          ),
          style: ThixPolicy.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.addrT('Annuler', 'Cancel'),
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(context.addrT('Supprimer', 'Delete')),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteAddress(String addressId) async {
    if (!_AddressValidators.isValidId(addressId)) {
      _showError(context.addrT('Identifiant invalide', 'Invalid ID'));
      return;
    }

    final confirmed = await _confirmDelete(addressId);
    if (!confirmed || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _submittingAddressId = addressId;
    });

    try {
      await ref.read(deliveryProvider).deleteAddress(addressId);
      debugPrint('[DeliveryAddress] 🗑️ Address deleted: ${_AddressValidators.shortId(addressId)}');
      if (mounted) {
        _showSuccess(context.addrT('Adresse supprimée', 'Address deleted'));
        Navigator.pop(context); // Ferme le bottom sheet d'édition
      }
    } catch (e) {
      debugPrint('[DeliveryAddress] ❌ Delete error: $e');
      if (mounted) _showError(_AddressValidators.friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingAddressId = null;
        });
      }
    }
  }

  // ============================================================
  // SHOW DIALOGS
  // ============================================================
  void _showAddAddressDialog() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddressFormSheet(
        mode: _AddressFormMode.add,
        isSubmitting: _isSubmitting,
        onSubmit: (formKey, controllers, isDefault) => _submitAddressForm(
          formKey: formKey,
          controllers: controllers,
          isDefault: isDefault,
          isEdit: false,
        ),
        title: context.addrT('Nouvelle adresse', 'New address'),
        submitLabel: context.addrT('Enregistrer l\'adresse', 'Save address'),
      ),
    );
  }

  void _showEditAddressDialog(Map<String, dynamic> address) {
    final id = address['id']?.toString();
    if (!_AddressValidators.isValidId(id)) {
      _showError(context.addrT('Adresse invalide', 'Invalid address'));
      return;
    }

    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddressFormSheet(
        mode: _AddressFormMode.edit,
        initialAddress: address,
        isSubmitting: _isSubmitting && _submittingAddressId == id,
        onSubmit: (formKey, controllers, isDefault) => _submitAddressForm(
          formKey: formKey,
          controllers: controllers,
          isDefault: isDefault,
          isEdit: true,
          addressId: id,
        ),
        onDelete: () => _deleteAddress(id!),
        title: context.addrT('Modifier l\'adresse', 'Edit address'),
        submitLabel: context.addrT('Enregistrer les modifications', 'Save changes'),
        deleteLabel: context.addrT('Supprimer cette adresse', 'Delete this address'),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(deliveryProvider);

    if (provider.isLoadingAddresses) {
      return const _SkeletonAddresses();
    }

    return Column(
      children: [
        Expanded(
          child: provider.addresses.isEmpty
              ? _EmptyState(
                  title: context.addrT('Aucune adresse', 'No addresses'),
                  subtitle: context.addrT(
                    'Ajoutez votre première adresse\npour être livré rapidement.',
                    'Add your first address\nto be delivered quickly.',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: provider.addresses.length,
                  itemBuilder: (context, index) {
                    final address = provider.addresses[index];
                    final addressId = address['id']?.toString();
                    final isSelected = provider.selectedAddress?['id'] == addressId;
                    final isSubmittingThis = _isSubmitting && _submittingAddressId == addressId;

                    return _AddressCard(
                      address: address,
                      isSelected: isSelected,
                      isSubmitting: isSubmittingThis,
                      onSelect: () => _selectAddress(address),
                      onEdit: () => _showEditAddressDialog(address),
                    );
                  },
                ),
        ),
        _AddAddressButton(
          label: context.addrT('Ajouter une adresse', 'Add address'),
          onPressed: _showAddAddressDialog,
        ),
      ],
    );
  }
}

// ============================================================================
// HELPERS
// ============================================================================
extension on _AddressValidators {
  static String shortId(String id) {
    if (id.length <= 8) return id.toUpperCase();
    return id.substring(0, 8).toUpperCase();
  }
}

String _shortId(String? id) {
  if (id == null || id.isEmpty) return 'N/A';
  if (id.length <= 8) return id.toUpperCase();
  return id.substring(0, 8).toUpperCase();
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _AddressCard extends StatelessWidget {
  final Map<String, dynamic> address;
  final bool isSelected;
  final bool isSubmitting;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  const _AddressCard({
    required this.address,
    required this.isSelected,
    required this.isSubmitting,
    required this.onSelect,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final fullName = _AddressValidators.sanitize(
      address['full_name']?.toString() ?? context.addrT('Destinataire', 'Recipient'),
      maxLength: _kMaxNameLength,
    );
    final addressLine = _AddressValidators.sanitize(
      address['address_line']?.toString() ?? '',
      maxLength: _kMaxAddressLength,
    );
    final commune = _AddressValidators.sanitize(address['commune']?.toString() ?? '', maxLength: 60);
    final city = _AddressValidators.sanitize(address['city']?.toString() ?? '', maxLength: 40);
    final phone = _AddressValidators.sanitize(address['phone']?.toString() ?? '', maxLength: _kMaxPhoneLength);
    final isDefault = address['is_default'] == true;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$fullName, $addressLine, $commune, $city',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isSubmitting ? 0.6 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? ThixPolicy.primary : ThixPolicy.border.withOpacity(0.6),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: ThixPolicy.shadowSoft(opacity: isSelected ? 0.08 : 0.04),
          ),
          child: RadioListTile<Map<String, dynamic>>(
            value: address,
            groupValue: ref_read_selected(context),
            onChanged: isSubmitting ? null : (_) => onSelect(),
            title: Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      fullName,
                      style: ThixPolicy.labelStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        fontSize: 16,
                        color: ThixPolicy.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ThixPolicy.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ThixPolicy.success.withOpacity(0.3)),
                      ),
                      child: Text(
                        context.addrT('Par défaut', 'Default'),
                        style: ThixPolicy.microStyle.copyWith(
                          fontSize: 11,
                          fontWeight: ThixPolicy.bold,
                          color: ThixPolicy.success,
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
                    const Icon(Icons.location_on_rounded, size: 16, color: ThixPolicy.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '$addressLine\n$commune, $city',
                        style: ThixPolicy.bodySmallStyle.copyWith(
                          color: ThixPolicy.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.phone_rounded, size: 16, color: ThixPolicy.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      phone,
                      style: ThixPolicy.captionStyle.copyWith(
                        fontWeight: ThixPolicy.semiBold,
                        color: ThixPolicy.textMain,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            activeColor: ThixPolicy.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            secondary: Semantics(
              button: true,
              label: context.addrT('Modifier', 'Edit'),
              child: IconButton(
                icon: Icon(
                  Icons.edit_note_rounded,
                  size: 28,
                  color: isSubmitting ? ThixPolicy.textDisabled : ThixPolicy.textMuted,
                ),
                tooltip: context.addrT('Modifier', 'Edit'),
                onPressed: isSubmitting ? null : onEdit,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper pour accéder au selectedAddress depuis le context (via Provider)
  Map<String, dynamic>? ref_read_selected(BuildContext context) {
    // On utilise un ProviderScope.read via Container pour éviter de re-builder
    try {
      final container = ProviderScope.containerOf(context);
      return container.read(deliveryProvider).selectedAddress;
    } catch (_) {
      return null;
    }
  }
}

class _AddAddressButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _AddAddressButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.06),
      ),
      child: SafeArea(
        top: false,
        child: Semantics(
          button: true,
          label: label,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add_location_alt_rounded, color: ThixPolicy.primary),
            label: Text(
              label,
              style: ThixPolicy.labelStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                fontSize: 16,
                color: ThixPolicy.primary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: ThixPolicy.primary,
              side: const BorderSide(color: ThixPolicy.primary, width: 2),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.map_rounded, size: 64, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: ThixPolicy.h3Style.copyWith(
                fontSize: 20,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(
                color: ThixPolicy.textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonAddresses extends StatelessWidget {
  const _SkeletonAddresses();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(child: Container(height: 16, color: Colors.grey.shade200)),
                const SizedBox(width: 8),
                Container(width: 60, height: 20, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20))),
                const SizedBox(width: 8),
                Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 12, width: double.infinity, color: Colors.grey.shade200),
            const SizedBox(height: 6),
            Container(height: 12, width: 200, color: Colors.grey.shade200),
            const SizedBox(height: 10),
            Container(height: 12, width: 120, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ADDRESS FORM SHEET (shared add/edit)
// ============================================================================
enum _AddressFormMode { add, edit }

class _AddressFormSheet extends StatefulWidget {
  final _AddressFormMode mode;
  final Map<String, dynamic>? initialAddress;
  final bool isSubmitting;
  final Future<bool> Function(
    GlobalKey<FormState> formKey,
    Map<String, TextEditingController> controllers,
    bool isDefault,
  ) onSubmit;
  final VoidCallback? onDelete;
  final String title;
  final String submitLabel;
  final String? deleteLabel;

  const _AddressFormSheet({
    required this.mode,
    required this.onSubmit,
    required this.title,
    required this.submitLabel,
    this.initialAddress,
    this.isSubmitting = false,
    this.onDelete,
    this.deleteLabel,
  });

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final addr = widget.initialAddress ?? {};
    _controllers = {
      'fullName': TextEditingController(text: addr['full_name']?.toString() ?? ''),
      'phone': TextEditingController(text: addr['phone']?.toString() ?? ''),
      'altPhone': TextEditingController(text: addr['alt_phone']?.toString() ?? ''),
      'city': TextEditingController(text: addr['city']?.toString() ?? 'Kinshasa'),
      'commune': TextEditingController(text: addr['commune']?.toString() ?? ''),
      'addressLine': TextEditingController(text: addr['address_line']?.toString() ?? ''),
      'landmark': TextEditingController(text: addr['landmark']?.toString() ?? ''),
    };
    _isDefault = addr['is_default'] == true;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return context.addrT('$fieldName requis', '$fieldName required');
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.addrT('Téléphone requis', 'Phone required');
    }
    if (!_AddressValidators.isValidDrcPhone(value)) {
      return context.addrT('Format: +243 8X XXX XXXX', 'Format: +243 8X XXX XXXX');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: ThixPolicy.h3Style.copyWith(
                  fontSize: 20,
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.textMain,
                ),
              ),
              const SizedBox(height: 24),

              _FormField(
                controller: _controllers['fullName']!,
                label: context.addrT('Nom et Prénom', 'Full name'),
                isRequired: true,
                validator: (v) => _validateRequired(v, context.addrT('Nom', 'Name')),
              ),

              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      controller: _controllers['phone']!,
                      label: context.addrT('Tél. principal', 'Main phone'),
                      type: TextInputType.phone,
                      isRequired: true,
                      validator: _validatePhone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FormField(
                      controller: _controllers['altPhone']!,
                      label: context.addrT('Tél. alternatif', 'Alt. phone'),
                      type: TextInputType.phone,
                    ),
                  ),
                ],
              ),

              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      controller: _controllers['city']!,
                      label: context.addrT('Ville', 'City'),
                      isRequired: true,
                      validator: (v) => _validateRequired(v, context.addrT('Ville', 'City')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FormField(
                      controller: _controllers['commune']!,
                      label: context.addrT('Commune / Quartier', 'District'),
                      isRequired: true,
                      validator: (v) => _validateRequired(v, context.addrT('Commune', 'District')),
                    ),
                  ),
                ],
              ),

              _FormField(
                controller: _controllers['addressLine']!,
                label: context.addrT('Avenue et Numéro', 'Street and number'),
                hint: context.addrT('Ex: De Bon 52', 'E.g. De Bon 52'),
                isRequired: true,
                validator: (v) => _validateRequired(v, context.addrT('Adresse', 'Address')),
              ),

              _FormField(
                controller: _controllers['landmark']!,
                label: context.addrT('Point de repère (Optionnel)', 'Landmark (optional)'),
                hint: context.addrT('Ex: En face de la pharmacie...', 'E.g. Across from pharmacy...'),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
                ),
                child: CheckboxListTile(
                  value: _isDefault,
                  onChanged: widget.isSubmitting ? null : (val) => setState(() => _isDefault = val ?? false),
                  activeColor: ThixPolicy.primary,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    context.addrT('Définir comme adresse par défaut', 'Set as default address'),
                    style: ThixPolicy.labelStyle.copyWith(
                      fontSize: 14,
                      fontWeight: ThixPolicy.semiBold,
                      color: ThixPolicy.textMain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Semantics(
                button: true,
                label: widget.submitLabel,
                enabled: !widget.isSubmitting,
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: widget.isSubmitting
                        ? null
                        : () async {
                            final success = await widget.onSubmit(_formKey, _controllers, _isDefault);
                            if (success && mounted) Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixPolicy.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: ThixPolicy.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: widget.isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            widget.submitLabel,
                            style: ThixPolicy.labelStyle.copyWith(
                              fontWeight: ThixPolicy.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),

              if (widget.mode == _AddressFormMode.edit && widget.onDelete != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  button: true,
                  label: widget.deleteLabel ?? '',
                  enabled: !widget.isSubmitting,
                  child: TextButton(
                    onPressed: widget.isSubmitting ? null : widget.onDelete,
                    child: Text(
                      widget.deleteLabel ?? '',
                      style: ThixPolicy.labelStyle.copyWith(
                        color: ThixPolicy.danger,
                        fontWeight: ThixPolicy.semiBold,
                      ),
                    ),
                  ),
                ),
              ],

              SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType type;
  final bool isRequired;
  final String? hint;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    this.type = TextInputType.text,
    this.isRequired = false,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        validator: validator,
        style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain),
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hint,
          filled: true,
          fillColor: ThixPolicy.surfaceSoft,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ThixPolicy.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ThixPolicy.danger, width: 1),
          ),
          labelStyle: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted),
        ),
      ),
    );
  }
}
