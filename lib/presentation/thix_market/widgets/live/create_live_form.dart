// lib/presentation/thix_market/widgets/live/create_live_form.dart
// ============================================================================
// CREATE LIVE FORM — PROD Enterprise v2
// ============================================================================
// Fonctionnalités :
//   - Upload thumbnail (Supabase Storage)
//   - Token Agora avec fallback sécurisé
//   - Sélection catalogue produits (bibliothèque de base)
//   - Enchères (startingPrice + auctionEndTime)
//   - Vote interactif (spectateurs votent pour le prochain produit)
//   - Contrôle dynamique (hôte pin/unpin en direct)
//   - Pré-pin (produits épinglés automatiquement au démarrage)
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../pages/live_stream_page.dart';

// ============================================================================
// DESIGN TOKENS (Enterprise palette)
// ============================================================================
class _LiveFormPalette {
  static const Color navy = Color(0xFF1B2A4A);
  static const Color navy2 = Color(0xFF2D4373);
  static const Color gold = Color(0xFFC9962C);
  static const Color goldLight = Color(0xFFF5E6B8);
  static const Color danger = Color(0xFFE53935);
  static const Color success = Color(0xFF2E7D32);
  static const Color info = Color(0xFF0288D1);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textSub = Color(0xFF5B6B82);
  static const Color textMuted = Color(0xFF8A8FA3);
  static const Color bgApp = Color(0xFFF6F7FB);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSoft = Color(0xFFEEF2F6);
}

// ============================================================================
// LOGGER
// ============================================================================
class _FormLogger {
  static const _tag = 'CreateLiveForm';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);

  static void _log(String level, String msg, Map<String, dynamic>? data) {
    if (!kDebugMode && level == 'INFO') return;
    final d = data == null
        ? ''
        : ' ${data.entries.map((e) => '${e.key}=${e.value}').join(', ')}';
    debugPrint('[$_tag] [$level] $msg$d');
  }
}

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kQueryTimeout = Duration(seconds: 15);
const Duration _kUploadTimeout = Duration(seconds: 30);
const int _kMaxTitleLength = 100;
const int _kMaxDescriptionLength = 500;
const int _kMaxPrePinned = 6;

// ============================================================================
// FORM
// ============================================================================
class CreateLiveForm extends StatefulWidget {
  final String shopId;
  final Function(Map<String, dynamic>)? onSuccess;

  const CreateLiveForm({super.key, required this.shopId, this.onSuccess});

  @override
  State<CreateLiveForm> createState() => _CreateLiveFormState();
}

class _CreateLiveFormState extends State<CreateLiveForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // ── Thumbnail ──
  File? _thumbnail;
  final ImagePicker _picker = ImagePicker();

  // ── Catalogue produits ──
  List<Map<String, dynamic>> _availableProducts = [];
  bool _loadingProducts = true;
  List<String> _selectedProductIds = [];

  // ── Enchères ──
  bool _hasAuction = false;
  double _startingPrice = 0;
  DateTime? _auctionEndTime;

  // ── Vote interactif ──
  bool _allowVoting = true;

  // ── Contrôle dynamique (hôte pin/unpin en live) ──
  bool _allowDynamicControl = true;

  // ── Pré-pin (produits épinglés au démarrage) ──
  List<String> _prePinnedProductIds = [];

  bool _isLoading = false;

  // ============================================================================
  // LIFECYCLE
  // ============================================================================
  @override
  void initState() {
    super.initState();
    _loadProducts();
    _FormLogger.info('Form initialized', {'shopId': widget.shopId});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ============================================================================
  // DATA LOADING
  // ============================================================================
  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select('id, title, price, image_url')
          .eq('shop_id', widget.shopId)
          .eq('status', 'active')
          .timeout(_kQueryTimeout);
      if (!mounted) return;
      setState(() {
        _availableProducts = List<Map<String, dynamic>>.from(response);
        _loadingProducts = false;
      });
      _FormLogger.info('Products loaded', {'count': _availableProducts.length});
    } catch (e) {
      _FormLogger.error('loadProducts failed', {'error': '$e'});
      if (!mounted) return;
      setState(() => _loadingProducts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de charger les produits'),
          backgroundColor: _LiveFormPalette.danger,
        ),
      );
    }
  }

  // ============================================================================
  // THUMBNAIL
  // ============================================================================
  Future<void> _pickThumbnail() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => _thumbnail = File(image.path));
      }
    } catch (e) {
      _FormLogger.error('pickThumbnail failed', {'error': '$e'});
    }
  }

  Future<String?> _uploadThumbnail() async {
    if (_thumbnail == null) return null;
    try {
      final fileExt = _thumbnail!.path.split('.').last;
      final fileName = '${const Uuid().v4()}.$fileExt';
      final filePath = 'live_thumbnails/$fileName';

      await Supabase.instance.client.storage
          .from('live_images')
          .upload(filePath, _thumbnail!)
          .timeout(_kUploadTimeout);

      return Supabase.instance.client.storage
          .from('live_images')
          .getPublicUrl(filePath);
    } catch (e) {
      _FormLogger.error('uploadThumbnail failed', {'error': '$e'});
      rethrow;
    }
  }

  // ============================================================================
  // PRODUCT SELECTION (catalogue)
  // ============================================================================
  void _toggleProductSelection(String productId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
        _prePinnedProductIds.remove(productId);
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  void _togglePrePinned(String productId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_prePinnedProductIds.contains(productId)) {
        _prePinnedProductIds.remove(productId);
      } else {
        if (_prePinnedProductIds.length >= _kMaxPrePinned) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maximum $_kMaxPrePinned produits pré-épinglés'),
              backgroundColor: _LiveFormPalette.info,
            ),
          );
          return;
        }
        _prePinnedProductIds.add(productId);
      }
    });
  }

  // ============================================================================
  // SUBMIT
  // ============================================================================
  Future<void> _processLive({required bool startNow}) async {
    if (!_formKey.currentState!.validate()) return;

    // ── Validations métier ──
    if (_thumbnail == null) {
      _showWarning('Veuillez ajouter une miniature');
      return;
    }
    if (_selectedProductIds.isEmpty) {
      _showWarning('Sélectionnez au moins un produit à présenter');
      return;
    }
    if (_hasAuction && _startingPrice <= 0) {
      _showWarning('Veuillez définir un prix de départ valide');
      return;
    }
    if (_hasAuction && _auctionEndTime == null) {
      _showWarning('Veuillez définir une date de fin pour les enchères');
      return;
    }
    if (_hasAuction &&
        _auctionEndTime != null &&
        _auctionEndTime!.isBefore(DateTime.now())) {
      _showWarning('La date de fin des enchères doit être future');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── Upload thumbnail ──
      final thumbnailUrl = await _uploadThumbnail();

      // ── Token Agora ──
      final channelName = 'live_${DateTime.now().millisecondsSinceEpoch}';
      final userId = Supabase.instance.client.auth.currentUser?.id;

      String token;
      try {
        final tokenResponse = await Supabase.instance.client.functions
            .invoke(
              'generate-rtc-token',
              body: {'channelName': channelName},
            )
            .timeout(_kQueryTimeout);
        token = tokenResponse.data['token']?.toString() ?? '';
        if (token.isEmpty) throw Exception('Token Agora vide');
        _FormLogger.info('Agora token generated');
      } catch (e) {
        _FormLogger.warn('Agora token fallback', {'error': '$e'});
        token = 'test_token_${DateTime.now().millisecondsSinceEpoch}';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Token Agora de test (fonction indisponible)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // ── Timestamps ──
      final now = DateTime.now();
      final liveStatus = startNow ? 'live' : 'scheduled';
      final scheduledStart =
          startNow ? now : now.add(const Duration(minutes: 5));

      // ── Payload live_sessions ──
      final liveData = {
        'shop_id': widget.shopId,
        'host_id': userId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'thumbnail_url': thumbnailUrl,
        'channel_name': channelName,
        'token': token,
        'products': _selectedProductIds,
        'pre_pinned_products': _prePinnedProductIds, // ✅ NEW
        'allow_voting': _allowVoting, // ✅ NEW
        'allow_dynamic_control': _allowDynamicControl, // ✅ NEW
        'has_auction': _hasAuction,
        'starting_price': _hasAuction ? _startingPrice : null,
        'auction_end_time':
            _hasAuction ? _auctionEndTime?.toIso8601String() : null,
        'status': liveStatus,
        'source': 'market',
        'scheduled_start': scheduledStart.toIso8601String(),
        'started_at': startNow ? now.toIso8601String() : null,
        'created_at': now.toIso8601String(),
      };

      final response = await Supabase.instance.client
          .from('live_sessions')
          .insert(liveData)
          .select()
          .single()
          .timeout(_kQueryTimeout);

      _FormLogger.info('Live created', {
        'id': response['id'],
        'status': liveStatus,
        'products': _selectedProductIds.length,
        'prePinned': _prePinnedProductIds.length,
        'voting': _allowVoting,
        'dynamic': _allowDynamicControl,
      });

      widget.onSuccess?.call(response);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(startNow
              ? '🔴 Live lancé avec succès !'
              : '📅 Live programmé avec succès'),
          backgroundColor: _LiveFormPalette.success,
        ),
      );

      if (startNow) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LiveStreamPage(
              liveId: response['id'].toString(),
              channelName: channelName,
              token: token,
              isHost: true,
            ),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      _FormLogger.error('processLive failed', {'error': '$e'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${e.toString()}'),
            backgroundColor: _LiveFormPalette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  // ============================================================================
  // BUILD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroHeader(),
            const SizedBox(height: 20),
            _buildThumbnailSection(),
            const SizedBox(height: 20),
            _buildTitleSection(),
            const SizedBox(height: 16),
            _buildDescriptionSection(),
            const SizedBox(height: 24),
            _buildProductsSection(),
            if (_selectedProductIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPrePinnedSection(),
            ],
            const SizedBox(height: 24),
            _buildInteractiveFeaturesSection(),
            const SizedBox(height: 24),
            _buildAuctionSection(),
            const SizedBox(height: 32),
            _buildActionButtons(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ HERO HEADER ═══════════════════
  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_LiveFormPalette.navy, _LiveFormPalette.navy2],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _LiveFormPalette.navy.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _LiveFormPalette.gold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.live_tv_rounded,
                color: _LiveFormPalette.navy, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Créer un live shopping',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    )),
                const SizedBox(height: 2),
                Text('Diffusez, vendez, interagissez en direct',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════ THUMBNAIL ═══════════════════
  Widget _buildThumbnailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Miniature *', Icons.photo_library_rounded,
            _LiveFormPalette.info),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickThumbnail,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _LiveFormPalette.bgApp,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _LiveFormPalette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _thumbnail != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_thumbnail!, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: _pickThumbnail,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _LiveFormPalette.gold.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_photo_alternate_rounded,
                            size: 32, color: _LiveFormPalette.gold),
                      ),
                      const SizedBox(height: 10),
                      const Text('Ajouter une miniature',
                          style: TextStyle(
                              color: _LiveFormPalette.textSub,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      const Text('1280 × 720 recommandé',
                          style: TextStyle(
                              color: _LiveFormPalette.textMuted, fontSize: 11)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════ TITLE ═══════════════════
  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Titre *', Icons.title_rounded, _LiveFormPalette.navy2),
        const SizedBox(height: 6),
        TextFormField(
          controller: _titleController,
          maxLength: _kMaxTitleLength,
          decoration: InputDecoration(
            hintText: 'Ex: Vente flash mode été',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _LiveFormPalette.gold, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _LiveFormPalette.border),
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Champ requis';
            if (v.trim().length < 3) return 'Titre trop court (min. 3 caractères)';
            return null;
          },
        ),
      ],
    );
  }

  // ═══════════════════ DESCRIPTION ═══════════════════
  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(
            'Description', Icons.description_rounded, _LiveFormPalette.navy2),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          maxLength: _kMaxDescriptionLength,
          decoration: InputDecoration(
            hintText: 'Décrivez votre live...',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _LiveFormPalette.gold, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _LiveFormPalette.border),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════ PRODUCTS CATALOGUE ═══════════════════
  Widget _buildProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionLabel('Produits à présenter *',
                Icons.shopping_bag_rounded, _LiveFormPalette.navy2),
            const Spacer(),
            if (_selectedProductIds.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _LiveFormPalette.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${_selectedProductIds.length} sélectionné(s)',
                    style: const TextStyle(
                        color: _LiveFormPalette.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingProducts)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: _LiveFormPalette.gold),
          ))
        else if (_availableProducts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _LiveFormPalette.bgApp,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _LiveFormPalette.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 40, color: _LiveFormPalette.textMuted),
                const SizedBox(height: 10),
                const Text('Aucun produit disponible',
                    style: TextStyle(
                        color: _LiveFormPalette.textSub,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Ajoutez des produits à votre boutique',
                    style: TextStyle(
                        color: _LiveFormPalette.textMuted, fontSize: 12)),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _loadProducts,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Rafraîchir'),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableProducts.map((product) {
              final id = product['id'].toString();
              final isSelected = _selectedProductIds.contains(id);
              return FilterChip(
                label: Text(
                  product['title'] ?? 'Sans titre',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? _LiveFormPalette.navy
                        : _LiveFormPalette.textSub,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) => _toggleProductSelection(id),
                selectedColor: _LiveFormPalette.goldLight,
                backgroundColor: _LiveFormPalette.bgApp,
                checkmarkColor: _LiveFormPalette.navy,
                side: BorderSide(
                  color: isSelected
                      ? _LiveFormPalette.gold
                      : _LiveFormPalette.border,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                avatar: _productAvatar(product),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget? _productAvatar(Map<String, dynamic> product) {
    final url = product['image_url']?.toString();
    if (url == null || url.isEmpty) return null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 24,
        height: 24,
        fit: BoxFit.cover,
        placeholder: (_, __) => const SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: _LiveFormPalette.gold)),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.image, size: 16, color: _LiveFormPalette.textMuted),
      ),
    );
  }

  // ═══════════════════ PRE-PINNED ═══════════════════
  Widget _buildPrePinnedSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _LiveFormPalette.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _LiveFormPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _LiveFormPalette.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.push_pin_rounded,
                    size: 14, color: _LiveFormPalette.gold),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Produits pré-épinglés au démarrage',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _LiveFormPalette.textMain)),
              ),
              Text('${_prePinnedProductIds.length}/$_kMaxPrePinned',
                  style: const TextStyle(
                      color: _LiveFormPalette.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
              'Ces produits apparaîtront automatiquement dans le carousel dès le début du live.',
              style: TextStyle(
                  color: _LiveFormPalette.textMuted,
                  fontSize: 11,
                  height: 1.4)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedProductIds.map((id) {
              final product = _availableProducts.firstWhere(
                (p) => p['id'].toString() == id,
                orElse: () => <String, dynamic>{},
              );
              final isPrePinned = _prePinnedProductIds.contains(id);
              return GestureDetector(
                onTap: () => _togglePrePinned(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPrePinned
                        ? _LiveFormPalette.gold
                        : _LiveFormPalette.bgApp,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPrePinned
                          ? _LiveFormPalette.gold
                          : _LiveFormPalette.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPrePinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        size: 12,
                        color: isPrePinned
                            ? _LiveFormPalette.navy
                            : _LiveFormPalette.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        product['title']?.toString() ?? 'Produit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isPrePinned
                              ? _LiveFormPalette.navy
                              : _LiveFormPalette.textSub,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════ INTERACTIVE FEATURES ═══════════════════
  Widget _buildInteractiveFeaturesSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _LiveFormPalette.navy.withOpacity(0.04),
            _LiveFormPalette.navy2.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _LiveFormPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _LiveFormPalette.info.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 14, color: _LiveFormPalette.info),
              ),
              const SizedBox(width: 8),
              const Text('Fonctionnalités interactives',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _LiveFormPalette.textMain)),
            ],
          ),
          const SizedBox(height: 12),
          _FeatureToggle(
            icon: Icons.how_to_vote_rounded,
            iconColor: const Color(0xFF7C3AED),
            title: 'Vote interactif',
            subtitle:
                'Les spectateurs votent pour le prochain produit à présenter',
            value: _allowVoting,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _allowVoting = v);
            },
          ),
          const Divider(height: 24, color: _LiveFormPalette.borderSoft),
          _FeatureToggle(
            icon: Icons.tune_rounded,
            iconColor: const Color(0xFF059669),
            title: 'Contrôle dynamique',
            subtitle:
                'L\'hôte peut épingler / retirer des produits en direct',
            value: _allowDynamicControl,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _allowDynamicControl = v);
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════ AUCTION ═══════════════════
  Widget _buildAuctionSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _LiveFormPalette.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasAuction ? _LiveFormPalette.gold : _LiveFormPalette.border,
          width: _hasAuction ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _LiveFormPalette.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.gavel_rounded,
                    size: 14, color: _LiveFormPalette.gold),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Enchères',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _LiveFormPalette.textMain)),
              ),
              Switch(
                value: _hasAuction,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _hasAuction = v);
                },
                activeColor: _LiveFormPalette.gold,
              ),
            ],
          ),
          if (_hasAuction) ...[
            const SizedBox(height: 12),
            _sectionLabel('Prix de départ *', Icons.payments_rounded,
                _LiveFormPalette.navy2),
            const SizedBox(height: 6),
            TextFormField(
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: 'FCFA',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: _LiveFormPalette.gold, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: _LiveFormPalette.border),
                ),
              ),
              onChanged: (v) => _startingPrice = double.tryParse(v) ?? 0,
              validator: (v) => _hasAuction && (v == null || v.isEmpty)
                  ? 'Champ requis'
                  : null,
            ),
            const SizedBox(height: 14),
            _sectionLabel('Fin des enchères *', Icons.event_rounded,
                _LiveFormPalette.navy2),
            const SizedBox(height: 6),
            _AuctionDatePicker(
              value: _auctionEndTime,
              onTap: _pickAuctionEndTime,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAuctionEndTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(hours: 2)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (time == null) return;
    setState(() {
      _auctionEndTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // ═══════════════════ ACTIONS ═══════════════════
  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _processLive(startNow: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _LiveFormPalette.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              disabledBackgroundColor: _LiveFormPalette.danger.withOpacity(0.5),
            ),
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.circle, size: 14),
            label: Text(
              _isLoading ? 'Lancement...' : 'Lancer le live maintenant',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : () => _processLive(startNow: false),
            style: OutlinedButton.styleFrom(
              foregroundColor: _LiveFormPalette.gold,
              side: const BorderSide(color: _LiveFormPalette.gold, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.schedule_rounded, size: 18),
            label: const Text('Programmer pour plus tard',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  // ═══════════════════ HELPERS ═══════════════════
  Widget _sectionLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _LiveFormPalette.textMain,
                letterSpacing: -0.1)),
      ],
    );
  }
}

// ============================================================================
// FEATURE TOGGLE
// ============================================================================
class _FeatureToggle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FeatureToggle({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _LiveFormPalette.textMain)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11,
                        color: _LiveFormPalette.textSub,
                        height: 1.3)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _LiveFormPalette.gold,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// AUCTION DATE PICKER
// ============================================================================
class _AuctionDatePicker extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;

  const _AuctionDatePicker({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _LiveFormPalette.bgApp,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _LiveFormPalette.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_rounded,
                color: _LiveFormPalette.gold, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value != null
                    ? '${value!.day}/${value!.month}/${value!.year} à ${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}'
                    : 'Sélectionner une date et une heure',
                style: TextStyle(
                  color: value != null
                      ? _LiveFormPalette.textMain
                      : _LiveFormPalette.textMuted,
                  fontWeight:
                      value != null ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: _LiveFormPalette.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
