// lib/presentation/thix_market/widgets/live/create_live_form.dart
// ============================================================================
// CREATE LIVE FORM — Production Enterprise v5
// ----------------------------------------------------------------------------
//  • ✅ Compatible Web + Mobile (plus de dart:io, XFile partout)
//  • ✅ Support 54 devises africaines + conversion automatique
//  • ✅ Internationalisation FR / EN / SW
//  • ✅ Upload thumbnail via bytes (web-safe)
//  • ✅ Navigation via GoRouter (plus de Navigator.push)
//  • ✅ Validation robuste + feedback haptique
//  • ✅ Gestion erreurs avec messages traduits
// ============================================================================

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../../core/african_currencies.dart';
import '../../core/currency_service.dart';
import '../../providers/currency_provider.dart';

// ============================================================================
// DESIGN TOKENS
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
    final d = data == null ? '' : ' ${data.entries.map((e) => '${e.key}=${e.value}').join(', ')}';
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
const int _kImageMaxDim = 1280;
const int _kImageQuality = 85;

// ============================================================================
// FORM
// ============================================================================
class CreateLiveForm extends ConsumerStatefulWidget {
  final String shopId;
  final Function(Map<String, dynamic>)? onSuccess;

  const CreateLiveForm({super.key, required this.shopId, this.onSuccess});

  @override
  ConsumerState<CreateLiveForm> createState() => _CreateLiveFormState();
}

class _CreateLiveFormState extends ConsumerState<CreateLiveForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startingPriceController = TextEditingController();

  // ── Thumbnail (XFile pour compatibilité Web) ──
  XFile? _thumbnailFile;
  Uint8List? _thumbnailBytes;
  final ImagePicker _picker = ImagePicker();

  // ── Catalogue produits ──
  List<Map<String, dynamic>> _availableProducts = [];
  bool _loadingProducts = true;
  List<String> _selectedProductIds = [];

  // ── Enchères ──
  bool _hasAuction = false;
  DateTime? _auctionEndTime;

  // ── Vote interactif ──
  bool _allowVoting = true;

  // ── Contrôle dynamique ──
  bool _allowDynamicControl = true;

  // ── Pré-pin ──
  List<String> _prePinnedProductIds = [];

  bool _isLoading = false;

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
    _startingPriceController.dispose();
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
          .select('id, title, price, currency, image_url, images')
          .eq('shop_id', widget.shopId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
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
      _showError(AppLocalizations.of(context).t('live_form_load_products_error'));
    }
  }

  // ============================================================================
  // THUMBNAIL (Web-safe avec XFile + Uint8List)
  // ============================================================================
  Future<void> _pickThumbnail() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _kImageMaxDim.toDouble(),
        maxHeight: (_kImageMaxDim * 0.5625).toDouble(), // 16:9
        imageQuality: _kImageQuality,
      );
      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        setState(() {
          _thumbnailFile = image;
          _thumbnailBytes = bytes;
        });
        HapticFeedback.selectionClick();
      }
    } catch (e) {
      _FormLogger.error('pickThumbnail failed', {'error': '$e'});
      _showError(AppLocalizations.of(context).t('live_form_thumbnail_error'));
    }
  }

  Future<String?> _uploadThumbnail() async {
    if (_thumbnailBytes == null || _thumbnailFile == null) return null;
    try {
      final fileName = '${const Uuid().v4()}.jpg';
      final filePath = 'live_thumbnails/$fileName';

      await Supabase.instance.client.storage
          .from('live_images')
          .uploadBinary(filePath, _thumbnailBytes!, fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            cacheControl: '31536000',
            upsert: false,
          ))
          .timeout(_kUploadTimeout);

      return Supabase.instance.client.storage.from('live_images').getPublicUrl(filePath);
    } catch (e) {
      _FormLogger.error('uploadThumbnail failed', {'error': '$e'});
      rethrow;
    }
  }

  // ============================================================================
  // PRODUCT SELECTION
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
          _showWarning(AppLocalizations.of(context).t('live_form_max_prepinned', args: ['$_kMaxPrePinned']));
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
    final l10n = AppLocalizations.of(context);

    if (!_formKey.currentState!.validate()) return;

    if (_thumbnailBytes == null) {
      _showWarning(l10n.t('live_form_thumbnail_required'));
      return;
    }
    if (_selectedProductIds.isEmpty) {
      _showWarning(l10n.t('live_form_product_required'));
      return;
    }
    if (_hasAuction) {
      final price = double.tryParse(_startingPriceController.text.replaceAll(RegExp(r'[^\d.]'), ''));
      if (price == null || price <= 0) {
        _showWarning(l10n.t('live_form_auction_price_required'));
        return;
      }
      if (_auctionEndTime == null) {
        _showWarning(l10n.t('live_form_auction_date_required'));
        return;
      }
      if (_auctionEndTime!.isBefore(DateTime.now())) {
        _showWarning(l10n.t('live_form_auction_date_future'));
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final thumbnailUrl = await _uploadThumbnail();
      final channelName = 'live_${DateTime.now().millisecondsSinceEpoch}';
      final userId = Supabase.instance.client.auth.currentUser?.id;

      // Token Agora
      String token;
      try {
        final tokenResponse = await Supabase.instance.client.functions
            .invoke('generate-rtc-token', body: {'channelName': channelName, 'role': 'publisher'})
            .timeout(_kQueryTimeout);
        token = tokenResponse.data?['token']?.toString() ?? '';
        if (token.isEmpty) throw Exception('Token vide');
        _FormLogger.info('Agora token generated');
      } catch (e) {
        _FormLogger.warn('Agora token fallback', {'error': '$e'});
        token = 'test_token_${DateTime.now().millisecondsSinceEpoch}';
        if (mounted) _showWarning(l10n.t('live_form_token_fallback'));
      }

      final now = DateTime.now().toUtc();
      final liveStatus = startNow ? 'live' : 'scheduled';
      final scheduledStart = startNow ? now : now.add(const Duration(minutes: 5));
      final startingPrice = _hasAuction
          ? double.tryParse(_startingPriceController.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0
          : null;

      // Devise par défaut du shop (CDF)
      final auctionCurrency = 'CDF';

      final liveData = {
        'shop_id': widget.shopId,
        'host_id': userId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'thumbnail_url': thumbnailUrl,
        'channel_name': channelName,
        'token': token,
        'products': _selectedProductIds,
        'pre_pinned_products': _prePinnedProductIds,
        'allow_voting': _allowVoting,
        'allow_dynamic_control': _allowDynamicControl,
        'has_auction': _hasAuction,
        'starting_price': startingPrice,
        'auction_currency': _hasAuction ? auctionCurrency : null,
        'auction_end_time': _hasAuction ? _auctionEndTime?.toUtc().toIso8601String() : null,
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
      });

      widget.onSuccess?.call(response);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(startNow ? l10n.t('live_form_started_success') : l10n.t('live_form_scheduled_success')),
          backgroundColor: _LiveFormPalette.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (startNow) {
        // ✅ Navigation via GoRouter
        context.go('/market/live/${response['id']}', extra: {
          'channelName': channelName,
          'token': token,
          'isHost': true,
        });
      } else {
        context.pop();
      }
    } catch (e) {
      _FormLogger.error('processLive failed', {'error': '$e'});
      if (mounted) _showError('${l10n.t("common_error")}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: _LiveFormPalette.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================================
  // BUILD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final displayCurrencyCode = ref.watch(currencyProvider);
    final currencyService = CurrencyService.instance;
    final currencySymbol = AfricanCurrencies.byCode(displayCurrencyCode)?.symbol ?? 'FC';

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroHeader(l10n),
            const SizedBox(height: 20),
            _buildThumbnailSection(l10n),
            const SizedBox(height: 20),
            _buildTitleSection(l10n),
            const SizedBox(height: 16),
            _buildDescriptionSection(l10n),
            const SizedBox(height: 24),
            _buildProductsSection(l10n, displayCurrencyCode, currencyService, lang),
            if (_selectedProductIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPrePinnedSection(l10n),
            ],
            const SizedBox(height: 24),
            _buildInteractiveFeaturesSection(l10n),
            const SizedBox(height: 24),
            _buildAuctionSection(l10n, currencySymbol),
            const SizedBox(height: 32),
            _buildActionButtons(l10n),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ HERO HEADER ═══════════════════
  Widget _buildHeroHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_LiveFormPalette.navy, _LiveFormPalette.navy2]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _LiveFormPalette.navy.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _LiveFormPalette.gold, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.live_tv_rounded, color: _LiveFormPalette.navy, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('live_form_title'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                const SizedBox(height: 2),
                Text(l10n.t('live_form_subtitle'), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════ THUMBNAIL ═══════════════════
  Widget _buildThumbnailSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(l10n.t('live_form_thumbnail_label'), Icons.photo_library_rounded, _LiveFormPalette.info),
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: _thumbnailBytes != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(_thumbnailBytes!, fit: BoxFit.cover)),
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: _pickThumbnail,
                          child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle), child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16)),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _LiveFormPalette.gold.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.add_photo_alternate_rounded, size: 32, color: _LiveFormPalette.gold)),
                      const SizedBox(height: 10),
                      Text(l10n.t('live_form_add_thumbnail'), style: const TextStyle(color: _LiveFormPalette.textSub, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(l10n.t('live_form_thumbnail_hint'), style: const TextStyle(color: _LiveFormPalette.textMuted, fontSize: 11)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════ TITLE ═══════════════════
  Widget _buildTitleSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(l10n.t('live_form_title_field'), Icons.title_rounded, _LiveFormPalette.navy2),
        const SizedBox(height: 6),
        TextFormField(
          controller: _titleController,
          maxLength: _kMaxTitleLength,
          decoration: InputDecoration(
            hintText: l10n.t('live_form_title_hint'),
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _LiveFormPalette.gold, width: 2)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _LiveFormPalette.border)),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return l10n.t('common_required');
            if (v.trim().length < 3) return l10n.t('live_form_title_too_short');
            return null;
          },
        ),
      ],
    );
  }

  // ═══════════════════ DESCRIPTION ═══════════════════
  Widget _buildDescriptionSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(l10n.t('live_form_description_label'), Icons.description_rounded, _LiveFormPalette.navy2),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          maxLength: _kMaxDescriptionLength,
          decoration: InputDecoration(
            hintText: l10n.t('live_form_description_hint'),
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _LiveFormPalette.gold, width: 2)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _LiveFormPalette.border)),
          ),
        ),
      ],
    );
  }

  // ═══════════════════ PRODUCTS CATALOGUE ═══════════════════
  Widget _buildProductsSection(AppLocalizations l10n, String displayCurrencyCode, CurrencyService currencyService, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionLabel(l10n.t('live_form_products_label'), Icons.shopping_bag_rounded, _LiveFormPalette.navy2),
            const Spacer(),
            if (_selectedProductIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _LiveFormPalette.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text('${_selectedProductIds.length} ${l10n.t("live_form_selected")}', style: const TextStyle(color: _LiveFormPalette.gold, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingProducts)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: _LiveFormPalette.gold)))
        else if (_availableProducts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _LiveFormPalette.bgApp, borderRadius: BorderRadius.circular(12), border: Border.all(color: _LiveFormPalette.border)),
            child: Column(children: [
              const Icon(Icons.inventory_2_outlined, size: 40, color: _LiveFormPalette.textMuted),
              const SizedBox(height: 10),
              Text(l10n.t('live_form_no_products'), style: const TextStyle(color: _LiveFormPalette.textSub, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(l10n.t('live_form_no_products_hint'), style: const TextStyle(color: _LiveFormPalette.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              TextButton.icon(onPressed: _loadProducts, icon: const Icon(Icons.refresh_rounded, size: 16), label: Text(l10n.t('common_refresh'))),
            ]),
          )
        else
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _availableProducts.map((product) {
              final id = product['id'].toString();
              final isSelected = _selectedProductIds.contains(id);
              // Prix converti dans la devise d'affichage
              final sellerCurrency = (product['currency'] ?? 'CDF').toString().toUpperCase();
              final priceRaw = (product['price'] as num?)?.toDouble() ?? 0;
              final convertedPrice = currencyService.convert(priceRaw, from: sellerCurrency, to: displayCurrencyCode);
              final formattedPrice = currencyService.formatPrice(convertedPrice, currencyCode: displayCurrencyCode, lang: lang);

              return FilterChip(
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['title'] ?? l10n.t('live_form_untitled'), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: isSelected ? _LiveFormPalette.navy : _LiveFormPalette.textSub, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, fontSize: 12)),
                    if (priceRaw > 0)
                      Text(formattedPrice, style: TextStyle(color: isSelected ? _LiveFormPalette.gold : _LiveFormPalette.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
                selected: isSelected,
                onSelected: (_) => _toggleProductSelection(id),
                selectedColor: _LiveFormPalette.goldLight,
                backgroundColor: _LiveFormPalette.bgApp,
                checkmarkColor: _LiveFormPalette.navy,
                side: BorderSide(color: isSelected ? _LiveFormPalette.gold : _LiveFormPalette.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                avatar: _productAvatar(product),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget? _productAvatar(Map<String, dynamic> product) {
    String? url = product['image_url']?.toString();
    if ((url == null || url.isEmpty) && product['images'] is List) {
      final images = product['images'] as List;
      if (images.isNotEmpty) url = images.first.toString();
    }
    if (url == null || url.isEmpty) return null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url, width: 24, height: 24, fit: BoxFit.cover,
        placeholder: (_, __) => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _LiveFormPalette.gold)),
        errorWidget: (_, __, ___) => const Icon(Icons.image, size: 16, color: _LiveFormPalette.textMuted),
      ),
    );
  }

  // ═══════════════════ PRE-PINNED ═══════════════════
  Widget _buildPrePinnedSection(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _LiveFormPalette.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: _LiveFormPalette.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: _LiveFormPalette.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.push_pin_rounded, size: 14, color: _LiveFormPalette.gold)),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.t('live_form_prepinned_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _LiveFormPalette.textMain))),
            Text('${_prePinnedProductIds.length}/$_kMaxPrePinned', style: const TextStyle(color: _LiveFormPalette.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text(l10n.t('live_form_prepinned_desc'), style: const TextStyle(color: _LiveFormPalette.textMuted, fontSize: 11, height: 1.4)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _selectedProductIds.map((id) {
              final product = _availableProducts.firstWhere((p) => p['id'].toString() == id, orElse: () => <String, dynamic>{});
              final isPrePinned = _prePinnedProductIds.contains(id);
              return GestureDetector(
                onTap: () => _togglePrePinned(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPrePinned ? _LiveFormPalette.gold : _LiveFormPalette.bgApp,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isPrePinned ? _LiveFormPalette.gold : _LiveFormPalette.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isPrePinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, size: 12, color: isPrePinned ? _LiveFormPalette.navy : _LiveFormPalette.textMuted),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(product['title']?.toString() ?? l10n.t('live_form_product_fallback'), maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isPrePinned ? _LiveFormPalette.navy : _LiveFormPalette.textSub, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════ INTERACTIVE FEATURES ═══════════════════
  Widget _buildInteractiveFeaturesSection(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_LiveFormPalette.navy.withOpacity(0.04), _LiveFormPalette.navy2.withOpacity(0.02)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _LiveFormPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: _LiveFormPalette.info.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.auto_awesome_rounded, size: 14, color: _LiveFormPalette.info)),
            const SizedBox(width: 8),
            Text(l10n.t('live_form_interactive_title'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _LiveFormPalette.textMain)),
          ]),
          const SizedBox(height: 12),
          _FeatureToggle(
            icon: Icons.how_to_vote_rounded, iconColor: const Color(0xFF7C3AED),
            title: l10n.t('live_form_voting_title'), subtitle: l10n.t('live_form_voting_desc'),
            value: _allowVoting, onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _allowVoting = v); },
          ),
          const Divider(height: 24, color: _LiveFormPalette.borderSoft),
          _FeatureToggle(
            icon: Icons.tune_rounded, iconColor: const Color(0xFF059669),
            title: l10n.t('live_form_dynamic_title'), subtitle: l10n.t('live_form_dynamic_desc'),
            value: _allowDynamicControl, onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _allowDynamicControl = v); },
          ),
        ],
      ),
    );
  }

  // ═══════════════════ AUCTION ═══════════════════
  Widget _buildAuctionSection(AppLocalizations l10n, String currencySymbol) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _LiveFormPalette.bgCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _hasAuction ? _LiveFormPalette.gold : _LiveFormPalette.border, width: _hasAuction ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: _LiveFormPalette.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.gavel_rounded, size: 14, color: _LiveFormPalette.gold)),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.t('live_form_auction_title'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _LiveFormPalette.textMain))),
            Switch(value: _hasAuction, onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _hasAuction = v); }, activeColor: _LiveFormPalette.gold),
          ]),
          if (_hasAuction) ...[
            const SizedBox(height: 12),
            _sectionLabel(l10n.t('live_form_starting_price'), Icons.payments_rounded, _LiveFormPalette.navy2),
            const SizedBox(height: 6),
            TextFormField(
              controller: _startingPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0', suffixText: currencySymbol,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _LiveFormPalette.gold, width: 2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _LiveFormPalette.border)),
              ),
              validator: (v) => _hasAuction && (v == null || v.trim().isEmpty) ? l10n.t('common_required') : null,
            ),
            const SizedBox(height: 14),
            _sectionLabel(l10n.t('live_form_auction_end'), Icons.event_rounded, _LiveFormPalette.navy2),
            const SizedBox(height: 6),
            _AuctionDatePicker(value: _auctionEndTime, onTap: _pickAuctionEndTime, l10n: l10n),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAuctionEndTime() async {
    final date = await showDatePicker(
      context: context, initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(hours: 2)), lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 18, minute: 0));
    if (time == null || !mounted) return;
    setState(() => _auctionEndTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  // ═══════════════════ ACTIONS ═══════════════════
  Widget _buildActionButtons(AppLocalizations l10n) {
    return Column(children: [
      SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : () => _processLive(startNow: true),
          style: ElevatedButton.styleFrom(backgroundColor: _LiveFormPalette.danger, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0, disabledBackgroundColor: _LiveFormPalette.danger.withOpacity(0.5)),
          icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.circle, size: 14),
          label: Text(_isLoading ? l10n.t('live_form_launching') : l10n.t('live_form_start_now'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity, height: 52,
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : () => _processLive(startNow: false),
          style: OutlinedButton.styleFrom(foregroundColor: _LiveFormPalette.gold, side: const BorderSide(color: _LiveFormPalette.gold, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          icon: const Icon(Icons.schedule_rounded, size: 18),
          label: Text(l10n.t('live_form_schedule'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ),
    ]);
  }

  Widget _sectionLabel(String label, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _LiveFormPalette.textMain, letterSpacing: -0.1)),
    ]);
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

  const _FeatureToggle({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value), behavior: HitTestBehavior.opaque,
      child: Row(children: [
        Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: iconColor)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _LiveFormPalette.textMain)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: _LiveFormPalette.textSub, height: 1.3)),
        ])),
        Switch(value: value, onChanged: onChanged, activeColor: _LiveFormPalette.gold),
      ]),
    );
  }
}

// ============================================================================
// AUCTION DATE PICKER
// ============================================================================
class _AuctionDatePicker extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  const _AuctionDatePicker({required this.value, required this.onTap, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: _LiveFormPalette.bgApp, borderRadius: BorderRadius.circular(10), border: Border.all(color: _LiveFormPalette.border)),
        child: Row(children: [
          const Icon(Icons.event_rounded, color: _LiveFormPalette.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value != null ? DateFormat('dd/MM/yyyy HH:mm', lang).format(value!) : l10n.t('live_form_select_datetime'),
              style: TextStyle(color: value != null ? _LiveFormPalette.textMain : _LiveFormPalette.textMuted, fontWeight: value != null ? FontWeight.w700 : FontWeight.w500, fontSize: 13),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _LiveFormPalette.textMuted, size: 18),
        ]),
      ),
    );
  }
}
