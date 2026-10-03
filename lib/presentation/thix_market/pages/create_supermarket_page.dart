// lib/presentation/thix_market/pages/create_supermarket_page.dart
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

import 'supermarket_space_page.dart';

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
    final file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      if (isLogo) {
        _logoBytes = bytes;
      } else {
        _coverBytes = bytes;
      }
    });
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
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        logoUrl: logoUrl,
        coverUrl: coverUrl,
      );

      // Rayons par défaut (12 allées)
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: ThixPolicy.danger),
      );
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
        title: Text(l10n.t('sm_create_title', fallback: 'Créer un supermarché')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Images ─
            Row(
              children: [
                _imagePicker(
                  bytes: _logoBytes,
                  isLogo: true,
                  label: l10n.t('sm_logo', fallback: 'Logo'),
                  icon: Icons.storefront_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _imagePicker(
                    bytes: _coverBytes,
                    isLogo: false,
                    label: l10n.t('sm_cover', fallback: 'Devanture'),
                    icon: Icons.photo_size_select_actual_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Nom ──
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.t('sm_name', fallback: 'Nom du supermarché *'),
                filled: true,
                fillColor: ThixPolicy.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'Nom requis' : null,
            ),
            const SizedBox(height: 14),

            // ── Ville ──
            DropdownButtonFormField<String>(
              value: _city,
              decoration: InputDecoration(
                labelText: l10n.t('sm_city', fallback: 'Ville *'),
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

            // ── Adresse ─
            TextFormField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                labelText: l10n.t('sm_address', fallback: 'Adresse'),
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
              decoration: InputDecoration(
                labelText: l10n.t('sm_desc', fallback: 'Description'),
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
                      Text(
                        l10n.t('sm_default_depts',
                            fallback: '12 rayons créés automatiquement'),
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: ThixPolicy.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kDefaultDepartments
                        .map((d) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Color(
                                        0xFF000000 | int.parse(d.colorHex.replaceAll('#', ''), radix: 16))
                                    .withOpacity(0.4)),
                              ),
                              child: Text(d.label,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ))
                        .toList(),
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
                            strokeWidth: 2, color: Colors.white))
                    : Text(l10n.t('sm_create_btn',
                        fallback: 'Créer le supermarché'),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
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
          height: isLogo ? 100 : 100,
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
