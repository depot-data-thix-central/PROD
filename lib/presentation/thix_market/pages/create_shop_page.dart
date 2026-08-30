// lib/presentation/thix_market/pages/create_shop_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/shop_provider.dart';
import '../providers/market_providers.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kUploadTimeout = Duration(seconds: 30);
const Duration _kCreateTimeout = Duration(seconds: 15);
const int _kMaxFileSizeMB = 5;
const int _kMaxNameLength = 100;
const int _kMaxDescLength = 500;
const int _kMaxAddressLength = 200;
const int _kImageQuality = 80;
const int _kImageMaxWidth = 1024;
const int _kImageMaxHeight = 1024;

const _kAllowedMimeTypes = {'image/jpeg', 'image/png', 'image/webp', 'image/heic'};
const _kAllowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic'};

// ============================================================================
// VALIDATEURS
// ============================================================================
class _CreateShopValidators {
  _CreateShopValidators._();

  /// Sanitize une chaîne pour prévenir XSS
  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  /// Validation email robuste (RFC 5322 simplifié)
  static bool isValidEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    final regex = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
);

    return regex.hasMatch(email.trim());
  }

  /// Validation téléphone international (E.164 simplifié)
  static bool isValidPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return true; // Optionnel
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(cleaned);
  }

  /// Validation taille fichier
  static bool isValidFileSize(int bytes) {
    return bytes <= _kMaxFileSizeMB * 1024 * 1024;
  }

  /// Validation extension
  static bool isValidExtension(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return _kAllowedExtensions.contains(ext);
  }

  /// Validation longueur
  static String? validateLength(String? value, int maxLength, String fieldName) {
    if (value != null && value.length > maxLength) {
      return '$fieldName trop long (max $maxLength caractères)';
    }
    return null;
  }
}

// ============================================================================
// PAGE
// ============================================================================
class CreateShopPage extends ConsumerStatefulWidget {
  const CreateShopPage({super.key});
  @override
  ConsumerState<CreateShopPage> createState() => _CreateShopPageState();
}

class _CreateShopPageState extends ConsumerState<CreateShopPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  XFile? _logo;
  Uint8List? _logoPreviewBytes;
  bool _loading = false;
  bool _uploading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    debugPrint('[CreateShop] 👋 Page disposed');
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.selectionClick();
    final picker = ImagePicker();

    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: _kImageQuality,
        maxWidth: _kImageMaxWidth.toDouble(),
        maxHeight: _kImageMaxHeight.toDouble(),
      );

      if (file == null) {
        debugPrint('[CreateShop] ⚠️ Image selection cancelled');
        return;
      }

      // Validation taille
      final bytes = await file.readAsBytes();
      if (!_CreateShopValidators.isValidFileSize(bytes.length)) {
        _showError('Image trop volumineuse (max ${_kMaxFileSizeMB}MB)');
        return;
      }

      // Validation extension
      if (!_CreateShopValidators.isValidExtension(file.name)) {
        _showError('Format non supporté. Utilisez JPG, PNG, WebP ou HEIC.');
        return;
      }

      // Compression (si pas déjà fait par picker)
      Uint8List? compressed;
      if (!kIsWeb) {
        try {
          compressed = await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: _kImageMaxWidth,
            minHeight: _kImageMaxHeight,
            quality: _kImageQuality,
          );
          debugPrint('[CreateShop] ✓ Image compressed: ${bytes.length} → ${compressed.length} bytes');
        } catch (e) {
          debugPrint('[CreateShop] ⚠️ Compression failed, using original: $e');
          compressed = bytes;
        }
      } else {
        compressed = bytes;
      }

      setState(() {
        _logo = file;
        _logoPreviewBytes = compressed;
      });

      debugPrint('[CreateShop] ✓ Image selected: ${file.name} (${compressed.length} bytes)');
    } catch (e) {
      debugPrint('[CreateShop] ❌ Pick image error: $e');
      _showError('Erreur lors de la sélection de l\'image');
    }
  }

  Future<String?> _uploadLogo() async {
    if (_logo == null || _logoPreviewBytes == null) return null;

    setState(() => _uploading = true);

    try {
      final db = ref.read(supabaseClientProvider);
      final uuid = const Uuid().v4();
      final ext = _logo!.name.split('.').last.toLowerCase();
      final path = 'shop-logos/$uuid.$ext';

      debugPrint('[CreateShop] 📤 Uploading logo to $path');

      await db.storage
          .from('shops')
          .uploadBinary(
            path,
            _logoPreviewBytes!,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          )
          .timeout(_kUploadTimeout);

      final url = db.storage.from('shops').getPublicUrl(path);
      debugPrint('[CreateShop] ✓ Logo uploaded: $url');
      return url;
    } on TimeoutException {
      debugPrint('[CreateShop] ❌ Upload timeout');
      throw Exception('Délai dépassé lors de l\'upload. Réessayez.');
    } catch (e) {
      debugPrint('[CreateShop] ❌ Upload error: $e');
      throw Exception('Erreur lors de l\'upload du logo');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteLogo(String url) async {
    try {
      final db = ref.read(supabaseClientProvider);
      final path = url.split('/shops/').last;
      await db.storage.from('shops').remove([path]);
      debugPrint('[CreateShop] 🗑️ Orphan logo deleted: $path');
    } catch (e) {
      debugPrint('[CreateShop] ⚠️ Failed to delete orphan logo: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    // Confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.store_rounded, color: ThixPolicy.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text('Créer la boutique ?', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold))),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir créer "${_nameCtrl.text.trim()}" ?',
          style: ThixPolicy.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    HapticFeedback.mediumImpact();
    setState(() => _loading = true);

    String? logoUrl;

    try {
      debugPrint('[CreateShop] 🏪 Creating shop "${_nameCtrl.text.trim()}"');

      // 1. Sanitize tous les inputs
      final name = _CreateShopValidators.sanitize(_nameCtrl.text.trim(), maxLength: _kMaxNameLength);
      final description = _CreateShopValidators.sanitize(_descCtrl.text.trim(), maxLength: _kMaxDescLength);
      final address = _CreateShopValidators.sanitize(_addressCtrl.text.trim(), maxLength: _kMaxAddressLength);
      final phone = _CreateShopValidators.sanitize(_phoneCtrl.text.trim(), maxLength: 20);
      final email = _CreateShopValidators.sanitize(_emailCtrl.text.trim(), maxLength: 100);

      // 2. Upload logo (si présent)
      if (_logo != null) {
        logoUrl = await _uploadLogo();
      }

      // 3. Créer la boutique
      final notifier = ref.read(currentShopProvider.notifier);
      final data = {
        'name': name,
        'description': description,
        'address': address,
        'phone': phone,
        'email': email,
      };

      if (logoUrl != null) data['logo_url'] = logoUrl;

      await notifier.createShopFromMap(data).timeout(_kCreateTimeout);

      debugPrint('[CreateShop] ✓ Shop created successfully');

      // 4. Invalider cache
      ref.invalidate(myShopsProvider);

      // 5. Feedback succès
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Boutique créée avec succès !'),
              ],
            ),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('[CreateShop] ❌ Create shop error: $e');

      // Cleanup : supprimer logo orphan si création a échoué
      if (logoUrl != null) {
        await _deleteLogo(logoUrl);
      }

      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          'Créer une boutique',
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
        ),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 20),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo picker
                Semantics(
                  button: true,
                  label: 'Sélectionner un logo',
                  child: Center(
                    child: GestureDetector(
                      onTap: _loading || _uploading ? null : _pickImage,
                      child: Container(
                        height: 110,
                        width: 110,
                        decoration: BoxDecoration(
                          color: ThixPolicy.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ThixPolicy.border),
                          boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
                        ),
                        child: _buildLogoPreview(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Nom
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _inputDecoration('Nom de la boutique *', Icons.store_rounded),
                  maxLength: _kMaxNameLength,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                      currentLength > maxLength! * 0.8
                          ? Text('$currentLength/$maxLength', style: ThixPolicy.captionStyle.copyWith(color: currentLength >= maxLength! ? ThixPolicy.danger : ThixPolicy.textMuted))
                          : null,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requis';
                    return _CreateShopValidators.validateLength(v, _kMaxNameLength, 'Nom');
                  },
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: _descCtrl,
                  decoration: _inputDecoration('Description', Icons.description_rounded),
                  maxLines: 3,
                  maxLength: _kMaxDescLength,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                      currentLength > maxLength! * 0.8
                          ? Text('$currentLength/$maxLength', style: ThixPolicy.captionStyle.copyWith(color: currentLength >= maxLength! ? ThixPolicy.danger : ThixPolicy.textMuted))
                          : null,
                  validator: (v) => _CreateShopValidators.validateLength(v, _kMaxDescLength, 'Description'),
                ),
                const SizedBox(height: 12),

                // Adresse
                TextFormField(
                  controller: _addressCtrl,
                  decoration: _inputDecoration('Adresse', Icons.location_on_rounded),
                  maxLength: _kMaxAddressLength,
                  validator: (v) => _CreateShopValidators.validateLength(v, _kMaxAddressLength, 'Adresse'),
                ),
                const SizedBox(height: 12),

                // Téléphone
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: _inputDecoration('Téléphone', Icons.phone_rounded),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && !_CreateShopValidators.isValidPhone(v)) {
                      return 'Numéro invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  decoration: _inputDecoration('Email', Icons.email_rounded),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && !_CreateShopValidators.isValidEmail(v)) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Submit button
                ElevatedButton(
                  onPressed: _loading || _uploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _loading || _uploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text(_uploading ? 'Upload du logo...' : 'Création...', style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_business_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text('Créer la boutique', style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoPreview() {
    if (_uploading) {
      return const Center(
        child: CircularProgressIndicator(color: ThixPolicy.primary),
      );
    }

    if (_logoPreviewBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(_logoPreviewBytes!, fit: BoxFit.cover),
      );
    }

    if (_logo != null && kIsWeb) {
      // Web : utiliser XFile.path comme URL
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(_logo!.path, fit: BoxFit.cover),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_rounded, size: 32, color: ThixPolicy.textMuted),
        const SizedBox(height: 6),
        Text('Logo', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: ThixPolicy.textMuted, size: 20),
      filled: true,
      fillColor: ThixPolicy.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ThixPolicy.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ThixPolicy.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ThixPolicy.danger),
      ),
      counterText: '',
    );
  }
}
