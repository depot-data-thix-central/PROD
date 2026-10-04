// lib/presentation/thix_market/pages/create_supermarket_page.dart
// ============================================================================
// CREATE SUPERMARKET PAGE — Production Enterprise
// ============================================================================
// Corrections :
//   ✅ Helper _smTr() pour i18n avec fallback (t() n'accepte pas `fallback:`)
//   ✅ Uint8List pour uploadImage
//   ✅ Validation + feedback UX + logs
// ============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_market/models/supermarket_models.dart';
import 'package:thix_id/services/supermarket_service.dart';

// ============================================================================
// I18N HELPER (fallback local, indépendant de AppLocalizations.t)
// ============================================================================
String _smTr(AppLocalizations l10n, String key, String fallback) {
  try {
    final v = l10n.t(key);
    return (v.isEmpty || v == key) ? fallback : v;
  } catch (_) {
    return fallback;
  }
}

// ============================================================================
// PAGE
// ============================================================================
class CreateSupermarketPage extends ConsumerStatefulWidget {
  const CreateSupermarketPage({super.key});

  @override
  ConsumerState<CreateSupermarketPage> createState() =>
      _CreateSupermarketPageState();
}

class _CreateSupermarketPageState extends ConsumerState<CreateSupermarketPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _service = SupermarketService();

  String? _city = 'Kinshasa';
  Uint8List? _logoBytes;
  Uint8List? _coverBytes;
  bool _submitting = false;

  static const List<String> _kCities = [
    'Kinshasa', 'Lubumbashi', 'Mbuji-Mayi', 'Kananga', 'Kisangani',
    'Bukavu', 'Goma', 'Matadi', 'Kolwezi', 'Likasi',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isLogo) async {
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _showError('Image trop volumineuse (max 5 Mo)');
        return;
      }
      setState(() {
        if (isLogo) {
          _logoBytes = bytes;
        } else {
          _coverBytes = bytes;
        }
      });
    } catch (e) {
      debugPrint('[CreateSupermarket] ❌ Pick image error: $e');
      _showError('Impossible de charger l\'image');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ThixPolicy.danger),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);

    try {
      String? logoUrl;
      String? coverUrl;
      if (_logoBytes != null) {
        logoUrl = await _service.uploadImage('logo.jpg', _logoBytes!);
      }
      if (_coverBytes != null) {
        coverUrl = await _service.uploadImage('cover.jpg', _coverBytes!);
      }

      final id = await _service.createSupermarket(
        name: _nameCtrl.text.trim(),
        city: _city!,
        address:
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        logoUrl: logoUrl,
        coverUrl: coverUrl,
      );

      await _service.createDefaultDepartments(id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Supermarché créé avec 12 rayons ✓'),
          backgroundColor: ThixPolicy.success,
        ),
      );
      context.pushReplacement('/market/supermarket/$id');
    } catch (e) {
      debugPrint('[CreateSupermarket] ❌ Submit error: $e');
      if (!mounted) return;
      _showError('Erreur : $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.primaryDeep,
        foregroundColor: Colors.white,
        title: Text(_smTr(l10n, 'sm_create_title', 'Créer un supermarché')),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Images ──
            Row(
              children: [
                _imagePicker(
                  bytes: _logoBytes,
                  isLogo: true,
                  label: _smTr(l10n, 'sm_logo', 'Logo'),
                  icon: Icons.storefront_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _imagePicker(
                    bytes: _coverBytes,
                    isLogo: false,
                    label: _smTr(l10n, 'sm_cover', 'Devanture'),
                    icon: Icons.photo_size_select_actual_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Nom ──
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText:
                    _smTr(l10n, 'sm_name', 'Nom du supermarché *'),
                filled: true,
                fillColor: ThixPolicy.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'Nom requis (3+ car.)' : null,
            ),
            const SizedBox(height: 14),

            // ── Ville ──
            DropdownButtonFormField<String>(
              value: _city,
              decoration: InputDecoration(
                labelText: _smTr(l10n, 'sm_city', 'Ville *'),
                filled: true,
                fillColor: ThixPolicy.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              items: _kCities
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _city = v),
            ),
            const SizedBox(height: 14),

            // ── Adresse ──
            TextFormField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                labelText: _smTr(l10n, 'sm_address', 'Adresse'),
                filled: true,
                fillColor: ThixPolicy.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // ── Description ──
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: _smTr(l10n, 'sm_desc', 'Description'),
                filled: true,
                fillColor: ThixPolicy.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // ── Aperçu rayons ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: ThixPolicy.primary.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.grid_view_rounded,
                          size: 16, color: ThixPolicy.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _smTr(l10n, 'sm_default_depts',
                              '12 rayons créés automatiquement'),
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: ThixPolicy.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kDefaultDepartments.map((d) {
                      final c = Color(0xFF000000 |
                          int.parse(
                              d.colorHex.replaceAll('#', ''),
                              radix: 16));
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.withOpacity(0.4)),
                        ),
                        child: Text(d.label,
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Submit ──
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _smTr(l10n, 'sm_create_btn',
                            'Créer le supermarché'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _imagePicker({
    required Uint8List? bytes,
    required bool isLogo,
    required String label,
    required IconData icon,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _pickImage(isLogo),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: bytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(bytes, fit: BoxFit.cover),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: ThixPolicy.textMuted, size: 26),
                    const SizedBox(height: 4),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 10.5,
                            color: ThixPolicy.textMuted,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
        ),
      ),
    );
  }
}
