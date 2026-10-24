// lib/presentation/thix_market/pages/create_local_product_page.dart
// ============================================================================
// FORMULAIRE PRODUIT LOCAL — suit la logique existante (_ProductFormSheet)
//  + champs locaux : secteur*, terroir, producteur, certifications
//  Insert dans `products` avec is_local = true  =>  espace dédié uniquement
// ============================================================================

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../core/local_sectors.dart';
import '../providers/local_market_providers.dart';

// ── Mêmes constantes que supermarket_manage_page (logique existante) ──
const Duration _kDbTimeout = Duration(seconds: 20);
const Duration _kUploadTimeout = Duration(seconds: 40);
const int _kMaxImages = 5;
const int _kMaxFileSizeMB = 5;
const int _kImageMaxDim = 1280;
const int _kImageQuality = 82;
const int _kMaxNameLength = 120;
const int _kMaxDescLength = 1000;
const String _kBucket = 'product_images';

class _LV {
  _LV._();
  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static double? parseDouble(String? t) {
    if (t == null) return null;
    final c = t.trim().replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
    if (c.isEmpty) return null;
    final v = double.tryParse(c);
    if (v == null || v.isNaN || v.isInfinite || v < 0 || v > 999999999) return null;
    return v;
  }

  static int? parseInt(String? t) {
    final c = (t ?? '').replaceAll(RegExp(r'[^\d]'), '');
    if (c.isEmpty) return null;
    final v = int.tryParse(c);
    if (v == null || v < 0 || v > 999999) return null;
    return v;
  }

  static bool isValidBarcode(String code) => RegExp(r'^\d{8,14}$').hasMatch(code);

  static String contentType(XFile f) {
    const byExt = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp', 'heic': 'image/heic'};
    final i = f.name.lastIndexOf('.');
    final e = i >= 0 ? f.name.substring(i + 1).toLowerCase() : '';
    if (byExt.containsKey(e)) return byExt[e]!;
    final mime = f.mimeType?.toLowerCase();
    if (mime != null && mime.startsWith('image/')) return mime;
    return 'image/jpeg';
  }

  static String extFromContentType(String ct) {
    const map = {'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic'};
    return map[ct] ?? 'jpg';
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('storage') || msg.contains('upload')) return 'Échec upload image. Réessayez.';
    if (msg.contains('is_local') || msg.contains('column') || msg.contains('does not exist')) {
      return 'Migration SQL "local_products" non appliquée sur Supabase.';
    }
    return 'Une erreur est survenue. Réessayez.';
  }
}

class _LocalUploadFailure implements Exception {
  final Object cause;
  _LocalUploadFailure(this.cause);
  @override
  String toString() => cause.toString();
}

class CreateLocalProductPage extends ConsumerStatefulWidget {
  const CreateLocalProductPage({super.key, this.shopId});
  final String? shopId;

  @override
  ConsumerState<CreateLocalProductPage> createState() => _CreateLocalProductPageState();
}

class _CreateLocalProductPageState extends ConsumerState<CreateLocalProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _promoPrice = TextEditingController();
  final _stock = TextEditingController();
  final _barcode = TextEditingController();
  final _terroir = TextEditingController();
  final _producer = TextEditingController();
  final _description = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _shopId;
  bool _shopResolved = false;

  String _currency = 'CDF';
  String _unit = 'pcs';
  String? _sector;
  final Set<String> _certs = {};
  bool _hasPromo = false;
  bool _perishable = false;
  DateTime? _expiry;

  final List<String> _existingUrls = [];
  final List<XFile> _newImages = [];
  final Map<String, Uint8List> _bytes = {};

  bool _saving = false;
  bool _uploading = false;
  int _progress = 0;
  int _total = 0;

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _shopId = widget.shopId;
    _resolveShop();
  }

  Future<void> _resolveShop() async {
    if (_shopId != null) {
      setState(() => _shopResolved = true);
      return;
    }
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid != null) {
        // ✅ FIX : liste + priorité boutique (fonctionne avec plusieurs shops)
        final me = await _db
            .from('shops')
            .select('id,type')
            .eq('owner_id', uid)
            .order('created_at', ascending: true)
            .limit(5)
            .timeout(_kDbTimeout);
        final list = List<Map<String, dynamic>>.from(me as List);
        if (list.isNotEmpty) {
          final pick = list.firstWhere(
            (s) => s['type']?.toString() != 'supermarket',
            orElse: () => list.first,
          );
          _shopId = pick['id']?.toString();
        }
      }
    } catch (e) {
      debugPrint('[LocalForm] ⚠️ shop resolve: $e');
    }
    if (mounted) setState(() => _shopResolved = true);
  }

  @override
  void dispose() {
    for (final c in [_name, _price, _promoPrice, _stock, _barcode, _terroir, _producer, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  String _t(String fr, String en, [String? sw]) {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'sw' && sw != null) return sw;
    return lang == 'fr' ? fr : en;
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating),
    );
  }

  // ─────────── IMAGES (même logique que l'existant) ───────────
  Future<void> _pickImages() async {
    HapticFeedback.selectionClick();
    final remaining = _kMaxImages - _existingUrls.length - _newImages.length;
    if (remaining <= 0) {
      _err('Maximum $_kMaxImages photos');
      return;
    }
    try {
      List<XFile> picked;
      if (remaining == 1) {
        final one = await _picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: _kImageMaxDim.toDouble(),
            maxHeight: _kImageMaxDim.toDouble(),
            imageQuality: _kImageQuality);
        picked = one == null ? [] : [one];
      } else {
        picked = await _picker.pickMultiImage(
            maxWidth: _kImageMaxDim.toDouble(),
            maxHeight: _kImageMaxDim.toDouble(),
            imageQuality: _kImageQuality,
            limit: remaining);
      }
      if (picked.isEmpty) return;
      final accepted = <XFile>[];
      int skipped = 0;
      for (final f in picked.take(remaining)) {
        try {
          final b = await f.readAsBytes();
          if (b.length > _kMaxFileSizeMB * 1024 * 1024) {
            skipped++;
            continue;
          }
          _bytes[f.path] = b;
          accepted.add(f);
        } catch (_) {
          skipped++;
        }
      }
      if (!mounted) return;
      setState(() => _newImages.addAll(accepted));
      if (skipped > 0) _err('$skipped image(s) ignorée(s) (> $_kMaxFileSizeMB Mo)');
    } catch (e) {
      debugPrint('[LocalForm] ❌ pick: $e');
      _err('Erreur lors de la sélection des photos');
    }
  }

  Future<List<String>> _uploadImages() async {
    if (_newImages.isEmpty) return [];
    final urls = <String>[];
    setState(() {
      _uploading = true;
      _progress = 0;
      _total = _newImages.length;
    });
    try {
      for (int i = 0; i < _newImages.length; i++) {
        final f = _newImages[i];
        final bytes = _bytes[f.path] ?? await f.readAsBytes();
        final ct = _LV.contentType(f);
        final path = 'products/local_${const Uuid().v4()}.${_LV.extFromContentType(ct)}';
        await _db.storage
            .from(_kBucket)
            .uploadBinary(path, bytes,
                fileOptions: FileOptions(contentType: ct, cacheControl: '31536000', upsert: false))
            .timeout(_kUploadTimeout);
        urls.add(_db.storage.from(_kBucket).getPublicUrl(path));
        if (mounted) setState(() => _progress = i + 1);
      }
    } catch (e) {
      throw _LocalUploadFailure(e);
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = 0;
          _total = 0;
        });
      }
    }
    return urls;
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (d != null) setState(() => _expiry = d);
  }

  // ─────────── SAUVEGARDE ───────────
  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }
    if (_shopId == null) {
      _err(_t('Boutique requise : créez d\'abord une boutique', 'Shop required: create a shop first'));
      return;
    }
    if (_sector == null) {
      _err(_t('Choisissez un secteur', 'Choose a sector'));
      return;
    }
    final price = _LV.parseDouble(_price.text);
    if (price == null || price <= 0) {
      _err('Prix invalide');
      return;
    }
    double? promo;
    if (_hasPromo) {
      promo = _LV.parseDouble(_promoPrice.text);
      if (promo == null || promo <= 0) {
        _err('Prix promo invalide');
        return;
      }
      if (promo >= price) {
        _err('Le prix promo doit être inférieur au prix normal');
        return;
      }
    }
    final stock = _LV.parseInt(_stock.text);
    if (stock == null) {
      _err('Quantité invalide');
      return;
    }
    final barcode = _barcode.text.trim();
    if (barcode.isNotEmpty && !_LV.isValidBarcode(barcode)) {
      _err('Code-barres invalide (8 à 14 chiffres)');
      return;
    }
    if (_perishable && _expiry == null) {
      _err('Choisissez la date d\'expiration');
      return;
    }
    if (_existingUrls.isEmpty && _newImages.isEmpty) {
      _err('Ajoutez au moins une photo');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    List<String> newUrls = [];
    bool saved = false;

    try {
      // 1. Barcode unique par boutique (logique existante)
      if (barcode.isNotEmpty) {
        try {
          final dup = await _db
              .from('products')
              .select('id,title')
              .eq('shop_id', _shopId!)
              .eq('barcode', barcode)
              .limit(1)
              .timeout(_kDbTimeout);
          if ((dup as List).isNotEmpty) {
            _err('Ce code-barres existe déjà dans votre boutique');
            return;
          }
        } catch (e) {
          debugPrint('[LocalForm] ⚠️ barcode check skipped: $e');
        }
      }

      // 2. Upload photos
      newUrls = await _uploadImages();
      final allUrls = [..._existingUrls, ...newUrls];

      // 3. Payload — colonnes existantes + colonnes locales
      final payload = <String, dynamic>{
        'shop_id': _shopId!,
        'title': _LV.sanitize(_name.text, maxLength: _kMaxNameLength),
        'description': _LV.sanitize(_description.text, maxLength: _kMaxDescLength),
        'price': price,
        'discount_price': _hasPromo ? promo : null,
        'stock': stock,
        'currency': _currency,
        'unit': _unit,
        'images': allUrls,
        'image_url': allUrls.first,
        'barcode': barcode.isEmpty ? null : barcode,
        'is_perishable': _perishable,
        'expiry_date': (_perishable && _expiry != null) ? DateFormat('yyyy-MM-dd').format(_expiry!) : null,
        // ── CHAMPS LOCAUX ──
        'is_local': true,
        'local_sector': _sector,
        'producer_name': _LV.sanitize(_producer.text, maxLength: 80).isEmpty
            ? null
            : _LV.sanitize(_producer.text, maxLength: 80),
        'terroir': _LV.sanitize(_terroir.text, maxLength: 80).isEmpty
            ? null
            : _LV.sanitize(_terroir.text, maxLength: 80),
        'certifications': _certs.toList(),
        // ── Champs requis par la table products (comme l'existant) ──
        'category': 'local',
        'condition': 'new',
        'status': 'active',
        'is_service': false,
        'free_shipping': false,
        'shipping_type': 'both',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Ville / pays hérités de la boutique (comme l'existant)
      try {
        final shop = await _db.from('shops').select('city,country').eq('id', _shopId!).maybeSingle().timeout(_kDbTimeout);
        final city = _LV.sanitize(shop?['city']?.toString(), maxLength: 60);
        final country = shop?['country']?.toString().trim() ?? '';
        if (city.isNotEmpty) payload['city'] = city;
        if (country.length == 2) payload['country'] = country.toUpperCase();
      } catch (_) {}

      await _db.from('products').insert(payload).select('id').single().timeout(_kDbTimeout);
      saved = true;

      if (mounted) {
        invalidateLocalProviders(ref);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('Produit local publié dans l\'espace dédié ✅', 'Local product published in the dedicated space ✅')),
            backgroundColor: kLocalGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on _LocalUploadFailure catch (e) {
      debugPrint('[LocalForm] ❌ upload: ${e.cause}');
      _err(_LV.friendlyError(e.cause));
    } catch (e) {
      debugPrint('[LocalForm] ❌ save: $e');
      _err('${_LV.friendlyError(e)}\n$e'.split('\n').take(2).join('\n'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ═══════════════════ UI ═══════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: kLocalGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t('Produit local', 'Local product', 'Bidhaa ya ndani'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(_t('Espace dédié — tous secteurs', 'Dedicated space — all sectors', 'Eneo maalum — sekta zote'),
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8))),
          ],
        ),
      ),
      body: !_shopResolved
          ? const Center(child: CircularProgressIndicator(color: kLocalGreen))
          : _shopId == null
              ? _buildNoShop()
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _buildPhotos(),
                      const SizedBox(height: 14),
                      _field(
                        controller: _name,
                        hint: '${_t('Nom du produit', 'Product name', 'Jina la bidhaa')} *',
                        validator: (v) => (v == null || v.trim().length < 2) ? 'Nom trop court' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              controller: _price,
                              hint: '${_t('Prix', 'Price', 'Bei')} *',
                              keyboard: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) => (_LV.parseDouble(v) ?? 0) <= 0 ? 'Prix invalide' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _dropdownCard(
                              label: _t('Devise', 'Currency', 'Sarafu'),
                              value: _currency,
                              items: const ['CDF', 'USD'],
                              onChanged: (v) => setState(() => _currency = v ?? 'CDF'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _dropdownCard(
                        label: '${_t('Secteur', 'Sector', 'Sekta')} *',
                        value: _sector,
                        hint: _t('Choisir un secteur', 'Choose a sector', 'Chagua sekta'),
                        items: kLocalSectors.map((s) => s.id).toList(),
                        labelOf: (id) {
                          final lang = Localizations.localeOf(context).languageCode;
                          final s = localSectorById(id);
                          return s?.label(lang) ?? id;
                        },
                        iconOf: (id) => localSectorById(id)?.icon,
                        onChanged: (v) {
                          setState(() {
                            _sector = v;
                            final s = localSectorById(v);
                            if (s != null) _unit = s.defaultUnit;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _dropdownCard(
                              label: '${_t('Unité de mesure', 'Unit', 'Kipimo')} *',
                              value: _unit,
                              items: kLocalUnits.map((u) => u['value']!).toList(),
                              labelOf: (v) => kLocalUnitLabel(v),
                              onChanged: (v) => setState(() => _unit = v ?? 'pcs'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              controller: _stock,
                              hint: '${_t('Quantité', 'Quantity', 'Kiasi')} *',
                              keyboard: TextInputType.number,
                              validator: (v) => _LV.parseInt(v) == null ? 'Quantité invalide' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t('Le prix affiché sera par ${kLocalUnitLabel(_unit)}',
                            'Displayed price will be per ${kLocalUnitLabel(_unit)}'),
                        style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 14),
                      _field(
                        controller: _producer,
                        hint: _t('Producteur / coopérative', 'Producer / cooperative', 'Mkulima / ushirika'),
                        prefixIcon: Icons.handshake_rounded,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _terroir,
                        hint: _t('Terroir / région d\'origine (ex : Kivu, RDC)', 'Origin region (e.g. Kivu, DRC)', 'Eneo asili (mf: Kivu, DRC)'),
                        prefixIcon: Icons.place_rounded,
                      ),
                      const SizedBox(height: 14),
                      _buildCerts(),
                      const SizedBox(height: 14),
                      _field(
                        controller: _barcode,
                        hint: _t('Code-barres', 'Barcode', 'Msimbo wa bidhaa'),
                        keyboard: TextInputType.number,
                        prefixIcon: Icons.qr_code_rounded,
                      ),
                      const SizedBox(height: 14),
                      _toggleCard(
                        icon: Icons.event_busy_rounded,
                        title: _t('Produit périssable', 'Perishable product', 'Bidhaa yenye mwisho'),
                        subtitle: _t('Définir une date d\'expiration', 'Set an expiry date', 'Weka tarehe ya mwisho'),
                        value: _perishable,
                        onChanged: (v) => setState(() {
                          _perishable = v;
                          if (!v) _expiry = null;
                        }),
                      ),
                      if (_perishable) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickExpiry,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: ThixPolicy.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: ThixPolicy.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: kLocalGreen),
                                const SizedBox(width: 10),
                                Text(
                                  _expiry != null
                                      ? DateFormat('dd/MM/yyyy').format(_expiry!)
                                      : _t('Choisir la date d\'expiration *', 'Pick expiry date *'),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _expiry != null ? ThixPolicy.textMain : ThixPolicy.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _toggleCard(
                        icon: Icons.local_offer_rounded,
                        title: _t('Promotion', 'Promotion', 'Promosheni'),
                        subtitle: _t('Afficher un prix réduit', 'Show a reduced price', 'Onyesha bei punguzwa'),
                        value: _hasPromo,
                        onChanged: (v) => setState(() => _hasPromo = v),
                      ),
                      if (_hasPromo) ...[
                        const SizedBox(height: 8),
                        _field(
                          controller: _promoPrice,
                          hint: '${_t('Prix promo', 'Promo price', 'Bei ya promosheni')} *',
                          keyboard: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _field(
                        controller: _description,
                        hint: _t('Description', 'Description', 'Maelezo'),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: (_saving || _uploading) ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kLocalGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _saving || _uploading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                    const SizedBox(width: 12),
                                    Text(_uploading ? 'Photos $_progress/$_total' : 'Enregistrement...'),
                                  ],
                                )
                              : Text(
                                  _t('Créer le produit local', 'Create local product', 'Unda bidhaa ya ndani'),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildNoShop() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, size: 56, color: kLocalGreen.withOpacity(0.5)),
            const SizedBox(height: 14),
            Text(_t('Une boutique est requise', 'A shop is required', 'Duka linahitajika'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain)),
            const SizedBox(height: 8),
            Text(_t('Créez votre boutique pour publier des produits locaux.',
                    'Create your shop to publish local products.', 'Fungua duka lako kuuza bidhaa za ndani.'),
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ThixPolicy.textSecondary)),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => context.push('/market/shop/create'),
              style: ElevatedButton.styleFrom(backgroundColor: kLocalGreen, foregroundColor: Colors.white),
              child: Text(_t('Créer ma boutique', 'Create my shop', 'Fungua duka')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotos() {
    final total = _existingUrls.length + _newImages.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_t('Photos', 'Photos', 'Picha')} ($total/$_kMaxImages) *',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textMain)),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: total + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              if (i == total) {
                return GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 92,
                    decoration: BoxDecoration(
                      color: kLocalGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kLocalGreen.withOpacity(0.4), width: 1.2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_rounded, color: kLocalGreen, size: 24),
                        const SizedBox(height: 4),
                        Text(_t('Ajouter', 'Add', 'Ongeza'),
                            style: const TextStyle(color: kLocalGreen, fontSize: 10.5, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                );
              }
              final isNew = i >= _existingUrls.length;
              return Stack(
                children: [
                  Container(
                    width: 92,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: ThixPolicy.card,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: isNew
                          ? Image.memory(_bytes[_newImages[i - _existingUrls.length].path]!, fit: BoxFit.cover)
                          : Image.network(_existingUrls[i], fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (isNew) {
                          _newImages.removeAt(i - _existingUrls.length);
                        } else {
                          _existingUrls.removeAt(i);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 12, color: ThixPolicy.danger),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCerts() {
    final lang = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_t('Labels & certifications', 'Labels & certifications', 'Vyeti'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textMain)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kLocalCertifications.map((c) {
            final on = _certs.contains(c.id);
            return FilterChip(
              selected: on,
              onSelected: (v) => setState(() => v ? _certs.add(c.id) : _certs.remove(c.id)),
              selectedColor: kLocalGreen.withOpacity(0.15),
              backgroundColor: ThixPolicy.card,
              side: BorderSide(color: on ? kLocalGreen : ThixPolicy.border),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(c.icon, size: 12, color: on ? kLocalGreen : ThixPolicy.textSecondary),
                  const SizedBox(width: 4),
                  Text(c.label(lang), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: on ? kLocalGreenDeep : ThixPolicy.textMain)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    int maxLines = 1,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 13.5, color: ThixPolicy.textMain, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: ThixPolicy.textMuted.withOpacity(0.85), fontSize: 13),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: ThixPolicy.textSecondary) : null,
        filled: true,
        fillColor: ThixPolicy.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: ThixPolicy.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: ThixPolicy.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kLocalGreen, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: ThixPolicy.danger)),
      ),
    );
  }

  Widget _dropdownCard({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String)? labelOf,
    IconData? Function(String)? iconOf,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary),
          border: InputBorder.none,
          isDense: true,
        ),
        hint: hint != null ? Text(hint, style: TextStyle(fontSize: 12.5, color: ThixPolicy.textMuted)) : null,
        items: items
            .map((id) => DropdownMenuItem(
                  value: id,
                  child: Row(
                    children: [
                      if (iconOf?.call(id) != null) ...[
                        Icon(iconOf!(id), size: 14, color: kLocalGreen),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(labelOf?.call(id) ?? id,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _toggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: kLocalGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: ThixPolicy.textMain)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: kLocalGreen),
        ],
      ),
    );
  }
}
