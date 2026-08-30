// lib/presentation/thix_market/widgets/shops/manage_shop_widget.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kUploadTimeout = Duration(seconds: 30);
const Duration _kRetryDelay = Duration(milliseconds: 400);

const int _kMaxFileSizeMB = 5;
const int _kImageMaxDim = 1024;
const int _kImageQuality = 80;
const _kAllowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic'};

const int _kMaxNameLength = 100;
const int _kMaxDescLength = 1000;
const int _kMaxAddressLength = 200;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ShopValidators {
  _ShopValidators._();

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

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

    static bool isValidEmail(String? email) {
    if (email == null || email.trim().isEmpty) return true; // Optionnel
    // On utilise r"..." (guillemets doubles) pour éviter que l'apostrophe de la regex ne ferme la chaîne
    return RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$")
        .hasMatch(email.trim());
  }


  static bool isValidPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return true;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(cleaned);
  }

  static bool isValidExtension(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return _kAllowedExtensions.contains(ext);
  }

  static bool isValidFileSize(int bytes) => bytes <= _kMaxFileSizeMB * 1024 * 1024;
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = 1,
  Duration timeout = _kRequestTimeout,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[ManageShop] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[ManageShop] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[ManageShop] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class ManageShopWidget extends StatefulWidget {
  final String shopId;
  final Function(Map<String, dynamic>)? onUpdate;
  final VoidCallback? onDirty;

  const ManageShopWidget({
    super.key,
    required this.shopId,
    this.onUpdate,
    this.onDirty,
  });

  @override
  State<ManageShopWidget> createState() => _ManageShopWidgetState();
}

class _ManageShopWidgetState extends State<ManageShopWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic> _shop = {};
  bool _isLoading = true;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Sauvegardes initiales pour détection "dirty"
  late Map<String, dynamic> _initialState;

  // Nouvelles images
  XFile? _newLogoXFile;
  XFile? _newCoverXFile;
  Uint8List? _newLogoBytes;
  Uint8List? _newCoverBytes;
  String? _category;

  static const List<Map<String, String>> _categories = [
    {'id': 'fashion', 'name': 'Mode & Accessoires'},
    {'id': 'electronics', 'name': 'Électronique'},
    {'id': 'home', 'name': 'Maison & Jardin'},
    {'id': 'services', 'name': 'Services'},
    {'id': 'vehicles', 'name': 'Véhicules'},
    {'id': 'realestate', 'name': 'Immobilier'},
    {'id': 'food', 'name': 'Alimentation'},
    {'id': 'beauty', 'name': 'Beauté & Bien-être'},
    {'id': 'sports', 'name': 'Sports & Loisirs'},
    {'id': 'other', 'name': 'Autres'},
  ];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    debugPrint('[ManageShop] 🏪 Widget init for ${widget.shopId}');
    _loadShopData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    debugPrint('[ManageShop] 👋 Widget disposed');
    super.dispose();
  }

  // ============================================================
  // DATA LOADING
  // ============================================================
  Future<void> _loadShopData() async {
    setState(() => _isLoading = true);

    try {
      final response = await _withRetry(
        () => Supabase.instance.client
            .from('shops')
            .select()
            .eq('id', widget.shopId)
            .single(),
        label: 'loadShop',
      );

      _shop = response;
      _nameController.text = _shop['name'] ?? '';
      _descriptionController.text = _shop['description'] ?? '';
      _addressController.text = _shop['address'] ?? '';
      _phoneController.text = _shop['phone'] ?? '';
      _emailController.text = _shop['email'] ?? '';
      _category = _shop['category'];

      _initialState = _captureState();

      // Écouter changements pour onDirty
      _nameController.addListener(_checkDirty);
      _descriptionController.addListener(_checkDirty);
      _addressController.addListener(_checkDirty);
      _phoneController.addListener(_checkDirty);
      _emailController.addListener(_checkDirty);

      debugPrint('[ManageShop] ✓ Loaded shop: ${_shop['name']}');
    } catch (e) {
      debugPrint('[ManageShop] ❌ Load error: $e');
      if (mounted) _showError('Erreur de chargement de la boutique');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _captureState() => {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'category': _category,
        'hasNewLogo': _newLogoBytes != null,
        'hasNewCover': _newCoverBytes != null,
      };

  void _checkDirty() {
    if (!mounted || _isLoading) return;
    final current = _captureState();
    final dirty = current.keys.any((k) => current[k] != _initialState[k]);
    if (dirty) widget.onDirty?.call();
  }

  // ============================================================
  // IMAGE UPLOAD
  // ============================================================
  Future<String?> _uploadImage(Uint8List bytes, String filename, String folder) async {
    try {
      final ext = filename.split('.').last.toLowerCase();
      final path = '$folder/${const Uuid().v4()}.$ext';

      await _withRetry(
        () => Supabase.instance.client.storage
            .from('shop_images')
            .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg')),
        label: 'uploadImage[$folder]',
        timeout: _kUploadTimeout,
      );

      return Supabase.instance.client.storage.from('shop_images').getPublicUrl(path);
    } catch (e) {
      debugPrint('[ManageShop] ❌ Upload error: $e');
      return null;
    }
  }

  Future<void> _deleteOrphanImage(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final path = url.split('/shop_images/').last;
      await Supabase.instance.client.storage.from('shop_images').remove([path]);
      debugPrint('[ManageShop] 🗑️ Orphan image deleted: $path');
    } catch (e) {
      debugPrint('[ManageShop] ⚠️ Orphan delete failed: $e');
    }
  }

  // ============================================================
  // UPDATE SHOP
  // ============================================================
  Future<void> _updateShop() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      _showError('Veuillez corriger les erreurs du formulaire');
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    String? newLogoUrl;
    String? newCoverUrl;

    try {
      String? logoUrl = _shop['logo_url']?.toString();
      String? coverUrl = _shop['cover_url']?.toString();

      if (_newLogoBytes != null && _newLogoXFile != null) {
        newLogoUrl = await _uploadImage(_newLogoBytes!, _newLogoXFile!.name, 'logos');
        if (newLogoUrl != null) logoUrl = newLogoUrl;
      }

      if (_newCoverBytes != null && _newCoverXFile != null) {
        newCoverUrl = await _uploadImage(_newCoverBytes!, _newCoverXFile!.name, 'covers');
        if (newCoverUrl != null) coverUrl = newCoverUrl;
      }

      final response = await _withRetry(
        () => Supabase.instance.client
            .from('shops')
            .update({
              'name': _ShopValidators.sanitize(_nameController.text.trim(), maxLength: _kMaxNameLength),
              'description': _ShopValidators.sanitize(_descriptionController.text.trim(), maxLength: _kMaxDescLength),
              'category': _category,
              'address': _ShopValidators.sanitize(_addressController.text.trim(), maxLength: _kMaxAddressLength),
              'phone': _ShopValidators.sanitize(_phoneController.text.trim(), maxLength: 20),
              'email': _ShopValidators.sanitize(_emailController.text.trim(), maxLength: 100),
              'logo_url': logoUrl,
              'cover_url': coverUrl,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.shopId)
            .select()
            .single(),
        label: 'updateShop',
      );

      _shop = response;
      _initialState = _captureState();
      widget.onUpdate?.call(response);

      debugPrint('[ManageShop] ✅ Shop updated: ${_shop['name']}');
      if (mounted) _showSuccess('Boutique mise à jour avec succès');
    } catch (e) {
      debugPrint('[ManageShop] ❌ Update error: $e');

      // Cleanup orphans
      await _deleteOrphanImage(newLogoUrl);
      await _deleteOrphanImage(newCoverUrl);

      if (mounted) _showError('Erreur lors de la mise à jour');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================
  Future<void> _pickImage(bool isLogo) async {
    HapticFeedback.selectionClick();
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: _kImageQuality,
        maxWidth: _kImageMaxDim.toDouble(),
        maxHeight: _kImageMaxDim.toDouble(),
      );

      if (image == null) return;

      // Validation extension
      if (!_ShopValidators.isValidExtension(image.name)) {
        _showError('Format non supporté. Utilisez JPG, PNG, WebP ou HEIC.');
        return;
      }

      // Lecture bytes
      final bytes = await image.readAsBytes();

      // Validation taille
      if (!_ShopValidators.isValidFileSize(bytes.length)) {
        _showError('Image trop volumineuse (max ${_kMaxFileSizeMB}MB)');
        return;
      }

      // Compression (pas sur web, déjà fait par picker)
      Uint8List finalBytes = bytes;
      if (!kIsWeb) {
        try {
          final compressed = await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: _kImageMaxDim,
            minHeight: _kImageMaxDim,
            quality: _kImageQuality,
          );
          finalBytes = compressed;
          debugPrint('[ManageShop] 🗜️ Image compressed: ${bytes.length} → ${compressed.length} bytes');
        } catch (e) {
          debugPrint('[ManageShop] ⚠️ Compression failed: $e');
        }
      }

      setState(() {
        if (isLogo) {
          _newLogoXFile = image;
          _newLogoBytes = finalBytes;
        } else {
          _newCoverXFile = image;
          _newCoverBytes = finalBytes;
        }
      });
      _checkDirty();
    } catch (e) {
      debugPrint('[ManageShop] ❌ Pick image error: $e');
      _showError('Erreur lors de la sélection de l\'image');
    }
  }

  // ============================================================
  // DELETE SHOP
  // ============================================================
  Future<void> _confirmDelete() async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
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
              child: const Icon(Icons.warning_amber_rounded, color: ThixPolicy.danger, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Action irréversible',
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.danger),
              ),
            ),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer cette boutique ?\n\n'
          'Cette action supprimera TOUS les produits, commandes et données associées.',
          style: ThixPolicy.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Double confirmation : taper le nom
    final nameCtrl = TextEditingController();
    final typed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text('Confirmation finale', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tapez le nom de votre boutique pour confirmer :',
              style: ThixPolicy.bodyStyle,
            ),
            const SizedBox(height: 4),
            Text(
              '"${_shop['name'] ?? ''}"',
              style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: ThixPolicy.surfaceSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final match = nameCtrl.text.trim() == (_shop['name']?.toString().trim() ?? '');
              Navigator.pop(ctx, match);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();

    if (typed != true) {
      _showError('Le nom ne correspond pas');
      return;
    }

    try {
      await _withRetry(
        () => Supabase.instance.client.from('shops').delete().eq('id', widget.shopId),
        label: 'deleteShop',
      );
      debugPrint('[ManageShop] 🗑️ Shop deleted: ${widget.shopId}');
      if (mounted) {
        _showSuccess('Boutique supprimée');
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[ManageShop] ❌ Delete error: $e');
      _showError('Erreur lors de la suppression');
    }
  }

  // ============================================================
  // UI HELPERS
  // ============================================================
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return ThixPolicy.success;
      case 'pending':
        return ThixPolicy.gold;
      case 'suspended':
        return ThixPolicy.danger;
      default:
        return ThixPolicy.textMuted;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'pending':
        return 'En attente';
      case 'suspended':
        return 'Suspendue';
      default:
        return 'Inconnu';
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _SkeletonManage();
    }

    return Column(
      children: [
        _ShopPreview(
          shop: _shop,
          newLogoBytes: _newLogoBytes,
          newCoverBytes: _newCoverBytes,
          onPickLogo: () => _pickImage(true),
          onPickCover: () => _pickImage(false),
        ),
        TabBar(
          controller: _tabController,
          indicatorColor: ThixPolicy.primary,
          labelColor: ThixPolicy.primary,
          unselectedLabelColor: ThixPolicy.textSecondary,
          labelStyle: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
          tabs: const [
            Tab(text: 'Informations'),
            Tab(text: 'Images'),
            Tab(text: 'Avancé'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInfoTab(),
              _buildImagesTab(),
              _buildAdvancedTab(),
            ],
          ),
        ),
        _BottomSaveBar(
          isSaving: _isSaving,
          onSave: _updateShop,
        ),
      ],
    );
  }

  // ============================================================
  // INFO TAB
  // ============================================================
  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _InputField(
              controller: _nameController,
              label: 'Nom de la boutique *',
              icon: Icons.store_rounded,
              maxLength: _kMaxNameLength,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requis';
                if (v.length > _kMaxNameLength) return 'Trop long';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _CategoryDropdown(
              value: _category,
              onChanged: (v) {
                setState(() => _category = v);
                _checkDirty();
              },
            ),
            const SizedBox(height: 16),
            _InputField(
              controller: _descriptionController,
              label: 'Description',
              icon: Icons.description_rounded,
              maxLines: 4,
              maxLength: _kMaxDescLength,
            ),
            const SizedBox(height: 16),
            _InputField(
              controller: _addressController,
              label: 'Adresse',
              icon: Icons.location_on_rounded,
              maxLength: _kMaxAddressLength,
            ),
            const SizedBox(height: 16),
            _InputField(
              controller: _phoneController,
              label: 'Téléphone',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v != null && v.isNotEmpty && !_ShopValidators.isValidPhone(v)) {
                  return 'Numéro invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _InputField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v != null && v.isNotEmpty && !_ShopValidators.isValidEmail(v)) {
                  return 'Email invalide';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // IMAGES TAB
  // ============================================================
  Widget _buildImagesTab() {
    final logoUrl = _ShopValidators.sanitizeUrl(_shop['logo_url']?.toString());
    final coverUrl = _ShopValidators.sanitizeUrl(_shop['cover_url']?.toString());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ImagePickerBlock(
            title: 'Logo',
            subtitle: 'Format carré, min 512x512px',
            bytes: _newLogoBytes,
            remoteUrl: logoUrl,
            size: 140,
            aspectRatio: 1,
            onTap: () => _pickImage(true),
          ),
          const SizedBox(height: 24),
          _ImagePickerBlock(
            title: 'Bannière',
            subtitle: 'Format paysage, min 1500x500px',
            bytes: _newCoverBytes,
            remoteUrl: coverUrl,
            size: 180,
            aspectRatio: 3,
            onTap: () => _pickImage(false),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADVANCED TAB
  // ============================================================
  Widget _buildAdvancedTab() {
    final status = _shop['status']?.toString();
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final isVerified = _shop['is_verified'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.info_outline_rounded, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statut de la boutique',
                        style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusText,
                        style: ThixPolicy.captionStyle.copyWith(color: statusColor, fontWeight: ThixPolicy.semiBold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Vérification (read-only)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isVerified ? ThixPolicy.primary : ThixPolicy.textMuted).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isVerified ? Icons.verified_rounded : Icons.gpp_maybe_rounded,
                    color: isVerified ? ThixPolicy.primary : ThixPolicy.textMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVerified ? 'Boutique vérifiée' : 'Non vérifiée',
                        style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isVerified
                            ? 'Votre boutique bénéficie d\'un badge de confiance'
                            : 'La vérification augmente la confiance des acheteurs',
                        style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                      ),
                    ],
                  ),
                ),
                if (!isVerified)
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Demande de vérification envoyée à l\'équipe THIX'),
                          backgroundColor: ThixPolicy.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Text('Demander'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Statistiques rapides
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statistiques rapides',
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatMini(
                        label: 'Vues',
                        value: '${_shop['views'] ?? 0}',
                        icon: Icons.visibility_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatMini(
                        label: 'Abonnés',
                        value: '${_shop['followers'] ?? 0}',
                        icon: Icons.favorite_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatMini(
                        label: 'Note',
                        value: '${_shop['rating']?.toStringAsFixed(1) ?? '0.0'} ★',
                        icon: Icons.star_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Zone danger
          Text(
            'ZONE DANGEREUSE',
            style: ThixPolicy.microStyle.copyWith(
              color: ThixPolicy.danger,
              fontWeight: ThixPolicy.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: ThixPolicy.danger.withOpacity(0.03),
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(color: ThixPolicy.danger.withOpacity(0.2)),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: ThixPolicy.danger),
              title: Text(
                'Supprimer la boutique',
                style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.danger),
              ),
              subtitle: Text(
                'Cette action est irréversible',
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.danger.withOpacity(0.8)),
              ),
              onTap: _confirmDelete,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _ShopPreview extends StatelessWidget {
  final Map<String, dynamic> shop;
  final Uint8List? newLogoBytes;
  final Uint8List? newCoverBytes;
  final VoidCallback onPickLogo;
  final VoidCallback onPickCover;

  const _ShopPreview({
    required this.shop,
    required this.newLogoBytes,
    required this.newCoverBytes,
    required this.onPickLogo,
    required this.onPickCover,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = _ShopValidators.sanitizeUrl(shop['cover_url']?.toString());
    final logoUrl = _ShopValidators.sanitizeUrl(shop['logo_url']?.toString());

    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          // Cover
          GestureDetector(
            onTap: onPickCover,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ThixPolicy.primary, ThixPolicy.inkDeep],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (newCoverBytes != null)
                    Image.memory(newCoverBytes!, fit: BoxFit.cover)
                  else if (coverUrl != null)
                    CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover)
                  else
                    const Center(
                      child: Icon(Icons.store_rounded, size: 50, color: Colors.white54),
                    ),
                  // Overlay hover
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: Icon(Icons.photo_camera_rounded, color: Colors.white70, size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Logo
          Positioned(
            bottom: 0,
            left: 16,
            child: Semantics(
              button: true,
              label: 'Modifier le logo',
              child: GestureDetector(
                onTap: onPickLogo,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: ThixPolicy.card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: ThixPolicy.shadowSoft(opacity: 0.15),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (newLogoBytes != null)
                          Image.memory(newLogoBytes!, fit: BoxFit.cover)
                        else if (logoUrl != null)
                          CachedNetworkImage(
                            imageUrl: logoUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.store_rounded, color: ThixPolicy.textMuted, size: 40),
                          )
                        else
                          Container(
                            color: ThixPolicy.primary.withOpacity(0.1),
                            child: const Icon(Icons.store_rounded, size: 40, color: ThixPolicy.primary),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
      style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted),
        prefixIcon: Icon(icon, color: ThixPolicy.textMuted),
        filled: true,
        fillColor: ThixPolicy.card,
        counterText: '',
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
          borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          borderSide: const BorderSide(color: ThixPolicy.danger),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({required this.value, required this.onChanged});

  static const List<Map<String, String>> _categories = [
    {'id': 'fashion', 'name': 'Mode & Accessoires'},
    {'id': 'electronics', 'name': 'Électronique'},
    {'id': 'home', 'name': 'Maison & Jardin'},
    {'id': 'services', 'name': 'Services'},
    {'id': 'vehicles', 'name': 'Véhicules'},
    {'id': 'realestate', 'name': 'Immobilier'},
    {'id': 'food', 'name': 'Alimentation'},
    {'id': 'beauty', 'name': 'Beauté & Bien-être'},
    {'id': 'sports', 'name': 'Sports & Loisirs'},
    {'id': 'other', 'name': 'Autres'},
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: 'Catégorie',
        labelStyle: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted),
        prefixIcon: const Icon(Icons.category_rounded, color: ThixPolicy.textMuted),
        filled: true,
        fillColor: ThixPolicy.card,
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
          borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
        ),
      ),
      dropdownColor: ThixPolicy.card,
      items: _categories
          .map((c) => DropdownMenuItem<String>(
                value: c['id'],
                child: Text(c['name']!, style: ThixPolicy.bodyStyle),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ImagePickerBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final Uint8List? bytes;
  final String? remoteUrl;
  final double size;
  final double aspectRatio;
  final VoidCallback onTap;

  const _ImagePickerBlock({
    required this.title,
    required this.subtitle,
    required this.bytes,
    required this.remoteUrl,
    required this.size,
    required this.aspectRatio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
        const SizedBox(height: 2),
        Text(subtitle, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: 'Modifier $title',
          child: GestureDetector(
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: ThixPolicy.card,
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (bytes != null)
                        Image.memory(bytes!, fit: BoxFit.cover)
                      else if (remoteUrl != null)
                        CachedNetworkImage(imageUrl: remoteUrl!, fit: BoxFit.cover)
                      else
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded, size: 40, color: ThixPolicy.textMuted),
                            const SizedBox(height: 4),
                            Text('Modifier', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomSaveBar extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave;

  const _BottomSaveBar({required this.isSaving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Semantics(
          button: true,
          label: isSaving ? 'Sauvegarde en cours' : 'Sauvegarder les modifications',
          enabled: !isSaving,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isSaving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: ThixPolicy.primary.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSaving
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Sauvegarder les modifications',
                          style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: Colors.white),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatMini({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: ThixPolicy.primary),
          const SizedBox(height: 6),
          Text(value, style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain, fontSize: 15)),
          const SizedBox(height: 2),
          Text(label, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _SkeletonManage extends StatelessWidget {
  const _SkeletonManage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 200, color: Colors.grey.shade200),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(
              5,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
