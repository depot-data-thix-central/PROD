// lib/presentation/thix_market/widgets/selling/publish_announcement_form.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../l10n/market_strings.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kUploadTimeout = Duration(seconds: 30);
const Duration _kSubmitTimeout = Duration(seconds: 20);
const Duration _kRetryDelay = Duration(milliseconds: 400);

const int _kMaxImages = 10;
const int _kMaxFileSizeMB = 5;
const int _kImageMaxDim = 1280;
const int _kImageQuality = 82;

const int _kMaxTitleLength = 120;
const int _kMaxDescLength = 2000;
const int _kMaxBrandLength = 60;
const int _kMaxCityLength = 60;
const int _kMaxWarrantyMonths = 120;

const Set<String> _kAllowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic'};

// ============================================================================
// VALIDATEURS
// ============================================================================
class _AnnouncementValidators {
  _AnnouncementValidators._();

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

  static bool isValidExtension(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return _kAllowedExtensions.contains(ext);
  }

  static bool isValidFileSize(int bytes) => bytes <= _kMaxFileSizeMB * 1024 * 1024;

  static double? safePrice(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final cleaned = text.replaceAll(RegExp(r'[^\d.]'), '');
    final val = double.tryParse(cleaned);
    if (val == null || val < 0 || val.isNaN || val.isInfinite) return null;
    if (val > 999999999) return null;
    return val;
  }

  static int? safeStock(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final val = int.tryParse(text.replaceAll(RegExp(r'[^\d]'), ''));
    if (val == null || val < 0) return null;
    if (val > 999999) return null;
    return val;
  }

  static int? safeWarranty(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final val = int.tryParse(text.replaceAll(RegExp(r'[^\d]'), ''));
    if (val == null || val < 0 || val > _kMaxWarrantyMonths) return null;
    return val;
  }

  static String? friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('storage') || msg.contains('upload')) return 'Échec upload image. Réessayez.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = 1,
  Duration timeout = _kUploadTimeout,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[PublishForm] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[PublishForm] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[PublishForm] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class PublishAnnouncementForm extends StatefulWidget {
  final String? shopId;
  final Map<String, dynamic>? editAnnouncement;
  final Function(Map<String, dynamic>)? onSuccess;
  final VoidCallback? onDirty;

  const PublishAnnouncementForm({
    super.key,
    required this.shopId,
    this.editAnnouncement,
    this.onSuccess,
    this.onDirty,
  });

  @override
  State<PublishAnnouncementForm> createState() => _PublishAnnouncementFormState();
}

class _PublishAnnouncementFormState extends State<PublishAnnouncementForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _brandController = TextEditingController();
  final _customCityController = TextEditingController();
  final _warrantyController = TextEditingController();
  final _shippingCostController = TextEditingController();

  // Nouvelles images sélectionnées
  List<XFile> _selectedImages = [];
  final Map<String, Uint8List> _imageBytesCache = {};

  // URLs existantes conservées en mode édition
  List<String> _existingImageUrls = [];

  String? _category;
  String? _condition;
  String? _shippingType;
  String? _currency = 'CDF';
  String? _city;
  String _placement = 'normal';
  DateTime? _flashEndTime;
  bool _freeShipping = false;
  bool _isService = false;
  bool _isSubmitting = false;
  bool _isUploading = false;
  int _uploadProgress = 0;
  int _uploadTotal = 0;

  Position? _currentPosition;

  static const List<String> _categoryIds = [
    'fashion', 'electronics', 'home', 'services', 'vehicles',
    'realestate', 'food', 'beauty', 'sports',
  ];
  static const List<String> _conditionIds = ['new', 'like_new', 'good', 'fair'];
  static const List<String> _shippingTypeIds = ['delivery', 'pickup', 'both'];

  final List<String> _cities = [
    'Kinshasa', 'Lubumbashi', 'Mbuji-Mayi', 'Kananga', 'Kisangani',
    'Bukavu', 'Goma', 'Matadi', 'Kolwezi', 'Likasi', 'Autre',
  ];

  final ImagePicker _picker = ImagePicker();

  bool get _isEditMode => widget.editAnnouncement != null;

  @override
  void initState() {
    super.initState();
    debugPrint('[PublishForm] 📝 Init (edit=$_isEditMode, shop=${widget.shopId?.substring(0, widget.shopId != null && widget.shopId!.length > 8 ? 8 : 0)})');
    _getCurrentLocation();
    if (_isEditMode) _loadEditData();

    // Écouter changements pour onDirty
    _titleController.addListener(_markDirty);
    _descriptionController.addListener(_markDirty);
    _priceController.addListener(_markDirty);
    _discountPriceController.addListener(_markDirty);
    _stockController.addListener(_markDirty);
    _brandController.addListener(_markDirty);
    _customCityController.addListener(_markDirty);
    _warrantyController.addListener(_markDirty);
    _shippingCostController.addListener(_markDirty);
  }

  void _markDirty() {
    widget.onDirty?.call();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _discountPriceController.dispose();
    _stockController.dispose();
    _brandController.dispose();
    _customCityController.dispose();
    _warrantyController.dispose();
    _shippingCostController.dispose();
    debugPrint('[PublishForm] 👋 Disposed');
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
        );
        if (mounted) setState(() => _currentPosition = position);
        debugPrint('[PublishForm] 📍 Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');
      }
    } catch (e) {
      debugPrint('[PublishForm] ⚠️ Location error: $e');
    }
  }

  void _loadEditData() {
    final data = widget.editAnnouncement!;
    _titleController.text = data['title']?.toString() ?? '';
    _descriptionController.text = data['description']?.toString() ?? '';
    _priceController.text = (data['price'] ?? 0).toString();
    _discountPriceController.text = (data['discount_price'] ?? '').toString();
    _stockController.text = (data['stock'] ?? 0).toString();
    _brandController.text = data['brand']?.toString() ?? '';
    _warrantyController.text = (data['warranty_months'] ?? '').toString();
    _shippingCostController.text = (data['shipping_cost'] ?? '').toString();
    _category = data['category']?.toString();
    _condition = data['condition']?.toString();
    _shippingType = data['shipping_type']?.toString();
    _currency = data['currency']?.toString() ?? 'CDF';
    _freeShipping = data['free_shipping'] == true;
    _isService = data['is_service'] == true;

    if (data['expires_at'] != null) {
      _flashEndTime = DateTime.tryParse(data['expires_at'].toString());
    }

    // Charger images existantes
    final existingImages = data['images'];
    if (existingImages is List) {
      _existingImageUrls = existingImages
          .map((e) => e.toString())
          .where((e) => e.startsWith('http'))
          .toList();
    }

    final existingCity = data['city']?.toString();
    if (existingCity != null && _cities.contains(existingCity)) {
      _city = existingCity;
    } else if (existingCity != null && existingCity.isNotEmpty) {
      _city = 'Autre';
      _customCityController.text = existingCity;
    }

    if (data['is_flash_sale'] == true) {
      _placement = 'flash_sale';
    } else if (data['is_featured'] == true) {
      _placement = 'recommended';
    } else {
      _placement = 'normal';
    }

    debugPrint('[PublishForm] ✓ Loaded edit data: "${_titleController.text.substring(0, _titleController.text.length.clamp(0, 40))}"');
  }

  // ============================================================
  // IMAGE PICKING & COMPRESSION
  // ============================================================
  Future<void> _pickImages() async {
    HapticFeedback.selectionClick();
    final currentCount = _selectedImages.length + _existingImageUrls.length;
    final remaining = _kMaxImages - currentCount;

    if (remaining <= 0) {
      _showError('Maximum $_kMaxImages images atteint');
      return;
    }

    try {
      final images = await _picker.pickMultiImage(
        maxWidth: _kImageMaxDim.toDouble(),
        maxHeight: _kImageMaxDim.toDouble(),
        imageQuality: _kImageQuality,
        limit: remaining,
      );

      if (images == null || images.isEmpty) return;

      int addedCount = 0;
      int skippedCount = 0;

      for (final img in images) {
        // Validation extension
        if (!_AnnouncementValidators.isValidExtension(img.name)) {
          debugPrint('[PublishForm] ⚠️ Skipped ${img.name}: invalid extension');
          skippedCount++;
          continue;
        }

        try {
          Uint8List bytes = await img.readAsBytes();

          // Validation taille
          if (!_AnnouncementValidators.isValidFileSize(bytes.length)) {
            debugPrint('[PublishForm] ⚠️ Skipped ${img.name}: too large (${bytes.length} bytes)');
            skippedCount++;
            continue;
          }

          // Compression additionnelle (mobile seulement)
          if (!kIsWeb) {
            try {
              final compressed = await FlutterImageCompress.compressWithList(
                bytes,
                minWidth: _kImageMaxDim,
                minHeight: _kImageMaxDim,
                quality: _kImageQuality,
              );
              bytes = compressed;
            } catch (e) {
              debugPrint('[PublishForm] ⚠️ Compression failed for ${img.name}: $e');
            }
          }

          _imageBytesCache[img.path] = bytes;
          addedCount++;
        } catch (e) {
          debugPrint('[PublishForm] ❌ Read bytes error for ${img.path}: $e');
          skippedCount++;
        }
      }

      if (mounted) {
        setState(() => _selectedImages = [..._selectedImages, ...images.take(addedCount)]);
        widget.onDirty?.call();

        if (skippedCount > 0) {
          _showError('$skippedCount image(s) ignorée(s) (format/taille invalide)');
        }
        debugPrint('[PublishForm] 📸 Picked $addedCount images, skipped $skippedCount');
      }
    } catch (e) {
      debugPrint('[PublishForm] ❌ Pick images error: $e');
      _showError('Erreur lors de la sélection des images');
    }
  }

  Future<void> _removeImage(int index, {bool isNew = true}) async {
    HapticFeedback.selectionClick();
    setState(() {
      if (isNew) {
        final removed = _selectedImages.removeAt(index);
        _imageBytesCache.remove(removed.path);
      } else {
        _existingImageUrls.removeAt(index);
      }
    });
    widget.onDirty?.call();
  }

  // ============================================================
  // UPLOAD IMAGES
  // ============================================================
  Future<List<String>> _uploadImages() async {
    if (_selectedImages.isEmpty) return [];

    final urls = <String>[];
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadTotal = _selectedImages.length;
    });

    try {
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final bytes = _imageBytesCache[image.path] ?? await image.readAsBytes();

        String? mimeType = image.mimeType;
        if (mimeType == null) {
          final ext = image.path.split('.').last.toLowerCase();
          mimeType = _getContentTypeFromExt(ext);
        }
        final ext = _getExtensionFromMime(mimeType);
        final fileName = '${const Uuid().v4()}.$ext';
        final filePath = 'products/$fileName';

        await _withRetry(
          () => Supabase.instance.client.storage.from('product_images').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              cacheControl: '31536000',
              upsert: false,
            ),
          ),
          label: 'uploadImage[$i/${_selectedImages.length}]',
          maxRetries: 2,
        );

        final publicUrl = Supabase.instance.client.storage.from('product_images').getPublicUrl(filePath);
        urls.add(publicUrl);

        if (mounted) {
          setState(() => _uploadProgress = i + 1);
        }
      }
      debugPrint('[PublishForm] ✓ Uploaded ${urls.length} images');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
          _uploadTotal = 0;
        });
      }
    }
    return urls;
  }

  Future<void> _cleanupOrphans(List<String> urls) async {
    if (urls.isEmpty) return;
    try {
      final paths = urls
          .map((u) {
            final match = RegExp(r'/product_images/(.*)$').firstMatch(u);
            return match?.group(1);
          })
          .whereType<String>()
          .toList();
      if (paths.isNotEmpty) {
        await Supabase.instance.client.storage.from('product_images').remove(paths);
        debugPrint('[PublishForm] 🗑️ Cleaned ${paths.length} orphan images');
      }
    } catch (e) {
      debugPrint('[PublishForm] ⚠️ Cleanup error: $e');
    }
  }

  String _getExtensionFromMime(String? mimeType) {
    const map = {
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/gif': 'gif',
      'image/webp': 'webp',
      'image/heic': 'heic',
    };
    return map[mimeType] ?? 'jpg';
  }

  String _getContentTypeFromExt(String ext) {
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'heic': 'image/heic',
    };
    return map[ext] ?? 'image/jpeg';
  }

  // ============================================================
  // DATE PICKER
  // ============================================================
  Future<void> _pickDateTime() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: ThixPolicy.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(
              primary: ThixPolicy.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        ),
      );

      if (time != null) {
        final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        if (selected.isBefore(now.add(const Duration(minutes: 5)))) {
          _showError('La date doit être dans le futur');
          return;
        }
        setState(() => _flashEndTime = selected);
        widget.onDirty?.call();
      }
    }
  }

  // ============================================================
  // CITY RESOLVER
  // ============================================================
  String? _resolveCity() {
    if (_city == 'Autre') {
      final custom = _AnnouncementValidators.sanitize(
        _customCityController.text,
        maxLength: _kMaxCityLength,
      );
      return custom.isEmpty ? null : custom;
    }
    return _city;
  }

  // ============================================================
  // SUBMIT
  // ============================================================
  Future<void> _submitForm() async {
    if (_isSubmitting || _isUploading) return;

    final t = context.mkt;
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    // Validation : au moins une image (nouvelle ou existante)
    if (_selectedImages.isEmpty && _existingImageUrls.isEmpty) {
      _showError(t.atLeastOneImage);
      return;
    }

    final resolvedCity = _resolveCity();
    if (resolvedCity == null) {
      _showError(t.cityRequired);
      return;
    }

    // Validation prix
    final price = _AnnouncementValidators.safePrice(_priceController.text);
    if (price == null || price <= 0) {
      _showError('Prix invalide');
      return;
    }

    double? discountPrice;
    if (_discountPriceController.text.trim().isNotEmpty) {
      discountPrice = _AnnouncementValidators.safePrice(_discountPriceController.text);
      if (discountPrice == null || discountPrice <= 0) {
        _showError('Prix réduit invalide');
        return;
      }
      if (discountPrice >= price) {
        _showError('Le prix réduit doit être inférieur au prix normal');
        return;
      }
    }

    // Validation stock
    int? stock;
    if (!_isService) {
      stock = _AnnouncementValidators.safeStock(_stockController.text);
      if (stock == null) {
        _showError('Stock invalide');
        return;
      }
    }

    // Validation flash sale
    if (_placement == 'flash_sale') {
      if (_flashEndTime == null) {
        _showError(t.flashDateRequired);
        return;
      }
      if (_flashEndTime!.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
        _showError('La date flash doit être dans le futur');
        return;
      }
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    List<String> newUrls = [];

    try {
      // 1. Upload nouvelles images
      if (_selectedImages.isNotEmpty) {
        newUrls = await _uploadImages();
      }

      // 2. Combiner images existantes + nouvelles
      final allImageUrls = [..._existingImageUrls, ...newUrls];

      // 3. Sanitize tous les inputs
      final productData = {
        'shop_id': widget.shopId,
        'title': _AnnouncementValidators.sanitize(_titleController.text, maxLength: _kMaxTitleLength),
        'description': _AnnouncementValidators.sanitize(_descriptionController.text, maxLength: _kMaxDescLength),
        'price': price,
        'discount_price': discountPrice,
        'stock': stock ?? 0,
        'brand': _AnnouncementValidators.sanitize(_brandController.text, maxLength: _kMaxBrandLength).isEmpty
            ? null
            : _AnnouncementValidators.sanitize(_brandController.text, maxLength: _kMaxBrandLength),
        'category': _category,
        'condition': _condition,
        'shipping_type': _shippingType,
        'free_shipping': _freeShipping,
        'is_service': _isService,
        'currency': _currency,
        'city': resolvedCity,
        'is_flash_sale': _placement == 'flash_sale',
        'is_featured': _placement == 'recommended',
        'expires_at': _placement == 'flash_sale' ? _flashEndTime?.toIso8601String() : null,
        'images': allImageUrls,
        'image_url': allImageUrls.isNotEmpty ? allImageUrls.first : null,
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
        'updated_at': DateTime.now().toIso8601String(),
        'warranty_months': _AnnouncementValidators.safeWarranty(_warrantyController.text),
        'shipping_cost': _AnnouncementValidators.safePrice(_shippingCostController.text),
      };

      // 4. Submit to DB
      Map<String, dynamic> response;
      if (_isEditMode) {
        response = await _withRetry(
          () => Supabase.instance.client
              .from('products')
              .update(productData)
              .eq('id', widget.editAnnouncement!['id'])
              .select()
              .single(),
          label: 'updateAnnouncement',
          timeout: _kSubmitTimeout,
        );
        debugPrint('[PublishForm] ✅ Updated ${widget.editAnnouncement!['id']}');
      } else {
        productData['created_at'] = DateTime.now().toIso8601String();
        productData['status'] = 'active';
        response = await _withRetry(
          () => Supabase.instance.client
              .from('products')
              .insert(productData)
              .select()
              .single(),
          label: 'createAnnouncement',
          timeout: _kSubmitTimeout,
        );
        debugPrint('[PublishForm] ✅ Created ${response['id']}');
      }

      widget.onSuccess?.call(response);
    } catch (e) {
      debugPrint('[PublishForm] ❌ Submit error: $e');
      // Cleanup orphans si création a échoué
      if (newUrls.isNotEmpty) {
        await _cleanupOrphans(newUrls);
      }
      if (mounted) _showError(_AnnouncementValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ============================================================
  // FEEDBACK
  // ============================================================
  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
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

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final t = context.mkt;
    final isBusy = _isSubmitting || _isUploading;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PLACEMENT
          Text(t.placementTitle, style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
          const SizedBox(height: 12),
          _PlacementOption(
            value: 'normal',
            title: t.placementStandardTitle,
            subtitle: t.placementStandardDesc,
            icon: Icons.view_agenda_rounded,
            isSelected: _placement == 'normal',
            onChanged: (v) {
              setState(() => _placement = v);
              widget.onDirty?.call();
            },
            groupValue: _placement,
          ),
          const SizedBox(height: 8),
          _PlacementOption(
            value: 'recommended',
            title: t.placementHeroTitle,
            subtitle: t.placementHeroDesc,
            icon: Icons.branding_watermark_rounded,
            isSelected: _placement == 'recommended',
            onChanged: (v) {
              setState(() => _placement = v);
              widget.onDirty?.call();
            },
            groupValue: _placement,
          ),
          const SizedBox(height: 8),
          _PlacementOption(
            value: 'flash_sale',
            title: t.placementFlashTitle,
            subtitle: t.placementFlashDesc,
            icon: Icons.bolt_rounded,
            isSelected: _placement == 'flash_sale',
            onChanged: (v) {
              setState(() => _placement = v);
              widget.onDirty?.call();
            },
            groupValue: _placement,
          ),

          // FLASH DATE
          if (_placement == 'flash_sale') ...[
            const SizedBox(height: 16),
            _FlashSaleBanner(
              endTime: _flashEndTime,
              onPickDate: _pickDateTime,
            ),
          ],

          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),

          // PHOTOS
          Text(t.photosTitle, style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
          const SizedBox(height: 4),
          Text(
            '${_selectedImages.length + _existingImageUrls.length}/$_kMaxImages images',
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _existingImageUrls.length + _selectedImages.length + 1,
              itemBuilder: (context, index) {
                final totalExisting = _existingImageUrls.length;
                final totalSelected = _selectedImages.length;

                // Bouton ajouter
                if (index == totalExisting + totalSelected) {
                  final canAdd = (totalExisting + totalSelected) < _kMaxImages;
                  return Semantics(
                    button: true,
                    label: canAdd ? 'Ajouter une photo' : 'Maximum atteint',
                    enabled: canAdd && !isBusy,
                    child: GestureDetector(
                      onTap: canAdd && !isBusy ? _pickImages : null,
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: canAdd ? ThixPolicy.primary.withOpacity(0.05) : ThixPolicy.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: canAdd ? ThixPolicy.primary.withOpacity(0.3) : ThixPolicy.border,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded, size: 28, color: canAdd ? ThixPolicy.primary : ThixPolicy.textMuted),
                            const SizedBox(height: 6),
                            Text(
                              t.addPhoto,
                              style: ThixPolicy.captionStyle.copyWith(
                                color: canAdd ? ThixPolicy.primary : ThixPolicy.textMuted,
                                fontWeight: ThixPolicy.semiBold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Images existantes (edit mode)
                if (index < totalExisting) {
                  return _ImageThumbnail(
                    imageUrl: _existingImageUrls[index],
                    bytes: null,
                    onRemove: isBusy ? null : () => _removeImage(index, isNew: false),
                  );
                }

                // Nouvelles images
                final newIdx = index - totalExisting;
                final image = _selectedImages[newIdx];
                return _ImageThumbnail(
                  imageUrl: null,
                  bytes: _imageBytesCache[image.path],
                  onRemove: isBusy ? null : () => _removeImage(newIdx, isNew: true),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // TITLE
          _InputField(
            controller: _titleController,
            label: t.titleLabel,
            isRequired: true,
            maxLength: _kMaxTitleLength,
          ),
          const SizedBox(height: 16),

          // DESCRIPTION
          _InputField(
            controller: _descriptionController,
            label: t.descriptionLabel,
            isRequired: true,
            maxLines: 4,
            maxLength: _kMaxDescLength,
          ),
          const SizedBox(height: 16),

          // PRICE ROW
          Row(
            children: [
              Expanded(
                child: _InputField(
                  controller: _priceController,
                  label: t.priceLabel,
                  isRequired: true,
                  type: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InputField(
                  controller: _discountPriceController,
                  label: t.discountPriceLabel,
                  type: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // CURRENCY
          _CurrencyDropdown(
            value: _currency,
            onChanged: (v) {
              setState(() => _currency = v);
              widget.onDirty?.call();
            },
          ),
          const SizedBox(height: 16),

          // STOCK + BRAND
          Row(
            children: [
              Expanded(
                child: _InputField(
                  controller: _stockController,
                  label: t.stockLabel,
                  isRequired: !_isService,
                  type: TextInputType.number,
                  enabled: !_isService,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InputField(
                  controller: _brandController,
                  label: t.brandLabel,
                  maxLength: _kMaxBrandLength,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // CATEGORY
          _CategoryDropdown(
            value: _category,
            items: _categoryIds.map((id) => DropdownMenuItem(value: id, child: Text(t.categoryName(id)))).toList(),
            label: '${t.categoryLabel} *',
            onChanged: (v) {
              setState(() => _category = v);
              widget.onDirty?.call();
            },
          ),
          const SizedBox(height: 16),

          // CONDITION
          _CategoryDropdown(
            value: _condition,
            items: _conditionIds.map((id) => DropdownMenuItem(value: id, child: Text(t.conditionName(id)))).toList(),
            label: '${t.conditionLabel} *',
            onChanged: (v) {
              setState(() => _condition = v);
              widget.onDirty?.call();
            },
          ),
          const SizedBox(height: 16),

          // CITY
          _CategoryDropdown(
            value: _city,
            items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            label: '${t.cityLabel} *',
            onChanged: (v) {
              setState(() => _city = v);
              widget.onDirty?.call();
            },
          ),
          if (_city == 'Autre') ...[
            const SizedBox(height: 8),
            _InputField(
              controller: _customCityController,
              label: t.customCityLabel,
              isRequired: true,
              maxLength: _kMaxCityLength,
            ),
          ],
          const SizedBox(height: 16),

          // SHIPPING TYPE
          _CategoryDropdown(
            value: _shippingType,
            items: _shippingTypeIds.map((id) => DropdownMenuItem(value: id, child: Text(t.shippingTypeName(id)))).toList(),
            label: '${t.shippingTypeLabel} *',
            onChanged: (v) {
              setState(() => _shippingType = v);
              widget.onDirty?.call();
            },
          ),
          const SizedBox(height: 16),

          // SHIPPING COST + WARRANTY
          Row(
            children: [
              Expanded(
                child: _InputField(
                  controller: _shippingCostController,
                  label: t.shippingCostLabel,
                  type: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InputField(
                  controller: _warrantyController,
                  label: t.warrantyLabel,
                  type: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // SWITCHES
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: ThixPolicy.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Semantics(
                  toggled: _freeShipping,
                  label: t.freeShipping,
                  child: SwitchListTile(
                    title: Text(t.freeShipping, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold, fontSize: 14)),
                    value: _freeShipping,
                    onChanged: (v) {
                      setState(() => _freeShipping = v);
                      widget.onDirty?.call();
                    },
                    activeColor: ThixPolicy.primary,
                  ),
                ),
                Divider(height: 1, color: ThixPolicy.border),
                Semantics(
                  toggled: _isService,
                  label: t.isServiceTitle,
                  child: SwitchListTile(
                    title: Text(t.isServiceTitle, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold, fontSize: 14)),
                    subtitle: Text(t.isServiceDesc, style: ThixPolicy.captionStyle),
                    value: _isService,
                    onChanged: (v) {
                      setState(() => _isService = v);
                      widget.onDirty?.call();
                    },
                    activeColor: ThixPolicy.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // UPLOAD PROGRESS
          if (_isUploading) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadTotal > 0 ? _uploadProgress / _uploadTotal : null,
                    backgroundColor: ThixPolicy.border,
                    color: ThixPolicy.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload des images... $_uploadProgress/$_uploadTotal',
                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.semiBold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // SUBMIT BUTTON
          Semantics(
            button: true,
            label: isBusy ? 'Envoi en cours' : (_isEditMode ? t.update : t.publish),
            enabled: !isBusy,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isBusy ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ThixPolicy.primary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: isBusy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          const SizedBox(width: 12),
                          Text(
                            _isUploading ? 'Upload en cours...' : 'Envoi...',
                            style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold),
                          ),
                        ],
                      )
                    : Text(
                        _isEditMode ? t.update : t.publish,
                        style: ThixPolicy.titleStyle.copyWith(fontSize: 16, fontWeight: ThixPolicy.bold, color: Colors.white),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _PlacementOption extends StatelessWidget {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final ValueChanged<String> onChanged;
  final String groupValue;

  const _PlacementOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onChanged,
    required this.groupValue,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title, ${isSelected ? "sélectionné" : "non sélectionné"}',
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? ThixPolicy.primary.withOpacity(0.05) : ThixPolicy.card,
            border: Border.all(
              color: isSelected ? ThixPolicy.primary : ThixPolicy.border,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? ThixPolicy.primary : ThixPolicy.textMuted, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ThixPolicy.labelStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        color: isSelected ? ThixPolicy.primary : ThixPolicy.textMain,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                    ),
                  ],
                ),
              ),
              Radio<String>(
                value: value,
                groupValue: groupValue,
                activeColor: ThixPolicy.primary,
                onChanged: (v) => onChanged(v!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlashSaleBanner extends StatelessWidget {
  final DateTime? endTime;
  final VoidCallback onPickDate;

  const _FlashSaleBanner({required this.endTime, required this.onPickDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.gold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThixPolicy.gold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: ThixPolicy.gold, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.mkt.flashEndLabel,
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 13, color: ThixPolicy.gold),
                ),
                const SizedBox(height: 2),
                Text(
                  endTime == null
                      ? context.mkt.flashEndUnset
                      : DateFormat('dd MMM yyyy à HH:mm', Localizations.localeOf(context).languageCode).format(endTime!),
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    color: endTime == null ? ThixPolicy.textMuted : ThixPolicy.textMain,
                    fontWeight: endTime == null ? ThixPolicy.regular : ThixPolicy.bold,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Choisir la date',
            child: TextButton(
              onPressed: onPickDate,
              style: TextButton.styleFrom(foregroundColor: ThixPolicy.gold),
              child: Text(context.mkt.setDate, style: const TextStyle(fontWeight: ThixPolicy.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? bytes;
  final VoidCallback? onRemove;

  const _ImageThumbnail({required this.imageUrl, required this.bytes, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Image${onRemove != null ? ", bouton supprimer" : ""}',
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: ThixPolicy.surfaceSoft,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: bytes != null
                  ? Image.memory(bytes!, width: 100, height: 100, fit: BoxFit.cover)
                  : imageUrl != null
                      ? FadeInImage.memoryNetwork(
                          placeholder: kTransparentImage,
                          image: imageUrl!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          imageErrorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted, size: 32),
                          ),
                        )
                      : const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                          ),
                        ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 4,
              right: 12,
              child: Semantics(
                button: true,
                label: 'Supprimer cette image',
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
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
  final int maxLines;
  final bool isRequired;
  final TextInputType type;
  final int? maxLength;
  final bool enabled;

  const _InputField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.isRequired = false,
    this.type = TextInputType.text,
    this.maxLength,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      enabled: enabled,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: type,
        enabled: enabled,
        style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain),
        validator: isRequired
            ? (v) => v == null || v.trim().isEmpty ? context.mkt.required : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          counterText: '',
          filled: true,
          fillColor: enabled ? ThixPolicy.card : ThixPolicy.surfaceSoft,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            borderSide: const BorderSide(color: ThixPolicy.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ThixPolicy.danger),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ThixPolicy.border.withOpacity(0.5)),
          ),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final String label;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: ThixPolicy.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            borderSide: const BorderSide(color: ThixPolicy.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ThixPolicy.danger),
          ),
        ),
        dropdownColor: ThixPolicy.card,
        items: items,
        onChanged: onChanged,
        validator: (v) => v == null ? context.mkt.requiredField : null,
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _CurrencyDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.mkt.currencyLabel,
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.mkt.currencyLabel,
          filled: true,
          fillColor: ThixPolicy.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            borderSide: const BorderSide(color: ThixPolicy.primary, width: 2),
          ),
        ),
        dropdownColor: ThixPolicy.card,
        items: const [
          DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
          DropdownMenuItem(value: 'CDF', child: Text('CDF (FC)')),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

// Transparent pixel pour FadeInImage placeholder
final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
