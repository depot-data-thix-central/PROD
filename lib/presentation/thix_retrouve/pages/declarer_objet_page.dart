/// Declarer Objet Page (Production Enterprise)
/// ThixPolicy + i18n 8 langues + sanitization + mounted checks
/// Semantics + HapticFeedback + logs structurés
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../models/objet_model.dart';
import '../providers/objet_providers.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kMaxTitleLength = 100;
const int _kMaxDescriptionLength = 1000;
const int _kMaxLocationLength = 150;
const int _kMaxRewardLength = 20;
const int _kMaxContactLength = 100;
const int _kMaxPhotoSizeBytes = 5 * 1024 * 1024; // 5 MB
const Duration _kSubmitThrottle = Duration(seconds: 3);
const Duration _kPickThrottle = Duration(milliseconds: 500);

// ============================================================================
// VALIDATORS & SANITIZERS
// ============================================================================

class _DeclareValidators {
  _DeclareValidators._();

  static String sanitize(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static bool isValidContact(String? contact) {
    if (contact == null || contact.trim().isEmpty) return true; // optionnel
    final c = contact.trim();
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    final phoneRegex = RegExp(r'^\+?[0-9\s\-()]{8,20}$');
    return emailRegex.hasMatch(c) || phoneRegex.hasMatch(c);
  }

  static bool isValidReward(String? reward) {
    if (reward == null || reward.trim().isEmpty) return true;
    final r = reward.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (r.isEmpty) return false;
    final n = int.tryParse(r);
    return n != null && n > 0 && n < 1000000000;
  }
}

// ============================================================================
// CATEGORY MODEL (i18n-ready)
// ============================================================================

class _ObjetCategory {
  final String code; // stable identifier
  final String i18nKey;
  final IconData icon;

  const _ObjetCategory({
    required this.code,
    required this.i18nKey,
    required this.icon,
  });
}

const List<_ObjetCategory> _kCategories = [
  _ObjetCategory(code: 'phone', i18nKey: 'cat_phone', icon: Icons.phone_android_rounded),
  _ObjetCategory(code: 'wallet', i18nKey: 'cat_wallet', icon: Icons.account_balance_wallet_rounded),
  _ObjetCategory(code: 'keys', i18nKey: 'cat_keys', icon: Icons.vpn_key_rounded),
  _ObjetCategory(code: 'documents', i18nKey: 'cat_documents', icon: Icons.description_rounded),
  _ObjetCategory(code: 'jewelry', i18nKey: 'cat_jewelry', icon: Icons.watch_rounded),
  _ObjetCategory(code: 'backpack', i18nKey: 'cat_backpack', icon: Icons.backpack_rounded),
  _ObjetCategory(code: 'accessories', i18nKey: 'cat_accessories', icon: Icons.headphones_rounded),
  _ObjetCategory(code: 'other', i18nKey: 'cat_other', icon: Icons.inventory_2_rounded),
];

// ============================================================================
// SCREEN
// ============================================================================

class DeclarerObjetPage extends ConsumerStatefulWidget {
  final StatutObjet type;

  const DeclarerObjetPage({super.key, required this.type});

  @override
  ConsumerState<DeclarerObjetPage> createState() => _DeclarerObjetPageState();
}

class _DeclarerObjetPageState extends ConsumerState<DeclarerObjetPage> {
  final _formKey = GlobalKey<FormState>();
  final _titreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _lieuCtrl = TextEditingController();
  final _recompenseCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  _ObjetCategory? _categorie;
  bool _isLoading = false;
  XFile? _photo;
  Uint8List? _photoBytes;
  DateTime? _lastSubmit;
  DateTime? _lastPick;

  final _picker = ImagePicker();

  bool get _isPerdu => widget.type == StatutObjet.perdu;

  Color get _accentColor => _isPerdu ? ThixPolicy.domainOpportunity : ThixPolicy.primary;
  Color get _accentSoft => _isPerdu
      ? ThixPolicy.domainOpportunity.withValues(alpha: 0.12)
      : ThixPolicy.primary.withValues(alpha: 0.12);

  @override
  void dispose() {
    _titreCtrl.dispose();
    _descCtrl.dispose();
    _lieuCtrl.dispose();
    _recompenseCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  // ─── PHOTO PICKING ─────────────────────────────────────────

  void _showPhotoPicker() {
    final now = DateTime.now();
    if (_lastPick != null && now.difference(_lastPick!) < _kPickThrottle) {
      debugPrint('[DeclareObjet] ⏱️ Photo pick throttled');
      return;
    }
    _lastPick = now;

    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.rLg)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ThixPolicy.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: l10n.t('declare_take_photo'),
              child: ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: ThixPolicy.primary),
                title: Text(
                  l10n.t('declare_take_photo'),
                  style: TextStyle(color: ThixPolicy.textMain),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickImage(ImageSource.camera);
                },
              ),
            ),
            Semantics(
              button: true,
              label: l10n.t('declare_pick_gallery'),
              child: ListTile(
                leading: Icon(Icons.photo_library_rounded, color: ThixPolicy.primary),
                title: Text(
                  l10n.t('declare_pick_gallery'),
                  style: TextStyle(color: ThixPolicy.textMain),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ),
            if (_photo != null)
              Semantics(
                button: true,
                label: l10n.t('declare_remove_photo'),
                child: ListTile(
                  leading: const Icon(Icons.delete_rounded, color: ThixPolicy.danger),
                  title: Text(
                    l10n.t('declare_remove_photo'),
                    style: const TextStyle(color: ThixPolicy.danger),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _removePhoto();
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    debugPrint('[DeclareObjet] 📷 Picking image from ${source.name}');

    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1200,
        requestFullMetadata: false,
      );
      if (x == null) {
        debugPrint('[DeclareObjet] ℹ️ Pick cancelled');
        return;
      }

      final bytes = await x.readAsBytes();
      if (bytes.length > _kMaxPhotoSizeBytes) {
        if (!mounted) return;
        _showError(AppLocalizations.of(context).t('declare_photo_too_large'));
        return;
      }

      if (!mounted) return;
      setState(() {
        _photo = x;
        _photoBytes = bytes;
      });
      HapticFeedback.mediumImpact();
      debugPrint('[DeclareObjet] ✓ Photo selected: ${(bytes.length / 1024).toStringAsFixed(0)} KB');
    } catch (e, stack) {
      debugPrint('[DeclareObjet] ❌ Pick failed: $e');
      if (kDebugMode) {
        debugPrint('[DeclareObjet] Stack: ${stack.toString().split('\n').first}');
      }
      if (mounted) {
        _showError(AppLocalizations.of(context).t('declare_photo_error'));
      }
    }
  }

  void _removePhoto() {
    HapticFeedback.lightImpact();
    setState(() {
      _photo = null;
      _photoBytes = null;
    });
    debugPrint('[DeclareObjet] 🗑️ Photo removed');
  }

  // ─── SUBMISSION ────────────────────────────────────────────

  Future<void> _submit() async {
    // Throttling anti-double-tap
    final now = DateTime.now();
    if (_lastSubmit != null && now.difference(_lastSubmit!) < _kSubmitThrottle) {
      debugPrint('[DeclareObjet] ⏱️ Submit throttled');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      debugPrint('[DeclareObjet] ⚠️ Form validation failed');
      return;
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);

    // Validate contact format
    final contact = _contactCtrl.text.trim();
    if (contact.isNotEmpty && !_DeclareValidators.isValidContact(contact)) {
      _showError(l10n.t('declare_invalid_contact'));
      return;
    }

    // Validate reward if provided
    if (_isPerdu && !_DeclareValidators.isValidReward(_recompenseCtrl.text)) {
      _showError(l10n.t('declare_invalid_reward'));
      return;
    }

    _lastSubmit = now;
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final sanitizedTitle = _DeclareValidators.sanitize(_titreCtrl.text, maxLength: _kMaxTitleLength);
    final sanitizedDesc = _DeclareValidators.sanitize(_descCtrl.text, maxLength: _kMaxDescriptionLength);
    final sanitizedLieu = _DeclareValidators.sanitize(_lieuCtrl.text, maxLength: _kMaxLocationLength);
    final sanitizedReward = _isPerdu
        ? _DeclareValidators.sanitize(_recompenseCtrl.text, maxLength: _kMaxRewardLength)
        : null;
    final sanitizedContact = _DeclareValidators.sanitize(contact, maxLength: _kMaxContactLength);

    debugPrint('[DeclareObjet] 🚀 Submitting: ${_isPerdu ? "perdu" : "trouvé"}');

    try {
      final service = ref.read(objetServiceProvider);

      await service.declarerObjet(
        titre: sanitizedTitle,
        description: sanitizedDesc,
        statut: widget.type,
        lieu: sanitizedLieu,
        recompense: (_isPerdu && (sanitizedReward?.isNotEmpty ?? false))
            ? sanitizedReward
            : null,
        categorie: _categorie?.code,
        contactInfo: sanitizedContact.isEmpty ? null : sanitizedContact,
        photoBytes: _photoBytes,
        photoFileName: _photo?.name ?? 'photo.jpg',
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      debugPrint('[DeclareObjet] ✓ Declaration successful');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isPerdu
                      ? l10n.t('declare_success_lost')
                      : l10n.t('declare_success_found'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pop(context, true);
    } catch (e, stack) {
      debugPrint('[DeclareObjet] ❌ Submit failed: $e');
      if (kDebugMode) {
        debugPrint('[DeclareObjet] Stack: ${stack.toString().split('\n').first}');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        HapticFeedback.heavyImpact();
        _showError(l10n.t('declare_submit_error'));
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: ThixPolicy.textMain),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          _isPerdu
              ? l10n.t('declare_title_lost')
              : l10n.t('declare_title_found'),
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.textMain,
            fontWeight: ThixPolicy.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(l10n),
            const SizedBox(height: 24),
            _buildPhotoZone(l10n),
            const SizedBox(height: 20),
            _buildTitleField(l10n),
            const SizedBox(height: 16),
            _buildCategoryDropdown(l10n),
            const SizedBox(height: 16),
            _buildDescriptionField(l10n),
            const SizedBox(height: 16),
            _buildLocationField(l10n),
            const SizedBox(height: 16),
            if (_isPerdu) ...[
              _buildRewardField(l10n),
              const SizedBox(height: 16),
            ],
            _buildContactField(l10n),
            const SizedBox(height: 32),
            _buildSubmitButton(l10n),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _accentColor,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        ),
        child: Row(
          children: [
            Icon(
              _isPerdu ? Icons.search_rounded : Icons.inventory_2_rounded,
              color: ThixPolicy.textMain,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isPerdu
                    ? l10n.t('declare_header_lost')
                    : l10n.t('declare_header_found'),
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: ThixPolicy.textMain,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoZone(AppLocalizations l10n) {
    return Semantics(
      button: true,
      label: _photoBytes != null
          ? l10n.t('declare_change_photo')
          : l10n.t('declare_add_photo'),
      child: GestureDetector(
        onTap: _showPhotoPicker,
        child: Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            border: Border.all(color: ThixPolicy.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: _photoBytes != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_photoBytes!, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Semantics(
                        button: true,
                        label: l10n.t('declare_remove_photo'),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _removePhoto();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.t('declare_change_photo'),
                          style: ThixPolicy.captionStyle
                              .copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_rounded,
                        size: 40, color: ThixPolicy.textMuted),
                    const SizedBox(height: 10),
                    Text(
                      l10n.t('declare_add_photo'),
                      style: ThixPolicy.bodyStyle.copyWith(
                        color: ThixPolicy.textMain,
                        fontWeight: ThixPolicy.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.t('declare_photo_hint'),
                      style: ThixPolicy.captionStyle
                          .copyWith(color: ThixPolicy.textMuted),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTitleField(AppLocalizations l10n) {
    return _formField(
      label: l10n.t('declare_field_title'),
      required: true,
      child: Semantics(
        textField: true,
        label: l10n.t('declare_field_title'),
        child: TextFormField(
          controller: _titreCtrl,
          maxLength: _kMaxTitleLength,
          textInputAction: TextInputAction.next,
          style: TextStyle(color: ThixPolicy.textMain),
          decoration: _inputDecoration(l10n.t('declare_title_hint')),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? l10n.t('declare_title_required')
              : null,
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(AppLocalizations l10n) {
    return _formField(
      label: l10n.t('declare_field_category'),
      child: Semantics(
        label: l10n.t('declare_field_category'),
        child: DropdownButtonFormField<_ObjetCategory>(
          value: _categorie,
          isExpanded: true,
          dropdownColor: ThixPolicy.card,
          style: TextStyle(color: ThixPolicy.textMain, fontSize: 14),
          decoration: _inputDecoration(l10n.t('declare_category_hint')),
          items: _kCategories
              .map((c) => DropdownMenuItem<_ObjetCategory>(
                    value: c,
                    child: Row(
                      children: [
                        Icon(c.icon, size: 18, color: ThixPolicy.primary),
                        const SizedBox(width: 10),
                        Text(l10n.t(c.i18nKey),
                            style: TextStyle(color: ThixPolicy.textMain)),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() => _categorie = v);
          },
        ),
      ),
    );
  }

  Widget _buildDescriptionField(AppLocalizations l10n) {
    return _formField(
      label: l10n.t('declare_field_description'),
      required: true,
      child: Semantics(
        textField: true,
        label: l10n.t('declare_field_description'),
        child: TextFormField(
          controller: _descCtrl,
          maxLines: 4,
          maxLength: _kMaxDescriptionLength,
          textInputAction: TextInputAction.next,
          style: TextStyle(color: ThixPolicy.textMain),
          decoration: _inputDecoration(
            _isPerdu
                ? l10n.t('declare_desc_hint_lost')
                : l10n.t('declare_desc_hint_found'),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? l10n.t('declare_desc_required')
              : null,
        ),
      ),
    );
  }

  Widget _buildLocationField(AppLocalizations l10n) {
    return _formField(
      label: _isPerdu
          ? l10n.t('declare_field_location_lost')
          : l10n.t('declare_field_location_found'),
      required: true,
      child: Semantics(
        textField: true,
        label: l10n.t('declare_field_location_lost'),
        child: TextFormField(
          controller: _lieuCtrl,
          maxLength: _kMaxLocationLength,
          textInputAction: TextInputAction.next,
          style: TextStyle(color: ThixPolicy.textMain),
          decoration: _inputDecoration(l10n.t('declare_location_hint')),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? l10n.t('declare_location_required')
              : null,
        ),
      ),
    );
  }

  Widget _buildRewardField(AppLocalizations l10n) {
    return _formField(
      label: l10n.t('declare_field_reward'),
      child: Semantics(
        textField: true,
        label: l10n.t('declare_field_reward'),
        child: TextFormField(
          controller: _recompenseCtrl,
          maxLength: _kMaxRewardLength,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          style: TextStyle(color: ThixPolicy.textMain),
          decoration: _inputDecoration(l10n.t('declare_reward_hint')),
        ),
      ),
    );
  }

  Widget _buildContactField(AppLocalizations l10n) {
    return _formField(
      label: l10n.t('declare_field_contact'),
      child: Semantics(
        textField: true,
        label: l10n.t('declare_field_contact'),
        child: TextFormField(
          controller: _contactCtrl,
          maxLength: _kMaxContactLength,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          style: TextStyle(color: ThixPolicy.textMain),
          decoration: _inputDecoration(l10n.t('declare_contact_hint')),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(AppLocalizations l10n) {
    return RepaintBoundary(
      child: Semantics(
        button: true,
        enabled: !_isLoading,
        label: _isPerdu
            ? l10n.t('declare_button_lost')
            : l10n.t('declare_button_found'),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: ThixPolicy.textMain,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              ),
              elevation: 0,
              disabledBackgroundColor: _accentSoft,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    _isPerdu
                        ? l10n.t('declare_button_lost')
                        : l10n.t('declare_button_found'),
                    style: ThixPolicy.titleStyle.copyWith(
                      color: ThixPolicy.textMain,
                      fontWeight: ThixPolicy.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────

  Widget _formField({
    required String label,
    required Widget child,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Row(
            children: [
              Text(
                label,
                style: ThixPolicy.labelStyle.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
              if (required) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(color: ThixPolicy.danger, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      counterText: '',
      hintStyle: ThixPolicy.bodySmallStyle.copyWith(
        color: ThixPolicy.textMuted,
      ),
      filled: true,
      fillColor: ThixPolicy.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        borderSide: BorderSide(color: ThixPolicy.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        borderSide: BorderSide(color: ThixPolicy.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        borderSide: BorderSide(color: _accentColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        borderSide: const BorderSide(color: ThixPolicy.danger, width: 1.5),
      ),
      errorStyle: TextStyle(color: ThixPolicy.danger, fontSize: 12),
    );
  }
}
